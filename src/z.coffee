_ = require 'lodash'
h = require 'virtual-dom/h'
isVNode = require 'virtual-dom/vnode/is-vnode'
isVText = require 'virtual-dom/vnode/is-vtext'
isWidget = require 'virtual-dom/vnode/is-widget'

isComponent = (x) ->
  _.isObject(x) and _.isFunction x.render

isChild = (x) ->
  isVNode(x) or isVText(x) or isWidget(x) or isComponent(x)

isChildren = (x) ->
  _.isArray(x) or _.isString(x) or _.isNumber(x) or isChild(x)

parseZfuncArgs = (tagName, children...) ->
  props = {}

  # children[0] is props
  if children[0] and not isChildren children[0]
    props = children[0]
    children.shift()

  if children[0] and _.isArray children[0]
    children = children[0]

  if _.isArray tagName
    return {tagName: null, props, children: tagName}

  if _.isObject tagName
    return {child: tagName, props}

  return {tagName, props, children}

getTagAttributes = (tagName) ->
  re = /\[([^=\]]+)=?([^\]]+)?\]/g
  match = re.exec tagName
  props = {}

  while match?
    if match[2]
      props[match[1]] = match[2]
    else
      props[match[1]] = true
    match = re.exec tagName

  return props

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

renderChild = (child, props = {}) ->
  if isComponent child
    tree = child.render props

    unless tree
      tree = z 'span'

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

    return tree

  if _.isNumber(child)
    return '' + child

  return child


module.exports = z = ->
  {child, tagName, props, children} = parseZfuncArgs.apply null, arguments

  if child
    return renderChild child, props

  if _.isNull tagName
    return z 'div', children

  # Default tag to div
  unless /[a-zA-Z]/.test tagName[0]
    tagName = 'div' + tagName

  tag = tagName.match(/(^[^.\[]+)/)[1]

  # Extract shortcut attributes
  attributes = getTagAttributes tagName
  props = _.merge props, {attributes}

  # Remove attribute declarations from tagName
  tagName = tagName.replace /\[[^\[]+\]/g, ''

  return h tagName, props, _.map _.filter(children), renderChild
