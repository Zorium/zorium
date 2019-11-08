_ = require 'lodash'

z = require './z'
render = require './render'
hydrate = require './hydrate'
renderToString = require './render_to_string'
State = require './state'
classKebab = require './class_kebab'
isSimpleClick = require './is_simple_click'
untilStable = require './until_stable'
{useMemo, Boundary, Context, useContext, useState} = require 'dyo/server/dist/dyo.umd.js'

DEFAULT_TIMEOUT_MS = 250

RootContext = ({children, awaitState}) ->
  z Context, {value: {awaitState}}, children

# BREAKING: remove z.bind()
# BREAKING: remove z.ev()
_.assign z, {
  z
  render
  hydrate
  renderToString: (tree, {timeout} = {}) ->
    timeout ?= DEFAULT_TIMEOUT_MS

    [initialHtml, html] = await Promise.all [
      renderToString z RootContext, {awaitState: false}, tree
      Promise.race [
        renderToString z RootContext, {awaitState: true}, tree
        new Promise (resolve, reject) ->
          setTimeout ->
            resolve null
          , timeout
      ]
    ]

    if html?
      return html
    else
      error = new Error 'Timeout'
      Object.defineProperty error, 'html',
        value: initialHtml
        enumerable: false
      throw error

  classKebab
  isSimpleClick
  untilStable
  Boundary
  useMemo
  useState: (cb) ->
    {awaitState} = useContext RootContext
    state = useMemo ->
      # TODO: only call cb() if awaitState?
      State(cb())
    , []

    await useMemo ->
      if awaitState
        state._onStable().then (stableDisposable) ->
          process.nextTick ->
            stableDisposable.unsubscribe()
    , [awaitState]

    state.getValue()
}

module.exports = z
