_ = require 'lodash'

z = require './z'
render = require './render'
hydrate = require './hydrate'
renderToString = require './render_to_string'
State = require './state'
classKebab = require './class_kebab'
isSimpleClick = require './is_simple_click'
untilStable = require './until_stable'
{useMemo, Boudary} = require 'dyo/server/dist/dyo.umd.js'

# BREAKING: remove z.bind()
# BREAKING: remove z.ev()
_.assign z, {
  z
  render
  hydrate
  renderToString
  classKebab
  isSimpleClick
  untilStable
  Boudary
  useState: (cb, deps = []) ->
    state = useMemo ->
      State(cb(deps))
    , []

    await state._onStable().then (stableDisposable) ->
      process.nextTick ->
        stableDisposable.unsubscribe()

    state.getValue()
}

module.exports = z
