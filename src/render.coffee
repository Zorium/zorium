# parseFromString polyfill for Android 4.1 and 4.3
# required for vdom-parser
# source: https://gist.github.com/eligrey/1129031
if window?
  do (DOMParser = window.DOMParser) ->
    DOMParser_proto = DOMParser.prototype
    real_parseFromString = DOMParser_proto.parseFromString
    # Firefox/Opera/IE throw errors on unsupported types
    try
      # WebKit returns null on unsupported types
      if (new DOMParser()).parseFromString('', 'text/html')
        # text/html parsing is natively supported
        return
    catch ex

    # coffeelint: disable=missing_fat_arrows
    DOMParser_proto.parseFromString = (markup, type) ->
      if /^\s*text\/html\s*(?:;|$)/i.test(type)
        doc = document.implementation.createHTMLDocument('')
        if markup.toLowerCase().indexOf('<!doctype') > -1
          doc.documentElement.innerHTML = markup
        else
          doc.body.innerHTML = markup
        doc
      else
        real_parseFromString.apply this, arguments
    # coffeelint: enable=missing_fat_arrows
    return

diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
isThunk = require 'virtual-dom/vnode/is-thunk'

if window?
  parser = require 'vdom-parser'

z = require './z'
isComponent = require './is_component'

flatten = (node) ->
  if isThunk node
    node.render()
  else
    node

parseFullTree = (tree) ->
  unless tree?.tagName is 'HTML' and tree.children.length is 2
    throw new Error 'Invalid HTML base element'

  $head = flatten tree.children[0]
  $body = flatten tree.children[1]
  $title = flatten $head.children[0]
  $root = flatten $body.children[0]

  unless $head?.tagName is 'HEAD' and $title?.tagName is 'TITLE'
    throw new Error 'Invalid HEAD base element'

  unless $body?.tagName is 'BODY' and $root?.properties.id is 'zorium-root'
    throw new Error 'Invalid BODY base element'

  return {
    $root: $root
    title: $title?.children[0]?.text
  }

module.exports = ($$root, tree) ->
  if isComponent tree
    tree = z tree

  if isThunk tree
    rendered = tree.render()
    if rendered.tagName is 'HTML'
      {title, $root} = parseFullTree(rendered)
      document.title = title
      tree = $root

  unless $$root._zorium_tree?
    seedTree = parser $$root
    $$root._zorium_tree = seedTree

  previousTree = $$root._zorium_tree

  patches = diff previousTree, tree
  patch $$root, patches
  $$root._zorium_tree = tree

  return $$root
