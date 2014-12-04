# TODO: make sure vtree isn't being included twice, as it's used by virtual-dom
isVNode = require 'vtree/is-vnode'
isVText = require 'vtree/is-vtext'
isWidget = require 'vtree/is-widget'

isComponent = (x) ->
  _.isObject(x) and _.isFunction x.render

isChild = (x) ->
  isVNode(x) or isVText(x) or isWidget(x) or isComponent(x)

isChildren = (x) ->
  _.isArray(x) or _.isString(x) or _.isNumber(x) or isChild(x)

getTagAttributes = (tagName) ->
  re = /\[([^=\]]+)=?([^\]]+)?\]/g
  match = re.exec tagName
  props = {}

  while match?
    if match[2]
      props[match[1]] = match[2]
    else
      props[match[1]] = true
    match = re.exec tagName

  return props

parseZfuncArgs = (tagName, children...) ->
  props = {}

  # children[0] is props
  if children[0] and not isChildren children[0]
    props = children[0]
    children.shift()

  if children[0] and _.isArray children[0]
    children = children[0]

  if _.isArray tagName
    return {tagName: null, props, children: tagName}

  return {tagName, props, children}

module.exports = {
  isComponent
  getTagAttributes
  parseZfuncArgs
}
