should = require('clay-chai').should()
createElement = require 'virtual-dom/create-element'
Promise = window.Promise or require 'promiz'
Rx = require 'rx-lite'

z = require 'zorium'

# TODO: batch redraws

htmlToNode = (html) ->
  root = document.createElement 'div'
  root.innerHTML = html
  return root.firstChild

deferred = ->
  resolve = null
  reject = null
  promise = new Promise (_resolve, _reject) ->
    resolve = _resolve
    reject = _reject
  promise.resolve = resolve
  promise.reject = reject

  return promise

describe 'Virtual DOM', ->
  it 'creates basic DOM trees', ->
    dom = z 'div',
      z '.cname#cid', 'abc'
      z 'a.b[href=#][data-non=123][eatme]',
        z 'img'

    $el = createElement(dom)

    result = '<div>' +
      '<div id="cid" class="cname">abc</div>' +
      '<a href="#" data-non="123" eatme="true" class="b">' +
        '<img>' +
      '</a>' +
    '</div>'

    $el.isEqualNode(htmlToNode(result)).should.be true

  it 'sets style', ->
    dom = z 'img',
      style:
        backgroundColor: 'red'
        lineHeight: '1rem'

    $el = createElement(dom)
    $el.style.lineHeight.should.be '1rem'
    $el.style.backgroundColor.should.be 'red'

  it 'renders numbers', ->
    dom = z 'div', 123

    result = '<div>123</div>'
    $el = createElement(dom)
    $el.isEqualNode(htmlToNode(result)).should.be true

  it 'supports default div tag prefixing', ->
    dom = z 'div',
      z '.container'
      z '#layout'
      z '[contenteditable]'

    result = '<div>' +
      '<div class="container"></div>' +
      '<div id="layout"></div>' +
      '<div contenteditable="true"></div>' +
    '</div>'

    $el = createElement(dom)
    $el.isEqualNode(htmlToNode(result)).should.be true

  it 'supports nested zorium components', ->
    class HelloWorldComponent
      render: ->
        z 'span', 'Hello World'
    hello = new HelloWorldComponent()
    dom = z 'div', hello

    $el = createElement(dom)

    result = '<div><span>Hello World</span></div>'

    $el.isEqualNode(htmlToNode(result)).should.be true

  it 'supports arrs', ->
    dom = z 'div', [
      z 'div', 'a'
      z 'div', 'b'
    ]

    $el = createElement(dom)

    result = '<div><div>a</div><div>b</div></div>'

    $el.isEqualNode(htmlToNode(result)).should.be true

  it 'allows component render to return an array', ->
    class HelloWorldComponent
      render: ->
        [
          z 'span', 'Hello'
          z 'span', 'World'
        ]

    hello = new HelloWorldComponent()

    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'
      hello or null

    $el = createElement(dom)

    result = '<div>' +
      '<div>a</div>' +
      '<div>b</div>' +
      '<div>' +
        '<span>Hello</span>' +
        '<span>World</span>' +
      '</div>' +
    '</div>'

    $el.isEqualNode(htmlToNode(result)).should.be true

  it 'allows component render to return undefined', ->
    class HelloWorldComponent
      render: ->
        return

    hello = new HelloWorldComponent()

    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'

    root = document.createElement 'div'

    result = '<div><div>' +
      '<div>a</div>' +
      '<div>b</div>' +
      '<div></div>' +
    '</div></div>'

    z.render root, dom

    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'
      hello

    z.render root, dom

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'allows undefined children on redraw', ->
    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'

    root = document.createElement 'div'

    result = '<div><div>' +
      '<div>a</div>' +
      '<div>b</div>' +
    '</div></div>'

    z.render root, dom

    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'
      undefined

    z.render root, dom

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'handles null children', ->
    dom = z 'div',
      null
      z 'span', 'Hello World'
      null
      z 'div', [
        null
        z 'div', 'World Hello'
      ]

    $el = createElement(dom)

    result = '<div>' +
      '<span>Hello World</span>' +
      '<div>' +
        '<div>World Hello</div>' +
      '</div>' +
    '</div>'

    $el.isEqualNode(htmlToNode(result)).should.be true

  # https://github.com/claydotio/zorium.js/issues/1
  it 'doesn\'t add extra class names', ->
    dom = z 'a[href=http://192.168.1.0]', 'test'
    $el = createElement(dom)
    result = '<a href="http://192.168.1.0">test</a>'

    $el.isEqualNode(htmlToNode(result)).should.be true


  # https://github.com/claydotio/zorium.js/issues/3
  it 'correctly patches component-based trees without DOM removal', ->
    class Uniq
      render: ->
        z '#uniq'

    dom = new Uniq()

    root = document.createElement 'div'
    z.render root, dom
    first = root.querySelector '#uniq'
    (first is root.querySelector '#uniq').should.be true
    z.render root, dom
    (first is root.querySelector '#uniq').should.be true
    z.render root, dom, z 'd'

  it 'passes props to render when z is used with a component', ->
    class A
      render: ({world}) ->
        z 'div', 'hello ' + world

    class B
      constructor: ->
        @$a = new A()
      render: =>
        z @$a, {world: 'world'}

    $b = new B()

    root = document.createElement 'div'

    z.render root, $b

    result = '<div><div>hello world</div></div>'
    root.isEqualNode(htmlToNode(result)).should.be true


  describe 'Anchor Tag', ->
    it 'defaults anchor tag onclick event to use router', ->
      preventDefaultCalled = 0
      goCalled = 0

      oldGo = z.router.go
      z.router.go = (path) ->
        goCalled += 1
        path.should.be '/pathname/here'

      dom = z.router.link z 'a[href=/pathname/here]'
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'
      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      dom.properties.onclick.call($el, e)

      z.router.go = oldGo

      preventDefaultCalled.should.be 1
      goCalled.should.be 1



    it 'doesn\'t default anchor tags with external path', ->
      preventDefaultCalled = 0
      goCalled = 0

      oldGo = z.router.go
      z.router.go = (path) ->
        goCalled += 1

      dom = z.router.link z 'a[href=http://google.com]'
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'

      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      dom.properties.onclick.call($el, e)

      z.router.go = oldGo

      preventDefaultCalled.should.be 0
      goCalled.should.be 0



    it 'writes if other properties exist', ->
      preventDefaultCalled = 0
      goCalled = 0

      oldGo = z.router.go
      z.router.go = (path) ->
        goCalled += 1
        path.should.be '/'

      dom = z.router.link z 'a[href=/][name=test]', {onmousedown: -> null}
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'

      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      dom.properties.onclick.call($el, e)

      z.router.go = oldGo

      preventDefaultCalled.should.be 1
      goCalled.should.be 1



    it 'throws if attempted to override onclick', (done) ->
      try
        z.router.link z 'a[href=/][name=test]',
          {onclick: -> clickCalled += 1}
        done(new Error 'Error expected')
      catch
        done()

