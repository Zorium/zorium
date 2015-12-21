if not window?
  # Avoid webpack include
  _toHTML = 'vdom-to-html'
  toHTML = require _toHTML

# TODO: use native promises, upgrade node
if window?
  Promise = window.Promise
else
  # Avoid webpack include
  _promiz = 'promiz'
  Promise = global.Promise or require _promiz

z = require './z'
assert = require './assert'
isComponent = require './is_component'
untilStable = require './until_stable'

DEFAULT_TIMEOUT_MS = 250

module.exports = (tree, {timeout} = {}) ->
  assert not window?, 'z.renderToString() called client-side'

  timeout ?= DEFAULT_TIMEOUT_MS

  if isComponent tree
    tree = z tree

  try
    safe = toHTML tree
  catch err
    return Promise.reject err

  untilStable tree, {timeout}
  .then -> toHTML tree
  .catch (err) ->
    err.html = safe
    throw err
