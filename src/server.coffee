cookie = require 'cookie'

z = require './z'
util = require './util'
renderer = require './renderer'
state = require './state'

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
    @root = null
    @mode = if window?.history?.pushState then 'pathname' else 'hash'
    @currentPath = null
    @isRedrawScheduled = false
    @animationRequestId = null
    @$rootComponent = null

    # coffeelint: disable=missing_fat_arrows
    @Redirect = ({path}) ->
      @name = 'redirect'
      @path = path
      @message = "Redirect to #{path}"
      @stack = (new Error()).stack
    @Redirect.prototype = new Error()

    @Error = ({tree, status}) ->
      @name = String status
      @tree = tree
      @status = status
      @message = "Error #{status}"
      @stack = (new Error()).stack
    @Error.prototype = new Error()
    # coffeelint: enable=missing_fat_arrows

    state.onAnyUpdate =>
      if window? and @$rootComponent
        @go @currentPath

    if window?
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

  setRootNode: (@root) => null

  setMode: (mode) =>
    @mode = mode

  setRootFactory: (factory) =>
    @$rootComponent = factory
      cookies: cookie.parse document.cookie or ''

  link: (node) =>
    if node.properties.onclick
      throw new Error 'onclick already bound, invalid usage'

    go = @go

    # coffeelint: disable=missing_fat_arrows
    node.properties.onclick = (e) ->
      $el = this
      isLocal = $el.hostname is window.location.hostname

      if isLocal
        e.preventDefault()
        go $el.pathname + $el.search
      # coffeelint: enable=missing_fat_arrows

    return node

  render: (props) =>
    try
      tree = z @$rootComponent, props
    catch err
      if err instanceof @Redirect
        return @go err.path
      else if err instanceof @Error
        tree = err.tree
      else throw err

    # Because the DOM doesn't let us directly manipulate top-level elements
    # We have to standardize a hack around it

    $root = if @root is document \
      then @globalRoot \
      else @root

    renderer.render $root, tree

  go: (path) =>
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
    (@events[name] = @events[name] or []).push(fn)

  emit: (name) =>
    args = _.rest arguments
    _.map @events[name], (fn) ->
      fn.apply null, args

  off: (name, fn) =>
    @events[name] = _.without(@events[name], fn)


module.exports = new Server()
