b = require 'b-assert'

z = require '../src/zorium'
bind = require '../src/bind'
util = require './util'

describe 'bind()', ->
  it 'binds, basic', ->
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
    b root.isEqualNode(util.htmlToNode(result1))
    bind root, new App2()
    b root.isEqualNode(util.htmlToNode(result2))

  it 'binds state', ->
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
    b root.isEqualNode(util.htmlToNode(result1))
    subject.onNext 'xyz'
    b root.isEqualNode(util.htmlToNode(result2))

  it 'binds nested state', ->
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
    b root.isEqualNode(util.htmlToNode(result1))
    subject1.onNext 'xyz'
    b root.isEqualNode(util.htmlToNode(result2))
    subject2.onNext 'yyy'
    b root.isEqualNode(util.htmlToNode(result3))

  # FIXME: maybe this shouldn't work?
  # it.only 'binds prerendered component', ->
  #   subject = new Rx.BehaviorSubject('abc')
  #
  #   class Root
  #     constructor: ->
  #       @child = z new Child(), {sub: 'xxx'}
  #     render: =>
  #       z 'div', @child
  #
  #   class Child
  #     constructor: ->
  #       @state = z.state
  #         subject: subject
  #     render: ({sub}) =>
  #       z 'div',
  #         "#{@state.getValue().subject} - #{sub}"
  #
  #   root = document.createElement 'div'
  #   result1 = '<div><div>abc - xxx</div></div>'
  #   result2 = '<div><div>xyz - xxx</div></div>'
  #
  #   bind root, new Root()
  #   console.log root
  #   b root.isEqualNode(util.htmlToNode(result1))
  #   subject.onNext 'xyz'
  #   console.log root
  #   b root.isEqualNode(util.htmlToNode(result2))

