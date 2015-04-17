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
Router = require './router'
renderer = require './renderer'
server = require './server'
state = require './state'

handleRouteError = (router, err, req, res, next) ->
  if err instanceof router.Redirect
    return res.redirect err.path
  else if err instanceof router.Error
    return res.status(err.status)
      .send '<!DOCTYPE html>' + toHTML err.tree
  else
    return next err

_.extend z,
  render: renderer.render
  Router: Router
  server: server
  state: state
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
      route = router.match(req.url)
      props = {
        path: req.url
        params: route.params
        query: req.query
        cookies: cookie.parse req.headers?.cookie or ''
      }

      try
        # Initialize tree, kicking off async fetches
        route.fn props

        state.onNextAllSettlemenmt ->
          try
            tree = route.fn props

            res.send '<!DOCTYPE html>' + toHTML tree

          catch err
            handleRouteError(router, err, req, res, next)
      catch err
        handleRouteError(router, err, req, res, next)

module.exports = z
