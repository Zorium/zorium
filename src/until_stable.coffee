_ = require 'lodash'

z = require './z'

render = (child, component) ->
  # NOTE: untilStable is only meant to pre-fill state
  #   and generally succeed except with malformed trees
  #   render() errors will be caught during stringification / mounting
  try
    child.render component.props
  catch
    {}

getComponents = (tree) ->
  if _.isArray tree
    return _.flatten _.map _.filter(tree), getComponents

  if tree.type?.zoriumComponent?
    [tree]
  else
    children = []
    unless tree.children?.forEach
      return children
    tree.children.forEach (child) -> children.push child
    _.flatten _.map children, getComponents

# TODO: leaks memory if tree never stabilizes...
untilStable = (component, disposablePromises) ->
  child = component.type.zoriumComponent

  # TODO: test performance assumption of preloading
  stateVal = null
  if child.state?
    stateVal = child.state.getValue()
    cached = _.map getComponents(render(child, component)), (component) ->
      untilStable component, disposablePromises

  (if child.state?
    # NOTE: untilStable is only meant to pre-fill state
    #   and generally succeed except with malformed trees
    promise = child.state._onStable().catch (err) ->
      console.error err
      null
    disposablePromises.push promise
    promise
  else
    Promise.resolve()
  ).then ->
    if child.state? and _.isEqual stateVal, child.state.getValue()
      return Promise.all cached
    Promise.all _.map getComponents(render(child, component)), (component) ->
      untilStable component, disposablePromises

module.exports = (tree, {timeout} = {}) ->
  if tree.render?
    tree = z tree

  return new Promise (resolve, reject) ->
    if timeout?
      setTimeout ->
        tree = null # XXX: reduce memory leakage (...?)
        reject new Error "Timeout, request took longer than #{timeout}ms"
      , timeout
    disposablePromises = []
    Promise.all _.map getComponents(tree), (component) ->
      untilStable component, disposablePromises
    .then resolve, reject
    .then ->
      # TODO: test for leaky subscriptions
      Promise.all disposablePromises
      .then (disposables) ->
        _.map disposables, (disposable) ->
          disposable?.unsubscribe()
    .catch (err) -> console.error err
  .then -> null
