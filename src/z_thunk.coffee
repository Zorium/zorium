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

module.exports = class ZThunk
  constructor: ({@props, @component}) ->
    @hook = hook
      beforeMount: ($el) =>
        # Wait for insertion into the DOM
        setTimeout =>
          # TODO: add a test for this verifying that hook order matters
          @component.afterMount?($el)
      beforeUnmount: =>
        @component.beforeUnmount?()

  type: 'Thunk'
  render: =>
    # TODO: this could be optimized to capture children during render
    tree = @component.render @props

    if isComponent(tree) or isThunk(tree)
      throw new Error 'Cannot return another component from render'

    if _.isArray tree
      throw new Error 'Render cannot return an array'

    unless tree?
      tree = h 'noscript'

    tree.hooks ?= {}
    tree.properties['zorium-hook'] = @hook
    tree.hooks['zorium-hook'] = @hook

    return tree
