b = require 'b-assert'
Rx = require 'rxjs/Rx'

{z, useState, useMemo} = require '../src'

describe.only 'server side rendering', ->
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
    Root = ->
      z 'div', 'test'

    z.renderToString Root
    .then (html) ->
      b html, '<DIV>test</DIV>'

  it 'supports render of component with props to string', ->
    Root = ({name}) ->
      z 'div', 'test ' + name

    z.renderToString z Root, {name: 'abc'}
    .then (html) ->
      b html, '<DIV>test abc</DIV>'

  it 'supports async rendering to string', ->
    pending = new Rx.ReplaySubject(1)
    Async = ->
      yield {abc} = await useState ->
        abc: pending

      yield z 'div', abc

    setTimeout ->
      pending.next 'abc'
    , 20
    z.renderToString Async
    .then (html) ->
      b html, '<DIV>abc</DIV>'

  it 'supports async rendering to string after sync change', ->
    componentSubject = new Rx.ReplaySubject(1)
    pending = new Rx.ReplaySubject(1)

    AsyncChild = ->
      yield {abc} = await useState ->
        abc: pending

      yield z 'div', abc

    Root = ->
      yield {$component} = await useState ->
        $component: componentSubject

      yield z 'div',
        $component

    componentSubject.next AsyncChild
    setTimeout ->
      pending.next 'abc'
    , 20
    z.renderToString Root
    .then (html) ->
      b html, '<DIV><DIV>abc</DIV></DIV>'

  it 'supports async rendering with props to string', ->
    pending = new Rx.ReplaySubject(1)
    Async = ({name}) ->
      yield {abc} = await useState ->
        abc: pending

      yield z 'div', abc + ' ' + name

    Parent = (params) ->
      z 'div',
        z Async, params

    setTimeout ->
      pending.next 'abc'
    , 50

    z.renderToString z Parent, {name: 'xxx'}
    .then (html) ->
      b html, '<DIV><DIV>abc xxx</DIV></DIV>'

  it 'supports async rendering with parent state with no streams', ->
    pending = new Rx.ReplaySubject(1)
    Async = ({name}) ->
      yield {abc} = await useState ->
        abc: pending

      yield z 'div', abc + ' ' + name

    Parent = (params) ->
      yield {$async} = await useState ->
        $async: Async

      yield z 'div',
        z $async, params

    setTimeout ->
      pending.next 'abc'
    , 50

    z.renderToString z Parent, {name: 'xxx'}
    .then (html) ->
      b html, '<DIV><DIV>abc xxx</DIV></DIV>'

  it 'logs state errors', ->
    Root = ->
      yield await Promise.resolve null

      yield await useState ->
        pending: Rx.Observable.throw new Error 'test'

      yield z 'div', 'abc'

    z.renderToString Root
    .then (html) ->
      throw new Error 'expected error'
    , (err) ->
      b err.message, 'test'
    .catch (err) ->
      console.log '???'

  it 'supports concurrent requests', (done) ->
    fastCallCnt = 0

    Slow = ->
      yield await useState ->
        slow: Rx.Observable.fromPromise(
          new Promise (resolve) ->
            setTimeout ->
              resolve 'slow'
            , 20
        )
      yield z 'div', 'slow'

    Fast = ->
      yield z 'div', 'fast'


    z.renderToString Slow
    .then (html) ->
      b fastCallCnt, 4
      b html, '<DIV>slow</DIV>'
      done()
    .catch done

    z.renderToString Fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    z.renderToString Fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    z.renderToString Fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done

    z.renderToString Fast
    .then (html) ->
      b html, '<DIV>fast</DIV>'
      fastCallCnt += 1
    .catch done
    null

  it 'defaults to 250ms timeout', ->
    Timeout = ->
      yield await useState ->
        never: new Rx.ReplaySubject(1)
      yield z 'div', 'test'

    startTime = Date.now()

    z.renderToString Timeout
    .then (x) ->
      throw new Error 'expected timeout error'
    , (err) ->
      b Object.getOwnPropertyDescriptor(err, 'html').enumerable, false
      b (Date.now() - startTime) > 248
      b err.message, 'Timeout'
      b err.html, '<DIV>test</DIV>'

  it 'allows custom timeouts', ->
    Timeout = ->
      yield await useState ->
        never: new Rx.ReplaySubject(1)
      yield z 'div', 'test'

    startTime = Date.now()

    z.renderToString Timeout, {timeout: 300}
    .then ->
      throw new Error 'expected timeout error'
    , (err) ->
      b (Date.now() - startTime) > 298
      b err.message, 'Timeout'
      b err.html, '<DIV>test</DIV>'


  # FIXME: no longer supported
  #   to add support would need to create a custom render target for updates
  # it.only 'supports slow child updates', ->
  #   s = new Rx.BehaviorSubject 'abc'
  #
  #   Child = ->
  #     yield await useState ->
  #       sideEffect: Rx.Observable.defer ->
  #         new Promise (resolve) ->
  #           setTimeout ->
  #             console.log 'NEXT'
  #             s.next 'xxx'
  #             resolve null
  #           , 20
  #
  #     yield z 'div', 'child'
  #
  #   Root = ->
  #     yield {slow} = await useState ->
  #       slow: s
  #
  #     yield z 'div', [
  #       slow
  #       Child
  #     ]
  #
  #   z.renderToString Root
  #   .then (html) ->
  #     b html, '<DIV>xxx<DIV>child</DIV></DIV>'
