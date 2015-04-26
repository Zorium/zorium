_ = require 'lodash'
h = require 'virtual-dom/h'
isVNode = require 'virtual-dom/vnode/is-vnode'
isVText = require 'virtual-dom/vnode/is-vtext'
isWidget = require 'virtual-dom/vnode/is-widget'

isComponent = (x) ->
  _.isObject(x) and _.isFunction x.render

isChild = (x) ->
  isVNode(x) or
  _.isString(x) or
  isComponent(x) or
  _.isNumber(x) or
  isVText(x) or
  isWidget(x)

isChildren = (x) ->
  _.isArray(x) or isChild(x)

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

createHook = (onMount, onBeforeUnmount) ->
  class Hook
    hook: ($el, propName) ->
      setTimeout ->
        onMount?($el)
    unhook: ->
      onBeforeUnmount?()

  new Hook()

renderChild = (child, props = {}) ->
  if isComponent child
    tree = child.render props

    unless tree
      tree = z 'noscript'

    tree.hooks ?= {}

    unless child._zorium_hook
      child._zorium_hook = createHook child.onMount, ->
        child._zorium_hasBoundState = false
        child.state?._unbind_subscriptions()
        child.onBeforeUnmount?()

    unless child._zorium_hasBoundState
      child._zorium_hasBoundState = true
      child.state?._bind_subscriptions()

    tree.properties['zorium-hook'] = child._zorium_hook
    tree.hooks['zorium-hook'] = child._zorium_hook

    return tree

  if _.isNumber(child)
    return '' + child

  return child


module.exports = z = ->
  {child, tagName, props, children} = parseZfuncArgs.apply null, arguments

  if child
    return renderChild child, props

  return h tagName, props, _.map children, renderChild