describe 'render()', ->
  it 'renders to dom node', ->
    root = document.createElement('div')
    z.render root, (z 'span', 'Hello World')
    result = '<div><span>Hello World</span></div>'
    root.isEqualNode(htmlToNode(result)).should.be true

  it 'renders components', ->
    class HelloWorldComponent
      render: ->
        z 'span', 'Hello World'
    hello = new HelloWorldComponent()

    root = document.createElement('div')
    $el = z.render root, hello
    result = '<div><span>Hello World</span></div>'

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'patches dom node on multiple renders', ->
    root = document.createElement('div')
    z.render root, (z 'span', 'Hello World')
    result1 = '<div><span>Hello World</span></div>'
    root.isEqualNode(htmlToNode(result1)).should.be true

    z.render root, (z 'span', 'Sayonara')
    result2 = '<div><span>Sayonara</span></div>'
    root.isEqualNode(htmlToNode(result2)).should.be true

    z.render root, (z 'span', (z 'div', 'done'))
    result3 = '<div><span><div>done</div></span></div>'
    root.isEqualNode(htmlToNode(result3)).should.be true

describe 'Lifecycle Callbacks', ->
  describe 'onMount', ->
    it 'gets called after initial load', (done) ->
      mountCalled = 0
      class BindComponent
        onMount: ($el) ->
          should.exist $el
          mountCalled += 1
        render: ->
          z 'div'

      bind = new BindComponent()
      root = document.createElement 'div'
      z.render root, bind
      setTimeout ->
        mountCalled.should.be 1
        done()
      , 20

    # https://github.com/claydotio/zorium.js/issues/5
    it 'is only called once on first render', (done) ->
      mountCalled = 0

      class BindComponent
        onMount: ($el) ->
          should.exist $el
          mountCalled += 1
        render: ->
          z 'div'

      bind = new BindComponent()

      dom = z 'div',
        bind
        z 'span', 'hello'


      root = document.createElement 'div'
      z.render root, dom

      dom = z 'div',
        bind
        z 'span', 'world'

      setTimeout ->
        z.redraw()

        setTimeout ->
          z.redraw()

          z.render root, dom

          setTimeout ->
            z.redraw()

            setTimeout ->
              mountCalled.should.be 1
              done()

            , 10
          , 20
        , 20
      , 20

  describe 'onBeforeUnmount', ->
    it 'gets called before removal from DOM', (done) ->
      class BindComponent
        onBeforeUnmount: ->
          done()
        render: ->
          z 'div'

      class ContainerComponent
        constructor: ->
          @removed = false
          @bind = new BindComponent()
        render: =>
          z 'div',
            unless @removed then @bind else 'hello'
        removeChild: =>
          @removed = true

      container = new ContainerComponent()
      root = document.createElement 'div'
      z.render root, container
      setTimeout ->
        container.removeChild()
        z.render root, container
      , 20

    it 'gets called after mounting only', (done) ->
      unmountCalled = 0
      mountCalled = 0
      class BindComponent
        onMount: ->
          mountCalled += 1
        onBeforeUnmount: ->
          unmountCalled += 1
        render: ->
          z 'div',
            z 'span', 'Hello World'
            z 'span', 'Goodbye'

      bind = new BindComponent()

      root = document.createElement 'div'
      z.render root, bind

      setTimeout ->
        mountCalled.should.be 1
        unmountCalled.should.be 0
        z.render root, z 'div'
        z.render root, bind
        unmountCalled.should.be 1
        done()
      , 20

    it 'remounts after unmounting', (done) ->
      unmountCalled = 0
      mountCalled = 0
      class BindComponent
        onMount: ->
          mountCalled += 1
        onBeforeUnmount: ->
          unmountCalled += 1
        render: ->
          z 'div'

      bind = new BindComponent()
      root = document.createElement 'div'
      z.render root, bind

      setTimeout ->
        mountCalled.should.be 1
        z.render root, z 'div'
        unmountCalled.should.be 1
        z.render root, bind

        setTimeout ->
          mountCalled.should.be 2
          done()

    it 'only doesn\'t get called if not unmounted', (done) ->
      unmountCalled = 0
      mountCalled = 0
      class BindComponent
        onMount: ->
          mountCalled += 1
        onBeforeUnmount: ->
          unmountCalled += 1
        render: ->
          z 'div',
            z 'span', 'Hello World'
            z 'span', 'Goodbye'

      bind = new BindComponent()

      root = document.createElement 'div'
      z.render root, bind
      window.requestAnimationFrame ->
        z.redraw()
        window.requestAnimationFrame ->
          z.redraw()
          window.requestAnimationFrame ->
            z.redraw()

            setTimeout ->
              mountCalled.should.be 1
              unmountCalled.should.be 0
              done()
            , 20

    # https://github.com/claydotio/zorium/issues/13
    it 'property replacing diff calls unhook method', ->
      unmountsCalled = 0

      class A
        onBeforeUnmount: ->
          unmountsCalled += 1
        render: ->
          z 'div', 'x'

      class B
        onBeforeUnmount: ->
          unmountsCalled += 1
        render: ->
          z 'div', 'x'

      $a = new A()
      $b = new B()

      root = document.createElement 'div'

      z.render root, $a
      z.render root, $b
      z.render root, z 'x'

      unmountsCalled.should.be 2

