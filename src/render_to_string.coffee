{render} = require 'dyo/server/dist/dyo.umd.js'

z = require './z'

DEFAULT_TIMEOUT_MS = 250

class Writable
  constructor: ->
    this.innerHTML = ''
    @end = @write
  write: (value) =>
    this.innerHTML += value

stringify = (tree) ->
  {innerHTML} = await render tree, new Writable(), ->
    console.log 'cb??????'
  return innerHTML

module.exports = (tree, {timeout} = {}) ->
  if window?
    throw new Error 'z.renderToString() called client-side'
  timeout ?= DEFAULT_TIMEOUT_MS

  # if tree.render? or tree.prototype?.render?
  #   tree = z tree

  stringify(tree)
