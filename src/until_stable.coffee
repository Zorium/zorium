_ = require 'lodash'
isThunk = require 'virtual-dom/vnode/is-thunk'

z = require './z'
isComponent = require './is_component'
getZThunks = require './get_z_thunks'

untilStable = (zthunk) ->
  state = zthunk.component.state

  try
    # Begin resolving children before current node is stable for performance
    # TODO: test performance assumption
    preloadPromise = Promise.all _.map getZThunks zthunk.render(), untilStable
    onStable = if state? then state._onStable else (-> Promise.resolve null)
    Promise.all [
      preloadPromise
      onStable()
    ]
    .then ->
      children = getZThunks zthunk.render()
      Promise.all _.map children, untilStable
    .then -> zthunk
  catch err
    return Promise.reject err

module.exports = (tree, {timeout} = {}) ->
  if isComponent tree
    tree = z tree

  return new Promise (resolve, reject) ->
    if timeout?
      setTimeout ->
        # TODO: this, print better explanation (maybe only in dev mode)
        reject new Error "Timeout, request took longer than #{timeout}ms"
      , timeout

    Promise.all _.map getZThunks(tree), (zthunk) ->
      untilStable zthunk
    .then resolve
    .catch reject
