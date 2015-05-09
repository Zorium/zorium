_ = require 'lodash'
Rx = require 'rx-lite'
toHTML = require 'vdom-to-html'

z = require './z'
StateFactory = require './state_factory'

if not Promise? and not window?
  # Avoid webpack include
  _bluebird = 'bluebird'
  Promise = require _bluebird

DEFAULT_TIMEOUT_MS = 250

module.exports = (tree, {timeout} = {}) ->
  timeout ?= DEFAULT_TIMEOUT_MS

  new Promise (resolve, reject) ->
    allStates = [] # for unbinding
    states = []
    disposables = []
    lastTree = null

    listener = ->
      runtimeError = null
      z._startRecordingStates()
      try
        lastTree = z tree
      catch err
        runtimeError = err
      states = z._getRecordedStates()
      allStates = allStates.concat states
      z._stopRecordingStates()

      if runtimeError
        return finish runtimeError

      _.map states, (state) ->
        unless state._isSubscribing()
          state._bind_subscriptions()
          disposables.push state.subscribe listener, onError

      immediate = if setImmediate? then setImmediate else setTimeout
      immediate ->
        isDone = _.every states, (state) ->
          state._isFulfilled()
        if isDone
          try
            lastTree = z tree
            finish(null)
          catch runtimeError
            finish runtimeError

    onError = (err) ->
      try
        lastTree = z tree
        finish err
      catch runtimeError
        finish runtimeError

    finish = _.once (err) ->
      _.map disposables, (disposable) -> disposable.dispose()
      _.map allStates, (state) -> state._unbind_subscriptions()

      if err
        if lastTree
          err.html = toHTML lastTree
        reject err
      else
        html = toHTML lastTree
        resolve html

    setTimeout ->
      finish new Error "Timeout, request took longer than #{timeout}ms"
    , timeout

    listener()
