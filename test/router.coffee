b = require 'b-assert'
Routes = require 'routes'
createElement = require 'virtual-dom/create-element'

z = require '../src/zorium'
util = require './util'

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

delay = (fn) ->
  setTimeout ->
    fn()
  , 20

describe 'router', ->
  it 'renders updated DOM', (done) ->
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
    delay ->
      b root.isEqualNode(util.htmlToNode(result1))
      z.router.go '/testa2'

      delay ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

  it 'redraws on state observable change', (done) ->
    subject = new Rx.BehaviorSubject('abc')

    class App
      constructor: ->
        @state = z.state
          subject: subject
      render: =>
        z 'div', "#{@state.getValue().subject}"

    router = new Router()
    router.add '/testaRedraw', new App()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    result1 = '<div><div>abc</div></div>'
    result2 = '<div><div>xyz</div></div>'

    z.router.go '/testaRedraw'
    delay ->
      b root.isEqualNode(util.htmlToNode(result1))
      subject.onNext 'xyz'

      delay ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

  it 'redraws on child state observable change, pre-rendered', (done) ->
    subject = new Rx.BehaviorSubject('abc')

    class Child
      constructor: ->
        @state = z.state
          subject: subject
      render: =>
        z 'div', "#{@state.getValue().subject}"

    class App
      constructor: ->
        @child = z new Child(), {}
      render: =>
        z 'div', @child

    router = new Router()
    router.add '/testaChildRedraw', new App()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    result1 = '<div><div><div>abc</div></div></div>'
    result2 = '<div><div><div>xyz</div></div></div>'

    z.router.go '/testaChildRedraw'
    delay ->
      b root.isEqualNode(util.htmlToNode(result1))

      subject.onNext 'xyz'
      delay ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

  it 'redraws on lazy state observable change', (done) ->
    lazyRuns = 0
    lazyPromise = util.deferred()

    cold = Rx.Observable.defer ->
      lazyRuns += 1
      Rx.Observable.fromPromise lazyPromise

    class App
      constructor: ->
        @state = z.state
          observable: cold

      render: =>
        z 'div', "Hello #{@state.getValue().observable}"

    router = new Router()
    router.add '/testLazyRedraw', new App()

    root = document.createElement 'div'

    b lazyRuns, 0

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    result1 = '<div><div>Hello null</div></div>'
    result2 = '<div><div>Hello xxx</div></div>'

    z.router.go '/testLazyRedraw'
    delay ->
      b lazyRuns, 1
      b root.isEqualNode(util.htmlToNode(result1))

      lazyPromise.then ->
        delay ->
          b lazyRuns, 1
          b root.isEqualNode(util.htmlToNode(result2))
          done()

      lazyPromise.resolve 'xxx'

  it 'unbinds state beforeUnmount', (done) ->
    appDrawCnt = 0
    app2DrawCnt = 0
    lazyPromise = util.deferred()

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
    delay ->
      b appDrawCnt, 2
      b app2DrawCnt, 0

      window.requestAnimationFrame ->
        z.router.go '/testUnbindLazy2'

        window.requestAnimationFrame ->

          b appDrawCnt, 2
          b app2DrawCnt, 2

          window.requestAnimationFrame ->
            b appDrawCnt, 2
            b app2DrawCnt, 2

            # should not cause re-draw
            lazyPromise.resolve 'x'

            lazyPromise.then ->
              window.requestAnimationFrame ->
                b appDrawCnt, 2
                b app2DrawCnt, 2
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
    b window.location.hash, '#/test'
    z.router.go '/test2'
    b window.location.hash, '#/test2'

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
    b window.location.pathname, '/test3'
    z.router.go '/test4'
    b window.location.pathname, '/test4'

  it 'updates query param in hash mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ({params, query}) ->
        b query.y, 'abc'
        z 'div', 'World Hello'

    root = document.createElement 'div'

    router = new Router()
    router.add '/test-qs', new App()
    router.add '/test-qs2', new App2()

    z.router.init {$$root: root, mode: 'hash'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    z.router.go '/test-qs?x=abc'
    b window.location.hash, '#/test-qs?x=abc'
    z.router.go '/test-qs?x=xxx'
    b window.location.hash, '#/test-qs?x=xxx'
    z.router.go '/test-qs2?y=abc'
    b window.location.hash, '#/test-qs2?y=abc'

  it 'updates query string in path mode', ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ({params, query}) ->
        b query.y, 'abc'
        z 'div', 'World Hello'

    root = document.createElement 'div'

    router = new Router()
    router.add '/test-qs3', new App()
    router.add '/test-qs4', new App2()


    z.router.init {$$root: root, mode: 'pathname'}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}
    z.router.go '/test-qs3?x=abc'
    b window.location.pathname, '/test-qs3'
    b window.location.search, '?x=abc'
    z.router.go '/test-qs3?x=xxx'
    b window.location.pathname, '/test-qs3'
    b window.location.search, '?x=xxx'
    z.router.go '/test-qs4?y=abc'
    b window.location.pathname, '/test-qs4'
    b window.location.search, '?y=abc'

  it 'routes to default current path in hash mode', (done) ->
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
    b root.isEqualNode(util.htmlToNode(result1))
    z.router.go()
    delay ->
      b root.isEqualNode(util.htmlToNode(result2))
      b window.location.hash, '#/test-pre-hash'
      done()

  it 'routes to default current path in hash mode with query string', (done) ->
    class App
      render: ({params, query}) ->
        b query.x, 'abc'
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
    b root.isEqualNode(util.htmlToNode(result1))
    z.router.go()

    delay ->
      b root.isEqualNode(util.htmlToNode(result2))
      b window.location.hash, '#/test-pre-hash-search?x=abc'
      done()

  it 'routes to default current path in pathname mode', (done) ->
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
    b root.isEqualNode(util.htmlToNode(result1))
    z.router.go()

    delay ->
      b root.isEqualNode(util.htmlToNode(result2))
      b window.location.pathname, '/test-pre'
      done()

  it 'routes to default current path in path mode with query string', (done) ->
    class App
      render: ({params, query}) ->
        b query.x, 'abc'
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
    b root.isEqualNode(util.htmlToNode(result1))
    z.router.go()
    delay ->
      b root.isEqualNode(util.htmlToNode(result2))
      b window.location.pathname, '/test-pre-search'
      b window.location.search, '?x=abc'
      done()

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

    delay ->
      b root.isEqualNode(util.htmlToNode(result1))
      window.location.hash = '/test6'

      setTimeout ->
        b root.isEqualNode(util.htmlToNode(result2))
        window.location.hash = '/test5'
        b window.location.hash, '#/test5'

        setTimeout ->
          b root.isEqualNode(util.htmlToNode(result1))
          done()
        , 90
      , 90

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
    delay ->
      window.history.back()

      delay ->
        b root.isEqualNode(util.htmlToNode(result1))
        z.router.go '/testb'
        z.router.go '/testa'

        delay ->
          window.history.back()

          delay ->
            b root.isEqualNode(util.htmlToNode(result2))
            b window.location.pathname, '/testb'
            done()

  it 'doesn\'t respond to popstate before initial route', (done) ->
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

    b root.isEqualNode(util.htmlToNode(result1))

    z.router.go '/'

    delay ->
      b root.isEqualNode(util.htmlToNode(result2))
      done()

  it 'passes params', (done) ->
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
    delay ->
      b root.isEqualNode(util.htmlToNode(result))
      done()

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

    delay ->
      b window.location.pathname, '/login2'
      done()

  # TODO: make sure batching to DOM (not necessarily render) happens
  # on animationFrame not just nextTick
  it 'batches redraws', (done) ->
    changeSubject = new Rx.BehaviorSubject 0
    class App
      constructor: ->
        @state = z.state
          change: changeSubject
      render: =>
        z 'div', "#{@state.getValue().change}"

    router = new Router()
    router.add '/testBatchRedraw', new App()

    root = document.createElement 'div'

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send z router, {path: req.path, query: req.query}

    z.router.go '/testBatchRedraw'

    result1 = '<div></div>'
    result2 = '<div><div>0</div></div>'
    result3 = '<div><div>6</div></div>'
    result4 = '<div><div>12</div></div>'
    result5 = '<div><div>18</div></div>'

    b root.isEqualNode(util.htmlToNode(result1))

    delay ->
      b root.isEqualNode(util.htmlToNode(result2))

      changeSubject.onNext 1
      b root.isEqualNode(util.htmlToNode(result2))
      changeSubject.onNext 2
      b root.isEqualNode(util.htmlToNode(result2))
      changeSubject.onNext 3
      changeSubject.onNext 4
      changeSubject.onNext 5
      changeSubject.onNext 6

      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result3))

        changeSubject.onNext 7
        changeSubject.onNext 8
        changeSubject.onNext 9
        b root.isEqualNode(util.htmlToNode(result3))
        changeSubject.onNext 10
        changeSubject.onNext 11
        changeSubject.onNext 12

        window.requestAnimationFrame ->
          b root.isEqualNode(util.htmlToNode(result4))

          changeSubject.onNext 13
          changeSubject.onNext 14
          changeSubject.onNext 15
          b root.isEqualNode(util.htmlToNode(result4))
          changeSubject.onNext 16
          changeSubject.onNext 17
          changeSubject.onNext 18

          window.requestAnimationFrame ->
            b root.isEqualNode(util.htmlToNode(result5))
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
      render: =>
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
    delay ->
      b root.isEqualNode(util.htmlToNode(result1))

      # change in props leads to both updating
      prefix = '2-'
      subject.onNext 'xyz'
      setTimeout ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

        # change in state currently does not lead to both updating
        # TODO: see if this can reasonably be fixed
        # subject.onNext 'xxx'
        # setTimeout ->
        #   b root.isEqualNode(util.htmlToNode(result3))
        #   done()
        # , 20
      , 20


  it 'renders full page, setting title and #zorium-root content', (done) ->
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
      root._zorium_tree = null
    else
      root = document.createElement 'div'
      root.id = 'zorium-root'
      document.body.appendChild root

    z.router.init {$$root: root}
    z.router.use (req, res) ->
      res.send new Root()

    b document.title isnt 'test_title'

    z.router.go '/renderFullPage'

    result = '<div id="zorium-root"><div>test-content</div></div>'

    delay ->
      b document.title, 'test_title'
      b root.isEqualNode(util.htmlToNode(result))
      done()

  it 'diffs full page', (done) ->
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
      root._zorium_tree = null
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

    delay ->
      b root.isEqualNode(util.htmlToNode(result))
      done()

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
      root._zorium_tree = null
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

    delay ->
      b root.isEqualNode(util.htmlToNode(result1))

      $root.state.set
        changeme: 'xxx'

      delay ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

  it 'binds updates when adding a new child', (done) ->
    subject = new Rx.BehaviorSubject 'abc'

    class Child
      constructor: ->
        @state = z.state
          subject: subject

      render: =>
        z 'div', "#{@state.getValue().subject}"

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

    result1 = '<div></div>'
    result2 = '<div><div><div>abc</div></div></div>'
    result3 = '<div><div><div>xyz</div></div></div>'

    z.router.go '/test-new-child'
    delay ->
      b root.isEqualNode(util.htmlToNode(result1))

      $a.addChild $child
      delay ->
        b root.isEqualNode(util.htmlToNode(result2))

        subject.onNext 'xyz'
        delay ->
          b root.isEqualNode(util.htmlToNode(result3))
          done()

  describe 'Anchor Tag', ->
    it 'defaults anchor tag onclick event to use router', (done) ->
      preventDefaultCalled = 0
      goCalled = 0

      dom = z.router.link z 'a', href: '/anchor1'
      $el = createElement(dom)

      b (typeof dom.properties.onclick), 'function'
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
        b req.path, '/anchor1'
        b preventDefaultCalled, 1
        res.send z router, {path: req.path, query: req.query}
        done()

      dom.properties.onclick.call($el, e)


    it 'doesn\'t default anchor tags with external path', (done) ->
      preventDefaultCalled = 0
      goCalled = 0

      dom = z.router.link z 'a', href: 'http://google.com'
      $el = createElement(dom)

      b (typeof dom.properties.onclick), 'function'

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
        b preventDefaultCalled, 0
        b goCalled, 0
        done()

    it 'writes if other properties exist', (done) ->
      preventDefaultCalled = 0
      goCalled = 0

      dom = z.router.link z 'a',
        href: '/anchor2'
        name: 'test'
        onmousedown: -> null
      $el = createElement(dom)

      b (typeof dom.properties.onclick), 'function'

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
        b req.path, '/anchor2'
        b preventDefaultCalled, 1
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
