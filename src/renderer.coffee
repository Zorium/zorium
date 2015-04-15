diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
createElement = require 'virtual-dom/create-element'

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

class Renderer
  constructor: ->
    @registeredRoots = {}
    @isRedrawScheduled = false

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
    unless @isRedrawScheduled
      @isRedrawScheduled = true
      window.requestAnimationFrame =>
        @isRedrawScheduled = false
        for id, root of @registeredRoots
          @render root.$root, root.tree

module.exports = new Renderer()
