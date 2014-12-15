routes = require 'routes'

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

    window.addEventListener 'popstate', (e) =>
      setTimeout =>
        pathname = window.location.pathname
        hash = window.location.hash.slice(1)
        path = if @mode is 'pathname' then pathname or hash \
               else hash or pathname
        @go(path)


  setRoot: ($root) =>
    @routesRoot = $root

  add: (path, componentClass) =>
    @router.addRoute path, ->
      return componentClass

  setMode: (mode) =>
    @mode = if mode is 'pathname' and window.history.pushState \
      then 'pathname'
      else 'hash'

  a: =>
    {tagName, props, children} = util.parseZfuncArgs.apply null, arguments

    unless tagName[0] is 'a'
      tagName = 'a' + tagName

    unless props.onclick
      props.onclick = (e) =>
        $el = e.target
        isLocal = $el.hostname is window.location.hostname

        if isLocal
          e.preventDefault()
          @go $el.pathname

    z tagName, props, children

  go: (path) =>

    # default path to current location
    unless path
      pathname = window.location.pathname
      hash = window.location.hash.slice(1)
      path = if @mode is 'pathname' then pathname or hash \
             else hash or pathname

    unless path and @routesRoot and path isnt @currentPath
      return

    route = @router.match(path)

    unless route
      return

    @currentPath = path

    if @mode is 'pathname'
      window.history.pushState null, null, path
    else
      window.location.hash = path

    @emit 'route', path

    componentClass = route.fn()
    renderer.render @routesRoot, new componentClass(route.params)

  on: (name, fn) =>
    (@events[name] = @events[name] or []).push(fn)

  emit: (name) =>
    args = _.rest arguments
    _.map @events[name], (fn) ->
      fn.apply null, args

  off: (name, fn) =>
    @events[name] = _.without(@events[name], fn)


module.exports = new Router()
