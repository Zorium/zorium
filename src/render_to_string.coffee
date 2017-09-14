z = require './z'
untilStable = require './until_stable'

DEFAULT_TIMEOUT_MS = 250

module.exports = (tree, {timeout} = {}) ->
  if window?
    throw new Error 'z.renderToString() called client-side'
  timeout ?= DEFAULT_TIMEOUT_MS

  if tree.render?
    tree = z tree

  untilStable tree, {timeout}
  .then (-> "#{tree}"), (err) ->
    err.html = "#{tree}"
    throw err
