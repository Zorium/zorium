routes = require 'routes'
Qs = require 'qs'

z = require './z'
util = require './util'
renderer = require './renderer'

getCurrentPath = (mode) ->
  hash = window.location.hash.slice(1)
  pathname = window.location.pathname
  search = window.location.search
  if pathname
    pathname += search

  return if mode is 'pathname' then pathname or hash \
         else hash or pathname

parseUrl = (url) ->
  a = document.createElement 'a'
  a.href = url

  {
    pathname: a.pathname
    hash: a.hash
    search: a.search
    path: a.pathname + a.search
  }

setPath = (path, mode, isReplacement) ->
  if mode is 'pathname'
    if isReplacement
      window.history.replaceState null, null, path
    else
      window.history.pushState null, null, path
  else
    window.location.hash = path

class Router
  constructor: ->
    @router = new routes()
    @events = {}
    @routesRoot = null
    @mode = if window.history?.pushState then 'pathname' else 'hash'
    @currentPath = null

    # some browsers erroneously call popstate on intial page load (iOS Safari)
    # We need to ignore that first event.
    # https://code.google.com/p/chromium/issues/detail?id=63040
    window.addEventListener 'popstate', (e) =>
      if @currentPath
        setTimeout @go

  setRoot: ($$root) =>
    @routesRoot = $$root

  setMode: (mode) =>
    @mode = mode

  add: (path, cb) =>
    @router.addRoute path, cb

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

  go: (path) =>
    isReplacement = not Boolean @currentPath
    url = parseUrl(path or getCurrentPath(@mode))
    queryParams = Qs.parse(url.search.slice(1))
    route = @router.match(url.pathname)

    # no match found
    if not route or @currentPath is url.path
      return

    setPath url.path, @mode, isReplacement
    @currentPath = url.path
    @emit 'route', url.path

    tree = route.fn({
      params: route.params
      query: queryParams
    })

    renderer.render @routesRoot, tree

  on: (name, fn) =>
    (@events[name] = @events[name] or []).push(fn)

  emit: (name) =>
    args = _.rest arguments
    _.map @events[name], (fn) ->
      fn.apply null, args

  off: (name, fn) =>
    @events[name] = _.without(@events[name], fn)


module.exports = new Router()