describe 'redraw()', ->
  it 'redraws all bound root nodes', (done) ->
    drawCnt = 0
    class RedrawComponent
      render: ->
        drawCnt += 1
        z 'div'

    draw = new RedrawComponent()
    root = document.createElement 'div'
    z.render root, draw
    z.redraw()
    window.requestAnimationFrame ->
      drawCnt.should.be 2
      done()

  it 'renders properly after multiple redraws', (done) ->
    drawCnt = 0
    class RedrawComponent
      render: ->
        drawCnt += 1
        z 'div'

    draw = new RedrawComponent()
    root = document.createElement 'div'
    z.render root, draw
    z.redraw()
    window.requestAnimationFrame ->
      z.redraw()
      window.requestAnimationFrame ->
        result = '<div><div></div></div>'
        root.isEqualNode(htmlToNode(result)).should.be true
        drawCnt.should.be 3
        done()

  it 'batches redraws', (done) ->
    drawCnt = 0
    class RedrawComponent
      render: ->
        drawCnt += 1
        z 'div'

    draw = new RedrawComponent()
    root = document.createElement 'div'
    z.render root, draw
    z.redraw()
    z.redraw()
    z.redraw()
    z.redraw()
    drawCnt.should.be 1
    window.requestAnimationFrame ->
      drawCnt.should.be 2
      done()

