_ = require 'lodash'
h = require 'virtual-dom/h'

util = require './util'

module.exports = z = ->
  {child, tagName, props, children} = util.parseZfuncArgs.apply null, arguments

  if child
    return renderChild child

  if _.isNull tagName
    return z 'div', children

  # Default tag to div
  unless /[a-zA-Z]/.test tagName[0]
    tagName = 'div' + tagName

  tag = tagName.match(/(^[^.\[]+)/)[1]

  # Extract shortcut attributes
  attributes = util.getTagAttributes tagName
  props = _.merge props, {attributes}

  # Remove attribute declarations from tagName
  tagName = tagName.replace /\[[^\[]+\]/g, ''

  return h tagName, props, _.map _.filter(children), renderChild

getChildSerializedState = (child) ->
  if _.isFunction(child.state) then child.state() else {}

renderChild = (child) ->
  if util.isComponent child
    tree = child.render getChildSerializedState child

    unless tree
      tree = z 'div'

    if _.isArray tree
      tree = z 'div', tree

    tree.hooks ?= {}

    if not child.zorium_hasBeenMounted and _.isFunction child.onMount
      class OnMountHook
        hook: ($el, propName) ->
          setTimeout ->
            child.onMount $el

      child.zorium_hasBeenMounted = true

      hook = new OnMountHook()
      tree.properties['zorium-onmount'] = hook
      tree.hooks['zorium-onmount'] = hook

    if _.isFunction child.onBeforeUnmount
      class OnBeforeUnmountHook
        hook: -> null
        unhook: ->
          child.onBeforeUnmount()
          child.zorium_hasBeenMounted = false

      hook = new OnBeforeUnmountHook()
      tree.properties['zorium-onbeforeunmount'] = hook
      tree.hooks['zorium-onbeforeunmount'] = hook

    if not child.zorium_isWatchingState and _.isFunction child.state
      child.state ->
        # TODO: Move this out, circular dependency with renderer
        z.redraw()

      child.zorium_isWatchingState = true

    return tree

  if _.isNumber(child)
    return '' + child

  return child
