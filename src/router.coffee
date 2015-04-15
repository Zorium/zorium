routes = require 'routes'
Qs = require 'qs'

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
    @router = new routes()

    # coffeelint: disable=missing_fat_arrows
    @Redirect = (path) ->
      @name = 'redirect'
      @path = path
      @message = "Redirecting to #{path}"
      @stack = (new Error()).stack
    @Redirect.prototype = new Error()
    # coffeelint: enable=missing_fat_arrows

  add: (path, cb) =>
    @router.addRoute path, cb

  resolve: ({path, cookies}) ->
    url = parseUrl path
    queryParams = Qs.parse(url.search?.slice(1))
    route = @router.match(url.pathname)

    # no match found
    unless route
      return null

    return route.fn({
      params: route.params
      query: queryParams
      cookies
    })


module.exports = Router
