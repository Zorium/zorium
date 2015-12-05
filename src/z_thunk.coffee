_ = require 'lodash'
h = require 'virtual-dom/h'
isThunk = require 'virtual-dom/vnode/is-thunk'

isComponent = require './is_component'

# TODO: explain why the fat arrow breaks it...
hook = ({beforeMount, beforeUnmount}) ->
  class Hook
    hook: ($el, propName) ->
      beforeMount($el)
    unhook: ->
      beforeUnmount()

  new Hook()

isZThunk = (node) ->
  isThunk(node) and node.component?

getZThunks = (node) ->
  if isZThunk node
    [node]
  else
    _.flatten _.map node.children, getZThunks

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

      # FIXME: this logic is brittle, breaks on A,B,B' (A' is removed instead)
      @component.__disposables = []
      @component.__hook ?= hook
        beforeMount: ($el) =>
          # Wait for insertion into the DOM
          # TODO: add a test for this verifying that hook order matters
          # TODO: test race condition where mount is called after unmount
          # TODO: document how a component may be mounted twice for
          # a page transition of one state to the next (think about this more)
          setTimeout =>
            if state?
              @component.__disposables.push state.subscribe dirty
            @component.afterMount?($el)
        beforeUnmount: =>
          @component.beforeUnmount?()
          disposable = @component.__disposables.shift()
          disposable?.dispose()

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
