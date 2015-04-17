diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
createElement = require 'virtual-dom/create-element'
virtualize = require 'vdom-virtualize'

z = require './z'

# requestAnimationFrame polyfill
# https://gist.github.com/paulirish/1579671
# MIT license
if window?
  do ->
    lastTime = 0
    vendors = [
      'ms'
      'moz'
      'webkit'
      'o'
    ]
    x = 0
    while x < vendors.length and not window.requestAnimationFrame
      window.requestAnimationFrame =
        window[vendors[x] + 'RequestAnimationFrame']
      window.cancelAnimationFrame =
        window[vendors[x] + 'CancelAnimationFrame'] or
        window[vendors[x] + 'CancelRequestAnimationFrame']
      x += 1
    if not window.requestAnimationFrame

      window.requestAnimationFrame = (callback, element) ->
        currTime = (new Date()).getTime()
        timeToCall = Math.max(0, 16 - (currTime - lastTime))
        id = window.setTimeout((->
          callback currTime + timeToCall
          return
        ), timeToCall)
        lastTime = currTime + timeToCall
        id

    if not window.cancelAnimationFrame

      window.cancelAnimationFrame = (id) ->
        clearTimeout id
        return

    return
  # end polyfill

parseFullTree = (tree) ->
  unless tree?.tagName is 'HTML'
    throw new Error 'Invalid HTML base element'

  $head = tree.children[0]
  $body = tree.children[1]
  $title = $head?.children[0]
  appTree = $body?.children[0]

  unless $head?.tagName is 'HEAD' and $title?.tagName is 'TITLE'
    throw new Error 'Invalid HEAD base element'

  unless $body?.tagName is 'BODY' and appTree.properties.id is 'zorium-root'
    throw new Error 'Invalid BODY base element'

  unless appTree.children.length is 1
    throw new Error 'zorium-root must only contain 1 direct child'

  return {
    appTree: appTree.children[0]
    title: $title?.children[0]?.text
  }

removeContentEditable = (vnode) ->
  delete vnode.properties?.contentEditable
  _.map vnode.children, removeContentEditable
  return vnode

class Renderer
  constructor: ->
    @registeredRoots = {}

    id = 0
    @nextRootId = ->
      id += 1

  render: ($root, tree) =>
    tree = z tree

    # Because the DOM doesn't let us directly manipulate top-level elements
    # We have to standardize a hack around it
    if tree?.tagName is 'HTML'
      {title, appTree} = parseFullTree tree

      unless $root._zoriumId
        seedTree = removeContentEditable virtualize $root.children[0]
        @render $root, seedTree

      document.title = title
      tree = appTree

    if $root._zoriumId
      root = @registeredRoots[$root._zoriumId]

      patches = diff root.tree, tree
      root.node = patch root.node, patches
      root.tree = tree

      return $root

    $el = createElement tree

    id = @nextRootId()
    $root._zoriumId = id
    @registeredRoots[id] =
      $root: $root
      node: $el
      tree: tree

    $root.appendChild $el

    return $root

module.exports = new Renderer()
