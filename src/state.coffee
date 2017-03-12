_ = require 'lodash'
Rx = require 'rxjs/Rx'

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

# TODO: fix cyclomatic complexity
module.exports = (initialState) ->
  assert _.isPlainObject(initialState), 'initialState must be a plain object'

  pendingSettlement = 0
  stateSubject = subjectFromInitialState initialState

  state = forkJoin _.map initialState, (val, key) ->
    if val?.subscribe?
      pendingSettlement += 1
      hasSettled = false
      val = val
      .do null, ->
        unless hasSettled
          pendingSettlement -= 1
          hasSettled = true
      .do (update) ->
        unless hasSettled
          pendingSettlement -= 1
          hasSettled = true

        currentState = stateSubject.getValue()
        if currentState[key] isnt update
          stateSubject.next _.defaults {
            "#{key}": update
          }, currentState
      Rx.Observable.of(null).concat val
    else
      Rx.Observable.of null
  .switchMap -> stateSubject

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

    stateSubject.next currentState

  stablePromise = null
  state._onStable = ->
    if stablePromise?
      return stablePromise
    disposable = null
    stablePromise = new Promise (resolve, reject) ->
      # TODO: make sure this doesn't leak server-side
      disposable = state.subscribe ->
        if pendingSettlement is 0
          resolve()
      , reject
    .catch (err) ->
      # disposing here server-side breaks cache
      if window?
        disposable?.unsubscribe()
      throw err
    .then ->
      # disposing here server-side breaks cache
      if window?
        disposable.unsubscribe()
      return null

  return state
