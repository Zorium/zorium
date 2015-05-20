_ = require 'lodash'
Qs = require 'qs'
isThunk = require 'virtual-dom/vnode/is-thunk'

z = require './z'
assert = require './assert'
render = require './render'
isSimpleClick = require './is_simple_click'
ev = require './ev'

getCurrentUrl = (mode) ->
  hash = window.location.hash.slice(1)
  pathname = window.location.pathname
  search = window.location.search
  if pathname
    pathname += search

  return if mode is 'pathname' then pathname or hash \
         else hash or pathname

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

class Router
  constructor: ->
    unless window?
      return

    @config = {
      $$root: null
      mode: if window.history?.pushState then 'pathname' else 'hash'
    }

    @currentUrl = null
    @animationRequestId = null
    @middleware = null
    @$lastRoot = null
    @lastDispose = null

    # some browsers erroneously call popstate on intial page load (iOS Safari)
    # We need to ignore that first event.
    # https://code.google.com/p/chromium/issues/detail?id=63040
    window.addEventListener 'popstate', (e) =>
      if @currentUrl
        setTimeout @go

  init: (config) =>
    assert window?, 'config called server-side'
    @config = _.defaults config, @config

  link: (node) =>
    if node.properties.onclick
      throw new Error 'onclick already bound, invalid usage'

    node.properties.onclick = ev (e, $$el) =>
      isLocal = $$el.hostname is window.location.hostname

      if isLocal and isSimpleClick e
        e.preventDefault()
        @go $$el.pathname + $$el.search

    return node

  use: (@middleware) => null

  go: (url, state) =>
    assert window?, 'z.router.go() called server-side'
    assert @config.$$root, 'z.router.go() called without $$root'
    assert @middleware, 'z.router.go() called without middleware'

    url ?= getCurrentUrl(@mode)
    isRedraw = url is @currentUrl
    {pathname, search} = parseUrl url
    query = Qs.parse(search?.slice(1))

    # Batching on requestAnimationFrame
    if @animationRequestId and isRedraw
      return
    else if @animationRequestId
      window.cancelAnimationFrame @animationRequestId
      @animationRequestId = null

    if not isRedraw
      hasRouted = Boolean @currentUrl
      @currentUrl = url

      if @config.mode is 'pathname'
        if hasRouted
          window.history.pushState null, null, url
        else
          window.history.replaceState null, null, url
      else
        window.location.hash = url

      @middleware
        path: pathname
        query: query
        state: state
      ,
        send: _.once ($component) =>
          $component = z $component
          getState = ($component) ->
            if isThunk $component
              $component.child.state
            else
              $component?.state

          if @lastDispose
            @lastDispose.dispose()
            @lastDispose = null

          # FIXME: This does not take into account components in other
          # parts of the full tree (e.g. <head>).
          getState(@$lastRoot)?._unbind_subscriptions()
          @$lastRoot = $component
          getState(@$lastRoot)?._bind_subscriptions()

          @lastDispose = $component.child?.__dirtyStream.subscribe (isDirty) =>
            if isDirty
              @go()

          render @config.$$root, @$lastRoot
    else
      @animationRequestId = window.requestAnimationFrame =>
        @animationRequestId = null
        render @config.$$root, @$lastRoot

router = new Router()
module.exports = {
  init: router.init
  link: router.link
  use: router.use
  go: router.go
}
