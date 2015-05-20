should = require('clay-chai').should()
createElement = require 'virtual-dom/create-element'
Promise = window.Promise or require 'promiz'
Rx = require 'rx-lite'
Routes = require 'routes'
Qs = require 'qs'

z = require '../src/zorium'

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

class Router
  constructor: ->
    @router = new Routes()

  add: (path, $component) =>
    @router.addRoute path, (props) -> z $component, props

  render: ({path, query}) =>
    route = @router.match(path)

    z 'div',
      route.fn {
        params: route.params
        query: query
      }

beforeEach (done) ->
  # Allows routes to settle
  window.requestAnimationFrame ->
    done()

describe 'Virtual DOM', ->
  it 'creates basic DOM trees', ->
    dom = z 'div',
      z '.cname#cid', 'abc'
      z 'a.b',
        href: '#'
        attributes:
          'data-non': 123
          eatme: 'true'
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

    result = '<div>' +
      '<div class="container"></div>' +
      '<div id="layout"></div>' +
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

  it 'allows component render to return undefined', ->
    class HelloWorldComponent
      render: ->
        return

    hello = new HelloWorldComponent()

    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'

    root = document.createElement 'div'

    result = '<div>' +
      '<div>a</div>' +
      '<div>b</div>' +
      '<noscript></noscript>' +
    '</div>'

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

    result = '<div>' +
      '<div>a</div>' +
      '<div>b</div>' +
    '</div>'

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
    dom = z 'a', href: 'http://192.168.1.0', 'test'
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
        z 'div',
          z @$a, {world: 'world'}

    $b = new B()

    root = document.createElement 'div'

    z.render root, $b

    result = '<div><div>hello world</div></div>'
    root.isEqualNode(htmlToNode(result)).should.be true


  describe 'Anchor Tag', ->
    it 'defaults anchor tag onclick event to use router', (done) ->
      preventDefaultCalled = 0
      goCalled = 0

      dom = z.router.link z 'a', href: '/anchor1'
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'
      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      router = new Router()
      router.add '/anchor1', z 'div'

      root = document.createElement 'div'

      z.router.init {$$root: root}
      z.router.use (req, res) ->
        req.path.should.be '/anchor1'
        preventDefaultCalled.should.be 1
        res.send z router, {path: req.path, query: req.query}
        done()

      dom.properties.onclick.call($el, e)


    it 'doesn\'t default anchor tags with external path', (done) ->
      preventDefaultCalled = 0
      goCalled = 0

      dom = z.router.link z 'a', href: 'http://google.com'
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'

      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      root = document.createElement 'div'

      z.router.init {$$root: root}
      z.router.use (req, res) ->
        goCalled += 1
        res.send new Router()

      dom.properties.onclick.call($el, e)

      setTimeout ->
        preventDefaultCalled.should.be 0
        goCalled.should.be 0
        done()

    it 'writes if other properties exist', (done) ->
      preventDefaultCalled = 0
      goCalled = 0

      dom = z.router.link z 'a',
        href: '/anchor2'
        name: 'test'
        onmousedown: -> null
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'

      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      router = new Router()
      router.add '/anchor2', z 'div'

      root = document.createElement 'div'

      z.router.init {$$root: root}
      z.router.use (req, res) ->
        req.path.should.be '/anchor2'
        preventDefaultCalled.should.be 1
        res.send z router, {path: req.path, query: req.query}
        done()

      dom.properties.onclick.call($el, e)

    it 'throws if attempted to override onclick', (done) ->
      try
        z.router.link z 'a', href: '/', name: 'test',
          {onclick: -> clickCalled += 1}
        done(new Error 'Error expected')
      catch
        done()

