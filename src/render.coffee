diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
createElement = require 'virtual-dom/create-element'
virtualize = require 'vdom-virtualize'
isThunk = require 'virtual-dom/vnode/is-thunk'

z = require './z'

parseFullTree = (tree) ->
  unless tree?.tagName is 'HTML'
    throw new Error 'Invalid HTML base element'

  $head = tree.children[0]
  $body = tree.children[1]
  $title = $head?.children[0]
  appTree = $body?.children[0]

  unless $head?.tagName is 'HEAD' and $title?.tagName is 'TITLE'
    throw new Error 'Invalid HEAD base element'

  unless $body?.tagName is 'BODY' and appTree?.properties.id is 'zorium-root'
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
    if isThunk(tree)
      tree = tree.render tree.vnode

    # Because the DOM doesn't let us directly manipulate top-level elements
    # We have to standardize a hack around it
    if tree?.tagName is 'HTML'
      {title, appTree} = parseFullTree tree

      unless $root._zoriumId
        seedRoot = $root.children[0]

        # virtualize existing DOM
        if seedRoot
          seedTree = removeContentEditable virtualize seedRoot
          $el = seedRoot
          id = @nextRootId()
          $root._zoriumId = id
          @registeredRoots[id] =
            $root: $root
            node: $el
            tree: seedTree

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

renderer = new Renderer()
module.exports = renderer.render
