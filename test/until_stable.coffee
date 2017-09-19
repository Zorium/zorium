b = require 'b-assert'
Rx = require 'rxjs/Rx'

z = require '../src'
util = require './util'

describe 'untilStable', ->
  it 'stabilizes simple tree prior to render', ->
    s = new Rx.ReplaySubject(1)
    class Root
      constructor: ->
        @state = z.state
          slow: s
      render: =>
        {slow} = @state.getValue()
        z 'div', slow or 'root'

    root = new Root()
    promise = z.untilStable root
    .then ->
      result = '<div><div>abc</div></div>'
      z.render root, $el = document.createElement 'div'
      util.assertDOM $el, util.htmlToNode(result)
    setTimeout ->
      s.next 'abc'
    return promise

  it 'stabilizes nested tree prior to render', ->
    s1 = new Rx.ReplaySubject(1)
    s2 = new Rx.ReplaySubject(1)
    class Child
      constructor: ->
        @state = z.state
          slow: s2
      render: =>
        {slow} = @state.getValue()
        z 'div',
          slow or 'child'

    class Root
      constructor: ->
        @$child = new Child()
        @state = z.state
          slow: s1
      render: =>
        {slow} = @state.getValue()
        z 'div',
          if slow? then @$child else 'root'

    root = new Root()
    promise = z.untilStable root
    .then ->
      result = '<div><div><div>xxx</div></div></div>'
      z.render root, $el = document.createElement 'div'
      util.assertDOM $el, util.htmlToNode(result)
    setTimeout ->
      s1.next 'abc'
      setTimeout ->
        s2.next 'xxx'
    return promise

  it 'doesn\'t throw on render error', ->
    class Root
      render: ->
        throw new Error 'x'

    z.untilStable new Root()

  it 'doesn\'t throw on state error', ->
    class Root
      constructor: ->
        @state = z.state
          err: Rx.Observable.throw new Error 'x'
      render: ->
        z 'div', 'root'

    localError = null
    oldLog = console.error
    console.error = (err) -> localError = err
    z.untilStable new Root()
    .then ->
      console.error = oldLog
      b localError?.message, 'x'

  it 'handles fragment children', ->
    s = new Rx.ReplaySubject(1)
    class Child
      constructor: ->
        @state = z.state
          slow: s
      render: =>
        {slow} = @state.getValue()
        z 'div',
          slow or 'child'

    class Root
      constructor: ->
        @$child = new Child()
      render: =>
        [z @$child]

    root = new Root()
    promise = z.untilStable root
    .then ->
      result = '<div><div>xxx</div></div>'
      z.render root, $el = document.createElement 'div'
      util.assertDOM $el, util.htmlToNode(result)
    setTimeout ->
      s.next 'xxx'
    return promise
