should = require('clay-chai').should()
Rx = require 'rx-lite'
Promise = require 'bluebird'

z = require '../src/zorium'

beforeEach (done) ->
  # Deal with weird timer issues
  setTimeout done, 100

describe 'server side rendering', ->
  it 'supports basic render to string', ->
    z.renderToString z 'div', 'test'
    .then (html) ->
      html.should.be '<div>test</div>'

  it 'supports basic render of component to string', ->
    class Root
      render: ->
        z 'div', 'test'

    z.renderToString new Root()
    .then (html) ->
      html.should.be '<div>test</div>'

  it 'supports render of component with props to string', ->
    class Root
      render: ({name}) ->
        z 'div', 'test ' + name

    z.renderToString z new Root(), {name: 'abc'}
    .then (html) ->
      html.should.be '<div>test abc</div>'

  it 'propogates errors', ->
    class MoveAlong
      render: ->
        throw new z.router.Redirect path: '/'

    $move = new MoveAlong()
    z.renderToString $move
    .then ->
      throw new Error 'Expected error'
    , (err) ->
      (err instanceof z.router.Redirect).should.be true

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

  it 'supports async rendering with props to string', ->
    class Async
      constructor: ->
        @pending = new Rx.ReplaySubject(1)
        @state = z.state
          abc: @pending
      render: ({name}) =>
        {abc} = @state.getValue()

        unless abc?
          @pending.onNext 'abc'

        z 'div', abc + ' ' + name

    $async = new Async()
    z.renderToString z $async, {name: 'xxx'}
    .then (html) ->
      html.should.be '<div>abc xxx</div>'

  it 'handles state errors, returning the latest tree', ->
    pending = new Rx.BehaviorSubject(null)
    pending.onError new Error 'test'

    class Root
      constructor: ->
        @state = z.state
          pending: pending

      render: ->
        z 'div', 'abc'

    $root = new Root()

    z.renderToString $root
    .then ->
      throw new Error 'expected error'
    , (err) ->
      err.message.should.be 'test'
      should.exist err.html
      err.html.should.be '<div>abc</div>'


  it 'handles runtime errors', ->
    class Root
      render: ->
        throw new Error 'test'
        z 'div', 'abc'

    $root = new Root()

    z.renderToString $root
    .then ->
      throw new Error 'expected error'
    , (err) ->
      err.message.should.be 'test'
      should.not.exist err.html

  it 'handles async runtime errors, returning last render (not guaranteed)', ->
    pending = new Rx.ReplaySubject(1)

    class Root
      constructor: ->
        @state = z.state
          err: pending

      render: =>
        {err} = @state.getValue()
        if err is 'invalid'
          throw new Error 'test'
        z 'div', 'abc'

    $root = new Root()

    setTimeout ->
      pending.onNext 'invalid'

    z.renderToString $root
    .then ->
      throw new Error 'expected error'
    , (err) ->
      err.message.should.be 'test'
      err.html.should.be '<div>abc</div>'

  it 'supports concurrent requests', (done) ->
    fastCallCnt = 0

    class Slow
      constructor: ->
        @state = z.state
          slow: Rx.Observable.fromPromise(
            new Promise (resolve) ->
              setTimeout ->
                resolve 'slow'
              , 20
          )
      render: ->
        z 'div', 'slow'

    class Fast
      render: ->
        z 'div', 'fast'


    $slow = new Slow()
    $fast = new Fast()
    z.renderToString $slow
    .then (html) ->
      fastCallCnt.should.be 4
      html.should.be '<div>slow</div>'
      done()
    .catch done

    z.renderToString $fast
    .then (html) ->
      html.should.be '<div>fast</div>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      html.should.be '<div>fast</div>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      html.should.be '<div>fast</div>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      html.should.be '<div>fast</div>'
      fastCallCnt += 1
    .catch done

  it 'defaults to 250ms timeout, returning latest tree', ->
    class Timeout
      constructor: ->
        @state = z.state
          oneHundredMs: Rx.Observable.fromPromise(
            new Promise (resolve) ->
              setTimeout ->
                resolve '100'
              , 100
          )
          never: Rx.Observable.empty()
      render: =>
        {oneHundredMs} = @state.getValue()
        oneHundredMs ?= ''
        z 'div', 'test ' + oneHundredMs

    $timeout = new Timeout()
    startTime = Date.now()

    z.renderToString $timeout
    .then ->
      throw new Error 'expected timeout error'
    , (err) ->
      (Date.now() - startTime).should.be.greaterThan 249
      err.message.should.be 'Timeout, request took longer than 250ms'
      err.html.should.be '<div>test 100</div>'

  it 'allows custom timeouts, returning latest tree', ->
    class Timeout
      constructor: ->
        @state = z.state
          threeHundredMs: Rx.Observable.fromPromise(
            new Promise (resolve) ->
              setTimeout ->
                resolve '300'
              , 100
          )
          never: Rx.Observable.empty()
      render: =>
        {threeHundredMs} = @state.getValue()
        threeHundredMs ?= ''
        z 'div', 'test ' + threeHundredMs

    startTime = Date.now()
    $timeout = new Timeout()

    z.renderToString $timeout, {timeout: 300}
    .then ->
      throw new Error 'expected timeout error'
    , (err) ->
      (Date.now() - startTime).should.be.greaterThan 299
      err.message.should.be 'Timeout, request took longer than 300ms'
      err.html.should.be '<div>test 300</div>'
