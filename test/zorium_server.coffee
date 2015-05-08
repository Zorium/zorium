should = require('clay-chai').should()
Rx = require 'rx-lite'
Promise = require 'promiz'

z = require '../src/zorium'

describe 'server side rendering', ->
  it 'supports basic render to string', ->
    z.renderToString z 'div', 'test'
    .then (html) ->
      html.should.be '<div>test</div>'

  it 'propogates errors', ->
    class MoveAlong
      render: ->
        throw new z.server.Redirect path: '/'

    $move = new MoveAlong()
    z.renderToString $move
    .then ->
      throw new Error 'Expected error'
    , (err) ->
      (err instanceof z.server.Redirect).should.be true

  it 'supports async rendering to string', ->
    class Async
      constructor: ->
        @pending = new Rx.ReplaySubject(1)
        @state = z.state
          abc: @pending
      render: =>
        {abc} = @state.getValue()

        unless abc?
          @pending.onNext 'abc'

        z 'div', abc

    $async = new Async()
    z.renderToString $async
    .then (html) ->
      html.should.be '<div>abc</div>'

  # it 'handles state errors', (done) ->
  #   pending = new Rx.BehaviorSubject(null)
  #   pending.onError new Error 'test'
  #
  #   class Root
  #     constructor: ->
  #       @state = z.state
  #         pending: pending
  #
  #     render: ->
  #       z 'div', 'test'
  #
  #   factory = ->
  #     new Root()
  #
  #   middleware = z.server.factoryToMiddleware factory
  #   res = {
  #     status: (status) ->
  #       return res
  #   }
  #   middleware {url: '/'}, res, (err) ->
  #     err.message.should.be 'test'
  #     done()
  #
  # it 'handles runtime errors', (done) ->
  #   factory = ->
  #     render: ->
  #       throw new Error 'test'
  #
  #   middleware = z.server.factoryToMiddleware factory
  #   res = {
  #     status: (status) ->
  #       return res
  #   }
  #   middleware {url: '/'}, res, (err) ->
  #     err.message.should.be 'test'
  #     done()
  #
  # it 'gets request objects', (done) ->
  #   factoryCalled = false
  #   factory = ->
  #     factoryCalled = true
  #     req = z.server.getReq()
  #     req.url.should.be '/'
  #     z 'div', 'test'
  #
  #   middleware = z.server.factoryToMiddleware factory
  #   res = {
  #     send: (html) ->
  #       factoryCalled.should.be true
  #       done()
  #     status: (status) ->
  #       status.should.be 200
  #       return res
  #   }
  #   middleware({url: '/'}, res, done)
  #
  # it 'supports concurrent requests', (done) ->
  #   fastResCalled = false
  #
  #   class Slow
  #     constructor: ->
  #       @state = z.state
  #         slow: Rx.Observable.fromPromise(
  #           new Promise (resolve) ->
  #             setTimeout ->
  #               resolve 'slow'
  #             , 20
  #         )
  #     render: ->
  #       z 'div', 'slow'
  #
  #   class Fast
  #     render: ->
  #       z 'div', 'fast'
  #
  #   class Root
  #     constructor: ->
  #       @state = z.state
  #         $slow: new Slow()
  #         $fast: new Fast()
  #     render: ({path}) =>
  #       {$slow, $fast} = @state.getValue()
  #
  #       if path is '/slow'
  #         return $slow
  #       else
  #         return $fast
  #
  #   factory = ->
  #     new Root()
  #
  #   middleware = z.server.factoryToMiddleware factory
  #
  #   slowRes = {
  #     send: (html) ->
  #       html.should.be '<!DOCTYPE html><div>slow</div>'
  #       fastResCalled.should.be true
  #       done()
  #     status: (status) ->
  #       return slowRes
  #   }
  #   fastRes = {
  #     send: (html) ->
  #       html.should.be '<!DOCTYPE html><div>fast</div>'
  #       fastResCalled = true
  #     status: (status) ->
  #       return fastRes
  #   }
  #   # TODO: check that status doesnt persist from slow
  #   middleware({url: '/slow'}, slowRes, done)
  #   middleware({url: '/'}, fastRes, done)

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
