routes = require 'routes'

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

  add: (path, cb) =>
    @router.addRoute path, cb

  match: (pathname) ->
    @router.match(pathname)

module.exports = Router
