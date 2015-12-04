_ = require 'lodash'
Rx = require 'rx-lite'
isThunk = require 'virtual-dom/vnode/is-thunk'

z = require './z'
render = require './render'
isComponent = require './is_component'
ZThunk = require './z_thunk'

# TODO: util?
forkJoin = (streams) ->
  Rx.Observable.combineLatest streams, (results...) -> results

watch = (tree) ->
  if isThunk(tree) and tree.component? # TODO: isZThunk
    zthunk = tree
    state = zthunk.component.state or Rx.Observable.just null

    return state
      .flatMapLatest ->
        # TODO: ugly?
        subtree = zthunk.render()
        forkJoin _.map subtree.children, watch
        .map ->
          # TODO: understand impact, see z.coffee (~L45)
          zthunk.component._zthunk = new ZThunk({
            props: zthunk.props
            component: zthunk.component
          })
  else if not _.isEmpty tree.children
    forkJoin _.map tree.children, watch
    .map (children) ->
      _.defaults {children}, tree
  else
    Rx.Observable.just tree

module.exports = ($$root, tree) ->
  if isComponent tree
    tree = z tree

  if $$root._zorium_bind_disposable?
    $$root._zorium_bind_disposable.dispose()

  $$root._zorium_bind_disposable = watch tree
  .subscribe _.debounce (tree) ->
    render $$root, tree
