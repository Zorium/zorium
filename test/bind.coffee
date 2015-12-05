b = require 'b-assert'

z = require '../src/zorium'
bind = require '../src/bind'
util = require './util'

# TODO: performance tests on large trees
describe 'bind()', ->
  it 'binds, basic', (done) ->
    class App
      render: ->
        z 'div', 'Hello World'

    class App2
      render: ->
        z 'div', 'XXXX'

    root = document.createElement 'div'

    result1 = '<div>Hello World</div>'
    result2 = '<div>XXXX</div>'

    bind root, new App()
    setTimeout -> # TODO: investigate race
      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result1))
        bind root, new App2()

        setTimeout -> # TODO: investigate race
          window.requestAnimationFrame ->
            b root.isEqualNode(util.htmlToNode(result2))
            done()

  it 'binds state', (done) ->
    subject = new Rx.BehaviorSubject('abc')

    class Root
      constructor: ->
        @state = z.state
          subject: subject
      render: =>
        z 'div', @state.getValue().subject

    root = document.createElement 'div'
    result1 = '<div>abc</div>'
    result2 = '<div>xyz</div>'

    bind root, new Root()
    window.requestAnimationFrame ->
      b root.isEqualNode(util.htmlToNode(result1))
      subject.onNext 'xyz'

      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

  it 'passes props', (done) ->
    subject = new Rx.BehaviorSubject(null)

    class Child
      constructor: ->
        @state = z.state
          subject: subject
      render: ({x} = {}) =>
        z 'div', "#{@state.getValue().subject} - #{x}"

    class Root
      constructor: ->
        @$child = new Child()
      render: =>
        z 'div',
          z 'span',
            z @$child, {x: 'x'}

    root = document.createElement 'div'

    result1 = '<div><span><div>null - x</div></span></div>'
    result2 = '<div><span><div>xxx - x</div></span></div>'

    bind root, new Root()
    window.requestAnimationFrame ->
      b root.isEqualNode(util.htmlToNode(result1))
      subject.onNext 'xxx'

      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

  it 'binds nested state', (done) ->
    subject1 = new Rx.BehaviorSubject('abc')
    subject2 = new Rx.BehaviorSubject('xxx')

    class Root
      constructor: ->
        @child = new Child()
      render: =>
        z 'div', @child

    class Child
      constructor: ->
        @grandChild = new GrandChild()
        @state = z.state
          subject: subject1
      render: =>
        z 'div',
          "#{@state.getValue().subject}"
          @grandChild

    class GrandChild
      constructor: ->
        @state = z.state
          subject: subject2
      render: =>
        z 'div', "#{@state.getValue().subject}"

    root = document.createElement 'div'
    result1 = '<div><div>abc<div>xxx</div></div></div>'
    result2 = '<div><div>xyz<div>xxx</div></div></div>'
    result3 = '<div><div>xyz<div>yyy</div></div></div>'

    bind root, new Root()
    window.requestAnimationFrame ->
      b root.isEqualNode(util.htmlToNode(result1))
      subject1.onNext 'xyz'

      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result2))
        subject2.onNext 'yyy'

        window.requestAnimationFrame ->
          b root.isEqualNode(util.htmlToNode(result3))
          done()

  it 'binds prerendered component', (done) ->
    subject = new Rx.BehaviorSubject('abc')

    class Root
      constructor: ->
        @child = z new Child(), {sub: 'xxx'}
      render: =>
        z 'div', @child

    class Child
      constructor: ->
        @state = z.state
          subject: subject
      render: ({sub}) =>
        z 'div',
          "#{@state.getValue().subject} - #{sub}"

    root = document.createElement 'div'
    result1 = '<div><div>abc - xxx</div></div>'
    result2 = '<div><div>xyz - xxx</div></div>'

    bind root, new Root()
    window.requestAnimationFrame ->
      b root.isEqualNode(util.htmlToNode(result1))
      subject.onNext 'xyz'

      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result2))
        done()

  it 'binds new child', (done) ->
    subject1 = new Rx.BehaviorSubject(null)
    subject2 = new Rx.BehaviorSubject('2')

    class Root
      constructor: ->
        @child = new Child()
        @state = z.state
          subject: subject1
      render: =>
        z 'div',
          if @state.getValue().subject?
            @child

    class Child
      constructor: ->
        @state = z.state
          subject: subject2
      render: =>
        z 'div', "#{@state.getValue().subject}"

    root = document.createElement 'div'
    result1 = '<div></div>'
    result2 = '<div><div>2</div></div>'
    result3 = '<div><div>3</div></div>'

    bind root, new Root()
    window.requestAnimationFrame ->
      b root.isEqualNode(util.htmlToNode(result1))
      subject1.onNext true

      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result2))
        subject2.onNext '3'

        setTimeout ->
          window.requestAnimationFrame ->
            b root.isEqualNode(util.htmlToNode(result3))
            done()

  # TODO: this test is perhaps a bit superfluous
  it 'binds a deep mutating tree', (done) ->
    subject1 = new Rx.BehaviorSubject('1')
    subject2 = new Rx.BehaviorSubject('2')
    subject3 = new Rx.BehaviorSubject('3')
    subject4 = new Rx.BehaviorSubject('4')

    class Node
      constructor: ({subject, @children}) ->
        @state = z.state
          subject: subject
      render: =>
        z 'div',
          ["#{@state.getValue().subject}"].concat @children


    d = new Node({subject: subject4})
    c = new Node({subject: subject3, children: [d]})
    bb = new Node({subject: subject2})
    topChildren = [c, bb]
    a = new Node({subject: subject1, children: topChildren})

    root = document.createElement 'div'
    result1 = '<div>1<div>3<div>4</div></div><div>2</div></div>'
    result2 = '<div>one<div>3<div>4</div></div><div>2</div></div>'
    result3 = '<div>one<div>3<div>4</div></div><div>two</div></div>'
    result4 = '<div>one<div>three<div>4</div></div><div>two</div></div>'
    result5 = '<div>one<div>three<div>four</div></div><div>two</div></div>'
    result6 = '<div>xxx<div>three<div>four</div</div></div>'

    bind root, a, true
    window.requestAnimationFrame ->
      b root.isEqualNode(util.htmlToNode(result1))
      subject1.onNext 'one'

      window.requestAnimationFrame ->
        b root.isEqualNode(util.htmlToNode(result2))
        subject2.onNext 'two'

        window.requestAnimationFrame ->
          b root.isEqualNode(util.htmlToNode(result3))
          subject3.onNext 'three'

          window.requestAnimationFrame ->
            b root.isEqualNode(util.htmlToNode(result4))
            subject4.onNext 'four'

            window.requestAnimationFrame ->
              b root.isEqualNode(util.htmlToNode(result5))
              topChildren.pop()
              subject1.onNext 'xxx'

              window.requestAnimationFrame ->
                b root.isEqualNode(util.htmlToNode(result6))
                done()
