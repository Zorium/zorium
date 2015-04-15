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
toHTML = require 'vdom-to-html'
cookie = require 'cookie'

z = require './z'
observe = require './observe'
Router = require './router'
renderer = require './renderer'
server = require './server'
state = require './state'

_.extend z,
  render: renderer.render
  redraw: renderer.redraw
  Router: Router
  server: server
  state: state

  # START LEGACY
  observe: observe
  oldState: (obj) ->
    observed = observe obj

    _set = observed.set.bind observed
    observed.set = (diff) ->
      _set _.defaults diff, observed()

    return observed
  # END LEGACY

  ev: (fn) ->
    # coffeelint: disable=missing_fat_arrows
    (e) ->
      $$el = this
      fn(e, $$el)
    # coffeelint: enable=missing_fat_arrows
  classKebab: (classes) ->
    _.map _.keys(_.pick classes, _.identity), _.kebabCase
    .join ' '

  routerToMiddleware: (router) ->
    (req, res, next) ->
      try
        # Initialize tree, kicking off async fetches
        router.resolve {
          path: req.url
          cookies: cookie.parse req.headers?.cookie or ''
        }

        state.onNextAllSettlemenmt ->
          tree = router.resolve {
            path: req.url
            cookies: cookie.parse req.headers?.cookie or ''
          }

          res.send '<!DOCTYPE html>' + toHTML tree
      catch err
        if err instanceof router.Redirect
          return res.redirect err.path
        else
          return next err

module.exports = z
