_ = require 'lodash'

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

z = require './z'
render = require './render'
server = require './server'
StateFactory = require './state_factory'
ev = require './ev'
classKebab = require './class_kebab'
cookies = require './cookies'

_.assign z,
  render: render
  server: server
  state: StateFactory.create
  cookies: cookies
  ev: ev
  classKebab: classKebab

module.exports = z
