_ = require 'lodash'
Rx = require 'rx-lite'
assert = require 'assert'

class StateFactory
  constructor: ->
    @anyUpdateListeners = []
    @errorListeners = []

  fireAnyUpdateListeners: =>
    _.map @anyUpdateListeners, (fn) ->
      fn()

  onAnyUpdate: (fn) =>
    @anyUpdateListeners.push fn

  create: (initialState) =>
    assert _.isPlainObject(initialState), 'initialState must be a plain object'

    isSubscribing = false
    pendingSettlement = 0
    currentValue = {}
    disposables = []
    selfDisposable = null
    isDirty = false

    state = new Rx.BehaviorSubject(currentValue)

    mapObservables = (collection, iteratee = _.identity, thisArg) ->
      # coffeelint: disable=missing_fat_arrows
      _.map collection, (val) ->
        if val?.subscribe
          iteratee.apply this, arguments
      , thisArg
      # coffeelint: enable=missing_fat_arrows

    # set currentState to all values of initialState
    _.map initialState, (val, key) ->
      if val?.subscribe
        currentValue[key] = null
      else
        currentValue[key] = val

    state = new Rx.BehaviorSubject(currentValue)

    state._isFulfilled = ->
      pendingSettlement is 0

    state._isSubscribing = ->
      isSubscribing

    state._bind_subscriptions = =>
      if isSubscribing
        return
      isSubscribing = true
      pendingSettlement = 0

      if window?
        selfDisposable = state.subscribe @fireAnyUpdateListeners,
                                         (err) -> throw err

      mapObservables initialState, (val ,key) ->
        pendingSettlement += 1

      mapObservables initialState, (val ,key) ->
        settle = _.once ->
          pendingSettlement -= 1

        disposables.push val.subscribe (update) ->
          settle()
          if currentValue[key] isnt update
            nextVal = {}
            nextVal[key] = update
            currentValue = _.defaults nextVal, currentValue
          state.onNext currentValue
        , (err) ->
          state.onError err

    state._unbind_subscriptions = ->
      unless isSubscribing
        return
      isSubscribing = false

      selfDisposable?.dispose()
      _.map disposables, (disposable) ->
        disposable.dispose()
      disposables = []

    state.set = (diff) ->
      assert _.isPlainObject(diff), 'diff must be a plain object'

      _.map diff, (val, key) ->
        if initialState[key]?.subscribe
          throw new Error 'Attempted to set observable value'
        else
          if currentValue[key] isnt val
            nextVal = {}
            nextVal[key] = val
            currentValue = _.defaults nextVal, currentValue

      state.onNext currentValue
      return state

    return state

module.exports = new StateFactory()
