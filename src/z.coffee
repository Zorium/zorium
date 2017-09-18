_ = require 'lodash'

parseTag = require './parseTag.js'
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
  if child?.render?
    if child._component?
      child._component
    else
      isMounted = false
      subscription = null

      # TODO: perf difference vs class constructor
      kv =
        zoriumComponent: child
        componentDidMount: ($$el) ->
          if isMounted
            err = new Error "Component mounted twice #{child.constructor.name}"
            if window.__mountTwiceError? # tests
              window.__mountTwiceError err
            else
              throw err
            return
          isMounted = true
          # TODO: .distinctUntilChanged() ?
          unless subscription
            subscription = child.state?.subscribe (state) =>
              this.setState state
            , (err) ->
              if child.afterThrow?
                child.afterThrow err
              else
                if window.__stateError? # tests
                  window.__stateError err
                else
                  throw new Error err

          child.afterMount? $$el
        componentWillUnmount: ->
          isMounted = false
          subscription?.unsubscribe()
          subscription = null
          child.beforeUnmount?()
        componentDidCatch: if child.afterThrow? then (err) ->
          child.afterThrow err
          err.report = false
          return null
        # coffeelint: disable=missing_fat_arrows
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
  else
    child

module.exports = z = (tagName, props, children...) ->
  unless _.isPlainObject props
    children = [props].concat children
    props = {}

  if _.isArray children[0]
    children = children[0]

  if _.isString tagName
    tagName = parseTag tagName, props
  else
    tagName = zChildToHChild tagName

  # TODO: remove
  _.merge props, props.attributes
  delete props.attributes

  # TODO: test perf
  # chillen = _.map children, zChildToHChild
  # unless chillen.length is 0 then chillen
  h tagName, props, _.map children, zChildToHChild
