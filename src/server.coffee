routes = require 'routes'
Qs = require 'qs'
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

parseUrl = (url) ->
  if window?
    a = document.createElement 'a'
    a.href = url

    {
      pathname: a.pathname
      hash: a.hash
      search: a.search
      path: a.pathname + a.search
    }
  else
    # Avoid webpack include
    _url = 'url'
    URL = require(_url)
    parsed = URL.parse url

    {
      pathname: parsed.pathname
      hash: parsed.hash
      search: parsed.search
      path: parsed.path
    }

class Server
  constructor: ->
    @events = {}
    @root = null
    @router = null
    @mode = if window?.history?.pushState then 'pathname' else 'hash'
    @currentPath = null
    @cachedPaths = {}
    @isRedrawScheduled = false
    @animationRequestId = null

    state.onAnyUpdate =>
      if window? and @router
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

  setRoot: ($$root) =>
    @root = $$root

  setMode: (mode) =>
    @mode = mode

  setRouter: (router) ->
    @router = router

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

  render: (route, props) =>
    try
      tree = route.fn props
    catch err
      if err instanceof @router.Redirect
        return @go err.path
      else if err instanceof @router.Error
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
    isReplacement = not Boolean @currentPath
    cookies = cookie.parse document.cookie or ''
    isRedraw = path is @currentPath
    url = parseUrl path
    queryParams = Qs.parse(url.search?.slice(1))

    if @isRedrawScheduled and isRedraw
      return
    else if @isRedrawScheduled
      @isRedrawScheduled = false
      window.cancelAnimationFrame @animationRequestId

    route = @router.match(url.pathname)

    props = {
      params: route.params
      query: queryParams
      cookies
    }

    if not isRedraw
      @currentPath = path
      setPath path, @mode, isReplacement
      @emit 'route', path
      @render(route, props)
    else
      @isRedrawScheduled = true
      @animationRequestId = window.requestAnimationFrame =>
        @isRedrawScheduled = false
        @render(route, props)

  on: (name, fn) =>
    (@events[name] = @events[name] or []).push(fn)

  emit: (name) =>
    args = _.rest arguments
    _.map @events[name], (fn) ->
      fn.apply null, args

  off: (name, fn) =>
    @events[name] = _.without(@events[name], fn)


module.exports = new Server()
