_ = require 'lodash'
h = require 'virtual-dom/h'

util = require './util'

module.exports = z = ->
  {child, tagName, props, children} = util.parseZfuncArgs.apply null, arguments

  if child
    return renderChild child, props

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

getOnMountHook = (child, onMount) ->
  class OnMountHook
    hook: ($el, propName) ->
      setTimeout ->
        onMount $el

  hook = child._zorium_OnMountHook or new OnMountHook()
  child._zorium_OnMountHook = hook
  return hook

getOnBeforeUnmountHook = (child, onUnhook) ->
  class OnBeforeUnmountHook
    # FIXME: https://github.com/Matt-Esch/virtual-dom/pull/175
    hook: -> null
    unhook: ->
      child.onBeforeUnmount()
      onUnhook()

  hook = child._zorium_OnBeforeUnmountHook or new OnBeforeUnmountHook()
  child._zorium_OnBeforeUnmountHook = hook
  return hook

# FIXME: reduce cyclomatic complexity
renderChild = (child, props = {}) ->
  if util.isComponent child
    tree = child.render props

    unless tree
      tree = z 'div'

    if _.isArray tree
      tree = z 'div', tree

    tree.hooks ?= {}

    if not child.zorium_hasBeenMounted and _.isFunction child.onMount
      child.zorium_hasBeenMounted = true
      hook = getOnMountHook child, child.onMount
      tree.properties['zorium-onmount'] = hook
      tree.hooks['zorium-onmount'] = hook

    if _.isFunction child.onBeforeUnmount
      hook = getOnBeforeUnmountHook child, ->
        child.zorium_hasBeenMounted = false
      tree.properties['zorium-onbeforeunmount'] = hook
      tree.hooks['zorium-onbeforeunmount'] = hook

    if not child.zorium_isWatchingState and _.isFunction child.state?.subscribe
      child.state.subscribe ->
        # TODO: Move this out, circular dependency with renderer
        if window?
          z.redraw()
      , (err) ->
        throw new Error err

      child.zorium_isWatchingState = true

    return tree

  if _.isNumber(child)
    return '' + child

  return child
