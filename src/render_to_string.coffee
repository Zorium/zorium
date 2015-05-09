_ = require 'lodash'
Rx = require 'rx-lite'
toHTML = require 'vdom-to-html'
isThunk = require 'virtual-dom/vnode/is-thunk'

z = require './z'
assert = require './assert'
StateFactory = require './state_factory'

if not Promise? and not window?
  # Avoid webpack include
  _bluebird = 'bluebird'
  Promise = require _bluebird

DEFAULT_TIMEOUT_MS = 250

tryCatch = (fn, catcher) ->
  try
    fn()
  catch err
    catcher(err)

module.exports = (tree, {timeout} = {}) ->
  timeout ?= DEFAULT_TIMEOUT_MS

  assert not window?, 'z.renderToString() called client-side'

  new Promise (resolve, reject) ->
    allStates = [] # for unbinding
    states = []
    disposables = []
    lastTree = null

    renderTree = (tree) ->
      if isThunk(tree)
        z tree.render tree.vnode
      else
        z tree

    listener = ->
      z._startRecordingStates()
      tryCatch ->
        lastTree = renderTree tree
      , finish
      states = z._getRecordedStates()
      allStates = allStates.concat states
      z._stopRecordingStates()

      _.map states, (state) ->
        unless state._isSubscribing()
          tryCatch ->
            state._bind_subscriptions()
          , (err) ->
            onError err
          disposables.push state.subscribe listener, onError

      setImmediate ->
        isDone = _.every allStates, (state) ->
          state._isFulfilled()
        if isDone
          tryCatch ->
            lastTree = renderTree tree
            finish(null)
          , finish

    onError = (err) ->
      tryCatch ->
        lastTree = renderTree tree
        finish err
      , finish

    finish = _.once (err) ->
      _.map disposables, (disposable) -> disposable.dispose()
      _.map allStates, (state) -> state._unbind_subscriptions()

      # Thunks make it difficult to render lastTree
      if err
        if lastTree
          tryCatch ->
            err.html = toHTML lastTree
          , (err) ->
            reject err
        reject err
      else
        tryCatch ->
          resolve toHTML lastTree
        , (err) ->
          reject err

    setTimeout ->
      finish new Error "Timeout, request took longer than #{timeout}ms"
    , timeout

    listener()
