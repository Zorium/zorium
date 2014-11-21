# Bind polyfill (phantomjs doesn't support bind)
# coffeelint: disable=missing_fat_arrows
unless Function::bind
  Function::bind = (oThis) ->

    # closest thing possible to the ECMAScript 5
    # internal IsCallable function
    throw new TypeError(
      'Function.prototype.bind - what is trying to be bound is not callable'
    ) if typeof this isnt 'function'
    aArgs = Array::slice.call(arguments, 1)
    fToBind = this
    fNOP = -> null

    fBound = ->
      fToBind.apply(
        (if this instanceof fNOP and oThis then this else oThis),
        aArgs.concat(Array::slice.call(arguments))
      )

    fNOP:: = @prototype
    fBound:: = new fNOP()
    fBound
# coffeelint: enable=missing_fat_arrows

_ = require 'lodash'
h = require 'virtual-dom/h'
diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
createElement = require 'virtual-dom/create-element'

# TODO: make sure vtree isn't being included twice, as it's used by virtual-dom
isVNode = require 'vtree/is-vnode'
isVText = require 'vtree/is-vtext'
isWidget = require 'vtree/is-widget'

renderedComponents = []

isComponent = (x) ->
  _.isObject(x) and _.isFunction x.render

isChild = (x) ->
  isVNode(x) or isVText(x) or isWidget(x) or isComponent(x)

isChildren = (x) ->
  _.isArray(x) or _.isString(x) or isChild(x)

getAttributes = (tagName) ->
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

renderChild = (child) ->
  if isComponent child
    tree = child.render()

    unless tree
      tree = z 'div'

    if _.isArray tree
      tree = z 'div', tree

    if not child.zorium_hasBeenMounted and _.isFunction child.onMount
      class OnMountHook
        hook: ($el, propName) ->
          setTimeout ->
            child.onMount $el

      child.zorium_hasBeenMounted = true
      tree.properties['ev-zorium-onmount'] = new OnMountHook()

    if _.isFunction child.onBeforeUnmount
      renderedComponents.push child
    return tree

  return child

# coffeelint: disable=missing_fat_arrows
onAnchorClick = (e) ->
  isLocal = @hostname is window.location.hostname

  if isLocal
    e.preventDefault()
    z.router?.go @pathname
# coffeelint: enable=missing_fat_arrows

z = (tagName, children...) ->
  if _.isArray tagName
    return z 'div', tagName

  # Default tag to div
  if tagName[0] is '.'
    tagName = 'div' + tagName

  tag = tagName.match(/(^[^.\[]+)/)[1]

  # Extract shortcut attributes
  attributes = getAttributes tagName

  # Remove attribute declarations from tagName
  tagName = tagName.replace /\[[^\[]+\]/g, ''
  props = {attributes}

  # use router for relative anchor tags by default
  if tag is 'a'
    props.onclick = onAnchorClick


  if children[0] and not isChildren children[0]
    props = _.merge props, children[0]

    # remove props from child list
    children.shift()

    # children may be passed as array
    children = if _.isArray children[0] then children[0] else children

    return h tagName, props, _.map _.filter(children), renderChild

  if children[0] and _.isArray children[0]
    children = children[0]

  return h tagName, props, _.map _.filter(children), renderChild

registeredRoots = {}
z.render = do ->
  id = 0

  nextRootId = ->
    id += 1

  return ($root, tree) ->
    renderedComponents = []

    renderedTree = renderChild tree

    if $root._zoriumId
      root = registeredRoots[$root._zoriumId]

      lastRendered = root.lastRendered

      for component in lastRendered
        unless component in renderedComponents
          component.onBeforeUnmount()
          component.zorium_hasBeenMounted = false

      root.lastRendered = renderedComponents

      patches = diff root.renderedTree, renderedTree
      root.node = patch root.node, patches
      root.tree = tree
      root.renderedTree = renderedTree


      return $root

    $el = createElement renderedTree

    id = nextRootId()
    $root._zoriumId = id
    registeredRoots[id] =
      $root: $root
      node: $el
      tree: tree
      renderedTree: renderedTree
      lastRendered: renderedComponents

    $root.appendChild $el

    renderedComponents = []
    return $root

z.redraw = ->
  for id, root of registeredRoots
    z.render root.$root, root.tree

router = new (require 'routes')()
class ZoriumRouter
  constructor: ->
    @routesRoot = null
    @mode = 'hash'
    window.addEventListener 'popstate', (e) => @go()

  setRoot: ($root) =>
    @routesRoot = $root

  add: (path, componentClass) ->
    router.addRoute path, ->
      return componentClass

  setMode: (mode) =>
    @mode = if mode is 'pathname' and window.history.pushState \
      then 'pathname'
      else 'hash'

  go: (path) =>
    unless @routesRoot
      return

    if path
      if @mode is 'pathname'
        window.history.pushState null, null, path
      else
        window.location.hash = path

      route = router.match(path)
      unless route
        return

      componentClass = route.fn()
      z.render @routesRoot, new componentClass(route.params)

    else
      pathname = window.location.pathname
      hash = window.location.hash.slice(1)
      path = if @mode is 'pathname' then pathname or hash \
              else hash or pathname

      route = router.match(path)
      unless route
        return
      componentClass = route.fn()

      z.render @routesRoot, new componentClass(route.params)


z.router = new ZoriumRouter()

module.exports = z
