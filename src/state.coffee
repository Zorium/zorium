_ = require 'lodash'
Rx = require 'rx-lite'

assert = require './assert'

# TODO: move to util?
forkJoin = (observables...) ->
  Rx.Observable.combineLatest _.flatten(observables), (results...) -> results

subjectFromInitialState = (initialState) ->
  new Rx.BehaviorSubject _.mapValues initialState, (val) ->
    if val?.subscribe?
      # BehaviorSubject
      if _.isFunction val.getValue
        try
          val.getValue()
        catch
          null
      else
        null
    else
      val

module.exports = (initialState) ->
  assert _.isPlainObject(initialState), 'initialState must be a plain object'

  pendingSettlement = 0
  stateSubject = subjectFromInitialState initialState

  state = forkJoin _.map initialState, (val, key) ->
    if val?.subscribe?
      pendingSettlement += 1
      hasSettled = false

      Rx.Observable.just(null).concat val.doOnNext (update) ->
        unless hasSettled
          pendingSettlement -= 1
          hasSettled = true

        currentState = stateSubject.getValue()
        if currentState[key] isnt update
          stateSubject.onNext _.defaults {
            "#{key}": update
          }, currentState
    else
      Rx.Observable.just null
  .flatMapLatest -> stateSubject

  state.getValue = _.bind stateSubject.getValue, stateSubject
  state.set = (diff) ->
    assert _.isPlainObject(diff), 'diff must be a plain object'

    currentState = stateSubject.getValue()

    _.map diff, (val, key) ->
      if initialState[key]?.subscribe?
        throw new Error 'Attempted to set observable value'
      else
        if currentState[key] isnt val
          currentState[key] = val

    stateSubject.onNext currentState

  state._subscribeOnStable = (cb) ->
    hasSettled = false
    state.subscribe (currentState) ->
      if pendingSettlement is 0 and not hasSettled
        hasSettled = true
        cb true

  return state
