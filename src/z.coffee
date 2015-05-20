_ = require 'lodash'
h = require 'virtual-dom/h'
Rx = require 'rx-lite'
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

class ComponentThunk
  constructor: ({@renderFn, @props, @child}) -> null
  type: 'Thunk'
  isEqual: (previous) =>
    not previous.child.__dirtySubject.getValue() and
    previous.child is @child and
    _.isEqual(@props, previous.props)
  render: (previous) =>
    if previous and @isEqual previous
      return previous.vnode
    else
      return @renderFn @child, @props

getChildren = (tree) ->
  if isThunk tree
    return [tree.child]
  else if tree.children
    return _.flatten _.map tree.children, getChildren
  else
    return []

renderComponent = (child, props) ->
  # TODO: this could be optimized to capture children during render
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

renderChild = (child, props = {}) ->
  # Don't defer anything while rendering server-side
  if isRecordingStates and isComponent(child)
    if child.state?
      recordedStates.push child.state
    return renderComponent child, props

  if isThunk child
    return renderChild child.child, child.props

  if isComponent child
    unless child.__isInitialized
      child.__isInitialized = true
      child.__dirtySubject = new Rx.BehaviorSubject(false)
      child.__dirtyStream = child.__dirtySubject.distinctUntilChanged()
      child.__disposables = []

      if child.state
        lastVal = child.state.getValue()
        child.state.subscribe (val) ->
          if lastVal isnt val
            lastVal = val
            child.__dirtySubject.onNext true

      child._zorium_hook = createHook ($el) ->
        # Wait for insertion into the DOM
        setTimeout ->
          # bind after insertion because of hook execution order
          # (unhook can be called after hook in one update)
          # TODO: add a test for this
          child.state?._bind_subscriptions()
          child.onMount?($el)
      , ->
        child.state?._unbind_subscriptions()
        child.onBeforeUnmount?()

    renderFn = (child, props) ->
      tree = renderComponent child, props

      childrenStreams = _.filter _.pluck getChildren(tree), '__dirtyStream'

      _.map child.__disposables, (disposable) ->
        disposable.dispose()

      child.__disposables = _.map childrenStreams, (dirtyStream) ->
        dirtyStream.subscribe (isDirty) ->
          child.__dirtySubject.onNext isDirty

      child.__dirtySubject.onNext false

      return tree

    return new ComponentThunk {child, props, renderFn}

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
