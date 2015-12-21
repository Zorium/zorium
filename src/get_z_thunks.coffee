_ = require 'lodash'
isZThunk = require './is_z_thunk'

module.exports = getZThunks = (tree) ->
  if isZThunk tree
    [tree]
  else
    _.flatten _.map tree.children, getZThunks
