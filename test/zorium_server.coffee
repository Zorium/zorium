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
