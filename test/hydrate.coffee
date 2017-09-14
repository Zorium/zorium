b = require 'b-assert'

z = require '../src/zorium'
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
