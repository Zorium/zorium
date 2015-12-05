_ = require 'lodash'
Rx = require 'rx-lite'
isThunk = require 'virtual-dom/vnode/is-thunk'

z = require './z'
render = require './render'
isComponent = require './is_component'
ZThunk = require './z_thunk'

isZThunk = (node) ->
  isThunk(node) and node.component?

module.exports = ($$root, tree) ->
  if isComponent tree
    tree = z tree

  # FIXME
  unless isZThunk tree
    throw new Error 'Not passed a component'

  # FIXME: if re-binding does not stop listening for old tree changes
  # though maybe it's fine because the component unmounts
  onchange = _.debounce ->
    render $$root, new ZThunk {
      component: tree.component
      props: tree.props
    }

  tree.component.__onDirty = onchange

  # for full-page rendering, root node is never mounted
  $$root.__disposable?.dispose()
  $$root.__disposable = tree.component.state?.subscribe onchange

  render $$root, new ZThunk {
    component: tree.component
    props: tree.props
  }
