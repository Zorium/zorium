_ = require 'lodash'
Rx = require 'rx-lite'

class StateFactory
  constructor: ->
    @anyUpdateListeners = []
    @errorListeners = []

  reset: =>
    @anyUpdateListeners = []
    @errorListeners = []

  fireAnyUpdateListeners: =>
    _.map @anyUpdateListeners, (fn) ->
      fn()

  fireError: (err) =>
    if _.isEmpty @errorListeners
      throw err

    _.map @errorListeners, (fn) ->
      fn(err)

  onAnyUpdate: (fn) =>
    @anyUpdateListeners.push fn

  onError: (fn) ->
    @errorListeners.push fn

  create: (initialState) =>
    unless _.isPlainObject initialState
      throw new Error 'initialState must be a plain object'

    isSubscribing = false
    pendingSettlement = 0
    currentValue = {}
    disposables = []
    selfDisposable = null

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

    state.onNext currentValue

    state._isFulfilled = ->
      pendingSettlement is 0

    state._isSubscribing = ->
      isSubscribing

    state._bind_subscriptions = =>
      if isSubscribing
        return
      isSubscribing = true
      pendingSettlement = 0

      selfDisposable = state.subscribe @fireAnyUpdateListeners, @fireError

      mapObservables initialState, (val ,key) ->
        pendingSettlement += 1

      mapObservables initialState, (val ,key) ->
        hasSettled = false
        disposables.push val.subscribe (update) ->
          currentValue[key] = update
          unless hasSettled
            hasSettled = true
            pendingSettlement -= 1
          state.onNext currentValue
        , (err) ->
          state.onError err

    state._unbind_subscriptions = ->
      unless isSubscribing
        return
      isSubscribing = false

      selfDisposable.dispose()
      _.map disposables, (disposable) ->
        disposable.dispose()
      disposables = []

    state.set = (diff) ->
      unless _.isPlainObject diff
        throw new Error 'diff must be a plain object'

      _.map diff, (val, key) ->
        if initialState[key]?.subscribe
          throw new Error 'Attempted to set observable value'
        else
          currentValue[key] = val

      state.onNext currentValue
      return state

    return state

module.exports = new StateFactory()
