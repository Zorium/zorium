b = require 'b-assert'

z = require '../src/zorium'
util = require './util'

describe 'render()', ->
  it 'renders to dom node', ->
    root = document.createElement('div')
    z.render root, (z 'div', 'Hello World')
    result = '<div>Hello World</div>'
    b root.isEqualNode(util.htmlToNode(result)), true

  it 'renders components', ->
    class HelloWorldComponent
      render: ->
        z 'div', 'Hello World'
    hello = new HelloWorldComponent()

    root = document.createElement('div')
    $el = z.render root, hello
    result = '<div>Hello World</div>'

    b root.isEqualNode(util.htmlToNode(result)), true

  it 'patches dom node on multiple renders', ->
    root = document.createElement('div')
    z.render root, (z 'div', 'Hello World')
    result1 = '<div>Hello World</div>'
    b root.isEqualNode(util.htmlToNode(result1)), true

    z.render root, (z 'div', 'Sayonara')
    result2 = '<div>Sayonara</div>'
    b root.isEqualNode(util.htmlToNode(result2)), true

    z.render root, (z 'div', (z 'div', 'done'))
    result3 = '<div><div>done</div></div>'
    b root.isEqualNode(util.htmlToNode(result3)), true

  # https://github.com/Zorium/zorium/issues/68
  it 'patches <iframe> node correctly', ->
    root = document.createElement('iframe')
    z.render root, (z 'iframe')
    result = '<iframe></iframe>'
    b root.isEqualNode(util.htmlToNode(result)), true
