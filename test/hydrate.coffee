z = require '../src'
util = require './util'

describe 'z.hydrate()', ->
  it 'hydrates', ->
    class Root
      render: ->
        [
          z 'head', z 'title', 'abc'
          z 'body'
        ]

    result = document.createElement 'html'
    result.innerHTML = '<head><title>abc</title><body></body></head>'

    $el = document.createElement('html')
    $el.innerHTML = '<head><title>xxx</title><body></body></head>'

    z.hydrate z(new Root()), $el
    util.assertDOM $el, result

  it 'hydrates with components', ->
    class Picker
      render: ->
        z 'div', 'picker'

    class X
      constructor: ->
        @p1 = new Picker()
        @p2 = new Picker()

      render: =>
        z 'div',
          [
            z @p1
            z @p2
          ]

    result = '<div><div>' +
      '<div>picker</div>' +
      '<div>picker</div>' +
    '</div></div>'

    $el = document.createElement('div')
    z.hydrate z(new X()), $el
    util.assertDOM $el, util.htmlToNode(result)

  it 'hydrates with components (class)', ->
    class Picker
      render: ->
        z 'div', 'picker'

    class X
      render: ->
        z 'div',
          [
            z Picker
            z Picker
          ]

    result = '<div><div>' +
      '<div>picker</div>' +
      '<div>picker</div>' +
    '</div></div>'

    $el = document.createElement('div')
    z.hydrate X, $el
    util.assertDOM $el, util.htmlToNode(result)

  it 'hydrates undefined', ->
    class Root
      render: ->
        z 'div',
          undefined
          z 'span'

    result = '<div><div><span></span></span></div>'
    $el = document.createElement 'div'
    $el.innerHTML = '<div><div>xxx</div></div>'
    z.hydrate new Root(), $el
    util.assertDOM $el, util.htmlToNode(result)

  it 'hydrates deep', ->
    class Child
      render: ->
        z 'div'

    class Root
      constructor: ->
        @$child = new Child()
      render: =>
        z 'div',
          undefined
          @$child
          undefined

    result = '<div><div><div></div></div></div>'
    $el = document.createElement 'div'
    $el.innerHTML = '<div><div style="color:red;">xxx</div></div>'
    z.hydrate new Root(), $el
    util.assertDOM $el, util.htmlToNode(result)

  it 'hydrates text replacing node', ->
    class Root
      render: ->
        z 'div',
          'abc'

    result = '<div><div>abc</div></div>'
    $el = document.createElement 'div'
    $el.innerHTML = '<div>abc<a>XXX</a></div>'
    z.hydrate new Root(), $el
    util.assertDOM $el, util.htmlToNode(result)

  it 'hydrates two consecutive text nodes', ->
    class Root
      render: ->
        z 'div',
          'abcabcabc'
          'xxx'

    result = '<div><div>abcabcabcxxx</div></div>'
    $el = document.createElement 'div'
    $el.innerHTML = '<div>buy now</div>'
    z.hydrate new Root(), $el
    util.assertDOM $el, util.htmlToNode(result)
