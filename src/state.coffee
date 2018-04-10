_ = require 'lodash'
Rx = require 'rxjs/Rx'

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
  unless _.isPlainObject(initialState)
    throw new Error 'initialState must be a plain object'

  pendingSettlement = 0
  stateSubject = subjectFromInitialState initialState

  state = Rx.Observable.combineLatest _.map initialState, (val, key) ->
    if val?.subscribe?
      pendingSettlement += 1
      hasSettled = false
      val = val
      .do (update) ->
        unless hasSettled
          pendingSettlement -= 1
          hasSettled = true

        currentState = stateSubject.getValue()
        if currentState[key] isnt update
          # TODO: avoid double state subject updates for single child update
          stateSubject.next _.assign _.clone(currentState), {
            "#{key}": update
          }
      , ->
        unless hasSettled
          pendingSettlement -= 1
          hasSettled = true
      Rx.Observable.of(null).concat(val)
    else
      Rx.Observable.of null
  .switchMap -> stateSubject

  state.getValue = _.bind stateSubject.getValue, stateSubject
  state.set = (diff) ->
    unless _.isPlainObject(diff)
      throw new Error 'diff must be a plain object'

    currentState = _.clone stateSubject.getValue()

    didReplace = false
    _.map diff, (val, key) ->
      if initialState[key]?.subscribe?
        throw new Error 'Attempted to set observable value'
      else
        if currentState[key] isnt val
          didReplace = true
          currentState[key] = val

    if didReplace
      stateSubject.next currentState

  stablePromise = null
  state._onStable = ->
    if stablePromise?
      return stablePromise
    disposable = null
    stablePromise = new Promise (resolve, reject) ->
      disposable = state.subscribe ->
        if pendingSettlement is 0
          resolve()
      , reject
    .catch (err) ->
      disposable?.unsubscribe()
      throw err
    .then -> disposable

  return state
