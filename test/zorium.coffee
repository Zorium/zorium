should = require('clay-chai').should()
createElement = require 'virtual-dom/create-element'
Promise = window.Promise or require 'promiz'
Rx = require 'rx-lite'
Routes = require 'routes'
Qs = require 'qs'
cookie = require 'cookie'

z = require 'zorium'

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

parseUrl = (url) ->
  if window?
    a = document.createElement 'a'
    a.href = url

    {
      pathname: a.pathname
      hash: a.hash
      search: a.search
      path: a.pathname + a.search
    }
  else
    # Avoid webpack include
    _url = 'url'
    URL = require(_url)
    parsed = URL.parse url

    {
      pathname: parsed.pathname
      hash: parsed.hash
      search: parsed.search
      path: parsed.path
    }

class Router
  constructor: ->
    @router = new Routes()

  add: (path, $component) =>
    @router.addRoute path, (props) -> z $component, props

  render: ({path}) =>
    url = parseUrl path
    route = @router.match(url.pathname)
    queryParams = Qs.parse(url.search?.slice(1))

    route.fn {
      params: route.params
      query: queryParams
    }

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
      '<span></span>' +
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

      oldGo = z.server.go
      z.server.go = (path) ->
        goCalled += 1
        path.should.be '/pathname/here'

      dom = z.server.link z 'a[href=/pathname/here]'
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'
      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      dom.properties.onclick.call($el, e)

      z.server.go = oldGo

      preventDefaultCalled.should.be 1
      goCalled.should.be 1



    it 'doesn\'t default anchor tags with external path', ->
      preventDefaultCalled = 0
      goCalled = 0

      oldGo = z.server.go
      z.server.go = (path) ->
        goCalled += 1

      dom = z.server.link z 'a[href=http://google.com]'
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'

      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      dom.properties.onclick.call($el, e)

      z.server.go = oldGo

      preventDefaultCalled.should.be 0
      goCalled.should.be 0



    it 'writes if other properties exist', ->
      preventDefaultCalled = 0
      goCalled = 0

      oldGo = z.server.go
      z.server.go = (path) ->
        goCalled += 1
        path.should.be '/'

      dom = z.server.link z 'a[href=/][name=test]', {onmousedown: -> null}
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'

      e = {
        target: $el
        preventDefault: ->
          preventDefaultCalled += 1
      }

      dom.properties.onclick.call($el, e)

      z.server.go = oldGo

      preventDefaultCalled.should.be 1
      goCalled.should.be 1



    it 'throws if attempted to override onclick', (done) ->
      try
        z.server.link z 'a[href=/][name=test]',
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

  it 'listens for global settlements', (done) ->
    pendingSettled = 2

    settled = new Rx.BehaviorSubject(null)
    pending1 = new Rx.ReplaySubject(1)
    pending2 = new Rx.ReplaySubject(1)

    z.state {
      settled
      pending1
      pending2
    }

    z.state.onNextAllSettlemenmt ->
      pendingSettled.should.be 0
      done()

    setTimeout ->
      pendingSettled -= 1
      pending1.onNext(null)

      setTimeout ->
        pendingSettled -= 1
        pending2.onNext(null)

  it 'listens for global updates', (done) ->
    updateCnt = 0

    settled = new Rx.BehaviorSubject(null)
    pending1 = new Rx.ReplaySubject(1)
    pending2 = new Rx.ReplaySubject(1)

    z.state {
      settled
      pending1
      pending2
    }

    z.state.onAnyUpdate ->
      updateCnt += 1

    setTimeout ->
      pending1.onNext(null)

      setTimeout ->
        pending2.onNext(null)

        setTimeout ->
          updateCnt.should.be 2
          done()

