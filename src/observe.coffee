_ = require 'lodash'
observStruct = require 'observ-struct'
observArray = require 'observ-array'
observ = require 'observ'

isPromise = (obj) ->
  _.isObject(obj) and _.isFunction(obj.then)

getAllProperties = (obj) ->
  allProps = []
  currentObject = obj

  loop
    props = Object.getOwnPropertyNames(currentObject)
    allProps = _.uniq allProps.concat props
    currentObject = Object.getPrototypeOf(currentObject)
    unless currentObject
      break

  return allProps

# TODO: don't do this...
extendMethods = (obj, source) ->
  _.each getAllProperties(source), (key) ->
    if _.isFunction source[key]
      obj[key] = source[key].bind source

observePromise = (promise) ->
  observed = observ(null)

  observed._promise = promise

  promise.then (val) ->
    if observed._promise is promise
      observed.set val

  extendMethods observed, promise
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

      promise.then (val) ->
        if observed._promise is promise
          _set val

      extendMethods observed, promise

      _set null
    else
      observed._promise = null
      _set diff

  return observed

module.exports = observe
