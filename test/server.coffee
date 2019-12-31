b = require 'b-assert'
Rx = require 'rxjs/Rx'

{z, useStream, useResource, renderToString} = require '../src'

it = if window? then (-> null) else global.it

describe 'server side rendering', ->
  it 'supports basic render to string', ->
    renderToString z 'div', 'test'
    .then (html) ->
      b html, '<DIV>test</DIV>'

  it 'renders un-paired tags properly', ->
    renderToString z 'br'
    .then (html) ->
      b html, '<BR>'
      renderToString z 'input'
    .then (html) ->
      b html, '<INPUT>'

  it 'supports basic render of component to string', ->
    Root = ->
      z 'div', 'test'

    renderToString Root
    .then (html) ->
      b html, '<DIV>test</DIV>'

  it 'supports render of component with props to string', ->
    Root = ({name}) ->
      z 'div', 'test ' + name

    renderToString z Root, {name: 'abc'}
    .then (html) ->
      b html, '<DIV>test abc</DIV>'

  it 'supports async rendering to string', ->
    pending = new Rx.ReplaySubject(1)
    Async = ->
      {abc} = useStream ->
        abc: pending

      z 'div', abc

    setTimeout ->
      pending.next 'abc'
    , 20
    renderToString Async
    .then (html) ->
      b html, '<DIV>abc</DIV>'

  it 'supports async rendering to string after sync change', ->
    componentSubject = new Rx.ReplaySubject(1)
    pending = new Rx.ReplaySubject(1)

    AsyncChild = ->
      {abc} = useStream ->
        abc: pending
      useResource ->
        Promise.resolve null

      z 'div', abc

    Root = ->
      {$component} = useStream ->
        $component: componentSubject

      z 'div',
        $component

    componentSubject.next AsyncChild
    setTimeout ->
      pending.next 'abc'
    , 20
    renderToString Root
    .then (html) ->
      b html, '<DIV><DIV>abc</DIV></DIV>'

  it 'supports async rendering with props to string', ->
    pending = new Rx.ReplaySubject(1)
    Async = ({name}) ->
      {abc} = useStream ->
        abc: pending

      z 'div', abc + ' ' + name

    Parent = (params) ->
      z 'div',
        z Async, params

    setTimeout ->
      pending.next 'abc'
    , 50

    renderToString z Parent, {name: 'xxx'}
    .then (html) ->
      b html, '<DIV><DIV>abc xxx</DIV></DIV>'

  it 'supports async rendering with parent state with no streams', ->
    pending = new Rx.ReplaySubject(1)
    Async = ({name}) ->
      {abc} = useStream ->
        abc: pending

      z 'div', abc + ' ' + name

    Parent = (params) ->
      {$async} = useStream ->
        $async: Async

      z 'div',
        z $async, params

    setTimeout ->
      pending.next 'abc'
    , 50

    renderToString z Parent, {name: 'xxx'}
    .then (html) ->
      b html, '<DIV><DIV>abc xxx</DIV></DIV>'

  it 'logs state errors', ->
    Root = ->
      useStream ->
        pending: Rx.Observable.throw new Error 'test'

      z 'div', 'abc'

    renderToString Root
    .then (html) ->
      throw new Error 'expected error'
    , (err) ->
      b err.message, 'test'

  it 'supports concurrent requests', (done) ->
    fastCallCnt = 0

    Slow = ->
      useStream ->
        slow: Rx.Observable.fromPromise(
          new Promise (resolve) ->
            setTimeout ->
              resolve 'slow'
            , 20
        )
      z 'div', 'slow'

    Fast = ->
      z 'div', 'fast'


    renderToString Slow
    .then (html) ->
      b fastCallCnt, 4
      b html, '<DIV>slow</DIV>'
      done()
    .catch done

    renderToString Fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    renderToString Fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    renderToString Fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    renderToString Fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done
    null

  it 'defaults to 250ms timeout', ->
    Timeout = ->
      useStream ->
        never: new Rx.ReplaySubject(1)
      z 'div', 'test'

    startTime = Date.now()

    renderToString Timeout
    .then (x) ->
      throw new Error 'expected timeout error'
    , (err) ->
      b Object.getOwnPropertyDescriptor(err, 'html').enumerable, false
      b (Date.now() - startTime) > 248
      b err.message, 'Timeout'
      b err.html, '<DIV>test</DIV>'

  it 'allows custom timeouts', ->
    Timeout = ->
      useStream ->
        never: new Rx.ReplaySubject(1)
      z 'div', 'test'

    startTime = Date.now()

    renderToString Timeout, {timeout: 275}
    .then ->
      throw new Error 'expected timeout error'
    , (err) ->
      b (Date.now() - startTime) >= 275
      b err.message, 'Timeout'
      b err.html, '<DIV>test</DIV>'

  it 'supports slow child updates', ->
    s = new Rx.BehaviorSubject 'abc'

    Child = ->
      useStream ->
        sideEffect: Rx.Observable.defer ->
          new Promise (resolve) ->
            setTimeout ->
              s.next 'xxx'
              resolve null
            , 20

      z 'div', 'child'

    Root = ->
      {slow} = useStream ->
        slow: s

      z 'div', [
        slow
        Child
      ]

    renderToString Root
    .then (html) ->
      b html, '<DIV>xxx<DIV>child</DIV></DIV>'