# FIXME
# watch = require '../src/watch'
# describe 'watch', ->
#   it 'watches a single node', (done) ->
#     subject = new Rx.BehaviorSubject(null)
#
#     class Root
#       constructor: ->
#         @state = z.state
#           subject: subject
#       render: ->
#         z 'div', 'Hello World'
#
#     cnt = 0
#     watch(new Root()).subscribe (tree) ->
#       cnt += 1
#       if cnt is 2
#         $el = createElement(tree)
#         result = '<div>Hello World</div>'
#         $el.isEqualNode(util.htmlToNode(result)).should.be true
#
#         done()
#       else
#         subject.onNext 'xxx'
#
#   it 'watches a child node', (done) ->
#     subject = new Rx.BehaviorSubject(null)
#
#     class Child
#       constructor: ->
#         @state = z.state
#           subject: subject
#       render: ->
#         z 'div', 'child'
#
#     class Root
#       constructor: ->
#         @$child = new Child()
#       render: =>
#         z 'div',
#           z 'span',
#             @$child
#
#     cnt = 0
#     watch(new Root()).subscribe (tree) ->
#       cnt += 1
#       if cnt is 2
#         $el = createElement(tree)
#         result = '<div><span><div>child</span></div></div>'
#         $el.isEqualNode(util.htmlToNode(result)).should.be true
#         done()
#       else
#         subject.onNext 'xxx'
#
#   it 'passes props', (done) ->
#     subject = new Rx.BehaviorSubject(null)
#
#     class Child
#       constructor: ->
#         @state = z.state
#           subject: subject
#       render: ({x} = {}) ->
#         x.should.be 'x'
#         z 'div', 'child'
#
#     class Root
#       constructor: ->
#         @$child = new Child()
#       render: =>
#         z 'div',
#           z 'span',
#             z @$child, {x: 'x'}
#
#     cnt = 0
#     watch(new Root()).subscribe (tree) ->
#       cnt += 1
#       if cnt is 2
#         done()
#       else
#         subject.onNext 'xxx'
#
#   it 'watches a multiple deep children', (done) ->
#     subject1 = new Rx.BehaviorSubject(null)
#     subject2 = new Rx.BehaviorSubject(null)
#
#     class Level2A
#       constructor: ->
#         @state = z.state
#           subject: subject1
#       render: ->
#         z 'div', 'level2'
#
#     class Level2B
#       constructor: ->
#         @state = z.state
#           subject: subject2
#       render: ->
#         z 'div', 'level2'
#
#     class Level1
#       constructor: ->
#         @level2a = new Level2A()
#         @level2b = new Level2B()
#       render: =>
#         z 'div',
#           z 'span',
#             @level2a
#           z 'span',
#             @level2b
#
#     class Root
#       constructor: ->
#         @level1 = new Level1()
#       render: =>
#         z 'div',
#           z 'span',
#             @level1
#
#     cnt = 0
#     watch(new Root()).subscribe ->
#       cnt += 1
#       if cnt is 3
#         done()
#       else if cnt is 1
#         subject1.onNext 'xxx'
#       else
#         subject2.onNext 'yyy'
#
#   it 'watches deep mutating tree', (done) ->
#     subject1 = new Rx.BehaviorSubject(null)
#     subject2 = new Rx.BehaviorSubject(null)
#     subject3 = new Rx.BehaviorSubject(null)
#     subject4 = new Rx.BehaviorSubject(null)
#
#     isStage2 = false
#     isStage3 = false
#     hasLevel2BRendered = false
#
#     class Level2A
#       constructor: ->
#         @state = z.state
#           subject: subject1
#       render: ->
#         z 'div', 'level2a'
#
#     class Level2B
#       constructor: ->
#         @state = z.state
#           subject: subject2
#       render: ->
#         hasLevel2BRendered = true
#         z 'div', 'level2b'
#
#     class Level1
#       constructor: ->
#         @level2a = new Level2A()
#         @level2b = new Level2B()
#         @state = z.state
#           subject: subject3
#       render: =>
#         z 'div',
#           z 'span',
#             if isStage2
#               @level2b
#             else
#               @level2a
#
#     class Root
#       constructor: ->
#         @level1 = new Level1()
#         @state = z.state
#           subject: subject4
#       render: =>
#         z 'div',
#           z 'span',
#             unless isStage3
#               @level1
#
#     cnt = 0
#     watch(new Root()).subscribe (tree) ->
#       cnt += 1
#       if cnt is 1
#         $el = createElement(tree)
#         result = '<div><span>' +
#           '<div><span>' +
#             '<div>level2a</div>' +
#           '</span></div>' +
#         '</span></div>'
#         $el.isEqualNode(util.htmlToNode(result)).should.be true
#         # noop
#         subject2.onNext 'xxxx'
#         subject2.onNext 'xxxx'
#         setTimeout ->
#           subject1.onNext 'y'
#         , 5
#       if cnt is 2
#         isStage2 = true
#         hasLevel2BRendered.should.be false
#         setTimeout ->
#           subject3.onNext 'yyy'
#         , 5
#       if cnt is 3
#         $el = createElement(tree)
#         result = '<div><span>' +
#           '<div><span>' +
#             '<div>level2b</div>' +
#           '</span></div>' +
#         '</span></div>'
#         $el.isEqualNode(util.htmlToNode(result)).should.be true
#         hasLevel2BRendered.should.be true
#         # noop
#         subject1.onNext 'zzz'
#         subject1.onNext 'zzz'
#         setTimeout ->
#           isStage3 = true
#           subject4.onNext '333'
#         , 5
#       if cnt is 4
#         $el = createElement(tree)
#         result = '<div><span></span></div>'
#         $el.isEqualNode(util.htmlToNode(result)).should.be true
#         subject1.onNext '111'
#         subject2.onNext '222'
#         subject3.onNext '333'
#         setTimeout ->
#           done()
#         , 5
#
#       if cnt > 4
#         done new Error 'too many updates'
