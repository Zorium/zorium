{hydrate} = require 'dyo'

z = require './z'

module.exports = (tree, $$root) ->
  if tree.render? or tree.prototype?.render?
    tree = z tree
  hydrate tree, $$root
