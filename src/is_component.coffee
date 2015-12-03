_ = require 'lodash'
isThunk = require 'virtual-dom/vnode/is-thunk'

module.exports = (x) ->
  _.isObject(x) and _.isFunction(x.render) and not isThunk x
