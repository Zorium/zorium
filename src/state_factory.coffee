_ = require 'lodash'
Rx = require 'rx-lite'

class StateFactory
  constructor: ->
    @settlementListeners = []
    @anyUpdateListeners = []
    @errorListeners = []
    @pendingSettlement = 0

  reset: =>
    @settlementListeners = []
    @anyUpdateListeners = []
    @errorListeners = []
    @pendingSettlement = 0

  fireSettlement: =>
    _.map @settlementListeners, (fn) ->
      fn()
    @settlementListeners = []

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

  onNextAllSettlemenmt: (fn) =>
    if @pendingSettlement is 0
      fn()
    else
      @settlementListeners.push fn

  onError: (fn) ->
    @errorListeners.push fn

  create: (initialState) =>
    unless _.isPlainObject initialState
      throw new Error 'initialState must be a plain object'

    isSubscribing = false
    currentValue = {}
    disposables = []

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

    state._bind_subscriptions = =>
      if isSubscribing
        return

      isSubscribing = true

      mapObservables initialState, (val ,key) =>
        @pendingSettlement += 1

      mapObservables initialState, (val ,key) =>
        hasSettled = false
        disposables.push \
        val.subscribe (update) =>
          currentValue[key] = update
          state.onNext currentValue
          unless hasSettled
            @pendingSettlement -= 1
            if @pendingSettlement is 0
              @fireSettlement()
            hasSettled = true
        , (err) ->
          state.onError err

    state._unbind_subscriptions = ->
      unless isSubscribing
        return

      isSubscribing = false

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

    state.subscribe @fireAnyUpdateListeners, @fireError

    return state

module.exports = new StateFactory()
