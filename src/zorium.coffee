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
renderer = require './renderer'
server = require './server'
state = require './state'

handleRenderError = (err, req, res, next) ->
  if err instanceof server.Redirect
    return res.redirect err.path
  else if err instanceof server.Error
    return res.status(err.status)
      .send '<!DOCTYPE html>' + toHTML err.tree
  else
    return next err

_.extend z,
  render: renderer.render
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

  factoryToMiddleware: (factory) ->
    (req, res, next) ->
      initialState = {
        initialPath: req.url
        cookies: cookie.parse req.headers?.cookie or ''
      }

      $root = factory(initialState)

      # Initialize tree, kicking off async fetches
      try
        z $root, {
          path: req.url
        }

        state.onNextAllSettlemenmt ->
          try
            tree = z $root, {
              path: req.url
            }

            res.send '<!DOCTYPE html>' + toHTML tree
          catch err
            handleRenderError(err, req, res, next)

      catch err
        handleRenderError(err, req, res, next)

module.exports = z
