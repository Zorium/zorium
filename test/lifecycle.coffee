b = require 'b-assert'

{z, render, useEffect} = require '../src'

it = if window? then global.it else (-> null)

describe 'Lifecycle Callbacks', ->
  describe 'useEffect', ->
    it 'gets called after initial load', (done) ->
      mountCalled = 0
      BindComponent = ->
        useEffect ->
          mountCalled += 1

        z 'div', 'xxx'

      root = document.createElement 'div'

      render BindComponent, root
      setTimeout ->
        b mountCalled, 1
        done()
      , 20

    # https://github.com/claydotio/zorium.js/issues/5
    it 'is only called once on first render', (done) ->
      mountCalled = 0

      BindComponent = ->
        useEffect ->
          mountCalled += 1

        z 'div'

      dom = z 'div',
        BindComponent
        z 'span', 'hello'


      root = document.createElement 'div'
      render dom, root

      setTimeout ->
        render dom, root

        setTimeout ->
          b mountCalled, 1
          done()
        , 10
      , 20

  describe 'useEffect (callback)', ->
    # TODO: check the DOM
    it 'gets called before removal from DOM', (done) ->
      BindComponent = ->
        useEffect ->
          return done

        z 'div'

      ContainerComponent = ->
        z 'div', BindComponent

      root = document.createElement 'div'
      render ContainerComponent, root
      setTimeout ->
        render z('div'), root
      , 20

    # https://github.com/claydotio/zorium/issues/13
    it 'property replacing diff calls unhook method', (done) ->
      unmountsCalled = 0

      A = ->
        useEffect ->
          ->
            unmountsCalled += 1
        z 'div', 'x'

      B = ->
        useEffect ->
          ->
            unmountsCalled += 1
        z 'div', 'x'

      root = document.createElement 'div'

      render A, root
      window.requestAnimationFrame ->
        render B, root

        window.requestAnimationFrame ->
          render z('x'), root

          window.requestAnimationFrame ->
            b unmountsCalled, 2
            done()
