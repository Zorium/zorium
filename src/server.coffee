routes = require 'routes'
Qs = require 'qs'
cookie = require 'cookie'

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

class Server
  constructor: ->
    @events = {}
    @root = null
    @router = null
    @mode = if window?.history?.pushState then 'pathname' else 'hash'
    @currentPath = null

    if window?
      # used for full-page rendering
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

  go: (path) =>
    path ?= getCurrentPath(@mode)
    isReplacement = not Boolean @currentPath
    url = parseUrl(path)
    cookies = cookie.parse document.cookie or ''

    unless @router
      return

    try
      tree = @router.resolve {path, cookies}
    catch err
      if err instanceof @router.Redirect
        return @go err.path
      else throw err

    # no match found
    unless tree
      return

    setPath url.path, @mode, isReplacement
    @currentPath = url.path
    @emit 'route', url.path

    # Because the DOM doesn't let us directly manipulate top-level elements
    # We have to standardize a hack around it
    if @root is document
      unless tree?.tagName is 'HTML'
        throw new Error 'Invalid HTML base element'

      head = tree.children[0]
      body = tree.children[1]
      title = head?.children[0]
      appRoot = body?.children[0]

      unless head?.tagName is 'HEAD' and title?.tagName is 'TITLE'
        throw new Error 'Invalid HEAD base element'

      unless body?.tagName is 'BODY' and appRoot.properties.id is 'zorium-root'
        throw new Error 'Invalid BODY base element'

      document.title = title.children[0].text
      renderer.render @globalRoot, appRoot
    else
      renderer.render @root, tree

  on: (name, fn) =>
    (@events[name] = @events[name] or []).push(fn)

  emit: (name) =>
    args = _.rest arguments
    _.map @events[name], (fn) ->
      fn.apply null, args

  off: (name, fn) =>
    @events[name] = _.without(@events[name], fn)


module.exports = new Server()
