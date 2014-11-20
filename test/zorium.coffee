should = require('clay-chai').should()

z = require 'zorium'

createElement = require 'virtual-dom/create-element'

# TODO: check for double child array children: [[..]]
# TODO: onUnload -> onBeforeUnload
describe 'Virtual DOM', ->
  it 'creates basic DOM trees', ->
    dom = z 'div',
      z '.cname#cid', 'abc'
      z 'a.b[href=#][data-non=123][eatme]',
        z 'img',
          style:
            backgroundColor: 'red'
            lineHeight: '1rem'

    $el = createElement(dom)

    result = '<div>' +
      '<div id="cid" class="cname">abc</div>' +
      '<a href="#" data-non="123" eatme="true" class="b">' +
        '<img style="background-color: red; line-height: 1rem; ">' +
      '</a>' +
    '</div>'

    new XMLSerializer().serializeToString($el).should.be result

  it 'supports nested zorium components', ->
    class HelloWorldComponent
      render: ->
        z 'span', 'Hello World'
    hello = new HelloWorldComponent()
    dom = z 'div', hello

    $el = createElement(dom)

    result = '<div><span>Hello World</span></div>'

    new XMLSerializer().serializeToString($el).should.be result

  it 'supports arrs', ->
    dom = z 'div', [
      z 'div', 'a'
      z 'div', 'b'
    ]

    $el = createElement(dom)

    result = '<div><div>a</div><div>b</div></div>'

    new XMLSerializer().serializeToString($el).should.be result

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

    new XMLSerializer().serializeToString($el).should.be result

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

    new XMLSerializer().serializeToString($el).should.be result

  # https://github.com/claydotio/zorium.js/issues/1
  it 'doesn\'t add extra class names', ->
    dom = z 'a[href=http://192.168.1.0]', 'test'
    $el = createElement(dom)
    result = '<a href="http://192.168.1.0">test</a>'

    new XMLSerializer().serializeToString($el).should.be result


  # https://github.com/claydotio/zorium.js/issues/3
  it 'correctly patches component-based trees without DOM removal', ->
    class Uniq
      render: ->
        z '#uniq'

    dom = new Uniq()

    root = document.createElement 'div'
    z.render root, dom
    first = root.querySelector '#uniq'
    (first == root.querySelector '#uniq').should.be true
    z.render root, dom
    (first == root.querySelector '#uniq').should.be true
    z.render root, dom, z 'd'


  describe 'Anchor Tag', ->
    it 'defaults anchor tag onclick event to use router', ->
      dom = z 'a[href=/pathname/here]'
      $el = createElement(dom)

      dom.properties.onclick.should.be.a.Function
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
      dom = z 'a[href=http://google.com]'
      $el = createElement(dom)

      dom.properties.onclick.should.be.a.Function
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
      dom = z 'a[href=/][name=test]', {onmousedown: -> null}
      $el = createElement(dom)

      dom.properties.onclick.should.be.a.Function
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
      dom = z 'a[href=/][name=test]', {onclick: -> clickCalled += 1}
      $el = createElement(dom)

      dom.properties.onclick.should.be.a.Function
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
    new XMLSerializer().serializeToString(root).should.be result

  it 'renders components', ->
    class HelloWorldComponent
      render: ->
        z 'span', 'Hello World'
    hello = new HelloWorldComponent()

    root = document.createElement('div')
    $el = z.render root, hello
    result = '<div><span>Hello World</span></div>'

    new XMLSerializer().serializeToString(root).should.be result

  it 'patches dom node on multiple renders', ->
    root = document.createElement('div')
    z.render root, (z 'span', 'Hello World')
    result1 = '<div><span>Hello World</span></div>'
    new XMLSerializer().serializeToString(root).should.be result1

    z.render root, (z 'span', 'Sayonara')
    result2 = '<div><span>Sayonara</span></div>'
    new XMLSerializer().serializeToString(root).should.be result2

    z.render root, (z 'span', (z 'div', 'done'))
    result3 = '<div><span><div>done</div></span></div>'
    new XMLSerializer().serializeToString(root).should.be result3

describe 'Hooks', ->
  it 'onMount', (done) ->
    class BindComponent
      onMount: ($el) ->
        should.exist $el
        done()
      render: ->
        z 'div'

    bind = new BindComponent()
    root = document.createElement 'div'
    z.render root, bind

  it 'onBeforeUnmount', (done) ->
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
    new XMLSerializer().serializeToString(root).should.be result
    drawCnt.should.be 3

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
      new XMLSerializer().serializeToString(root).should.be result1
      z.router.go '/test2'
      new XMLSerializer().serializeToString(root).should.be result2

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
    new XMLSerializer().serializeToString(root).should.be result1

    window.location.hash = '/test2'
    z.router.go()
    new XMLSerializer().serializeToString(root).should.be result2

    window.location.hash = '/test'
    window.location.hash.should.be '#/test'
    new XMLSerializer().serializeToString(root).should.be result1

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
    new XMLSerializer().serializeToString(root).should.be result1

    window.history.pushState null, null, '/test2'
    z.router.go()
    new XMLSerializer().serializeToString(root).should.be result2

    window.history.back()
    setTimeout ->
      window.location.pathname.should.be '/test'
      new XMLSerializer().serializeToString(root).should.be result1
      done()

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

    new XMLSerializer().serializeToString(root).should.be result




# TODO: batch redraws
# Observable state?
# Streams?
