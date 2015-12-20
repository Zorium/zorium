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

  $head = tree.children[0]
  body = flatten tree.children[1]
  root = flatten body.children[0]

  unless body?.tagName is 'BODY' and root?.properties.id is 'zorium-root'
    throw new Error 'Invalid BODY base element'

  return {
    $root: root
    $head: $head
  }

renderHead = ($head) ->
  head = flatten $head

  unless head?.tagName is 'HEAD'
    throw new Error 'Invalid HEAD base element, not type <head>'

  title = head.children?[0]?.children?[0]?.text

  unless title?
    throw new Error 'Invalid HEAD base element, missing title'

  document.title = title

  mutable = _.filter head.children, (node) ->
    node.tagName is 'META' or node.tagName is 'LINK'

  current = _.filter document.head.children, (node) ->
    node.tagName is 'META' or node.tagName is 'LINK'

  if _.isEmpty mutable
    return null

  unless mutable.length is current.length
    throw new Error 'Cannot mutate <head> element count dynamically'

  _.map _.zip(current, mutable), ([current, mutable]) ->
    if current.tagName isnt mutable.tagName
      throw new Error 'Type mismatch when updating <head>'

    _.map mutable.properties, (val, key) ->
      if current[key] isnt val
        current[key] = val

module.exports = render = ($$root, tree) ->
  if isComponent tree
    tree = z tree

  if isThunk tree
    rendered = tree.render()
    if rendered.tagName is 'HTML'
      {$root, $head} = parseFullTree(rendered)

      onchange = _.debounce ->
        renderHead $head

      document.head.__disposable?.dispose()
      hasState = $head.component?.state?

      if hasState
        document.head.__disposable = $head.component.state.subscribe onchange
      else
        renderHead $head

      tree = $root

  unless $$root._zorium_tree?
    seedTree = parser $$root
    $$root._zorium_tree = seedTree

  previousTree = $$root._zorium_tree

  patches = diff previousTree, tree
  patch $$root, patches
  $$root._zorium_tree = tree

  return $$root
