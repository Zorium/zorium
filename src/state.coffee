_ = require 'lodash'
Rx = require 'rx-lite'

settlementListeners = []
pendingSettlement = 0

fireSettlement = ->
  _.map settlementListeners, (fn) ->
    fn()
  settlementListeners = []

State = (initialState) ->
  currentValue = {}

  state = new Rx.BehaviorSubject(currentValue)

  # set currentState to all values of initialState
  _.map initialState, (val, key) ->
    if val?.subscribe
      currentValue[key] = null
      pendingSettlement += 1
      val.subscribe (update) ->
        currentValue[key] = update
        state.onNext currentValue
    else
      currentValue[key] = val

  # watch for all state values to settle
  _.map initialState, (val, key) ->
    if val?.subscribe
      hasSettled = false
      val.subscribe (update) ->
        unless hasSettled
          pendingSettlement -= 1
          if pendingSettlement is 0
            fireSettlement()
          hasSettled = true

  state.onNext currentValue

  state.set = (diff) ->
    _.map diff, (val, key) ->
      if initialState[key]?.subscribe
        throw new Error 'Attempted to set observable value'
      else
        currentValue[key] = val

    state.onNext currentValue
    return state

  return state


State.onNextAllSettlemenmt = (fn) ->
  if pendingSettlement is 0
    fn()
  else
    settlementListeners.push fn
  return null

module.exports = State
