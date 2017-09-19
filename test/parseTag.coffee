b = require 'b-assert'

parseTag = require '../src/parseTag'

describe 'parseTag', ->
  it 'parses class names and ids from tag names, with side-effects', ->
    testTag = (fromTag, fromProps, toTag, toProps) ->
      parsed = parseTag(fromTag, fromProps)
      b parsed, toTag
      b fromProps, toProps

    testTag(null, {}, 'DIV', {})
    testTag('div', {}, 'DIV', {})
    testTag('html', {}, 'HTML', {})
    testTag('.abc', {}, 'DIV', {className: 'abc'})
    testTag('.abc', {className: 'yyy'}, 'DIV', {className: 'abc yyy'})
    testTag('.abc.xxx', {}, 'DIV', {className: 'abc xxx'})
    testTag('html.abc', {}, 'HTML', {className: 'abc'})
    testTag('#one', {}, 'DIV', {id: 'one'})
    testTag('#one', {id: 'nine'}, 'DIV', {id: 'nine'})
    testTag('#one#two', {}, 'DIV', {id: 'two'})
    testTag('#one.abc', {}, 'DIV', {className: 'abc', id: 'one'})
    testTag('.abc#one', {}, 'DIV', {className: 'abc', id: 'one'})
    testTag('span#one.xxx', {}, 'SPAN', {className: 'xxx', id: 'one'})