describe 'z.observe()', ->
  it 'observes values', ->
    types = [
      'a', 1, [2], false, {b: 1}
    ]
    changed = [
      'b', 9, [2,1], true, {c: 2}
    ]

    for type, i in types
      a = z.observe type
      a().should.be type

      change = changed[i]

      a (newed) ->
        newed.should.be change

      a.set change

  it 'observes promises', ->
    promise = deferred()
    p = z.observe promise

    (p() is null).should.be true

    promise.resolve 1

    p.then ->
      p().should.be 1

  it 'observes promises', ->
    p = z.observe new Promise (resolve) -> resolve 1
    p.then (one) ->
      one.should.be 1

  it 'throws on rejected promises', (done) ->
    p = deferred()

    obj = z.observe p

    (obj() is null).should.be true

    oldError = window.onerror
    window.onerror = (e) ->
      window.onerror = oldError
      done()

    p.reject new Error 'abc'

  it 'sets promises correctly', ->
    p = deferred()

    obj = z.observe null

    obj.set p

    (obj() is null).should.be true

    p.resolve 'abc'

    obj.then ->
      obj().should.be 'abc'

  it 'sets promises correctly against race conditions', ->
    p1 = deferred()
    p2 = deferred()

    obj = z.observe null

    obj.set p1
    obj.set p2

    (obj() is null).should.be true

    p2.resolve 'a'
    p2.then ->
      obj().should.be 'a'

      p1.resolve 'NO'
      p1.then ->
        obj().should.be 'a'

