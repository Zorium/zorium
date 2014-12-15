diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
createElement = require 'virtual-dom/create-element'

z = require './z'

class Renderer
  constructor: ->
    @registeredRoots = {}

    id = 0
    @nextRootId = ->
      id += 1

  render: ($root, tree) =>
    renderedTree = z tree

    if $root._zoriumId
      root = @registeredRoots[$root._zoriumId]

      patches = diff root.renderedTree, renderedTree
      root.node = patch root.node, patches
      root.tree = tree
      root.renderedTree = renderedTree

      return $root

    $el = createElement renderedTree

    id = @nextRootId()
    $root._zoriumId = id
    @registeredRoots[id] =
      $root: $root
      node: $el
      tree: tree
      renderedTree: renderedTree

    $root.appendChild $el

    return $root

  redraw: =>
    for id, root of @registeredRoots
      @render root.$root, root.tree

module.exports = new Renderer()
