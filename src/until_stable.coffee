_ = require 'lodash'

z = require './z'

render = (child, component) ->
  # NOTE: untilStable is only meant to pre-fill state
  #   and generally succeed except with malformed trees
  #   render() errors will be caught during stringification / mounting
  try
    child.render component.props
  catch err
    {}

getComponents = (tree) ->
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
      # NOTE: untilStable is only meant to pre-fill state
      #   and generally succeed except with malformed trees
      child.state._onStable().catch (err) -> console.error err
  ]
  .then ->
    if child.state? and stateVal is child.state.getValue()
      return Promise.all cached
    Promise.all _.map getComponents(render(child, component)), untilStable

module.exports = (tree, {timeout} = {}) ->
  if tree.render?
    tree = z tree

  return new Promise (resolve, reject) ->
    if timeout?
      setTimeout ->
        reject new Error "Timeout, request took longer than #{timeout}ms"
      , timeout
    Promise.all _.map getComponents(tree), untilStable
    .then resolve, reject
  .then -> null
