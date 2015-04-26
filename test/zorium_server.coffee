should = require('clay-chai').should()
Rx = require 'rx-lite'

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
    middleware({url: '/'}, res)

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
    })

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
    })

  it 'manages cookies', (done) ->
    hasSetCookies = false

    factory = ->
      z.cookies.get('preset').getValue().should.be 'abc'
      z.cookies.set 'clientset', 'xyz', {domain: 'test.com'}
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
    , res
