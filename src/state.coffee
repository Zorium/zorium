_ = require 'lodash'
Rx = require 'rxjs/Rx'

module.exports = (initialState) ->
  unless _.isPlainObject(initialState)
    throw new Error 'initialState must be a plain object'

  currentState = _.mapValues initialState, (val) ->
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
  stateSubject = new Rx.BehaviorSubject currentState
  streams = _.pickBy initialState, (x) -> x?.subscribe?

  pendingStream = if _.isEmpty streams
    Rx.Observable.of null
  else
    Rx.Observable.combineLatest _.map streams, (val, key) ->
      val.do (update) ->
        currentState = _.assign _.clone(currentState), {
          "#{key}": update
        }

  state = Rx.Observable.combineLatest \
    [stateSubject].concat _.map streams, (val, key) ->
      Rx.Observable.defer ->
        Rx.Observable.of currentState[key]
      .concat(
        val.do (update) ->
          if currentState[key] isnt update
            currentState = _.assign _.clone(currentState), {
              "#{key}": update
            }
      )
      .distinctUntilChanged()
    .map -> currentState

  state.getValue = -> currentState
  state.set = (diff) ->
    unless _.isPlainObject(diff)
      throw new Error 'diff must be a plain object'

    didReplace = false
    _.map diff, (val, key) ->
      if initialState[key]?.subscribe?
        throw new Error 'Attempted to set observable value'
      else
        if currentState[key] isnt val
          didReplace = true

    if didReplace
      currentState = _.assign _.clone(currentState), diff
      stateSubject.next currentState

  stablePromise = null
  state._onStable = ->
    if stablePromise?
      return stablePromise
    # NOTE: we subscribe here instead of take(1) to allow for state
    #  updates caused by chilren to their parents (who have already stabilized)
    disposable = null
    stablePromise = new Promise (resolve, reject) ->
      disposable = pendingStream.subscribe resolve, reject
    .catch (err) ->
      disposable?.unsubscribe()
      throw err
    .then -> disposable

  return state