describe 'server', ->
  it 'renders updated DOM', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    factory = ->
      router = new Router()
      router.add '/testa1', new App()
      router.add '/testa2', new App2()
      return router

    root = document.createElement 'div'

    z.server.setRootNode root
    z.server.setRootFactory factory

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.server.go '/testa1'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.server.go '/testa2'
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

    factory = ->
      router = new Router()
      router.add '/testaRedraw', new App()
      return router

    root = document.createElement 'div'

    z.server.setRootNode root
    z.server.setRootFactory factory

    z.server.go '/testaRedraw'
    drawCnt.should.be 1

    subject.onNext 'abc'

    window.requestAnimationFrame ->
      drawCnt.should.be 2
      done()

  it 'updates location hash', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test', new App()
      router.add '/test2', new App2()
      return router

    z.server.setRootFactory factory
    z.server.setMode 'hash'

    z.server.go '/test'
    window.location.hash.should.be '#/test'
    z.server.go '/test2'
    window.location.hash.should.be '#/test2'

  it 'updated pathname', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test3', new App()
      router.add '/test4', new App2()
      return router
    z.server.setRootFactory factory


    z.server.setMode 'pathname'

    z.server.go '/test3'
    window.location.pathname.should.be '/test3'
    z.server.go '/test4'
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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test-qs', new App()
      router.add '/test-qs2', new App2()
      return router
    z.server.setRootFactory factory


    z.server.setMode 'hash'

    z.server.go '/test-qs?x=abc'
    window.location.hash.should.be '#/test-qs?x=abc'
    z.server.go '/test-qs?x=xxx'
    window.location.hash.should.be '#/test-qs?x=xxx'
    z.server.go '/test-qs2?y=abc'
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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test-qs3', new App()
      router.add '/test-qs4', new App2()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'pathname'

    z.server.go '/test-qs3?x=abc'
    window.location.pathname.should.be '/test-qs3'
    window.location.search.should.be '?x=abc'
    z.server.go '/test-qs3?x=xxx'
    window.location.pathname.should.be '/test-qs3'
    window.location.search.should.be '?x=xxx'
    z.server.go '/test-qs4?y=abc'
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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test-pre-hash', new App()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'hash'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.server.go()
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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test-pre-hash-search', new App()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'hash'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.server.go()
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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test-pre', new App()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'pathname'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.server.go()
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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test-pre-search', new App()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'pathname'
    root.isEqualNode(htmlToNode(result1)).should.be true
    z.server.go()
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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test5', new App()
      router.add '/test6', new App2()
      return router
    z.server.setRootFactory factory

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.server.setMode 'hash'
    z.server.go '/test5'

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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/testa', new App()
      router.add '/testb', new App2()
      return router
    z.server.setRootFactory factory

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.server.setMode 'pathname'

    z.server.go '/testa'
    z.server.go '/testb'
    window.history.back()
    setTimeout ->
      root.isEqualNode(htmlToNode(result1)).should.be true
      z.server.go '/testb'
      z.server.go '/testa'
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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/', new App()
      return router
    z.server.setRootFactory factory

    result1 = '<div></div>'
    result2 = '<div><div>Hello World</div></div>'

    z.server.setMode 'pathname'

    event = new Event 'popstate'
    window.dispatchEvent event

    root.isEqualNode(htmlToNode(result1)).should.be true

    z.server.go '/'
    root.isEqualNode(htmlToNode(result2)).should.be true

  it 'passes params', ->
    class App
      render: ({params}) ->
        z 'div', 'Hello ' + params.key

    root = document.createElement 'div'

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test/:key', new App()
      return router
    z.server.setRootFactory factory

    result = '<div><div>Hello world</div></div>'
    z.server.go('/test/world')

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'emits route events (hash mode)', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test7', new App()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'hash'

    callbackCalled = 0
    listener = (path) ->
      callbackCalled += 1
      path.should.be '/test7'

    z.server.on('route', listener)
    z.server.go '/test7'
    z.server.off('route', listener)

    setTimeout ->
      callbackCalled.should.be 1
      done()

  it 'emits route events (path mode)', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test8', new App()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'pathname'

    callbackCalled = 0
    listener = (path) ->
      callbackCalled += 1
      path.should.be '/test8'

    z.server.on('route', listener)
    z.server.go '/test8'
    z.server.off('route', listener)

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

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test9',
        render: ->
          throw new z.server.Redirect path: '/login1'
      router.add '/login1', new Login()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'pathname'

    z.server.go '/test9'

    setTimeout ->
      window.location.pathname.should.be '/login1'
      done()

  it 'allows 404 errors', ->
    root = document.createElement 'div'

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test404',
        render: ->
          tree = z 'div', '404'
          throw new z.server.Error {tree, status: 404}
      return router
    z.server.setRootFactory factory

    result = '<div><div>404</div></div>'
    z.server.go('/test404')

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'allows 500 errors', ->
    root = document.createElement 'div'

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test500',
        render: ->
          tree = z 'div', '500'
          throw new z.server.Error {tree, status: 500}
      return router
    z.server.setRootFactory factory

    result = '<div><div>500</div></div>'
    z.server.go('/test500')

    root.isEqualNode(htmlToNode(result)).should.be true

  it 'allows async redirect', (done) ->
    class App
      render: ->
        done(new Error 'Should not be called')
        z 'div'

    class Login
      render: -> z 'div'

    root = document.createElement 'div'

    z.server.setRootNode root
    factory = ->
      router = new Router()
      router.add '/test10',
        render: ->
          setTimeout -> z.server.go '/login2'
          z 'div'
      router.add '/login2', new Login()
      return router
    z.server.setRootFactory factory

    z.server.setMode 'pathname'

    z.server.go '/test10'

    setTimeout ->
      window.location.pathname.should.be '/login2'
      done()

  it 'batches redraws', (done) ->
    drawCnt = 0
    class App
      render: ->
        drawCnt += 1
        z 'div', 'Hello World'

    factory = ->
      router = new Router()
      router.add '/testBatchRedraw', new App()
      return router

    root = document.createElement 'div'

    z.server.setRootNode root
    z.server.setRootFactory factory

    z.server.go '/testBatchRedraw'
    z.server.go '/testBatchRedraw'
    z.server.go '/testBatchRedraw'
    z.server.go '/testBatchRedraw'
    z.server.go '/testBatchRedraw'

    drawCnt.should.be 1
    window.requestAnimationFrame ->
      drawCnt.should.be 2

      z.server.go '/testBatchRedraw'
      z.server.go '/testBatchRedraw'
      z.server.go '/testBatchRedraw'
      z.server.go '/testBatchRedraw'
      z.server.go '/testBatchRedraw'

      window.requestAnimationFrame ->
        drawCnt.should.be 3
        done()

  it 'renders full page, setting title and #zorium-root content', ->
    class Root
      render: ->
        z 'html',
          z 'head',
            z 'title', 'test_title'
          z 'body',
            z '#zorium-root',
              z 'div', 'test-content'


    factory = ->
      new Root()

    root = document

    z.server.setRootNode root
    z.server.setRootFactory factory

    rootNode = document.getElementById 'zorium-root'
    rootNode.innerHTML = ''
    document.title.should.not.be 'test_title'

    z.server.go '/renderFullPage'

    result = '<div id="zorium-root"><div>test-content</div></div>'

    document.title.should.be 'test_title'
    rootNode.isEqualNode(htmlToNode(result)).should.be true

  it 'diffs full page', ->
    class Root
      render: ->
        z 'html',
          z 'head',
            z 'title', 'some_title'
          z 'body',
            z '#zorium-root',
              z '.t', 'test-content'


    factory = ->
      new Root()

    root = document

    z.server.setRootNode root
    z.server.setRootFactory factory

    rootNode = document.getElementById 'zorium-root'
    rootNode._zoriumId = null
    rootNode.innerHTML = '<div class="t"></div>'

    z.server.go '/diffFullPage'

    result = '<div id="zorium-root"><div class="t">test-content</div></div>'

    rootNode.isEqualNode(htmlToNode(result)).should.be true


  it 'manages cookies', (done) ->
    z.server.setCookie 'testCookie', 'testValue'
    cookies = cookie.parse document.cookie
    cookies.testCookie.should.be 'testValue'
    z.server.getCookie('testCookie').getValue().should.be 'testValue'

    z.server.setCookie 'something', 'test', {domain: 'test.com'}
    z.server.getCookie('something').getValue().should.be 'test'

    z.server.getCookie('testCookie').subscribe (update) ->
      if update is 'testValue'
        return
      update.should.be 'another!'
      done()

    z.server.setCookie 'testCookie', 'another!'

describe 'z.ev', ->
  it 'wraps the this', ->
    fn = z.ev (e, $$el) ->
      e.ev.should.be 'x'
      $$el.a.should.be 'b'

    fn.call {a: 'b'}, {ev: 'x'}
