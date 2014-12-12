_ = require 'lodash'
observStruct = require 'observ-struct'
observArray = require 'observ-array'
observ = require 'observ'

isPromise = (obj) ->
  _.isObject(obj) and _.isFunction(obj.then)


observePromise = (observable, promise) ->
  _set = observable.set.bind observable
  observable._pending = promise

  promise.then (val) ->
    if observable._pending is promise
      _set val

  for key in Object.keys promise
    if _.isFunction promise[key]
      observable[key] = promise[key].bind promise

  return observable


observePromise = (promise) ->
  observed = observ(null)

  observed._promise = promise

  promise.then (val) ->
    if observed._promise is promise
      observed.set val

  for key in Object.keys promise
    if _.isFunction promise[key]
      observed[key] = promise[key].bind promise

  return observed


observe = (obj) ->
  observed = switch
    when  _.isFunction obj
      obj

    when _.isArray obj
      observArray obj

    when isPromise obj
      observePromise obj

    when _.isObject obj
      observStruct obj

    else
      observ obj

  _set = observed.set.bind observed

  observed.set = (diff) ->
    if isPromise diff
      promise = diff
      observed._promise = diff

      promise.then (val) =>
        if this._promise is promise
          _set val

      for key in Object.keys promise
        if _.isFunction promise[key]
          observed[key] = promise[key].bind promise

      _set null
    else
      _set diff

  return observed

module.exports = observe
