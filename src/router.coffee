routes = require 'routes'
Qs = require 'qs'

parseUrl = (url) ->
  a = document.createElement 'a'
  a.href = url

  {
    pathname: a.pathname
    hash: a.hash
    search: a.search
    path: a.pathname + a.search
  }

class Router
  constructor: ->
    @router = new routes()

  add: (path, cb) =>
    @router.addRoute path, cb

  resolve: ({path}) ->
    url = parseUrl path
    queryParams = Qs.parse(url.search.slice(1))
    route = @router.match(url.pathname)

    # no match found
    unless route
      return null

    return route.fn({
      params: route.params
      query: queryParams
    })


module.exports = Router
