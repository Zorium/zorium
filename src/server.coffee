_ = require 'lodash'
toHTML = require 'vdom-to-html'

z = require './z'
render = require './render'
StateFactory = require './state_factory'
cookies = require './cookies'
isSimpleClick = require './is_simple_click'
ev = require './ev'

getCurrentPath = (mode) ->
  hash = window.location.hash.slice(1)
  pathname = window.location.pathname
  search = window.location.search
  if pathname
    pathname += search

  return if mode is 'pathname' then pathname or hash \
         else hash or pathname

setPath = (path, mode, isReplacement) ->
  if mode is 'pathname'
    if isReplacement
      window.history.replaceState null, null, path
    else
      window.history.pushState null, null, path
  else
    window.location.hash = path

class Server
  constructor: ->
    @events = {}
    @$$root = null
    @mode = if window?.history?.pushState then 'pathname' else 'hash'
    @currentPath = null
    @isRedrawScheduled = false
    @animationRequestId = null
    @$root = null
    @status = null # server only
    @req = null # server only

    # coffeelint: disable=missing_fat_arrows
    @Redirect = ({path}) ->
      @name = 'redirect'
      @path = path
      @message = "Redirect to #{path}"
      @stack = (new Error()).stack
    @Redirect.prototype = new Error()
    # coffeelint: enable=missing_fat_arrows

    if window?
      StateFactory.onAnyUpdate =>
        if @$root
          @go @currentPath

      # used for full-page rendering
      @globalRoot = document.getElementById 'zorium-root'

      unless @globalRoot
        @globalRoot = document.createElement 'div'
        @globalRoot.id = 'zorium-root'
        document.body.appendChild @globalRoot

      # some browsers erroneously call popstate on intial page load (iOS Safari)
      # We need to ignore that first event.
      # https://code.google.com/p/chromium/issues/detail?id=63040
      window.addEventListener 'popstate', (e) =>
        if @currentPath
          setTimeout @go

  setStatus: (@status) =>
    if window?
      throw new Error 'z.server.setStatus() called client-side'
    null

  getReq: =>
    if window?
      throw new Error 'z.server.getReq() called client-side'
    @req

  factoryToMiddleware: (factory) =>
    handleRenderError = (err, req, res, next) =>
      if err instanceof @Redirect
        return res.redirect err.path
      else
        return next err

    setResCookies = (res, cookies) ->
      _.map cookies._getConstructors(), (config, key) ->
        res.cookie key, config.value, config.opts

    (req, res, next) =>
      # Reset state between requests
      @setStatus 200
      @req = req
      cookies._reset()
      StateFactory.reset()

      StateFactory.onError (err) ->
        if _.isPlainObject err
          err = new Error JSON.stringify err
        next err

      cookies._set req.headers?.cookie

      $root = factory()

      # Initialize tree, kicking off async fetches
      try
        z $root, {
          path: req.url
        }

        StateFactory.onNextAllSettlemenmt =>
          try
            tree = z $root, {
              path: req.url
            }

            setResCookies(res, cookies)
            res.status(@status).send '<!DOCTYPE html>' + toHTML tree
          catch err
            setResCookies(res, cookies)
            handleRenderError(err, req, res, next)

      catch err
        setResCookies(res, cookies)
        handleRenderError(err, req, res, next)

  set: ({mode, factory, $$root}) =>
    @mode = mode or @mode
    @$root = factory?() or @$root
    @$$root = $$root or @$$root

  link: (node) =>
    if node.properties.onclick
      throw new Error 'onclick already bound, invalid usage'

    node.properties.onclick = ev (e, $$el) =>
      isLocal = $$el.hostname is window.location.hostname

      if isLocal and isSimpleClick e
        e.preventDefault()
        @go $$el.pathname + $$el.search

    return node

  render: (props) =>
    try
      tree = z @$root, props
    catch err
      if err instanceof @Redirect
        return @go err.path
      else throw err

    # Because the DOM doesn't let us directly manipulate top-level elements
    # We have to standardize a hack around it

    $root = if @$$root is document \
      then @globalRoot \
      else @$$root

    render $root, tree

  go: (path) =>
    unless window?
      throw new Error 'z.server.go() called server-side'

    path ?= getCurrentPath(@mode)
    hasRouted = not Boolean @currentPath
    isRedraw = path is @currentPath

    if @isRedrawScheduled and isRedraw
      return
    else if @isRedrawScheduled
      @isRedrawScheduled = false
      window.cancelAnimationFrame @animationRequestId

    props = {
      path: path
    }

    if not isRedraw
      @currentPath = path
      setPath path, @mode, hasRouted
      @emit 'route', path
      @render(props)
    else
      @isRedrawScheduled = true
      @animationRequestId = window.requestAnimationFrame =>
        @isRedrawScheduled = false
        @render(props)

  on: (name, fn) =>
    unless window?
      throw new Error 'z.server.on() called server-side'

    (@events[name] = @events[name] or []).push(fn)

  emit: (name) =>
    args = _.rest arguments
    _.map @events[name], (fn) ->
      fn.apply null, args

  off: (name, fn) =>
    unless window?
      throw new Error 'z.server.off() called server-side'

    @events[name] = _.without(@events[name], fn)

server = new Server()
module.exports = {
  off: server.off
  on: server.on
  go: server.go
  link: server.link
  set: server.set
  setStatus: server.setStatus
  getReq: server.getReq
  factoryToMiddleware: server.factoryToMiddleware
  Redirect: server.Redirect
}
