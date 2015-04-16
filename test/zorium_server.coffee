should = require('clay-chai').should()
z = require '../src/zorium'


describe 'router', ->
  it 'creates express middleware', (done) ->
    router = new z.Router()
    router.add '/', ->
      z 'div', 'test'

    middleware = z.routerToMiddleware router
    middleware({url: '/'}, {send: (html) ->
      html.should.be '<!DOCTYPE html><div>test</div>'
      done()
    })

  it 'passes in cookies to routes via express middleware', (done) ->
    router = new z.Router()
    router.add '/', ({cookies}) ->
      z 'div', cookies.foo

    middleware = z.routerToMiddleware router
    middleware({
      url: '/'
      headers:
        cookie: 'foo=bar;'
    }, {send: (html) ->
      html.should.be '<!DOCTYPE html><div>bar</div>'
      done()
    })

  it 'supports redirects', (done) ->
    router = new z.Router()
    router.add '/', ({cookies}) ->
      throw new router.Redirect path: '/login'
      z 'div', cookies.foo

    middleware = z.routerToMiddleware router
    middleware({
      url: '/'
      headers:
        cookie: 'foo=bar;'
    }, {redirect: (path) ->
      path.should.be '/login'
      done()
    })

  it 'supports 404 errors', (done) ->
    status = 200
    router = new z.Router()
    router.add '/', ->
      z 'div', 'test'

    router.add '*', ->
      tree = z 'div', '404'
      throw new router.Error({status: 404, tree})

    middleware = z.routerToMiddleware router
    res = {
      status: (_status) ->
        status = _status
        return res
      send: (html) ->
        html.should.be '<!DOCTYPE html><div>404</div>'
        status.should.be 404
        done()
    }

    middleware({url: '/404'}, res, -> done(new Error 'next()'))

  it 'supports 500 errors', (done) ->
    status = 200
    router = new z.Router()
    router.add '/', ->
      z 'div', 'test'

    router.add '*', ->
      tree = z 'div', '500'
      throw new router.Error({status: 500, tree})

    middleware = z.routerToMiddleware router
    res = {
      status: (_status) ->
        status = _status
        return res
      send: (html) ->
        html.should.be '<!DOCTYPE html><div>500</div>'
        status.should.be 500
        done()
    }

    middleware({url: '/404'}, res, -> done(new Error 'next()'))
