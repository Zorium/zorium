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
h = require 'virtual-hyperscript'
diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
createElement = require 'virtual-dom/create-element'
routes = require 'routes'
observe = require './observe'

util = require './util'

router = new routes()
renderedComponents = []
registeredRoots = {}

z = ->
  {tagName, props, children} = util.parseZfuncArgs.apply null, arguments

  if _.isNull tagName
    return z 'div', children

  # Default tag to div
  unless /[a-zA-Z]/.test tagName[0]
    tagName = 'div' + tagName

  tag = tagName.match(/(^[^.\[]+)/)[1]

  # Extract shortcut attributes
  attributes = util.getTagAttributes tagName
  props = _.merge props, {attributes}

  # Remove attribute declarations from tagName
  tagName = tagName.replace /\[[^\[]+\]/g, ''

  return h tagName, props, _.map _.filter(children), renderChild

z.observe = observe
z.state = (obj) ->
  observed = observe obj

  _set = observed.set.bind observed
  observed.set = (diff) ->
    _set _.defaults diff, observed()

  return observed

renderChild = (child) ->
  if util.isComponent child
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

    if not child.zorium_isWatchingState and _.isFunction child.state
      child.state ->
        z.redraw()

      child.zorium_isWatchingState = true

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

  a: ->
    {tagName, props, children} = util.parseZfuncArgs.apply null, arguments

    unless tagName[0] is 'a'
      tagName = 'a' + tagName

    unless props.onclick
      props.onclick = onAnchorClick

    z tagName, props, children

  go: (path) =>
    unless @routesRoot
      return

    if path
      if @mode is 'pathname'
        window.history.pushState null, null, path
      else
        window.location.hash = path
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
