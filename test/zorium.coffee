should = require('clay-chai').should()
createElement = require 'virtual-dom/create-element'
Promise = require 'promiz'

z = require 'zorium'

# TODO: batch redraws

htmlToNode = (html) ->
  root = document.createElement 'div'
  root.innerHTML = html
  return root.firstChild

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


  it 'javascript format check', ->
    AppComponent = (params) ->
      state = z.state(z: 'Zorium')
      clicker = (e) ->
        state.set z: 'AllOfTheThings'
        return

      state: state
      render: ->
        return z 'a.zorium-link[href=/]', z('img[src=' + state().z + '.png]',
          onclick: clicker
        )

    comp = new AppComponent()
    dom = z 'div', comp

    $el = createElement(dom)

    result = '<div><a href="/" class="zorium-link">' +
             '<img src="Zorium.png"></a></div>'

    $el.isEqualNode(htmlToNode(result)).should.be true

    z.render document.body, new AppComponent()

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


  describe 'Anchor Tag', ->
    it 'defaults anchor tag onclick event to use router', ->
      dom = z.router.a '[href=/pathname/here]'
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'
      preventDefaultCalled = 0
      goCalled = 0
      e = {
        preventDefault: ->
          preventDefaultCalled += 1
      }

      oldGo = z.router.go
      z.router.go = (path) ->
        goCalled += 1
        path.should.be '/pathname/here'

      dom.properties.onclick.call($el, e)

      z.router.go = oldGo

      preventDefaultCalled.should.be 1
      goCalled.should.be 1



    it 'doesn\'t default anchor tags with external path', ->
      dom = z.router.a '[href=http://google.com]'
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'
      preventDefaultCalled = 0
      goCalled = 0
      e = {
        preventDefault: ->
          preventDefaultCalled += 1
      }

      oldGo = z.router.go
      z.router.go = (path) ->
        goCalled += 1

      dom.properties.onclick.call($el, e)

      z.router.go = oldGo

      preventDefaultCalled.should.be 0
      goCalled.should.be 0



    it 'writes if other properties exist', ->
      dom = z.router.a '[href=/][name=test]', {onmousedown: -> null}
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'
      preventDefaultCalled = 0
      goCalled = 0
      e = {
        preventDefault: ->
          preventDefaultCalled += 1
      }

      oldGo = z.router.go
      z.router.go = (path) ->
        goCalled += 1
        path.should.be '/'

      dom.properties.onclick.call($el, e)

      z.router.go = oldGo

      preventDefaultCalled.should.be 1
      goCalled.should.be 1



    it 'doesn\'t override current onclick', ->
      clickCalled = 0
      dom = z.router.a '[href=/][name=test]', {onclick: -> clickCalled += 1}
      $el = createElement(dom)

      (typeof dom.properties.onclick).should.be 'function'
      preventDefaultCalled = 0
      goCalled = 0
      e = {
        preventDefault: ->
          preventDefaultCalled += 1
      }

      oldGo = z.router.go
      z.router.go = (path) ->
        goCalled += 1
        path.should.be '/'

      dom.properties.onclick.call($el, e)

      z.router.go = oldGo

      preventDefaultCalled.should.be 0
      goCalled.should.be 0
      clickCalled.should.be 1





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
          z 'div',
            z 'span', 'Hello World'
            z 'span', 'Goodbye'

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
      z.redraw()
      unmountCalled.should.be 0

      setTimeout ->
        z.redraw()
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

