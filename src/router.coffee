_ = require 'lodash'

z = require './z'
assert = require './assert'
render = require './render'
StateFactory = require './state_factory'
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

class Router
  constructor: ->
    # coffeelint: disable=missing_fat_arrows
    @Redirect = ({path}) ->
      @name = 'redirect'
      @path = path
      @message = "Redirect to #{path}"
      @stack = (new Error()).stack
    @Redirect.prototype = new Error()
    # coffeelint: enable=missing_fat_arrows

    unless window?
      return

    @events = {}
    @$$root = null
    @mode = if window?.history?.pushState then 'pathname' else 'hash'
    @currentPath = null
    @isRedrawScheduled = false
    @animationRequestId = null
    @$root = null

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

  config: ({mode, $root, $$root}) =>
    assert window?, 'config called server-side'

    @mode = mode or @mode
    @$root = $root or @$root
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

  go: (path) =>
    assert window?, 'z.router.go() called server-side'

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

    renderOrRedirect = (props) =>
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

    if not isRedraw
      @currentPath = path
      setPath path, @mode, hasRouted
      @emit 'go', {path}
      renderOrRedirect(props)
    else
      @isRedrawScheduled = true
      @animationRequestId = window.requestAnimationFrame =>
        @isRedrawScheduled = false
        renderOrRedirect(props)

  on: (name, fn) =>
    assert window?, 'z.router.on() called server-side'

    (@events[name] = @events[name] or []).push(fn)

  emit: (name) =>
    args = _.rest arguments
    _.map @events[name], (fn) ->
      fn.apply null, args

  off: (name, fn) =>
    assert window?, 'z.router.off() called server-side'

    @events[name] = _.without(@events[name], fn)

router = new Router()
module.exports = {
  off: router.off
  on: router.on
  go: router.go
  link: router.link
  config: router.config
  Redirect: router.Redirect
}
