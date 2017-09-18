b = require 'b-assert'
Rx = require 'rxjs/Rx'

z = require '../src/zorium'
util = require './util'

describe 'render()', ->
  it 'renders to dom node', ->
    root = document.createElement('div')
    z.render (z 'div', 'Hello World'), root
    result = '<div><div>Hello World</div></div>'
    b root.isEqualNode(util.htmlToNode(result)), true

  it 'renders components', ->
    class HelloWorldComponent
      render: ->
        z 'div', 'Hello World'
    hello = new HelloWorldComponent()

    root = document.createElement('div')
    $el = z.render hello, root
    result = '<div><div>Hello World</div></div>'

    b root.isEqualNode(util.htmlToNode(result)), true

  it 'patches dom node on multiple renders', ->
    root = document.createElement('div')
    z.render (z 'div', 'Hello World'), root
    result1 = '<div><div>Hello World</div></div>'
    b root.isEqualNode(util.htmlToNode(result1)), true

    z.render (z 'div', 'Sayonara'), root
    result2 = '<div><div>Sayonara</div></div>'
    b root.isEqualNode(util.htmlToNode(result2)), true

    z.render (z 'div', (z 'div', 'done')), root
    result3 = '<div><div><div>done</div></div></div>'
    b root.isEqualNode(util.htmlToNode(result3)), true

  # https://github.com/Zorium/zorium/issues/68
  it 'patches <iframe> node correctly', ->
    root = document.createElement('div')
    z.render (z 'iframe'), root
    result = '<div><iframe></iframe></div>'

    util.assertDOM root, util.htmlToNode(result)

  it 'binds, basic', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'XXXX'

    root = document.createElement 'div'

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>XXXX</div></div>'

    z.render new App(), root
    window.requestAnimationFrame ->
      b root.isEqualNode(util.htmlToNode(result1))
      z.render new App2(), root

      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

  it 'binds state', (done) ->
    subject = new Rx.BehaviorSubject('abc')

    class Root
      constructor: ->
        @state = z.state
          subject: subject
      render: =>
        z 'div', @state.getValue().subject

    root = document.createElement 'div'
    result1 = '<div><div>abc</div></div>'
    result2 = '<div><div>xyz</div></div>'

    z.render new Root(), root
    window.requestAnimationFrame ->
      util.assertDOM root, util.htmlToNode(result1)
      subject.next 'xyz'

      window.requestAnimationFrame ->
        util.assertDOM root, util.htmlToNode(result2)
        done()

  it 'dissalows re-using components', (done) ->
    class Root
      constructor: ->
        @child = new Child()
      render: =>
        z 'div',
          @child
          @child

    class Child
      render: -> z 'div', 'x'

    root = document.createElement 'div'

    window.__mountTwiceError = ->
      window.__mountTwiceError = null
      done()

    z.render new Root(), root

  it 'passes props', (done) ->
    subject = new Rx.BehaviorSubject(null)

    class Child
      constructor: ->
        @state = z.state
          subject: subject
      render: ({x} = {}) =>
        z 'div', "#{@state.getValue().subject} - #{x}"

    class Root
      constructor: ->
        @$child = new Child()
      render: =>
        z 'div',
          z 'span',
            z @$child, {x: 'x'}

    root = document.createElement 'div'

    result1 = '<div><div><span><div>null - x</div></span></div></div>'
    result2 = '<div><div><span><div>xxx - x</div></span></div></div>'

    z.render new Root(), root
    window.requestAnimationFrame ->
      util.assertDOM root, util.htmlToNode(result1)
      subject.next 'xxx'

      window.requestAnimationFrame ->
        util.assertDOM root, util.htmlToNode(result2)
        done()

  it 'binds nested state', (done) ->
    subject1 = new Rx.BehaviorSubject('abc')
    subject2 = new Rx.BehaviorSubject('xxx')

    class Root
      constructor: ->
        @child = new Child()
      render: =>
        z 'div', @child

    class Child
      constructor: ->
        @grandChild = new GrandChild()
        @state = z.state
          subject: subject1
      render: =>
        z 'div',
          "#{@state.getValue().subject}"
          @grandChild

    class GrandChild
      constructor: ->
        @state = z.state
          subject: subject2
      render: =>
        z 'div', "#{@state.getValue().subject}"

    root = document.createElement 'div'
    result1 = '<div><div><div>abc<div>xxx</div></div></div></div>'
    result2 = '<div><div><div>xyz<div>xxx</div></div></div></div>'
    result3 = '<div><div><div>xyz<div>yyy</div></div></div></div>'

    z.render new Root(), root
    window.requestAnimationFrame ->
      util.assertDOM root, util.htmlToNode(result1)
      subject1.next 'xyz'

      window.requestAnimationFrame ->
        util.assertDOM root, util.htmlToNode(result2)
        subject2.next 'yyy'

        window.requestAnimationFrame ->
          util.assertDOM root, util.htmlToNode(result3)
          done()

  it 'binds prerendered component', (done) ->
    subject = new Rx.BehaviorSubject('abc')

    class Root
      constructor: ->
        @child = z new Child(), {sub: 'xxx'}
      render: =>
        z 'div', @child

    class Child
      constructor: ->
        @state = z.state
          subject: subject
      render: ({sub}) =>
        z 'div',
          "#{@state.getValue().subject} - #{sub}"

    root = document.createElement 'div'
    result1 = '<div><div><div>abc - xxx</div></div></div>'
    result2 = '<div><div><div>xyz - xxx</div></div></div>'

    z.render new Root(), root
    window.requestAnimationFrame ->
      util.assertDOM root, util.htmlToNode(result1)
      subject.next 'xyz'

      window.requestAnimationFrame ->
        util.assertDOM root, util.htmlToNode(result2)
        done()

  it 'binds new child', (done) ->
    subject1 = new Rx.BehaviorSubject(null)
    subject2 = new Rx.BehaviorSubject('2')

    class Root
      constructor: ->
        @child = new Child()
        @state = z.state
          subject: subject1
      render: =>
        z 'div',
          if @state.getValue().subject?
            @child

    class Child
      constructor: ->
        @state = z.state
          subject: subject2
      render: =>
        z 'div', "#{@state.getValue().subject}"

    root = document.createElement 'div'
    result1 = '<div><div></div></div>'
    result2 = '<div><div><div>2</div></div></div>'
    result3 = '<div><div><div>3</div></div></div>'

    z.render new Root(), root
    window.requestAnimationFrame ->
      util.assertDOM root, util.htmlToNode(result1)
      subject1.next true

      window.requestAnimationFrame ->
        util.assertDOM root, util.htmlToNode(result2)
        subject2.next '3'

        setTimeout ->
          window.requestAnimationFrame ->
            util.assertDOM root, util.htmlToNode(result3)
            done()

  it 'binds a deep mutating tree', (done) ->
    subject1 = new Rx.BehaviorSubject('1')
    subject2 = new Rx.BehaviorSubject('2')
    subject3 = new Rx.BehaviorSubject('3')
    subject4 = new Rx.BehaviorSubject('4')

    class Node
      constructor: ({subject, @children}) ->
        @state = z.state
          subject: subject
      render: =>
        z 'div',
          ["#{@state.getValue().subject}"].concat @children


    d = new Node({subject: subject4})
    c = new Node({subject: subject3, children: [d]})
    bb = new Node({subject: subject2})
    topChildren = [c, bb]
    a = new Node({subject: subject1, children: topChildren})

    root = document.createElement 'div'
    result1 = '<div><div>1<div>3<div>4</div></div><div>2</div></div></div>'
    result2 = '<div><div>one<div>3<div>4</div></div><div>2</div></div></div>'
    result3 = '<div><div>one<div>3<div>4</div></div><div>two</div></div></div>'
    result4 =
      '<div><div>one<div>three<div>4</div></div><div>two</div></div></div>'
    result5 =
      '<div><div>one<div>three<div>four</div></div><div>two</div></div></div>'
    result6 = '<div><div>xxx<div>three<div>four</div</div></div></div>'

    z.render a, root
    window.requestAnimationFrame ->
      util.assertDOM root, util.htmlToNode result1
      subject1.next 'one'

      window.requestAnimationFrame ->
        util.assertDOM root, util.htmlToNode result2
        subject2.next 'two'

        window.requestAnimationFrame ->
          util.assertDOM root, util.htmlToNode result3
          subject3.next 'three'

          window.requestAnimationFrame ->
            util.assertDOM root, util.htmlToNode result4
            subject4.next 'four'

            window.requestAnimationFrame ->
              util.assertDOM root, util.htmlToNode result5
              topChildren.pop()
              subject1.next 'xxx'

              window.requestAnimationFrame ->
                util.assertDOM root, util.htmlToNode result6
                done()

  it 'doesnt double mount caused by component re-use (never unmounted)', ->
    unmnt = 0
    class X
      render: ->
        z 'div', 'xxx'

    class Page
      constructor: ({defaultPage}) -> {@$layout, @$x} = defaultPage
      beforeUnmount: ->
        unmnt += 1
      render: =>
        z 'div',
          z @$layout, {
            @$x
          }

    class DefaultPage
      constructor: ->
        $x = new X()
        @$layout = new DefaultLayout()
        return {$x, @$layout}

    class DefaultLayout
      render: ({$x}) ->
        z 'div', $x

    s = new Rx.BehaviorSubject(false)
    class Root
      constructor: ->
        defaultPage = new DefaultPage()
        @$page1 = new Page({defaultPage})
        @$page2 = new Page({defaultPage})
        @state = z.state {shouldTwo: s}
      render: =>
        {shouldTwo} = @state.getValue()
        z 'div',
          if shouldTwo
            @$page2
          else
            @$page1

    $el = document.createElement('div')
    z.render z(new Root()), $el
    b unmnt, 0
    s.next true
    b unmnt, 1

  it 'unmount triggers multiple layers deep', ->
    unmnt = 0
    d = new Rx.BehaviorSubject false

    class X
      render: ({child}) ->
        z 'div', child
      beforeUnmount: -> unmnt += 1

    class Root
      constructor: ->
        @xs = _.map _.range(5), -> new X()
        @state = z.state
          drop: d
      render: =>
        {drop} = @state.getValue()

        z 'div',
          if drop
            z @xs[0]
          else
            z @xs[0],
              child: z @xs[1],
                child: z @xs[2],
                  child: z @xs[3],
                    child: @xs[4]

    $el = document.createElement('div')
    z.render z(new Root()), $el
    b unmnt, 0
    d.next true
    b unmnt, 4

  it 'passes props to children on re-render', (done) ->
    s = new Rx.BehaviorSubject false
    l = new Rx.BehaviorSubject {}
    class Child
      constructor: ->
        @state = z.state
          s: s
      render: ({x}) ->
        z 'div',
          x
    class Root
      constructor: ->
        @$child = new Child()
        @state = z.state
          locale: l

      render: =>
        {locale} = @state.getValue()
        z 'div',
          z @$child, {x: locale['xxx']}

    result1 = '<div><div>' +
      '<div></div>' +
    '</div></div>'

    result2 = '<div><div>' +
      '<div>abc</div>' +
    '</div></div>'

    $el = document.createElement('div')
    z.render z(new Root()), $el
    util.assertDOM $el, util.htmlToNode result1
    l.next {'xxx': 'abc'}
    setTimeout ->
      util.assertDOM $el, util.htmlToNode result2
      s.next true
      setTimeout ->
        util.assertDOM $el, util.htmlToNode result2
        done()
      , 17
    , 17

  it 'state.set re-renders component', ->
    class Root
      constructor: ->
        @state = z.state
          x: 'abc'
      render: =>
        {x} = @state.getValue()
        z 'div', x

    result = '<div><div>xxx</div></div>'
    root = new Root()
    $el = document.createElement 'div'
    z.render root, $el
    root.state.set {x: 'xxx'}
    util.assertDOM $el, util.htmlToNode result

  it 'remove array of children properly', (done) ->
    class Ripple
      constructor: ->
        @state = z.state
          $waves: []

      ripple: =>
        {$waves} = @state.getValue()
        $wave =  z '.wave', 'wave'
        @state.set {$waves: $waves.concat $wave}
        window.setTimeout =>
          {$waves} = @state.getValue()
          @state.set {$waves: _.without $waves, $wave}
        , 20

      render: =>
        {$waves} = @state.getValue()

        z '.ripple',
          onmousedown: @ripple
          $waves

    $el = document.createElement 'div'
    z.render z(new Ripple()), $el
    r = $el.querySelector '.ripple'
    event = new Event 'mousedown'
    r.dispatchEvent event
    r.dispatchEvent event
    setTimeout ->
      r.dispatchEvent event
      r.dispatchEvent event
      setTimeout ->
        done()
      , 40
    , 40

  it 'allows dynamic appending of components', (done) ->
    t = new Rx.BehaviorSubject false
    class C
      render: ->
        z 'div', 'child'
    class P
      constructor: ->
        @$c = new C()
        @state = z.state
          test: t

      render: =>
        {test} = @state.getValue()

        z 'div',
          z 'form',
            'x'
          if test
            @$c

    result = '<div><div><form>x</form><div>child</div></div></div>'

    $el = document.createElement 'div'
    z.render z(new P()), $el
    t.next true
    setTimeout ->
      b $el.isEqualNode util.htmlToNode result
      done()
    , 20

  it 'updates on state change', (done) ->
    l = new Rx.BehaviorSubject 'abc'

    class Root
      constructor: ->
        @state = z.state
          locale: l

      render: =>
        {locale} = @state.getValue()
        z 'div', locale

    result = '<div><div>xxx</div></div>'

    $el = document.createElement('div')
    z.render new Root(), $el
    l.next 'xxx'
    setTimeout ->
      util.assertDOM $el, util.htmlToNode(result)
      done()
    , 17

  it 'passes state errors to afterThrow', ->
    err = new Rx.BehaviorSubject null
    localError = null

    class Root
      constructor: ->
        @state = z.state
          err: err
      afterThrow: (err) ->
        localError = err
      render: ->
        z 'div', 'xxx'

    z.render new Root(), document.createElement('div')
    b localError, null
    err.error new Error 'oh no'
    b localError?.message, 'oh no'

  it 'logs state errors if uncaught', (done) ->
    err = new Rx.BehaviorSubject null

    class Root
      constructor: ->
        @state = z.state
          err: err
      render: ->
        z 'div', 'xxx'

    window.__stateError = (err) ->
      window.__stateError = null
      b err.message, 'oh no'
      done()

    z.render new Root(), document.createElement('div')
    err.error new Error 'oh no'

  it 'efficiently re-renders', (done) ->
    childRenders = 0
    rootRenders = 0
    s1 = new Rx.BehaviorSubject 'initA'
    s2 = new Rx.BehaviorSubject 'initB'

    class Child
      constructor: ->
        @state = z.state
          b: s2
      render: ({x}) ->
        childRenders += 1
        z 'div', 'x'

    class Root
      constructor: ->
        @c1 = new Child()
        @state = z.state
          aa: s1
      render: =>
        {aa} = @state.getValue()
        rootRenders += 1
        z 'div',
          z @c1, {x: if aa is 'initA' then 'x' else 'y'}, ['x']

    dom = z new Root()
    z.untilStable dom
    .then ->
      b rootRenders, 1
      b childRenders, 1
      z.render dom, document.createElement 'div'
      b rootRenders, 2
      b childRenders, 2
      s1.next 'secondA'
      b rootRenders, 3
      b childRenders, 3
      s1.next 'thirdA'
      b rootRenders, 4
      b childRenders, 3
      s2.next 'secondB'
      b rootRenders, 4
      b childRenders, 4
      s2.next 'thirdB'
      b rootRenders, 4
      b childRenders, 5
      setTimeout ->
        b rootRenders, 4
        b childRenders, 5
        done()
      , 17
    .catch done
    null
