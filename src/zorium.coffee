# Bind polyfill (phantomjs doesn't support bind)
# coffeelint: disable=missing_fat_arrows
unless Function::bind
  Function::bind = (oThis) ->

    # closest thing possible to the ECMAScript 5
    # internal IsCallable function
    throw new TypeError(
      'Function.prototype.bind - what is trying to be bound is not callable'
    ) if typeof this isnt 'function'
    aArgs = Array::slice.call(arguments, 1)
    fToBind = this
    fNOP = -> null

    fBound = ->
      fToBind.apply(
        (if this instanceof fNOP and oThis then this else oThis),
        aArgs.concat(Array::slice.call(arguments))
      )

    fNOP:: = @prototype
    fBound:: = new fNOP()
    fBound
# coffeelint: enable=missing_fat_arrows

_ = require 'lodash'
Rx = require 'rx-lite'

z = require './z'
observe = require './observe'
router = require './router'
renderer = require './renderer'

_.extend z,
  render: renderer.render
  redraw: renderer.redraw
  router: router

  # START LEGACY
  observe: observe
  oldState: (obj) ->
    observed = observe obj

    _set = observed.set.bind observed
    observed.set = (diff) ->
      _set _.defaults diff, observed()

    return observed
  # END LEGACY

  state: (initialState) ->
    currentValue = {}

    state = new Rx.BehaviorSubject(currentValue)

    # set currentState to all values of initialState
    _.forEach initialState, (val, key) ->
      if val?.subscribe
        currentValue[key] = null
        val.subscribe (update) ->
          currentValue[key] = update
          state.onNext currentValue
      else
        currentValue[key] = val

    state.onNext currentValue

    state.set = (diff) ->
      _.forEach diff, (val, key) ->
        if initialState[key]?.subscribe
          throw new Error 'Attempted to set observable value'
        else
          currentValue[key] = val

      state.onNext currentValue
      return state

    return state
  ev: (fn) ->
    # coffeelint: disable=missing_fat_arrows
    (e) ->
      $$el = this
      fn(e, $$el)
    # coffeelint: enable=missing_fat_arrows
  classKebab: (classes) ->
    _.map _.keys(_.pick classes, _.identity), _.kebabCase
    .join ' '

module.exports = z
