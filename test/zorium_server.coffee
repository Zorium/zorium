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
