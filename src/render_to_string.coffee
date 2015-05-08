_ = require 'lodash'
Rx = require 'rx-lite'
toHTML = require 'vdom-to-html'

z = require './z'
StateFactory = require './state_factory'

Promise = if window?
  window.Promise
else
  _promiz = 'promiz'
  require _promiz

module.exports = (tree) ->
  new Promise (resolve) ->
    # for unbinding
    allStates = []
    states = []
    disposables = []

    listener = ->
      z._startRecordingStates()
      z tree
      states = z._getRecordedStates()
      allStates = allStates.concat states
      z._stopRecordingStates()
      _.map states, (state) ->
        unless state._isSubscribing()
          state._bind_subscriptions()
          disposables.push state.subscribe listener
      setTimeout ->
        finish()

    finish = ->
      isDone = _.every states, (state) ->
        state._isFulfilled()

      if isDone
        result = z tree
        _.map disposables, (disposable) -> disposable.dispose()
        _.map allStates, (state) -> state._unbind_subscriptions()
        resolve toHTML result

    listener()
