_ = require 'lodash'
h = require 'virtual-dom/h'
isVNode = require 'virtual-dom/vnode/is-vnode'
isVText = require 'virtual-dom/vnode/is-vtext'
isWidget = require 'virtual-dom/vnode/is-widget'
isThunk = require 'virtual-dom/vnode/is-thunk'

isRecordingStates = false
recordedStates = []

isComponent = (x) ->
  _.isObject(x) and _.isFunction(x.render) and not isThunk x

isChild = (x) ->
  isVNode(x) or
  _.isString(x) or
  isComponent(x) or
  _.isNumber(x) or
  isVText(x) or
  isWidget(x) or
  isThunk(x)

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

createHook = (onBeforeMount, onBeforeUnmount) ->
  class Hook
    hook: ($el, propName) ->
      onBeforeMount($el)
    unhook: ->
      onBeforeUnmount()

  new Hook()

renderComponent = (child, props) ->
  tree = child.render props

  if isComponent(tree) or isThunk(tree)
    throw new Error 'Cannot return another component from render'

  if _.isArray tree
    throw new Error 'Render cannot return an array'

  unless tree
    tree = z 'noscript'

  tree.hooks ?= {}
  tree.properties['zorium-hook'] = child._zorium_hook
  tree.hooks['zorium-hook'] = child._zorium_hook

  return tree

class Thunk
  constructor: ({@renderFn, @props, @child}) ->
    @isDirty = false
  type: 'Thunk'
  dirty: =>
    @isDirty = true
  isEqual: (previous) =>
    not previous.isDirty and
    previous.child is @child and
    _.isEqual(@props, previous.props)
  render: (previous) =>
    if previous and @isEqual previous
      return previous.vnode
    else
      return @renderFn()

safeRender = (child, props) ->
  try
    renderComponent(child, props)
    return {error: null}
  catch err
    return {error: err}

parentComponent = null
renderChild = (child, props = {}) ->
  # Don't defer anything while rendering server-side
  if isRecordingStates and isComponent(child)
    if child.state?
      recordedStates.push child.state
    return renderComponent child, props

  if isComponent child
    if child._zorium_is_initialized
      return child._zorium_create_thunk props

    parent = parentComponent

    # initialize zorium component
    child._zorium_is_initialized = true

    child._zorium_hook = createHook ($el) ->
      child.state?._bind_subscriptions()

      # Wait for insertion into the DOM
      setTimeout ->
        child.onMount?($el)
    , ->
      child.state?._unbind_subscriptions()
      child.onBeforeUnmount?()

    # Handle multiple rendered instances
    child._zorium_thunks = []
    child._zorium_create_thunk = (props) ->
      thunk = new Thunk {
        renderFn: ->
          try
            parentComponent = child
            res = renderComponent child, props
            parentComponent = parent
            return res
          catch err
            parentComponent = parent
            throw err
        props: props
        child: child
      }
      child._zorium_thunks.push thunk
      return thunk

    child._makeDirty = ->
      parent?._makeDirty()
      _.map child._zorium_thunks, (thunk) ->
        thunk.dirty()
      child._zorium_thunks = []

    # On state change, make parents dirty
    lastVal = child.state?.getValue()
    child.state?.subscribe (state) ->
      unless lastVal is state
        lastVal = state
        child._makeDirty()

    return child._zorium_create_thunk props

  if _.isNumber(child)
    return '' + child

  return child


module.exports = z = ->
  {child, tagName, props, children} = parseZfuncArgs.apply null, arguments

  if child
    return renderChild child, props

  return h tagName, props, _.map children, renderChild

# FIXME: This is a hack to get at the states
z._getRecordedStates = ->
  recordedStates

z._startRecordingStates = ->
  isRecordingStates = true

z._stopRecordingStates = ->
  recordedStates = []
  isRecordingStates = false
