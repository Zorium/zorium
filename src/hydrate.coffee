{hydrate} = require 'dio.js'

z = require './z'

module.exports = (tree, $$root) ->
  if tree.render? or tree.prototype?.render?
    tree = z tree
  hydrate tree, $$root
