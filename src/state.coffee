_ = require 'lodash'
Rx = require 'rx-lite'

settlementListeners = []
anyUpdateListeners = []
pendingSettlement = 0

fireSettlement = ->
  _.map settlementListeners, (fn) ->
    fn()
  settlementListeners = []

fireAnyUpdateListeners = ->
  _.map anyUpdateListeners, (fn) ->
    fn()

State = (initialState) ->
  currentValue = {}
  disposables = []

  state = new Rx.BehaviorSubject(currentValue)

  # set currentState to all values of initialState
  _.map initialState, (val, key) ->
    if val?.subscribe
      currentValue[key] = null
    else
      currentValue[key] = val

  state.onNext currentValue

  state._bind_subscriptions = ->
    _.map initialState, (val, key) ->
      if val?.subscribe
        pendingSettlement += 1

    _.map initialState, (val, key) ->
      if val?.subscribe
        hasSettled = false
        disposables.push \
        val.subscribe (update) ->
          currentValue[key] = update
          state.onNext currentValue
          unless hasSettled
            pendingSettlement -= 1
            if pendingSettlement is 0
              fireSettlement()
            hasSettled = true
        , (err) -> throw err

  state._unbind_subscriptions = ->
    _.map disposables, (disposable) ->
      disposable.dispose()
    disposables = []

  state.set = (diff) ->
    _.map diff, (val, key) ->
      if initialState[key]?.subscribe
        throw new Error 'Attempted to set observable value'
      else
        currentValue[key] = val

    state.onNext currentValue
    return state

  state.subscribe fireAnyUpdateListeners, (err) -> throw err

  return state


State.onAnyUpdate = (fn) ->
  anyUpdateListeners.push fn
  return null

State.onNextAllSettlemenmt = (fn) ->
  if pendingSettlement is 0
    fn()
  else
    settlementListeners.push fn
  return null

module.exports = State
