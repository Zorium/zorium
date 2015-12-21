_ = require 'lodash'
h = require 'virtual-dom/h'
isThunk = require 'virtual-dom/vnode/is-thunk'

isComponent = require './is_component'
getZThunks = require './get_z_thunks'

# TODO: explain why the fat arrow breaks it...
hook = ({beforeMount, beforeUnmount}) ->
  class Hook
    hook: ($el, propName) ->
      beforeMount($el)
    unhook: ->
      beforeUnmount()

  new Hook()

module.exports = class ZThunk
  constructor: ({@props, @component}) ->
    # TODO: move somewhere else
    # TODO: make sure this isn't leaking memory
    unless @component.__isInitialized
      @component.__isInitialized = true
      state = @component.state

      # TODO: debounce here for performance
      dirty = =>
        @component.__isDirty = true
        @component.__onDirty?()

      mountQueueCnt = 0
      unmountQueueCnt = 0
      mountedEl = null
      runHooks = =>
        $el = mountedEl

        if mountQueueCnt > unmountQueueCnt + 1
          throw new Error "Component '#{@component.constructor?.name}'
            cannot be mounted twice at the same time"

        if unmountQueueCnt > 0
          @component.beforeUnmount?()
          @component.__disposable?.dispose()
          unmountQueueCnt = 0
          mountedEl = null

        if mountQueueCnt > 0 and mountQueueCnt >= unmountQueueCnt
          @component.__disposable = state?.subscribe dirty
          @component.afterMount?($el)
          mountQueueCnt = 0

      @component.__hook ?= hook
        beforeMount: ($el) ->
          mountQueueCnt += 1
          mountedEl = $el

          setTimeout ->
            runHooks()

        beforeUnmount: ->
          unmountQueueCnt += 1

          setTimeout ->
            runHooks()

      currentChildren = []
      @component.__onRender = (tree) =>
        @component.__isDirty = false
        nextChildren = _.map getZThunks(tree), (thunk) -> thunk.component
        newChildren = _.difference nextChildren, currentChildren
        currentChildren = nextChildren

        _.map newChildren, (child) ->
          child.__onDirty = dirty

  type: 'Thunk'

  isEqual: (previous) =>
    previous?.componenet is @component and
    not @component.__isDirty and
    _.isEqual previous.props, @props

  render: (previous) =>
    if @isEqual(previous)
      return previous

    # TODO: this could be optimized to capture children during render
    tree = @component.render @props

    if isComponent(tree) or isThunk(tree)
      throw new Error 'Cannot return another component from render'

    if _.isArray tree
      throw new Error 'Render cannot return an array'

    unless tree?
      tree = h 'noscript'

    tree.hooks ?= {}
    tree.properties['zorium-hook'] = @component.__hook
    tree.hooks['zorium-hook'] = @component.__hook

    @component.__onRender tree

    return tree
