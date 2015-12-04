_ = require 'lodash'
Rx = require 'rx-lite'
isThunk = require 'virtual-dom/vnode/is-thunk'

if not window?
  # Avoid webpack include
  _toHTML = 'vdom-to-html'
  toHTML = require _toHTML

# TODO: use native promises, upgrade node
if not Promise? and not window?
  # Avoid webpack include
  _promiz = 'promiz'
  Promise = require _promiz

z = require './z'
assert = require './assert'
isComponent = require './is_component'

DEFAULT_TIMEOUT_MS = 250

module.exports = (tree, {timeout} = {}) ->
  assert not window?, 'z.renderToString() called client-side'

  timeout ?= DEFAULT_TIMEOUT_MS

  if isComponent tree
    tree = z tree

  # TODO: ugly, depends on timeout in closure
  untilStable = (tree) ->
    if isThunk(tree) and tree.component?
      zthunk = tree
      state = zthunk.component.state

      # Begin resolving children before current node is stable for performance
      try
        _.map zthunk.render().children, untilStable
      catch err
        return Promise.reject err

      new Promise (resolve, reject) ->
        setTimeout ->
          reject new Error "Timeout, request took longer than #{timeout}ms"
        , timeout

        onStable = if state? then state._subscribeOnStable else (cb) -> cb()
        onStable ->
          try
            children = zthunk.render().children
          catch err
            return reject err
          resolve Promise.all _.map children, untilStable
      .then -> zthunk
    else
      Promise.all _.map tree.children, untilStable
      .then -> tree

  try
    safe = toHTML tree
  catch err
    return Promise.reject err

  untilStable tree
  .then -> toHTML tree
  .catch (err) ->
    err.html = safe
    throw err
