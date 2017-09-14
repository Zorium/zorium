{hydrate} = require 'dio.js'

z = require './z'

module.exports = (tree, $$root) ->
  if tree.render?
    tree = z tree
  hydrate tree, $$root
