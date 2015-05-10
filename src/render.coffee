diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
virtualize = require 'vdom-virtualize'

flattenTree = require './flatten_tree'

parseFullTree = (tree) ->
  unless tree?.tagName is 'HTML' and tree.children.length is 2
    throw new Error 'Invalid HTML base element'

  $head = flattenTree tree.children[0]
  $body = flattenTree tree.children[1]
  $title = flattenTree $head.children[0]
  $root = flattenTree $body.children[0]

  unless $head?.tagName is 'HEAD' and $title?.tagName is 'TITLE'
    throw new Error 'Invalid HEAD base element'

  unless $body?.tagName is 'BODY' and $root?.properties.id is 'zorium-root'
    throw new Error 'Invalid BODY base element'

  return {
    $root: $root
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

  render: ($$root, tree) =>
    unless $$root instanceof HTMLElement
      throw new Error 'invalid $$root'

    tree = flattenTree tree

    # Because the DOM doesn't let us directly manipulate top-level elements
    # We have to standardize a hack around it
    if tree?.tagName is 'HTML'
      {title, $root} = parseFullTree tree
      document.title = title
      tree = $root

    unless $$root._zoriumId
      seedTree = removeContentEditable virtualize $$root
      id = @nextRootId()
      $$root._zoriumId = id
      @registeredRoots[id] =
        node: $$root
        tree: seedTree

    root = @registeredRoots[$$root._zoriumId]

    patches = diff root.tree, tree
    root.node = patch root.node, patches
    root.tree = tree

    return $$root



renderer = new Renderer()
module.exports = renderer.render
