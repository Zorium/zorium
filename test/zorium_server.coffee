should = require('clay-chai').should()
Rx = require 'rx-lite'
Promise = require 'promiz'

z = require '../src/zorium'

describe 'router', ->
  it 'creates express middleware', (done) ->
    statusCalled = false

    factory = ->
      z 'div', 'test'

    middleware = z.server.factoryToMiddleware factory
    res = {
      send: (html) ->
        html.should.be '<!DOCTYPE html><div>test</div>'
        statusCalled.should.be true
        done()
      status: (status) ->
        statusCalled = true
        status.should.be 200
        return res
    }
    middleware({url: '/'}, res, done)

  it 'supports redirects', (done) ->
    factory = ->
      render: ->
        throw new z.server.Redirect path: '/login'

    middleware = z.server.factoryToMiddleware factory
    middleware({
      url: '/'
      headers:
        cookie: 'foo=bar;'
    }, {
      redirect: (path) ->
        path.should.be '/login'
        done()
    }, done)

  it 'supports 404 errors', (done) ->
    statusCalled = false

    factory = ->
      render: ->
        z.server.setStatus 404
        z 'div', '404'

    middleware = z.server.factoryToMiddleware factory

    res = {
      send: (html) ->
        html.should.be '<!DOCTYPE html><div>404</div>'
        statusCalled.should.be true
        done()
      status: (status) ->
        statusCalled = true
        status.should.be 404
        return res
    }
    middleware({url: '/404'}, res, done)

  it 'supports 500 errors', (done) ->
    statusCalled = false

    factory = ->
      render: ->
        z.server.setStatus 500
        z 'div', '500'

    middleware = z.server.factoryToMiddleware factory
    res = {
      status: (status) ->
        statusCalled = true
        status.should.be 500
        return res
      send: (html) ->
        html.should.be '<!DOCTYPE html><div>500</div>'
        statusCalled.should.be true
        done()
    }

    middleware({url: '/500'}, res, done)

  it 'supports async redirects', (done) ->
    class Root
      constructor: ->
        @pending = new Rx.ReplaySubject(1)
        @state = z.state
          pending: @pending
      render: ->
        {pending} = @state.getValue()

        if pending
          throw new z.server.Redirect path: '/login'
        else
          @pending.onNext true

        z 'div', 'x'

    factory = ->
      new Root()

    middleware = z.server.factoryToMiddleware factory
    middleware({url: '/'}, {redirect: (path) ->
      path.should.be '/login'
      done()
    }, done)

  it 'manages cookies', (done) ->
    hasSetCookies = false

    factory = ->
      z.server.getCookie('preset').getValue().should.be 'abc'
      z.server.setCookie 'clientset', 'xyz', {domain: 'test.com'}
      z 'div', 'test'

    res =
      send: (html) ->
        hasSetCookies.should.be true
        html.should.be '<!DOCTYPE html><div>test</div>'
        done()
      status: (status) ->
        status.should.be 200
        return res
      cookie: (name, value, opts) ->
        hasSetCookies = true
        name.should.be 'clientset'
        value.should.be 'xyz'
        opts.domain.should.be 'test.com'

    middleware = z.server.factoryToMiddleware factory
    middleware
      url: '/'
      headers:
        cookie: 'preset=abc'
    , res, done

  it 'clears cookies from previous requests', (done) ->
    factory = ->
      should.not.exist z.server.getCookie('secret').getValue()
      z.server.setCookie 'secret', 'abc'
      z 'div', 'test'

    middleware = z.server.factoryToMiddleware factory

    res1 =
      send: (html) ->
        html.should.be '<!DOCTYPE html><div>test</div>'

        res2 =
          send: (html) ->
            html.should.be '<!DOCTYPE html><div>test</div>'
            done()
          status: (status) ->
            status.should.be 200
            return res2
          cookie: -> null

        middleware
          url: '/'
        , res2, done
      status: (status) ->
        status.should.be 200
        return res1
      cookie: -> null

    middleware
      url: '/'
    , res1, done

  it 'handles state errors', (done) ->
    pending = new Rx.BehaviorSubject(null)
    pending.onError new Error 'test'

    class Root
      constructor: ->
        @state = z.state
          pending: pending

      render: ->
        z 'div', 'test'

    factory = ->
      new Root()

    middleware = z.server.factoryToMiddleware factory
    res = {
      status: (status) ->
        return res
    }
    middleware {url: '/'}, res, (err) ->
      err.message.should.be 'test'
      done()

  it 'handles runtime errors', (done) ->
    factory = ->
      render: ->
        throw new Error 'test'

    middleware = z.server.factoryToMiddleware factory
    res = {
      status: (status) ->
        return res
    }
    middleware {url: '/'}, res, (err) ->
      err.message.should.be 'test'
      done()

  it 'gets request objects', (done) ->
    factoryCalled = false
    factory = ->
      factoryCalled = true
      req = z.server.getReq()
      req.url.should.be '/'
      z 'div', 'test'

    middleware = z.server.factoryToMiddleware factory
    res = {
      send: (html) ->
        factoryCalled.should.be true
        done()
      status: (status) ->
        status.should.be 200
        return res
    }
    middleware({url: '/'}, res, done)

  # FIXME
  # it 'times out requests after 250ms, using latest snapshot', (done) ->
  #   statusCalled = false
  #   timeoutCalled = false
  #   startTime = Date.now()
  #
  #   class Timeout
  #     constructor: ->
  #       @state = z.state
  #         oneHundredMs: Rx.Observable.fromPromise(
  #           new Promise (resolve) ->
  #             setTimeout ->
  #               resolve '100'
  #             , 100
  #         )
  #         never: Rx.Observable.empty()
  #     render: =>
  #       {oneHundredMs} = @state.getValue()
  #       oneHundredMs ?= ''
  #       z 'div', 'test ' + oneHundredMs
  #
  #   factory = ->
  #     new Timeout()
  #
  #   listener = ({req}) ->
  #     z.server.off 'timeout', listener
  #     req.url.should.be '/'
  #     timeoutCalled = true
  #   z.server.on 'timeout', listener
  #
  #   middleware = z.server.factoryToMiddleware factory
  #   res = {
  #     send: (html) ->
  #       (Date.now() - startTime).should.be.less.than 260
  #       (Date.now() - startTime).should.be.greater.than 249
  #       html.should.be '<!DOCTYPE html><div>test 100</div>'
  #       statusCalled.should.be true
  #       timeoutCalled.should.be true
  #       done()
  #     status: (status) ->
  #       statusCalled = true
  #       status.should.be 200
  #       return res
  #   }
  #   middleware({url: '/'}, res, done)
