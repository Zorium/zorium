{render} = require 'dyo'

z = require './z'

# BREAKING: render does not replace the element any more, only appends children
# BRAKING: order of arguments
module.exports = (tree, $$root) ->
  if tree.render? or tree.prototype?.render?
    tree = z tree
  render tree, $$root
