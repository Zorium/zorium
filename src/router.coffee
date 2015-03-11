routes = require 'routes'
Qs = require 'qs'

z = require './z'
util = require './util'
renderer = require './renderer'

class Router
  constructor: ->
    @router = new routes()
    @events = {}
    @routesRoot = null
    @mode = 'hash'
    @currentPath = null
    @currentHash = '' # only valid when using pathname
    @currentSearch = ''

    # some browsers erroneously call popstate on intial page load (iOS Safari)
    # We need to ignore that first event.
    # https://code.google.com/p/chromium/issues/detail?id=63040
    window.addEventListener 'popstate', (e) =>
      if @currentPath
        setTimeout @go


  setRoot: ($root) =>
    @routesRoot = $root

  add: (path, componentClass, pathTransformFn = ((path) -> path)) =>
    @router.addRoute path, ->
      return [componentClass, pathTransformFn]

  setMode: (mode) =>
    @mode = if mode is 'pathname' and window.history.pushState \
      then 'pathname'
      else 'hash'

  link: (node) =>
    if node.properties.onclick
      throw new Error 'onclick already bound, invalid usage'

    node.properties.onclick = do =>
      router = this
      mode = @mode
      # coffeelint: disable=missing_fat_arrows
      (e) ->
        $el = this
        isLocal = $el.hostname is window.location.hostname

        if isLocal
          e.preventDefault()
          router.go $el.pathname + $el.search + $el.hash
      # coffeelint: enable=missing_fat_arrows

    return node

  setUrl: (url) =>
    hasRouted = @currentPath
    @currentPath = url.pathname
    @currentHash = url.hash
    @currentSearch = url.search

    if @mode is 'pathname'
      if hasRouted
        window.history.pushState null, null, url.pathname + url.search
      else
        window.history.replaceState null, null, url.pathname + url.search
    else
      window.location.hash = url.pathname + url.search

    @emit 'route', url.pathname

  getCurrentPath: =>
    hash = window.location.hash.slice(1)
    pathname = window.location.pathname
    search = window.location.search
    if pathname
      pathname += search
      pathname += '#' + hash

    return if @mode is 'pathname' then pathname or hash \
           else hash or pathname

  parseUrl: (url) ->
    a = document.createElement 'a'
    a.href = url

    {
      pathname: a.pathname
      hash: a.hash
      search: a.search
    }

  hasPathChanged: (path) ->
    path and @routesRoot and path isnt @currentPath

  hasSearchChanged: (search) ->
    search isnt @currentSearch

  # TODO: fix cyclomatic complexity
  go: (path) =>
    # default path to current location
    unless path
      path = @getCurrentPath()

    url = @parseUrl path
    path = url.pathname
    queryParams = Qs.parse(url.search.slice(1))

    unless @hasPathChanged(path) or @hasSearchChanged(url.search)
      if url.hash isnt @currentHash and @mode is 'pathname'
        @currentHash = url.hash
        window.location.hash = url.hash
      return

    route = @router.match(path)

    unless route
      return

    [componentClass, pathTransformFn] = route.fn()

    transformedPath = pathTransformFn(path)

    enter = (transformedPath) =>
      if transformedPath isnt path
        @go transformedPath
      else
        isHashDifferent = @currentHash isnt url.hash
        @setUrl url
        renderer.render @routesRoot,
          new componentClass(route.params, queryParams)
        if @mode is 'pathname' and isHashDifferent
          window.location.hash = url.hash

    if _.isFunction transformedPath?.then
      transformedPath.then enter
      # It is a mistake to pass a rejected promise
      .catch (err) ->
        setTimeout ->
          throw err
    else
      enter(transformedPath)

  on: (name, fn) =>
    (@events[name] = @events[name] or []).push(fn)

  emit: (name) =>
    args = _.rest arguments
    _.map @events[name], (fn) ->
      fn.apply null, args

  off: (name, fn) =>
    @events[name] = _.without(@events[name], fn)


module.exports = new Router()
