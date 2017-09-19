b = require 'b-assert'

z = require '../src/zorium'
util = require './util'

describe 'z()', ->
  it 'creates basic DOM trees', ->
    dom = z 'div',
      z '.cname#cid', 'abc'
      z 'a.b',
        href: '#'
        'data-non': 123
        eatme: 'true'
        z 'img'

    result = '<div><div>' +
      '<div id="cid" class="cname">abc</div>' +
      '<a href="#" data-non="123" eatme="true" class="b">' +
        '<img>' +
      '</a>' +
    '</div></div>'

    $el = document.createElement('div')
    z.render dom, $el
    util.assertDOM $el, util.htmlToNode result

  it 'sets style', ->
    dom = z 'img',
      style:
        backgroundColor: 'red'
        lineHeight: '1rem'

    $el = document.createElement('div')
    z.render dom, $el
    b $el.children[0].style.lineHeight, '1rem'
    b $el.children[0].style.backgroundColor, 'red'

  it 'renders numbers', ->
    dom = z 'div', 123

    result = '<div>123</div>'

    $el = document.createElement('div')
    z.render dom, $el
    b $el.innerHTML, result

  it 'supports default div tag prefixing', ->
    dom = z 'div',
      z '.container'
      z '#layout'

    result = '<div>' +
      '<div class="container"></div>' +
      '<div id="layout"></div>' +
    '</div>'

    $el = document.createElement('div')
    z.render dom, $el
    b $el.innerHTML, result

  it 'supports nested zorium components', ->
    class HelloWorldComponent
      render: ->
        z 'span', 'Hello World'
    hello = new HelloWorldComponent()
    dom = z 'div', hello

    result = '<div><span>Hello World</span></div>'

    $el = document.createElement('div')
    z.render dom, $el
    b $el.innerHTML, result

  it 'supports arrs', ->
    dom = z 'div', [
      z 'div', 'a'
      z 'div', 'b'
    ]

    result = '<div><div><div>a</div><div>b</div></div></div>'

    $el = document.createElement('div')
    z.render dom, $el
    b $el.isEqualNode(util.htmlToNode(result)), true

  it 'allows component render to return undefined', ->
    class HelloWorldComponent
      render: ->
        return

    hello = new HelloWorldComponent()

    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'
      hello

    root = document.createElement 'div'

    result = '<div><div>' +
      '<div>a</div>' +
      '<div>b</div>' +
      # BREAKING
      # '<noscript></noscript>' +
    '</div></div>'

    z.render dom, root

    util.assertDOM(root, util.htmlToNode(result))

  it 'allows undefined children on redraw', ->
    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'

    root = document.createElement 'div'

    result = '<div><div>' +
      '<div>a</div>' +
      '<div>b</div>' +
    '</div></div>'

    z.render dom, root

    dom = z 'div',
      z 'div', 'a'
      z 'div', 'b'
      undefined

    z.render dom, root
    util.assertDOM root, util.htmlToNode result

  it 'handles null children', ->
    dom = z 'div',
      null
      z 'span', 'Hello World'
      null
      z 'div', [
        null
        z 'div', 'World Hello'
      ]

    $el = document.createElement 'div'
    z.render dom, $el

    result = '<div><div>' +
      '<span>Hello World</span>' +
      '<div>' +
        '<div>World Hello</div>' +
      '</div>' +
    '</div></div>'

    util.assertDOM $el, util.htmlToNode result

  # https://github.com/claydotio/zorium.js/issues/1
  it 'doesn\'t add extra class names', ->
    dom = z 'a', href: 'http://192.168.1.0', 'test'
    $el = document.createElement 'div'
    z.render dom, $el
    result = '<div><a href="http://192.168.1.0">test</a></div>'

    b $el.isEqualNode(util.htmlToNode(result)), true


  # https://github.com/claydotio/zorium.js/issues/3
  it 'correctly patches component-based trees without DOM removal', ->
    class Uniq
      render: ->
        z '#uniq'

    dom = new Uniq()

    root = document.createElement 'div'
    z.render dom, root
    first = root.querySelector '#uniq'
    b (first is root.querySelector '#uniq'), true
    z.render dom, root
    b (first is root.querySelector '#uniq'), true
    z.render dom, root

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

    z.render $b, root

    result = '<div><div><div>hello world</div></div></div>'
    b root.isEqualNode(util.htmlToNode(result)), true

describe 'z.classKebab', ->
  it 'kebabs objects', ->
    kebab = z.classKebab
      a: true
      b: true
      c: true
      d: 0
      e: false
      f: null
      g: undefined

    b kebab, 'a b c'

describe 'z.isSimpleClick', ->
  it 'checks for non-left clicks', ->
    b z.isSimpleClick({which: 2}), false
    b z.isSimpleClick({which: 1}), true
    b z.isSimpleClick({which: 1, shiftKey: true}), false
