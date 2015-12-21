_ = require 'lodash'
isThunk = require 'virtual-dom/vnode/is-thunk'

# TODO: use native promises, upgrade node
if window?
  Promise = window.Promise
else
  # Avoid webpack include
  _promiz = 'promiz'
  Promise = global.Promise or require _promiz

z = require './z'
isComponent = require './is_component'
getZThunks = require './get_z_thunks'

untilStable = (zthunk) ->
  state = zthunk.component.state

  # Begin resolving children before current node is stable for performance
  # TODO: test performance assumption
  try
    children = getZThunks zthunk.render()
    Promise.all _.map children, untilStable
  catch err
    return Promise.reject err

  new Promise (resolve, reject) ->
    # TODO: make sure this doesn't leak
    onStable = if state? then state._subscribeOnStable else (cb) -> cb()
    onStable ->
      try
        children = getZThunks zthunk.render()
      catch err
        return reject err
      resolve Promise.all _.map children, untilStable
  .then -> zthunk

module.exports = (tree, {timeout} = {}) ->
  if isComponent tree
    tree = z tree

  return new Promise (resolve, reject) ->
    if timeout?
      setTimeout ->
        reject new Error "Timeout, request took longer than #{timeout}ms"
      , timeout

    Promise.all _.map getZThunks(tree), (zthunk) ->
      untilStable zthunk
    .then resolve
    .catch reject
