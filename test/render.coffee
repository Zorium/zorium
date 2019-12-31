_ = require 'lodash'
b = require 'b-assert'
Rx = require 'rxjs/Rx'

{
  z, render, useState, useStream, useMemo,
  useCallback, useLayout, Boundary
} = require '../src'
{assertDOM} = require './util'

it = if window? then global.it else (-> null)

describe 'render()', ->
  it 'renders to dom node', ->
    root = document.createElement('div')
    render (z 'div', 'Hello World'), root
    result = '<div><div>Hello World</div></div>'
    assertDOM(root, result)

  it 'renders components', ->
    HelloWorldComponent = ->
      z 'div', 'Hello World'

    render HelloWorldComponent, root = document.createElement('div')
    result = '<div><div>Hello World</div></div>'

    assertDOM(root, result)

  it 'patches dom node on multiple renders', ->
    root = document.createElement('div')
    render (z 'div', 'Hello World'), root
    result1 = '<div><div>Hello World</div></div>'
    assertDOM(root, result1)

    render (z 'div', 'Sayonara'), root
    result2 = '<div><div>Sayonara</div></div>'
    assertDOM(root, result2)

    render (z 'div', (z 'div', 'done')), root
    result3 = '<div><div><div>done</div></div></div>'
    assertDOM(root, result3)

  # https://github.com/Zorium/zorium/issues/68
  it 'patches <iframe> node correctly', ->
    root = document.createElement('div')
    render (z 'iframe'), root
    result = '<div><iframe></iframe></div>'

    assertDOM root, result

  it 'binds, basic', (done) ->
    App = ->
      z 'div', 'Hello World'

    App2 = ->
      z 'div', 'XXXX'

    root = document.createElement 'div'

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>XXXX</div></div>'

    render App, root
    window.requestAnimationFrame ->
      assertDOM(root, result1)
      render App2, root

      window.requestAnimationFrame ->
        assertDOM(root, result2)
        done()

  it 'binds state', (done) ->
    subject = new Rx.BehaviorSubject('abc')

    Root = ->
      state = useStream ->
        subject: subject

      z 'div', state.subject

    root = document.createElement 'div'
    result1 = '<div><div>abc</div></div>'
    result2 = '<div><div>xyz</div></div>'

    render Root, root
    window.requestAnimationFrame ->
      assertDOM root, result1
      subject.next 'xyz'

      window.requestAnimationFrame ->
        assertDOM root, result2
        done()

  it 'correctly handle component which fails to mount', ->
    Throw = ->
      throw new Error 'xxx'

    Root = ->
      z Throw

    errFn = console.error
    console.error = -> null
    try
      render Root, document.createElement 'div'
    catch err
      b _.includes err.message, 'xxx'
    finally
      console.error = errFn

  it 'passes props', (done) ->
    subject = new Rx.BehaviorSubject(null)

    Child = ({x}) ->
      state = useStream ->
        subject: subject

      z 'div', "#{state.subject} - #{x}"

    Root = ->
      z 'div',
        z 'span',
          z Child, {x: 'x'}

    root = document.createElement 'div'

    result1 = '<div><div><span><div>null - x</div></span></div></div>'
    result2 = '<div><div><span><div>xxx - x</div></span></div></div>'

    render Root, root
    window.requestAnimationFrame ->
      assertDOM root, result1
      subject.next 'xxx'

      window.requestAnimationFrame ->
        assertDOM root, result2
        done()

  it 'binds nested state', (done) ->
    subject1 = new Rx.BehaviorSubject('abc')
    subject2 = new Rx.BehaviorSubject('xxx')

    Root = ->
      z 'div', Child

    Child = ->
      state = useStream ->
        subject: subject1

      z 'div',
        "#{state.subject}"
        GrandChild

    GrandChild = ->
      state = useStream ->
        subject: subject2

      z 'div', "#{state.subject}"

    root = document.createElement 'div'
    result1 = '<div><div><div>abc<div>xxx</div></div></div></div>'
    result2 = '<div><div><div>xyz<div>xxx</div></div></div></div>'
    result3 = '<div><div><div>xyz<div>yyy</div></div></div></div>'

    render Root, root
    window.requestAnimationFrame ->
      assertDOM root, result1
      subject1.next 'xyz'

      window.requestAnimationFrame ->
        assertDOM root, result2
        subject2.next 'yyy'

        window.requestAnimationFrame ->
          assertDOM root, result3
          done()

  it 'binds prerendered component', (done) ->
    subject = new Rx.BehaviorSubject('abc')

    Root = ->
      child = useMemo -> z Child, {sub: 'xxx'}
      z 'div', child

    Child = ({sub}) ->
      state = useStream ->
        subject: subject
      z 'div',
        "#{state.subject} - #{sub}"

    root = document.createElement 'div'
    result1 = '<div><div><div>abc - xxx</div></div></div>'
    result2 = '<div><div><div>xyz - xxx</div></div></div>'

    render Root, root
    window.requestAnimationFrame ->
      assertDOM root, result1
      subject.next 'xyz'

      window.requestAnimationFrame ->
        assertDOM root, result2
        done()

  it 'binds new child', (done) ->
    subject1 = new Rx.BehaviorSubject(null)
    subject2 = new Rx.BehaviorSubject('2')

    Root = ->
      state = useStream ->
        subject: subject1
      z 'div',
        if state.subject?
          Child

    Child = ->
      state = useStream ->
        subject: subject2
      z 'div', "#{state.subject}"

    root = document.createElement 'div'
    result1 = '<div><div></div></div>'
    result2 = '<div><div><div>2</div></div></div>'
    result3 = '<div><div><div>3</div></div></div>'

    render Root, root
    window.requestAnimationFrame ->
      assertDOM root, result1
      subject1.next true

      window.requestAnimationFrame ->
        assertDOM root, result2
        subject2.next '3'

        setTimeout ->
          window.requestAnimationFrame ->
            assertDOM root, result3
            done()

  it 'binds a deep mutating tree', (done) ->
    subject1 = new Rx.BehaviorSubject('1')
    subject2 = new Rx.BehaviorSubject('2')
    subject3 = new Rx.BehaviorSubject('3')
    subject4 = new Rx.BehaviorSubject('4')

    NodeGen = ({subject, children}) ->
      ->
        state = useStream ->
          subject: subject
        z 'div',
          ["#{state.subject}"].concat children


    d = NodeGen({subject: subject4})
    c = NodeGen({subject: subject3, children: [d]})
    bb = NodeGen({subject: subject2})
    topChildren = [c, bb]
    a = NodeGen({subject: subject1, children: topChildren})

    root = document.createElement 'div'
    result1 = '<div><div>1<div>3<div>4</div></div><div>2</div></div></div>'
    result2 = '<div><div>one<div>3<div>4</div></div><div>2</div></div></div>'
    result3 = '<div><div>one<div>3<div>4</div></div><div>two</div></div></div>'
    result4 =
      '<div><div>one<div>three<div>4</div></div><div>two</div></div></div>'
    result5 =
      '<div><div>one<div>three<div>four</div></div><div>two</div></div></div>'

    render a, root
    window.requestAnimationFrame ->
      assertDOM root, result1
      subject1.next 'one'

      window.requestAnimationFrame ->
        assertDOM root, result2
        subject2.next 'two'

        window.requestAnimationFrame ->
          assertDOM root, result3
          subject3.next 'three'

          window.requestAnimationFrame ->
            assertDOM root, result4
            subject4.next 'four'

            window.requestAnimationFrame ->
              assertDOM root, result5
              done()

  it 'unmount triggers multiple layers deep', (done) ->
    unmnt = 0
    d = new Rx.BehaviorSubject false

    X = ({child}) ->
      useLayout ->
        ->
          unmnt += 1
      , []
      z 'div', child

    Root = ->
      {drop} = useStream ->
        drop: d

      z 'div',
        if drop
          z X
        else
          z X,
            child: z X,
              child: z X,
                child: z X,
                  child: X

    $el = document.createElement('div')
    render z(Root), $el
    b unmnt, 0
    d.next true
    window.requestAnimationFrame ->
      b unmnt, 4
      done()

  it 'passes props to children on re-render', (done) ->
    s = new Rx.BehaviorSubject false
    l = new Rx.BehaviorSubject {}
    Child = ({x}) ->
      useStream ->
        s: s
      z 'div',
        x
    Root = ->
      {locale} = useStream ->
        locale: l

      z 'div',
        z Child, {x: locale['xxx']}

    result1 = '<div><div>' +
      '<div></div>' +
    '</div></div>'

    result2 = '<div><div>' +
      '<div>abc</div>' +
    '</div></div>'

    $el = document.createElement('div')
    render z(Root), $el
    assertDOM $el, result1
    l.next {'xxx': 'abc'}
    window.requestAnimationFrame ->
      assertDOM $el, result2
      s.next true
      window.requestAnimationFrame ->
        assertDOM $el, result2
        done()

  it 'remove array of children properly', (done) ->
    Ripple = ->
      [$waves, setWaves] = useState []

      ripple = useCallback ->
        $wave =  z '.wave', 'wave'
        setWaves $waves.concat $wave
        window.requestAnimationFrame ->
          setWaves _.without $waves, $wave
      , [$waves]

      z '.ripple',
        onmousedown: ripple
        $waves

    $el = document.createElement 'div'
    render z(Ripple), $el
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
    C = ->
      z 'div', 'child'
    P = ->
      {test} = useStream ->
        test: t

      z 'div',
        z 'form',
          'x'
        if test
          C

    result = '<div><div><form>x</form><div>child</div></div></div>'

    $el = document.createElement 'div'
    render z(P), $el
    t.next true
    window.requestAnimationFrame ->
      assertDOM $el, result
      done()

  it 'updates on state change', (done) ->
    l = new Rx.BehaviorSubject 'abc'

    Root = ->
      {locale} = useStream ->
        locale: l

      z 'div', locale

    result = '<div><div>xxx</div></div>'

    $el = document.createElement('div')
    render Root, $el
    l.next 'xxx'
    window.requestAnimationFrame ->
      assertDOM $el, result
      done()

  it 'passes state errors to Boundary', (done) ->
    shouldError = new Rx.BehaviorSubject false
    localError = null

    Child = ->
      useStream ->
        {shouldError}
      z 'div', 'xxx'

    Root = ->
      if localError?
        return null
      z Boundary,
        fallback: (err) -> localError = err
        z 'div', Child

    render Root, document.createElement('div')
    b localError, null
    shouldError.error new Error 'oh no'
    window.requestAnimationFrame ->
      b localError?.message, 'oh no'
      done()

  it 'passes render errors to Boundary', (done) ->
    shouldError = new Rx.BehaviorSubject false
    localError = null

    Child = ->
      state = useStream ->
        {shouldError}
      if state.shouldError
        throw new Error 'oh no'
      z 'div', 'xxx'

    Root = ->
      if localError?
        return null
      z Boundary,
        fallback: (err) -> localError = err
        z 'div', Child

    render Root, document.createElement('div')
    b localError, null
    shouldError.next true
    window.requestAnimationFrame ->
      b localError?.message, 'oh no'
      done()

  it 'recovers gracefully with Boundary', ->
    Throw = ->
      throw new Error 'xxx'

    Root = ->
      z Boundary,
        fallback: ->
          z 'div', 'abc'
        z Throw

    result = '<div><div>abc</div></div>'
    render Root, $el = document.createElement('div')
    assertDOM $el, result

  it 'logs state errors if uncaught', (done) ->
    err = new Rx.BehaviorSubject null

    Root = ->
      useStream ->
        err: err
      z 'div', 'xxx'

    originalLog = console.error
    console.error = ->
      console.error = originalLog
      done()
    render Root, document.createElement('div')
    err.error new Error 'oh no'

  it 'handles mount-state consistency', (done) ->
    s = new Rx.BehaviorSubject 'a'
    stack = []

    ChildGen = (id) ->
      ->
        useLayout ->
          stack.push 'mount|' + id
          ->
            stack.push 'unmount|' + id
        , []
        z 'div'

    C1 = ChildGen '1'
    C2 = ChildGen '2'
    C3 = ChildGen '3'

    Root = ->
      {status} = useStream ->
        status: s
      z 'div',
        switch status
          when 'a'
            C1
          when 'b'
            C2
          when 'c'
            C3
          when 'd'
            [C1, C2, C3]
          when 'e'
            [C3, C2, C1]

    tStack = []
    b stack, tStack
    render Root, document.createElement('div')
    window.requestAnimationFrame ->
      b stack, tStack = tStack.concat ['mount|1']
      s.next 'b'
      window.requestAnimationFrame ->
        b stack, tStack = tStack.concat ['unmount|1', 'mount|2']
        s.next 'c'
        window.requestAnimationFrame ->
          b stack, tStack = tStack.concat ['unmount|2', 'mount|3']
          s.next 'd'
          window.requestAnimationFrame ->
            b stack, tStack = \
              tStack.concat ['unmount|3', 'mount|1', 'mount|2', 'mount|3']
            s.next 'e'
            window.requestAnimationFrame ->
              b stack, tStack = \
                tStack.concat ['unmount|1', 'unmount|3', 'mount|3', 'mount|1']
              done()

  it 'replaces innerHTML tree diffs properly', (done) ->
    a = new Rx.BehaviorSubject true
    Root = ->
      {isA} = useStream ->
        isA: a
      if isA
        z 'div', [undefined]
      else
        z 'div',
          innerHTML: 'x'

    result1 = '<div><div></div></div>'
    result2 = '<div><div>x</div></div>'
    result3 = '<div><div></div></div>'
    result4 = '<div><div>x</div></div>'

    render Root, $el = document.createElement 'div'
    assertDOM $el, result1
    window.requestAnimationFrame ->
      a.next false
      window.requestAnimationFrame ->
        assertDOM $el, result2
        a.next true
        window.requestAnimationFrame ->
          assertDOM $el, result3
          a.next false
          window.requestAnimationFrame ->
            assertDOM $el, result4
            done()

  it 'correctly diffs between static vdom-node and text-node', (done) ->
    a = new Rx.BehaviorSubject true
    x = z 'span'
    Root = ->
      {isA} = useStream ->
        isA: a
      z 'div',
        if isA
          x
        else
          'test'

    result1 = '<div><div><span></span></div></div>'
    result2 = '<div><div>test</div></div>'
    result3 = '<div><div><span></span></div></div>'
    render Root, $el = document.createElement 'div'
    assertDOM $el, result1
    a.next false
    window.requestAnimationFrame ->
      assertDOM $el, result2
      a.next true
      window.requestAnimationFrame ->
        assertDOM $el, result3
        done()

  it 'correctly deals mount/unmounts when static node changes', ->
    a = new Rx.BehaviorSubject true

    Ser = ->
      z 'div', 'ser'

    Static = ->
      {child} = useStream ->
        child: a.map ->
          z 'div',
            Ser
      z 'div',
        child

    Root = ->
      {isA} = useStream ->
        isA: a
      z 'div',
        if isA
          Static

    # failure triggers invariant
    render Root, document.createElement 'div'
    a.next false
    a.next true
    a.next false

  it 'renders nested children after parent-child state mutations', ->
    filter = new Rx.BehaviorSubject 'abc'
    page = new Rx.BehaviorSubject 'bbb'

    Child = ->
      z 'div', 'child'

    Wrapper = ({children}) ->
      useStream ->
        page: page
      z 'div', children

    Root = ->
      useStream ->
        filter: filter
      z 'div',
        z Wrapper,
          z Child, 'xxx'

    render Root, document.createElement 'div'
    filter.next 'xxx'
    page.next 'ccc'
