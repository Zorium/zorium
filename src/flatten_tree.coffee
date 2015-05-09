isThunk = require 'virtual-dom/vnode/is-thunk'

z = require './z'

module.exports = (tree) ->
  tree = z tree
  if isThunk(tree)
    tree.render tree.vnode
  else
    tree
