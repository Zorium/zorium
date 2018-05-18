_ = require 'lodash'

parseTag = require './parse_tag'
{h} = require 'dio.js'

hasOwnProperty = Object.hasOwnProperty

compareChildren = (a, b) ->
  if isSame a.children, b.children
    return false
  if a.children.length isnt b.children.length
    return true
  for child, i in a.children
    unless isSame child, b.children[i]
      return true
  false

compare = (a, b) ->
  for key of a
    if not hasOwnProperty.call(b, key)
      return true
  for key of b
    if key is 'children'
      continue
    if not isSame a[key], b[key]
      return true
  false

isSame = (a, b) ->
  if a is b
    a isnt 0 or 1 / a is 1 / b
  else
    a isnt a and b isnt b

zChildToHChild = (child) ->
  if _.isFunction child?.render
    if child._component?
      child._component
    else
      mountCounter = 0
      subscription = null
      instance = null

      # TODO: perf difference vs class constructor
      kv =
        displayName: child.constructor.name
        zoriumComponent: child
        componentWillMount: ->
          mountCounter += 1
        # coffeelint: disable=missing_fat_arrows
        componentDidMount: ($$el) ->
        # coffeelint: enable=missing_fat_arrows
          if mountCounter > 1
            child.beforeUnmount?()
            setTimeout ->
              if mountCounter > 1
                err = \
                  new Error "Component mounted twice #{child.constructor.name}"
                if window.__mountTwiceError? # tests
                  window.__mountTwiceError err
                else
                  throw err
          instance = this
          unless subscription
            subscription = child.state?.subscribe (state) ->
              try
                instance.setState state
              catch err
                if window?
                  setTimeout -> throw err
                else
                  console.error err
            , (err) ->
              try
                instance.setState Promise.reject err
              catch err
                if window?
                  setTimeout -> throw err
                else
                  console.error err
          child.afterMount? $$el
        componentWillUnmount: ->
          mountCounter -= 1
          if mountCounter is 0
            subscription?.unsubscribe()
            subscription = null
            child.beforeUnmount?()
          if mountCounter < 0
            throw new Error 'Unreachable! Something went horribly wrong'
        # coffeelint: disable=missing_fat_arrows
        componentDidCatch: if child.afterThrow?
          (args...) ->
            child.afterThrow.apply child, args
            this.forceUpdate()
        shouldComponentUpdate: (props, state) ->
          compare(this.props, props) or \
          compare(this.state, state) or \
          compareChildren(this.props, props)
        # coffeelint: enable=missing_fat_arrows
        getInitialState: ->
          # TODO: understand what this does and add a test for it
          if child.state?
            child.state.getValue()

      child._component = (props) -> child.render props
      for key, val of kv
        child._component[key] = val
      return child._component
  else if child?.prototype?.render?
    if child._component?
      child._component
    else
      # XXX: dedupe above
      # NOTE: does not support async server-side rendering
      child._component = class ZoriumComponent
        @displayName: child.name
        constructor: ->
          @subscription = null
          @zoriumComponent = new child()

          if @zoriumComponent.afterThrow?
            @componentDidCatch = (args...) =>
              @zoriumComponent.afterThrow.apply @zoriumComponent, args
              @forceUpdate()

        componentDidMount: ($$el) =>
          @subscription = @zoriumComponent.state?.subscribe (state) =>
            try
              @setState state
            catch err
              if window?
                setTimeout -> throw err
              else
                console.error err
          , (err) =>
            try
              @setState Promise.reject err
            catch err
              if window?
                setTimeout -> throw err
              else
                console.error err
          @zoriumComponent.afterMount? $$el

        componentWillUnmount: =>
          @subscription = @subscription?.unsubscribe()
          @subscription = null
          @zoriumComponent.beforeUnmount?()

        render: (args...) =>
          @zoriumComponent.render.apply @zoriumComponent, args

        # coffeelint: disable=missing_fat_arrows
        shouldComponentUpdate: (props, state) ->
          compare(this.props, props) or \
          compare(this.state, state) or \
          compareChildren(this.props, props)
        # coffeelint: enable=missing_fat_arrows
        getInitialState: =>
          # TODO: understand what this does and add a test for it
          if @zoriumComponent.state?
            @zoriumComponent.state.getValue()
  else
    child

# BREAKING: no longer supports {attributes} prop
module.exports = (tagName, props, children...) ->
  unless _.isPlainObject(props)
    if props?
      children = [props].concat children
    props = {}

  if _.isArray children[0]
    children = children[0]

  if _.isString tagName
    tagName = parseTag tagName, props
  else
    tagName = zChildToHChild tagName

  # TODO: test perf
  # chillen = _.map children, zChildToHChild
  # unless chillen.length is 0 then chillen
  h tagName, props, _.map children, zChildToHChild
