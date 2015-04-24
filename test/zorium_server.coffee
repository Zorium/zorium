should = require('clay-chai').should()
Rx = require 'rx-lite'

z = require '../src/zorium'

describe 'router', ->
  it 'creates express middleware', (done) ->
    factory = ->
      z 'div', 'test'

    middleware = z.factoryToMiddleware factory
    middleware({url: '/'}, {send: (html) ->
      html.should.be '<!DOCTYPE html><div>test</div>'
      done()
    })

  it 'supports redirects', (done) ->
    factory = ->
      render: ->
        throw new z.server.Redirect path: '/login'

    middleware = z.factoryToMiddleware factory
    middleware({
      url: '/'
      headers:
        cookie: 'foo=bar;'
    }, {redirect: (path) ->
      path.should.be '/login'
      done()
    })

  it 'supports 404 errors', (done) ->
    status = 200
    factory = ->
      render: ->
        tree = z 'div', '404'
        throw new z.server.Error({status: 404, tree})

    middleware = z.factoryToMiddleware factory
    res = {
      status: (_status) ->
        status = _status
        return res
      send: (html) ->
        html.should.be '<!DOCTYPE html><div>404</div>'
        status.should.be 404
        done()
    }

    middleware({url: '/404'}, res, -> done(new Error 'next()'))

  it 'supports 500 errors', (done) ->
    status = 200
    factory = ->
      render: ->
        tree = z 'div', '500'
        throw new z.server.Error({status: 500, tree})

    middleware = z.factoryToMiddleware factory
    res = {
      status: (_status) ->
        status = _status
        return res
      send: (html) ->
        html.should.be '<!DOCTYPE html><div>500</div>'
        status.should.be 500
        done()
    }

    middleware({url: '/404'}, res, -> done(new Error 'next()'))

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

    middleware = z.factoryToMiddleware factory
    middleware({url: '/'}, {redirect: (path) ->
      path.should.be '/login'
      done()
    })

  it 'manages cookies', (done) ->
    hasSetCookies = false

    factory = ->
      z.server.getCookie('preset').getValue().should.be 'abc'
      z.server.setCookie 'clientset', 'xyz', {domain: 'test.com'}
      z 'div', 'test'

    middleware = z.factoryToMiddleware factory
    middleware
      url: '/'
      headers:
        cookie: 'preset=abc'
    ,
      send: (html) ->
        hasSetCookies.should.be true
        html.should.be '<!DOCTYPE html><div>test</div>'
        done()
      cookie: (name, value, opts) ->
        hasSetCookies = true
        name.should.be 'clientset'
        value.should.be 'xyz'
        opts.domain.should.be 'test.com'
