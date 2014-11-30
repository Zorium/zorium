_ = require 'lodash'
observStruct = require 'observ-struct'
observArray = require 'observ-array'
observ = require 'observ'

_observe = (obj) ->
  if _.isFunction obj
    return obj

  if _.isArray obj
    # FIXME: PR observ-array to add values
    return observArray _.map obj, _observe

  if _.isObject obj
    if _.isFunction obj.then
      observed = observ null

      obj.then (val) ->
        observed.set val
        return val

      for key in Object.keys obj
        if _.isFunction obj[key]
          observed[key] = obj[key].bind obj

      return observed

    return observStruct _.transform obj, (obj, val, key) ->
      obj[key] = _observe val
    , {}

  return observ obj

module.exports = _observe