describe 'z.state', ->
  it 'obesrves state, returning an observable', ->
    subject = new Rx.BehaviorSubject(null)
    promise = Promise.resolve 'b'
    state = z.state
      a: 'a'
      b: Rx.Observable.fromPromise promise
      c: subject

    _.isFunction(state.subscribe).should.be true

    state.subscribe (state) ->
      state.a.should.be 'a'

    state.getValue().should.be {a: 'a', b: null, c: null}

    promise.then ->
      state.getValue().should.be {a: 'a', b: 'b', c: null}
      subject.onNext 'c'
      state.getValue().should.be {a: 'a', b: 'b', c: 'c'}

      state.set x: 'x'
      state.getValue().x.should.be 'x'
      state.set x: 'X'
      state.getValue().x.should.be 'X'

  it 'sets state with false values', ->
    state = z.state
      a: 'a'
      b: false
      c: 123

    state.getValue().should.be {a: 'a', b: false, c: 123}

  it 'redraws on state observable change', (done) ->
    subject = new Rx.BehaviorSubject(null)
    redrawCnt = 0

    class App
      constructor: ->
        @state = z.state
          subject: subject
      render: ->
        redrawCnt += 1
        z 'div'

    root = document.createElement 'div'
    app = new App()
    z.render root, app
    redrawCnt.should.be 1

    subject.onNext 'abc'

    window.requestAnimationFrame ->
      redrawCnt.should.be 2
      done()

  it 'errors when setting observable values in diff', ->
    subject = new Rx.BehaviorSubject(null)

    state = z.state
      subject: subject

    (->
      state.set subject: 'subject'
    ).should.throw()

  it 'throws errors', ->
    subject = new Rx.BehaviorSubject(null)

    state = z.state
      subject: subject

    (->
      subject.onError new Error 'err'
    ).should.throw()

# START LEGACY
describe 'z.oldState', ->
  it 'observes state', ->

    promise = deferred()

    state = z.oldState
      a: 'abc'
      b: 123
      c: [1, 2, 3]
      d: z.observe promise

    state().should.be
      a: 'abc'
      b: 123
      c: [1, 2, 3]
      d: null

    promise.resolve(123)

    # promise resolved
    state.d.then ->
      state().d.should.be 123

      # watch for changes
      state (state) ->
        state.b.should.be 321

      # partial update
      state.set
        b: 321
      state().should.be
        a: 'abc'
        b: 321
        c: [1, 2, 3]
        d: 123

  it 'redraws on state observable change', (done) ->
    cnt = 0
    class App
      constructor: ->
        @oldState = z.oldState
          abc: 'def'
      render: ->
        cnt += 1
        z 'div'

    root = document.createElement 'div'
    app = new App()
    z.render root, app
    z.render root, app
    z.render root, app

    app.oldState.set
      abc: 'fed'

    window.requestAnimationFrame ->
      app.oldState.set
        abc: 'den'

      window.requestAnimationFrame ->
        cnt.should.be 5
        done()

  it 'redraws on promise resolution', (done) ->
    promise = deferred()
    p2 = deferred()
    cnt = 0
    class App
      constructor: ->
        @oldState = z.oldState
          p: z.observe promise
          p2: z.observe p2
      render: ->
        cnt += 1
        z 'div'

    root = document.createElement 'div'
    app = new App()
    z.render root, app

    window.requestAnimationFrame ->
      promise.resolve 'abc'

      promise.then ->
        window.requestAnimationFrame ->
          app.oldState().p.should.be 'abc'
          cnt.should.be 2
          done()

  it 'allows overriding of promised params', ->
    p = deferred()
    state = z.oldState
      p: z.observe p

    state.set
      p: 'y'

    p.resolve('p')
    p.then ->
      state().p.should.be 'y'
# END LEGACY