describe 'render()', ->
  it 'renders to dom node', ->
    root = document.createElement('div')
    z.render root, (z 'div', 'Hello World')
    result = '<div>Hello World</div>'
    root.isEqualNode(htmlToNode(result)).should.be true

  it 'renders components', ->
    class HelloWorldComponent
      render: ->
        z 'div', 'Hello World'
    hello = new HelloWorldComponent()

    root = document.createElement('div')
    $el = z.render root, hello
    result = '<div>Hello World</div>'

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'patches dom node on multiple renders', ->
    root = document.createElement('div')
    z.render root, (z 'div', 'Hello World')
    result1 = '<div>Hello World</div>'
    root.isEqualNode(htmlToNode(result1)).should.be true

    z.render root, (z 'div', 'Sayonara')
    result2 = '<div>Sayonara</div>'
    root.isEqualNode(htmlToNode(result2)).should.be true

    z.render root, (z 'div', (z 'div', 'done'))
    result3 = '<div><div>done</div></div>'
    root.isEqualNode(htmlToNode(result3)).should.be true

describe 'Lifecycle Callbacks', ->
  describe 'afterMount', ->
    it 'gets called after initial load', (done) ->
      mountCalled = 0
      class BindComponent
        afterMount: ($el) ->
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
        afterMount: ($el) ->
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

      setTimeout ->
        z.render root, dom

        setTimeout ->
          z.render root, dom

          dom = z 'div',
            bind
            z 'span', 'world'
          z.render root, dom

          setTimeout ->
            z.render root, dom

            setTimeout ->
              mountCalled.should.be 1
              done()

            , 10
          , 20
        , 20
      , 20

  describe 'beforeUnmount', ->
    it 'gets called before removal from DOM', (done) ->
      class BindComponent
        beforeUnmount: ->
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
        afterMount: ->
          mountCalled += 1
        beforeUnmount: ->
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
        afterMount: ->
          mountCalled += 1
        beforeUnmount: ->
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
        afterMount: ->
          mountCalled += 1
        beforeUnmount: ->
          unmountCalled += 1
        render: ->
          z 'div',
            z 'span', 'Hello World'
            z 'span', 'Goodbye'

      bind = new BindComponent()

      root = document.createElement 'div'
      z.render root, bind
      window.requestAnimationFrame ->
        z.render root, bind
        window.requestAnimationFrame ->
          z.render root, bind
          window.requestAnimationFrame ->
            z.render root, bind

            setTimeout ->
              mountCalled.should.be 1
              unmountCalled.should.be 0
              done()
            , 20

    # https://github.com/claydotio/zorium/issues/13
    it 'property replacing diff calls unhook method', ->
      unmountsCalled = 0

      class A
        beforeUnmount: ->
          unmountsCalled += 1
        render: ->
          z 'div', 'x'

      class B
        beforeUnmount: ->
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

describe 'z.state', ->
  it 'obesrves state, returning an observable', ->
    subject = new Rx.BehaviorSubject(null)
    promise = Promise.resolve 'b'
    state = z.state
      a: 'a'
      b: Rx.Observable.fromPromise promise
      c: subject

    state._bind_subscriptions()

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

    state._bind_subscriptions()

    (->
      subject.onError new Error 'err'
    ).should.throw()

  it 'lazy subscribes', ->
    lazyRuns = 0

    cold = Rx.Observable.defer ->
      lazyRuns += 1
      Rx.Observable.return lazyRuns

    state = z.state
      lazy: cold

    lazyRuns.should.be 0

    state._bind_subscriptions()
    lazyRuns.should.be 1

    state.set a: 'b'
    lazyRuns.should.be 1

    state2 = z.state
      lazy: cold

    lazyRuns.should.be 1

    state2._bind_subscriptions()
    lazyRuns.should.be 2

    state.getValue().lazy.should.be 1
    state2.getValue().lazy.should.be 2

