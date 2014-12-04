_ = require 'lodash'
observStruct = require 'observ-struct'
observArray = require 'observ-array'
observ = require 'observ'

isPromise = (obj) ->
  _.isObject(obj) and _.isFunction(obj.then)


# coffeelint: disable=missing_fat_arrows
observePromise = (observable, promise) ->
  this._set = observable.set.bind observable
  this._set._pending = promise

  promise.then (val) =>
    console.log 'PROMISE RESOLVED', val
    if this._set._pending is promise
      console.log 'SETTING VALUE'
      this._set val

  for key in Object.keys promise
    if _.isFunction promise[key]
      observable[key] = promise[key].bind promise

  return observable
# coffeelint: enable=missing_fat_arrows


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

  observed._set = observed.set.bind observed

  # coffeelint: disable=missing_fat_arrows
  observed.set = (diff) ->
    if isPromise diff
      promise = diff
      this._promise = diff

      promise.then (val) =>
        if this._promise is promise
          this.set val

      for key in Object.keys promise
        if _.isFunction promise[key]
          this[key] = promise[key].bind promise

      this.set null
    else
      this._set diff
  # coffeelint: enable=missing_fat_arrows

  return observed

module.exports = observe
