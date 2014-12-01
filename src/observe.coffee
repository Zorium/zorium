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
    if this._set._pending is promise
      this._set val

  for key in Object.keys promise
    if _.isFunction promise[key]
      observable[key] = promise[key].bind promise

  return observable
# coffeelint: enable=missing_fat_arrows

observe = (obj) ->
  observed = switch
    when  _.isFunction obj
      obj

    when _.isArray obj
      observArray obj

    when isPromise obj
      do ->
        return observePromise observ(null), obj

    when _.isObject obj
      observStruct obj

    else
      observ obj

  observed._set = observed.set.bind observed

  # coffeelint: disable=missing_fat_arrows
  observed.set = (diff) ->
    if isPromise diff
      observePromise this, diff
    else
      this._set diff
  # coffeelint: enable=missing_fat_arrows

  return observed

module.exports = observe
