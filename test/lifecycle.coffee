b = require 'b-assert'

z = require '../src/zorium'

describe 'Lifecycle Callbacks', ->
  describe 'afterMount', ->
    it 'gets called after initial load', (done) ->
      mountCalled = 0
      class BindComponent
        afterMount: ($el) ->
          b $el?
          mountCalled += 1
        render: ->
          z 'div', 'xxx'

      bind = new BindComponent()
      root = document.createElement 'div'

      z.render root, bind
      setTimeout ->
        b mountCalled, 1
        done()
      , 20

    # https://github.com/claydotio/zorium.js/issues/5
    it 'is only called once on first render', (done) ->
      mountCalled = 0

      class BindComponent
        afterMount: ($el) ->
          b $el?
          mountCalled += 1
        render: ->
          z 'div'

      bind = new BindComponent()

      dom = z 'div',
        bind
        z 'span', 'hello'


      root = document.createElement 'div'
      z.render root, dom

      setTimeout ->
        z.render root, dom

        setTimeout ->
          z.render root, dom

          dom = z 'div',
            bind
            z 'span', 'world'
          z.render root, dom

          setTimeout ->
            z.render root, dom

            setTimeout ->
              b mountCalled, 1
              done()

            , 10
          , 20
        , 20
      , 20

  describe 'beforeUnmount', ->
    it 'gets called before removal from DOM', (done) ->
      class BindComponent
        beforeUnmount: ->
          done()
        render: ->
          z 'div'

      class ContainerComponent
        constructor: ->
          @removed = false
          @bind = new BindComponent()
        render: =>
          z 'div',
            unless @removed then @bind else 'hello'
        removeChild: =>
          @removed = true

      container = new ContainerComponent()
      root = document.createElement 'div'
      z.render root, container
      setTimeout ->
        z.render root, z 'div'
      , 20

    it 'gets called after mounting only', (done) ->
      unmountCalled = 0
      mountCalled = 0
      class BindComponent
        afterMount: ->
          mountCalled += 1
        beforeUnmount: ->
          unmountCalled += 1
        render: ->
          z 'div',
            z 'span', 'Hello World'
            z 'span', 'Goodbye'

      bind = new BindComponent()

      root = document.createElement 'div'
      z.render root, bind

      setTimeout ->
        b mountCalled, 1
        b unmountCalled, 0
        z.render root, z 'div'
        z.render root, bind

        setTimeout ->
          b unmountCalled, 1
          done()
      , 20

    it 'remounts after unmounting', (done) ->
      unmountCalled = 0
      mountCalled = 0
      class BindComponent
        afterMount: ->
          mountCalled += 1
        beforeUnmount: ->
          unmountCalled += 1
        render: ->
          z 'div'

      bind = new BindComponent()
      root = document.createElement 'div'
      z.render root, bind

      setTimeout ->
        b mountCalled, 1
        z.render root, z 'div'

        setTimeout ->
          b unmountCalled, 1
          z.render root, bind

          setTimeout ->
            b mountCalled, 2
            done()

    it 'only doesn\'t get called if not unmounted', (done) ->
      unmountCalled = 0
      mountCalled = 0
      class BindComponent
        afterMount: ->
          mountCalled += 1
        beforeUnmount: ->
          unmountCalled += 1
        render: ->
          z 'div',
            z 'span', 'Hello World'
            z 'span', 'Goodbye'

      bind = new BindComponent()

      root = document.createElement 'div'
      z.render root, bind
      window.requestAnimationFrame ->
        z.render root, bind
        window.requestAnimationFrame ->
          z.render root, bind
          window.requestAnimationFrame ->
            z.render root, bind

            setTimeout ->
              b mountCalled, 1
              b unmountCalled, 0
              done()
            , 20

    # https://github.com/claydotio/zorium/issues/13
    it 'property replacing diff calls unhook method', (done) ->
      unmountsCalled = 0

      class A
        beforeUnmount: ->
          unmountsCalled += 1
        render: ->
          z 'div', 'x'

      class B
        beforeUnmount: ->
          unmountsCalled += 1
        render: ->
          z 'div', 'x'

      $a = new A()
      $b = new B()

      root = document.createElement 'div'

      z.render root, $a
      setTimeout ->
        z.render root, $b

        setTimeout ->
          z.render root, z 'x'

          setTimeout ->
            b unmountsCalled, 2
            done()