describe 'router', ->
  beforeEach (done) ->
    # Allow routes to settle
    setTimeout ->
      done()
    , 100

  it 'renders updated DOM', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/testa1', -> new App()
    z.router.add '/testa2', -> new App2()

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.router.go '/testa1'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.router.go '/testa2'
    root.isEqualNode(htmlToNode(result2)).should.be true

  it 'updates location hash', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test', -> new App()
    z.router.add '/test2', -> new App2()

    z.router.setMode 'hash'

    z.router.go '/test'
    window.location.hash.should.be '#/test'
    z.router.go '/test2'
    window.location.hash.should.be '#/test2'

  it 'updated pathname', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test3', -> new App()
    z.router.add '/test4', -> new App()

    z.router.setMode 'pathname'

    z.router.go '/test3'
    window.location.pathname.should.be '/test3'
    z.router.go '/test4'
    window.location.pathname.should.be '/test4'

  it 'doesn\'t render same route twice', ->
    rendered = 0
    class App
      render: ->
        rendered += 1
        z 'div', 'Hello World'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/twice', -> new App()

    z.router.setMode 'hash'

    z.router.go '/twice'
    rendered.should.be 1
    z.router.go '/twice'
    rendered.should.be 1

  it 'updates query param in hash mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      constructor: (pathParams, {x, y} = {}) ->
        should.not.exist x
        y.should.be 'abc'
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test-qs', -> new App()
    z.router.add '/test-qs2', ({params, query}) -> new App2(params, query)

    z.router.setMode 'hash'

    z.router.go '/test-qs?x=abc'
    window.location.hash.should.be '#/test-qs?x=abc'
    z.router.go '/test-qs?x=xxx'
    window.location.hash.should.be '#/test-qs?x=xxx'
    z.router.go '/test-qs2?y=abc'
    window.location.hash.should.be '#/test-qs2?y=abc'

  it 'updates query string in path mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      constructor: (pathParams, {x, y}) ->
        should.not.exist x
        y.should.be 'abc'
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test-qs3', -> new App()
    z.router.add '/test-qs4', ({params, query}) -> new App2(params, query)

    z.router.setMode 'pathname'

    z.router.go '/test-qs3?x=abc'
    window.location.pathname.should.be '/test-qs3'
    window.location.search.should.be '?x=abc'
    z.router.go '/test-qs3?x=xxx'
    window.location.pathname.should.be '/test-qs3'
    window.location.search.should.be '?x=xxx'
    z.router.go '/test-qs4?y=abc'
    window.location.pathname.should.be '/test-qs4'
    window.location.search.should.be '?y=abc'

  it 'ignores hash if in hash mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test-ignore-hash', -> new App()
    z.router.add '/test-ignore-hash2', -> new App2()

    z.router.setMode 'hash'

    z.router.go '/test-ignore-hash#abc'
    window.location.hash.should.be '#/test-ignore-hash'
    z.router.go '/test-ignore-hash2#efg'
    window.location.hash.should.be '#/test-ignore-hash2'

  it 'ignores hash if in pathname mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test-use-path', -> new App()
    z.router.add '/test-use-path2', -> new App2()

    z.router.setMode 'pathname'

    z.router.go '/test-use-path#abc'
    window.location.pathname.should.be '/test-use-path'
    window.location.hash.should.be ''
    z.router.go '/test-use-path#def'
    window.location.pathname.should.be '/test-use-path'
    window.location.hash.should.be ''
    z.router.go '/test-use-path2#abc'
    window.location.pathname.should.be '/test-use-path2'
    window.location.hash.should.be ''

  it 'routes to default current path in hash mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    window.location.hash = '/test-pre-hash'

    z.router.setRoot root
    z.router.add '/test-pre-hash', -> new App()

    z.router.setMode 'hash'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.router.go()
    root.isEqualNode(htmlToNode(result2)).should.be true
    window.location.hash.should.be '#/test-pre-hash'

  it 'routes to default current path in hash mode with query string', ->
    class App
      constructor: (pathParams, {x}) ->
        x.should.be 'abc'
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    window.location.hash = '/test-pre-hash-search?x=abc'

    z.router.setRoot root
    z.router.add '/test-pre-hash-search',
      ({params, query}) -> new App(params, query)

    z.router.setMode 'hash'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.router.go()
    root.isEqualNode(htmlToNode(result2)).should.be true
    window.location.hash.should.be '#/test-pre-hash-search?x=abc'

  it 'routes to default current path in pathname mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    window.history.pushState null, null, '/test-pre'

    z.router.setRoot root
    z.router.add '/test-pre', -> new App()

    z.router.setMode 'pathname'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.router.go()
    root.isEqualNode(htmlToNode(result2)).should.be true
    window.location.pathname.should.be '/test-pre'

  it 'routes to default current path in pathname mode with query string', ->
    class App
      constructor: (pathParams, {x}) ->
        x.should.be 'abc'
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    window.history.pushState null, null, '/test-pre-search?x=abc'

    z.router.setRoot root
    z.router.add '/test-pre-search', ({params, query}) -> new App(params, query)

    z.router.setMode 'pathname'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.router.go()
    root.isEqualNode(htmlToNode(result2)).should.be true
    window.location.pathname.should.be '/test-pre-search'
    window.location.search.should.be '?x=abc'


  it 'responds to hashchange', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test5', -> new App()
    z.router.add '/test6', -> new App2()

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.router.setMode 'hash'
    z.router.go '/test5'

    window.location.hash = '/test5'
    setTimeout ->
      root.isEqualNode(htmlToNode(result1)).should.be true

      window.location.hash = '/test6'
      setTimeout ->
        root.isEqualNode(htmlToNode(result2)).should.be true

        window.location.hash = '/test5'
        window.location.hash.should.be '#/test5'
        setTimeout ->
          root.isEqualNode(htmlToNode(result1)).should.be true
          done()

  it 'responds to popstate', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/testa', -> new App()
    z.router.add '/testb', -> new App2()

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.router.setMode 'pathname'

    z.router.go '/testa'
    z.router.go '/testb'
    window.history.back()
    setTimeout ->
      root.isEqualNode(htmlToNode(result1)).should.be true
      z.router.go '/testb'
      z.router.go '/testa'
      window.history.back()
      setTimeout ->
        root.isEqualNode(htmlToNode(result2)).should.be true
        window.location.pathname.should.be '/testb'
        done()
      , 90
    , 90

  it 'doesn\'t respond to popstate before initial route', ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/', -> new App()

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    z.router.setMode 'pathname'

    event = new Event 'popstate'
    window.dispatchEvent event

    root.isEqualNode(htmlToNode(result1)).should.be true

    z.router.go '/'
    root.isEqualNode(htmlToNode(result2)).should.be true

  it 'passes params', ->
    class App
      constructor: (params) ->
        @key = params?.key or 'FALSE'

      render: =>
        z 'div', 'Hello ' + @key

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test/:key', ({params, query}) -> new App(params, query)

    result = '<div><div>Hello world</div></div>'
    z.router.go('/test/world')

    root.isEqualNode(htmlToNode(result)).should.be true


  it 'emits route events (hash mode)', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test7', -> new App()

    z.router.setMode 'hash'

    callbackCalled = 0
    listener = (path) ->
      callbackCalled += 1
      path.should.be '/test7'

    z.router.on('route', listener)
    z.router.go '/test7'
    z.router.off('route', listener)

    setTimeout ->
      callbackCalled.should.be 1
      done()

  it 'emits route events (path mode)', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test8', -> new App()

    z.router.setMode 'pathname'

    callbackCalled = 0
    listener = (path) ->
      callbackCalled += 1
      path.should.be '/test8'

    z.router.on('route', listener)
    z.router.go '/test8'
    z.router.off('route', listener)

    setTimeout ->
      callbackCalled.should.be 1
      done()

  it 'allows redirects', (done) ->
    class App
      render: ->
        done(new Error 'Should not be called')
        z 'div'

    class Login
      render: -> z 'div'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test9', -> z.router.go '/login1'
    z.router.add '/login1', -> new Login()

    z.router.setMode 'pathname'

    z.router.go '/test9'

    setTimeout ->
      window.location.pathname.should.be '/login1'
      done()

  it 'allows async redirect', (done) ->
    class App
      render: ->
        done(new Error 'Should not be called')
        z 'div'

    class Login
      render: -> z 'div'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test10', ->
      setTimeout -> z.router.go '/login2'
      z 'div'
    z.router.add '/login2', -> new Login()

    z.router.setMode 'pathname'

    z.router.go '/test10'

    setTimeout ->
      window.location.pathname.should.be '/login2'
      done()

  describe 'z.ev', ->
    it 'wraps the this', ->
      fn = z.ev (e, $$el) ->
        e.ev.should.be 'x'
        $$el.a.should.be 'b'

      fn.call {a: 'b'}, {ev: 'x'}
