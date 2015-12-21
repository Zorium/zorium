isThunk = require 'virtual-dom/vnode/is-thunk'

module.exports = (node) ->
  isThunk(node) and node.component?
