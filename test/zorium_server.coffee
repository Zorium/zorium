b = require 'b-assert'
Rx = require 'rxjs/Rx'

z = require '../src'

describe 'server side rendering', ->
  if window?
    return

  it 'supports basic render to string', ->
    z.renderToString z 'div', 'test'
    .then (html) ->
      b html, '<DIV>test</DIV>'

  it 'renders un-paired tags properly', ->
    z.renderToString z 'br'
    .then (html) ->
      b html, '<BR>'
      z.renderToString z 'input'
    .then (html) ->
      b html, '<INPUT>'

  it 'supports basic render of component to string', ->
    class Root
      render: ->
        z 'div', 'test'

    z.renderToString new Root()
    .then (html) ->
      b html, '<DIV>test</DIV>'

  it 'supports basic render of component to string (class)', ->
    class Root
      render: ->
        z 'div', 'test'

    z.renderToString Root
    .then (html) ->
      b html, '<DIV>test</DIV>'

  it 'supports render of component with props to string', ->
    class Root
      render: ({name}) ->
        z 'div', 'test ' + name

    z.renderToString z new Root(), {name: 'abc'}
    .then (html) ->
      b html, '<DIV>test abc</DIV>'

  it 'supports async rendering to string', ->
    class Async
      constructor: ->
        @pending = new Rx.ReplaySubject(1)
        @state = z.state
          abc: @pending
      render: =>
        {abc} = @state.getValue()

        z 'div', abc

    $async = new Async()
    setTimeout ->
      $async.pending.next 'abc'
    , 20
    z.renderToString $async
    .then (html) ->
      b html, '<DIV>abc</DIV>'

  it 'DOES NOT support async rendering to string (class)', ->
    p = new Rx.ReplaySubject(1)
    class Async
      constructor: ->
        @state = z.state
          abc: p
      render: =>
        {abc} = @state.getValue()

        z 'div', abc

    setTimeout ->
      p.next 'abc'
    , 20
    z.renderToString Async
    .then (html) ->
      b html, '<DIV></DIV>'

  it 'supports async rendering to string after sync change', ->
    componentSubject = new Rx.ReplaySubject(1)

    class AsyncChild
      constructor: ->
        @pending = new Rx.ReplaySubject(1)
        @state = z.state
          abc: @pending
      render: =>
        {abc} = @state.getValue()

        z 'div', abc

    class Root
      constructor: ->
        @state = z.state
          $component: componentSubject
      render: =>
        {$component} = @state.getValue()

        z 'div',
          $component

    $root = new Root()
    child = new AsyncChild()
    componentSubject.next child
    setTimeout ->
      child.pending.next 'abc'
    z.renderToString $root
    .then (html) ->
      b html, '<DIV><DIV>abc</DIV></DIV>'

  it 'supports async rendering with props to string', ->
    pending = new Rx.ReplaySubject(1)
    class Async
      constructor: ->
        @state = z.state
          abc: pending
      render: ({name}) =>
        {abc} = @state.getValue()

        z 'div', abc + ' ' + name

    class Parent
      constructor: ->
        @$async = new Async()
      render: (params) =>
        z 'div',
          z @$async, params

    setTimeout ->
      pending.next 'abc'
    , 50

    z.renderToString z new Parent(), {name: 'xxx'}
    .then (html) ->
      b html, '<DIV><DIV>abc xxx</DIV></DIV>'

  it 'supports async rendering with parent state with no streams', ->
    pending = new Rx.ReplaySubject(1)
    class Async
      constructor: ->
        @state = z.state
          abc: pending
      render: ({name}) =>
        {abc} = @state.getValue()

        z 'div', abc + ' ' + name

    class Parent
      constructor: ->
        @state = z.state
          $async: new Async()
      render: (params) =>
        {$async} = @state.getValue()

        z 'div',
          z $async, params

    setTimeout ->
      pending.next 'abc'
    , 50

    z.renderToString z new Parent(), {name: 'xxx'}
    .then (html) ->
      b html, '<DIV><DIV>abc xxx</DIV></DIV>'

  it 'logs state errors', ->
    localError = null
    class Root
      constructor: ->
        @state = z.state
          pending: Rx.Observable.throw new Error 'test'
      render: ->
        z 'div', 'abc'

    oldLog = console.error
    console.error = (err) ->
      localError = err
    z.renderToString new Root()
    .then (html) ->
      console.error = oldLog
      b html, '<DIV>abc</DIV>'
      b localError?.message, 'test'

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
      b fastCallCnt, 4
      b html, '<DIV>slow</DIV>'
      done()
    .catch done

    z.renderToString $fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done
    null

  it 'defaults to 250ms timeout', ->
    class Timeout
      constructor: ->
        @state = z.state
          never: new Rx.ReplaySubject(1)
      render: ->
        z 'div', 'test'

    $timeout = new Timeout()
    startTime = Date.now()

    z.renderToString $timeout
    .then ->
      throw new Error 'expected timeout error'
    , (err) ->
      b Object.getOwnPropertyDescriptor(err, 'html').enumerable, false
      b (Date.now() - startTime) > 248
      b err.message, 'Timeout, request took longer than 250ms'
      b err.html, '<DIV>test</DIV>'

  it 'allows custom timeouts', ->
    class Timeout
      constructor: ->
        @state = z.state
          never: new Rx.ReplaySubject(1)
      render: ->
        z 'div', 'test'

    startTime = Date.now()
    $timeout = new Timeout()

    z.renderToString $timeout, {timeout: 300}
    .then ->
      throw new Error 'expected timeout error'
    , (err) ->
      b (Date.now() - startTime) > 298
      b err.message, 'Timeout, request took longer than 300ms'
      b err.html, '<DIV>test</DIV>'

  it 'names components for logging (instance)', (done) ->
    oldLog = console.error
    console.error = (err) ->
      console.error = oldLog
      b err.indexOf('<Throw>') isnt -1
      done()

    class Throw
      render: ->
        throw new Error 'x'
    '' + z new Throw()

  it 'names components for logging (static)', (done) ->
    oldLog = console.error
    console.error = (err) ->
      console.error = oldLog
      b err.indexOf('<Throw>') isnt -1
      done()

    class Throw
      render: ->
        throw new Error 'x'
    '' + z Throw

  it 'supports slow child updates', ->
    s = new Rx.BehaviorSubject 'abc'

    class Child
      constructor: ->
        @state = z.state
          sideEffect: Rx.Observable.defer ->
            new Promise (resolve) ->
              setTimeout ->
                s.next 'xxx'
                resolve null
              , 20

      render: ->
        z 'div', 'child'

    class Root
      constructor: ->
        @$child = new Child()
        @state = z.state
          slow: s

      render: =>
        {slow} = @state.getValue()
        z 'div',
          slow
          @$child

    z.renderToString new Root()
    .then (html) ->
      b html, '<DIV>xxx<DIV>child</DIV></DIV>'
