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

z = require './z'
observe = require './observe'
router = require './router'
renderer = require './renderer'

_.extend z,
  render: renderer.render
  redraw: renderer.redraw
  router: router
  observe: observe
  state: (obj) ->
    observed = observe obj

    _set = observed.set.bind observed
    observed.set = (diff) ->
      _set _.defaults diff, observed()

    return observed
  ev: (fn) ->
    # coffeelint: disable=missing_fat_arrows
    (e) ->
      $$el = this
      fn(e, $$el)
    # coffeelint: enable=missing_fat_arrows

module.exports = z