describe 'router', ->
  it 'renders updated DOM', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'XXXXXXXXXXX'

    router = new Router()
    router.add '/testa1', new App()
    router.add '/testa2', new App2()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>XXXXXXXXXXX</div></div>'

    z.router.go '/testa1'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.router.go '/testa2'
    root.isEqualNode(htmlToNode(result2)).should.be true

  it 'redraws on state observable change', (done) ->
    drawCnt = 0
    subject = new Rx.BehaviorSubject(null)

    class App
      constructor: ->
        @state = z.state
          subject: subject

      render: ->
        drawCnt += 1
        z 'div', 'Hello World'

    router = new Router()
    router.add '/testaRedraw', new App()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    z.router.go '/testaRedraw'
    drawCnt.should.be 1

    subject.onNext 'abc'

    setTimeout ->
      window.requestAnimationFrame ->
        drawCnt.should.be 2
        done()

  it 'redraws on child state observable change, pre-rendered', (done) ->
    drawCnt = 0
    subject = new Rx.BehaviorSubject(null)

    class Child
      constructor: ->
        @state = z.state
          subject: subject
      render: ->
        drawCnt += 1
        return z 'div', 'x'

    class App
      constructor: ->
        @state = z.state
          $child: z new Child(), {}

      render: =>
        {$child} = @state.getValue()
        z 'div', $child

    router = new Router()
    router.add '/testaChildRedraw', new App()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    z.router.go '/testaChildRedraw'
    drawCnt.should.be 1

    subject.onNext 'abc'
    setTimeout ->
      window.requestAnimationFrame ->
        drawCnt.should.be 2
        done()

  it 'redraws on lazy state observable change', (done) ->
    drawCnt = 0
    lazyRuns = 0
    lazyPromise = deferred()

    cold = Rx.Observable.defer ->
      lazyRuns += 1
      Rx.Observable.fromPromise lazyPromise

    class App
      constructor: ->
        @state = z.state
          observable: cold

      render: ->
        drawCnt += 1
        z 'div', 'Hello World'

    router = new Router()
    router.add '/testLazyRedraw', new App()

    root = document.createElement 'div'

    lazyRuns.should.be 0

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    z.router.go '/testLazyRedraw'
    window.requestAnimationFrame ->
      drawCnt.should.be 1
      lazyRuns.should.be 1

      lazyPromise.then ->
        window.requestAnimationFrame ->
          lazyRuns.should.be 1
          drawCnt.should.be 2
          done()

      lazyPromise.resolve 'x'

  it 'unbinds state beforeUnmount', (done) ->
    appDrawCnt = 0
    app2DrawCnt = 0
    lazyPromise = deferred()

    cold = Rx.Observable.defer ->
      Rx.Observable.fromPromise lazyPromise

    class App
      constructor: ->
        @state = z.state
          observable: cold
      render: ->
        appDrawCnt += 1
        z 'div', 'Hello World'

    class App2
      render: ->
        app2DrawCnt += 1
        z 'div', 'Hello World'

    router = new Router()
    router.add '/testUnbindLazy', new App()
    router.add '/testUnbindLazy2', new App2()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    z.router.go '/testUnbindLazy'
    appDrawCnt.should.be 1
    app2DrawCnt.should.be 0

    window.requestAnimationFrame ->
      z.router.go '/testUnbindLazy2'

      appDrawCnt.should.be 1
      app2DrawCnt.should.be 1

      window.requestAnimationFrame ->
        appDrawCnt.should.be 1
        app2DrawCnt.should.be 1

        # should not cause re-draw
        lazyPromise.resolve 'x'

        lazyPromise.then ->
          window.requestAnimationFrame ->
            appDrawCnt.should.be 1
            app2DrawCnt.should.be 1
            done()


  it 'updates location hash', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    router = new Router()
    router.add '/test', new App()
    router.add '/test2', new App2()

    z.router.init {$$root: root, mode: 'hash'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

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

    router = new Router()
    router.add '/test3', new App()
    router.add '/test4', new App2()


    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    z.router.go '/test3'
    window.location.pathname.should.be '/test3'
    z.router.go '/test4'
    window.location.pathname.should.be '/test4'

  it 'updates query param in hash mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ({params, query}) ->
        query.y.should.be 'abc'
        z 'div', 'World Hello'

    root = document.createElement 'div'

    router = new Router()
    router.add '/test-qs', new App()
    router.add '/test-qs2', new App2()

    z.router.init {$$root: root, mode: 'hash'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

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
      render: ({params, query}) ->
        query.y.should.be 'abc'
        z 'div', 'World Hello'

    root = document.createElement 'div'

    router = new Router()
    router.add '/test-qs3', new App()
    router.add '/test-qs4', new App2()


    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    z.router.go '/test-qs3?x=abc'
    window.location.pathname.should.be '/test-qs3'
    window.location.search.should.be '?x=abc'
    z.router.go '/test-qs3?x=xxx'
    window.location.pathname.should.be '/test-qs3'
    window.location.search.should.be '?x=xxx'
    z.router.go '/test-qs4?y=abc'
    window.location.pathname.should.be '/test-qs4'
    window.location.search.should.be '?y=abc'

  it 'routes to default current path in hash mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    window.location.hash = '/test-pre-hash'

    router = new Router()
    router.add '/test-pre-hash', new App()

    z.router.init {$$root: root, mode: 'hash'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.router.go()
    root.isEqualNode(htmlToNode(result2)).should.be true
    window.location.hash.should.be '#/test-pre-hash'

  it 'routes to default current path in hash mode with query string', ->
    class App
      render: ({params, query}) ->
        query.x.should.be 'abc'
        z 'div', 'Hello World'

    root = document.createElement 'div'

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    window.location.hash = '/test-pre-hash-search?x=abc'

    router = new Router()
    router.add '/test-pre-hash-search', new App()

    z.router.init {$$root: root, mode: 'hash'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
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

    router = new Router()
    router.add '/test-pre', new App()

    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.router.go()
    root.isEqualNode(htmlToNode(result2)).should.be true
    window.location.pathname.should.be '/test-pre'

  it 'routes to default current path in pathname mode with query string', ->
    class App
      render: ({params, query}) ->
        query.x.should.be 'abc'
        z 'div', 'Hello World'

    root = document.createElement 'div'

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    window.history.pushState null, null, '/test-pre-search?x=abc'

    router = new Router()
    router.add '/test-pre-search', new App()

    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
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

    router = new Router()
    router.add '/test5', new App()
    router.add '/test6', new App2()

    z.router.init {$$root: root, mode: 'hash'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.router.go '/test5'

    window.location.hash = '/test5'
    setTimeout -> # TODO: figure out why this needs 2
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

    router = new Router()
    router.add '/testa', new App()
    router.add '/testb', new App2()

    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'


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
    , 120

  it 'doesn\'t respond to popstate before initial route', ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    router = new Router()
    router.add '/', new App()

    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'


    event = new Event 'popstate'
    window.dispatchEvent event

    root.isEqualNode(htmlToNode(result1)).should.be true

    z.router.go '/'
    root.isEqualNode(htmlToNode(result2)).should.be true

  it 'passes params', ->
    class App
      render: ({params}) ->
        z 'div', 'Hello ' + params.key

    root = document.createElement 'div'

    router = new Router()
    router.add '/test/:key', new App()

    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    result = '<div><div>Hello world</div></div>'
    z.router.go('/test/world')

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'passes state', ->
    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z 'div', req.state.x
    result = '<div>abc</div>'
    z.router.go('/', {x: 'abc'})

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'allows async redirect', (done) ->
    class App
      render: ->
        done(new Error 'Should not be called')
        z 'div'

    class Login
      render: -> z 'div'

    root = document.createElement 'div'

    router = new Router()
    router.add '/test10',
      render: ->
        setTimeout -> z.router.go '/login2'
        z 'div'
    router.add '/login2', new Login()

    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    z.router.go '/test10'

    setTimeout ->
      window.location.pathname.should.be '/login2'
      done()

  it 'batches redraws', (done) ->
    drawCnt = 0
    changeSubject = new Rx.BehaviorSubject null
    class App
      constructor: ->
        @state = z.state
          change: changeSubject
      render: ->
        drawCnt += 1
        z 'div', 'Hello World'

    router = new Router()
    router.add '/testBatchRedraw', new App()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    z.router.go '/testBatchRedraw'
    z.router.go '/testBatchRedraw'
    z.router.go '/testBatchRedraw'
    z.router.go '/testBatchRedraw'
    z.router.go '/testBatchRedraw'

    drawCnt.should.be 1

    window.requestAnimationFrame ->
      drawCnt.should.be 1

      changeSubject.onNext 1
      changeSubject.onNext 2
      changeSubject.onNext 3
      changeSubject.onNext 4
      changeSubject.onNext 5
      changeSubject.onNext 6

      window.requestAnimationFrame ->
        drawCnt.should.be 2

        changeSubject.onNext 7
        changeSubject.onNext 8
        changeSubject.onNext 9
        changeSubject.onNext 10
        changeSubject.onNext 11
        changeSubject.onNext 12

        window.requestAnimationFrame ->
          drawCnt.should.be 3

          changeSubject.onNext 7
          changeSubject.onNext 8
          changeSubject.onNext 9
          changeSubject.onNext 10
          changeSubject.onNext 11
          changeSubject.onNext 12

          window.requestAnimationFrame ->
            drawCnt.should.be 4
            done()

  it 'when re-using components, all instances are updated', (done) ->
    subject = new Rx.BehaviorSubject 'abc'
    prefix = '1-'

    class A
      constructor: ->
        @state = z.state
          abc: subject
      render: ({name}) =>
        {abc} = @state.getValue()

        z '.z-a',
          z 'div', name
          z 'div', abc

    class B
      constructor: ->
        @state = z.state
          $a: new A()
      render: ->
        {$a} = @state.getValue()

        z 'div',
          z '.a1',
            z $a, {name: prefix + 'a1'}
          z '.a2',
            z $a, {name: prefix + 'a2'}

    router = new Router()
    router.add '/test-reuse', new B()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    result1 = '<div><div>' +
                '<div class="a1"><div class="z-a">' +
                  '<div>1-a1</div>' +
                  '<div>abc</div>' +
                '</div></div>' +
                '<div class="a2"><div class="z-a">' +
                  '<div>1-a2</div>' +
                  '<div>abc</div>' +
                '</div></div>' +
              '</div></div>'

    result2 = '<div><div>' +
                '<div class="a1"><div class="z-a">' +
                  '<div>2-a1</div>' +
                  '<div>xyz</div>' +
                '</div></div>' +
                '<div class="a2"><div class="z-a">' +
                  '<div>2-a2</div>' +
                  '<div>xyz</div>' +
                '</div></div>' +
              '</div></div>'

    result3 = '<div><div>' +
                '<div class="a1"><div class="z-a">' +
                  '<div>2-a1</div>' +
                  '<div>xxx</div>' +
                '</div></div>' +
                '<div class="a2"><div class="z-a">' +
                  '<div>2-a2</div>' +
                  '<div>xxx</div>' +
                '</div></div>' +
              '</div></div>'

    z.router.go '/test-reuse'
    root.isEqualNode(htmlToNode(result1)).should.be true

    # change in props leads to both updating
    prefix = '2-'
    subject.onNext 'xyz'
    setTimeout ->
      root.isEqualNode(htmlToNode(result2)).should.be true
      done()

      # change in state currently does not lead to both updating
      # TODO: see if this can reasonably be fixed
      # subject.onNext 'xxx'
      # setTimeout ->
      #   root.isEqualNode(htmlToNode(result3)).should.be true
      #   done()
      # , 20
    , 20


  it 'renders full page, setting title and #zorium-root content', ->
    class Root
      render: ->
        z 'html',
          z 'head',
            z 'title', 'test_title'
          z 'body',
            z '#zorium-root',
              z 'div', 'test-content'

    root = document.getElementById 'zorium-root'
    if root
      root._zoriumId = null
    else
      root = document.createElement 'div'
      root.id = 'zorium-root'
      document.body.appendChild root

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send new Root()

    document.title.should.not.be 'test_title'

    z.router.go '/renderFullPage'

    result = '<div id="zorium-root"><div>test-content</div></div>'

    document.title.should.be 'test_title'
    root.isEqualNode(htmlToNode(result)).should.be true

  it 'diffs full page', ->
    class Root
      render: ->
        z 'html',
          z 'head',
            z 'title', 'some_title'
          z 'body',
            z '#zorium-root',
              z '.t', 'test-content'

    root = document.getElementById 'zorium-root'
    if root
      root._zoriumId = null
    else
      root = document.createElement 'div'
      root.id = 'zorium-root'
      document.body.appendChild root
    root.innerHTML = '<div class="t"></div>'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send new Root()

    z.router.go '/diffFullPage'

    result = '<div id="zorium-root"><div class="t">test-content</div></div>'

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'binds to root state when full page rendering', (done) ->
    class Root
      constructor: ->
        @state = z.state
          changeme: 'changeme'
      render: =>
        {changeme} = @state.getValue()

        z 'html',
          z 'head',
            z 'title', 'x'
          z 'body',
            z '#zorium-root',
              z 'div', changeme

    root = document.getElementById 'zorium-root'
    if root
      root._zoriumId = null
    else
      root = document.createElement 'div'
      root.id = 'zorium-root'
      document.body.appendChild root

    $root = new Root()
    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send $root

    z.router.go '/'

    # TODO: figure out why class=""
    result1 = '<div id="zorium-root"><div class="">changeme</div></div>'
    result2 = '<div id="zorium-root"><div class="">xxx</div></div>'

    root.isEqualNode(htmlToNode(result1)).should.be true

    $root.state.set
      changeme: 'xxx'

    setTimeout ->
      root.isEqualNode(htmlToNode(result2)).should.be true
      done()
    , 20

  it 'binds updates when adding a new child', (done) ->
    subject = new Rx.BehaviorSubject 'abc'
    class Child
      constructor: ->
        @state = z.state
          abc: subject

      render: =>
        {abc} = @state.getValue()

        z 'div', abc

    class A
      constructor: ->
        @state = z.state
          children: []

      addChild: ($el) =>
        {children} = @state.getValue()
        @state.set children: children.concat $el

      render: =>
        {children} = @state.getValue()

        z 'div',
          children

    router = new Router()
    $a = new A()
    $child = new Child()
    router.add '/test-new-child', $a

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    result1 = '<div><div></div></div>'
    result2 = '<div><div><div>abc</div></div></div>'
    result3 = '<div><div><div>xyz</div></div></div>'

    z.router.go '/test-new-child'
    root.isEqualNode(htmlToNode(result1)).should.be true

    $a.addChild $child
    setTimeout ->
      root.isEqualNode(htmlToNode(result2)).should.be true

      subject.onNext 'xyz'
      setTimeout ->
        root.isEqualNode(htmlToNode(result3)).should.be true
        done()
      , 20
    , 20

describe 'z.ev', ->
  it 'wraps the this', ->
    fn = z.ev (e, $$el) ->
      e.ev.should.be 'x'
      $$el.a.should.be 'b'

    fn.call {a: 'b'}, {ev: 'x'}

describe 'classKebab', ->
  it 'kebabs objects', ->
    kebab = z.classKebab
      a: true
      b: true
      c: true
      d: 0
      e: false
      f: null
      g: undefined

    kebab.should.be 'a b c'

describe 'isSimpleClick', ->
  it 'checks for non-left clicks', ->
    z.isSimpleClick {which: 2}
    .should.be false

    z.isSimpleClick {which: 1}
    .should.be true

    z.isSimpleClick {which: 1, shiftKey: true}
    .should.be false
