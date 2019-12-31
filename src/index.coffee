_ = require 'lodash'

State = require './state'
dyo = require 'dyo'
parseTag = require './parse_tag'
{
  h, useMemo, Context, useContext, useState,
  useResource, useLayout, Suspense, render
} = dyo

DEFAULT_TIMEOUT_MS = 250

z = (tagName, props, children...) ->
  unless _.isPlainObject(props)
    if props?
      children = [props].concat children
    props = {}

  if _.isArray children[0]
    children = children[0]

  if _.isString tagName
    tagName = parseTag tagName, props

  h tagName, props, children

RootContext = ({shouldSuspend, awaitStable, children}) ->
  z Context, {value: {shouldSuspend, awaitStable}}, children

module.exports = _.defaults {
  z

  Boundary: ({children, fallback}) ->
    z dyo.Boundary,
      fallback: (err) ->
        fallback err.message
      children

  classKebab: (classes) ->
    _.map _.keys(_.pickBy classes, _.identity), _.kebabCase
    .join ' '

  isSimpleClick: (e) ->
    not (e.which > 1 or e.shiftKey or e.altKey or e.metaKey or e.ctrlKey)

  useStream: (cb) ->
    {awaitStable, shouldSuspend} = useContext RootContext
    state = useMemo ->
      # TODO: only call cb() if not shouldSuspend and not awaitStable?
      State(cb())
    , []

    [value, setValue] = useState state.getValue()
    [error, setError] = useState null

    if error?
      throw error

    if shouldSuspend
      # XXX
      value = useResource ->
        state._onStable().then (stableDisposable) ->
          # TODO: is this a huge performance penalty? (for concurrent)
          # FIXME: should promise chain the nextTick (+tests)
          process.nextTick ->
            stableDisposable.unsubscribe()
        .then -> state.getValue()
    else if window?
      useLayout ->
        subscription = state.subscribe setValue, setError
        # TODO: tests for unsubscribe
        ->
          subscription.unsubscribe()
      , []
    else
      useMemo ->
        if awaitStable?
          awaitStable state._onStable().then (stableDisposable) ->
            setValue value = state.getValue()
            stableDisposable
      , [awaitStable]

    value

  render: (tree, $$root) ->
    render z(RootContext, {shouldSuspend: false}, tree), $$root

  renderToString: (tree, {timeout} = {}) ->
    timeout ?= DEFAULT_TIMEOUT_MS

    stablePromises = []
    awaitStable = (x) -> stablePromises.push x
    initialHtml = await render \
      z(RootContext, {shouldSuspend: false, awaitStable}, tree), {}

    try
      return await Promise.race [
        Promise.all stablePromises
        .then (stableDisposables) ->
          render \
            z(RootContext, {shouldSuspend: true}, z Suspense, tree), {}
          .then (html) ->
            _.map stableDisposables, (stableDisposable) ->
              stableDisposable.unsubscribe()
            html
        new Promise (resolve, reject) ->
          setTimeout ->
            reject new Error 'Timeout'
          , timeout
      ]
    catch err
      Object.defineProperty err, 'html',
        value: initialHtml
        enumerable: false
      throw err
}, dyo
