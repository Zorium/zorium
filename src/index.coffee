_ = require 'lodash'

z = require './z'
render = require './render'
hydrate = require './hydrate'
renderToString = require './render_to_string'
state = require './state'
classKebab = require './class_kebab'
isSimpleClick = require './is_simple_click'
untilStable = require './until_stable'

# BREAKING: remove z.bind()
# BREAKING: remove z.ev()
_.assign z, {
  render
  hydrate
  renderToString
  state
  classKebab
  isSimpleClick
  untilStable
}

module.exports = z
