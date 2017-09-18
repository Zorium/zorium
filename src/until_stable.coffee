_ = require 'lodash'

z = require './z'

render = (child, component) ->
  try
    child.render component.props
  catch err
    # TODO: understand why a noop here is fine
    {}

getComponents = (tree) ->
  # TODO: add a test for this
  if _.isArray tree
    return _.flatten _.map tree, getComponents

  if tree.type?.zoriumComponent?
    [tree]
  else
    children = []
    unless tree.children?.forEach
      return children
    tree.children.forEach (child) -> children.push child
    _.flatten _.map children, getComponents

untilStable = (component) ->
  child = component.type.zoriumComponent

  # TODO: test performance assumption of preloading
  stateVal = null
  if child.state?
    stateVal = child.state.getValue()
    cached = _.map getComponents(render(child, component)), untilStable

  Promise.all [
    if child.state?
      child.state._onStable().catch (err) -> child.afterThrow? err
  ]
  .then ->
    if child.state? and stateVal is child.state.getValue()
      return Promise.all cached
    Promise.all _.map getComponents(render(child, component)), untilStable

module.exports = (tree, {timeout} = {}) ->
  if tree.render? # TODO: test
    tree = z tree

  return new Promise (resolve, reject) ->
    if timeout?
      setTimeout ->
        reject new Error "Timeout, request took longer than #{timeout}ms"
      , timeout
    Promise.all _.map getComponents(tree), untilStable
    .then resolve, reject
  .then -> null