describe 'redraw()', ->
  it 'redraws all bound root nodes', ->
    drawCnt = 0
    class RedrawComponent
      render: ->
        drawCnt += 1
        z 'div'

    draw = new RedrawComponent()
    root = document.createElement 'div'
    z.render root, draw
    z.redraw()
    drawCnt.should.be 2

  it 'renders properly after multiple redraws', ->
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
    result = '<div><div></div></div>'
    root.isEqualNode(htmlToNode(result)).should.be true
    drawCnt.should.be 3

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
    promise = new Promise (@resolve, reject) => null
    p = z.observe promise

    (p() is null).should.be true

    promise.resolve 1

    p.then ->
      p().should.be 1

  it 'ignores rejected promises', ->
    p = new Promise (_, @reject) => null

    obj = z.observe p

    (obj() is null).should.be true

    p.reject new Error 'abc'

    p.catch ->
      (obj() is null).should.be true

  it 'sets promises correctly', ->
    p = new Promise (@resolve) => null

    obj = z.observe null

    obj.set p

    (obj() is null).should.be true

    p.resolve 'abc'

    obj.then ->
      obj().should.be 'abc'

  it 'sets promises correctly against race conditions', ->
    p1 = new Promise (@resolve) => null
    p2 = new Promise (@resolve) => null

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
  it 'observes state', ->

    promise = new Promise (@resolve, reject) => null

    state = z.state
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

  it 'redraws on state observable change', ->
    cnt = 0
    class App
      constructor: ->
        @state = z.state
          abc: 'def'
      render: ->
        cnt += 1
        z 'div'

    root = document.createElement 'div'
    app = new App()
    z.render root, app
    z.render root, app
    z.render root, app

    app.state.set
      abc: 'fed'

    app.state.set
      abc: 'den'

    cnt.should.be 5

  it 'redraws on promise resolution', ->
    promise = new Promise (@resolve) => null
    cnt = 0
    class App
      constructor: ->
        @state = z.state
          p: z.observe promise
      render: ->
        cnt += 1
        z 'div'

    root = document.createElement 'div'
    app = new App()
    z.render root, app

    promise.resolve 'abc'

    promise.then ->
      cnt.should.be 2


describe 'router', ->
  describe 'route()', ->
    it 'renders updated DOM', ->
      class App
        render: ->
          z 'div', 'Hello World'

      class App2
        render: ->
          z 'div', 'World Hello'

      root = document.createElement 'div'

      z.router.setRoot root
      z.router.add '/test', App
      z.router.add '/test2', App2

      result1 = '<div><div>Hello World</div></div>'
      result2 = '<div><div>World Hello</div></div>'

      z.router.go '/test'
      root.isEqualNode(htmlToNode(result1)).should.be true
      z.router.go '/test2'
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
    z.router.add '/test', App
    z.router.add '/test2', App2

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
    z.router.add '/test', App
    z.router.add '/test2', App2

    z.router.setMode 'pathname'

    z.router.go '/test'
    window.location.pathname.should.be '/test'
    z.router.go '/test2'
    window.location.pathname.should.be '/test2'

  it 'default routes hash', ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test', App

    z.router.setMode 'hash'

    window.location.hash = '/test'
    z.router.go()
    window.location.hash.should.be '#/test'

  it 'default routes pathname', ->
    class App
      render: ->
        z 'div', 'Hello World'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test', App

    z.router.setMode 'pathname'

    window.history.pushState null, null, '/test'
    z.router.go()
    window.location.pathname.should.be '/test'

  it 'responds to hashchange', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test', App
    z.router.add '/test2', App2

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.router.setMode 'hash'

    window.location.hash = '/test'
    z.router.go()
    root.isEqualNode(htmlToNode(result1)).should.be true

    window.location.hash = '/test2'
    z.router.go()
    root.isEqualNode(htmlToNode(result2)).should.be true

    window.location.hash = '/test'
    window.location.hash.should.be '#/test'
    root.isEqualNode(htmlToNode(result1)).should.be true

  it 'responds to popstate', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'World Hello'

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test', App
    z.router.add '/test2', App2

    result1 = '<div><div>Hello World</div></div>'
    result2 = '<div><div>World Hello</div></div>'

    z.router.setMode 'pathname'

    window.history.pushState null, null, '/test'
    z.router.go()
    root.isEqualNode(htmlToNode(result1)).should.be true

    window.history.pushState null, null, '/test2'
    z.router.go()
    root.isEqualNode(htmlToNode(result2)).should.be true

    window.history.back()
    setTimeout ->
      window.location.pathname.should.be '/test'
      root.isEqualNode(htmlToNode(result1)).should.be true
      done()
    , 30

  it 'passes params', ->
    class App
      constructor: (params) ->
        @key = params?.key or 'FALSE'

      render: =>
        z 'div', 'Hello ' + @key

    root = document.createElement 'div'

    z.router.setRoot root
    z.router.add '/test/:key', App

    result = '<div><div>Hello world</div></div>'
    z.router.go('/test/world')

    root.isEqualNode(htmlToNode(result)).should.be true
