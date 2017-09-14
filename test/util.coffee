assertDOM = (a, b) ->
  unless a.tagName is b.tagName
    throw new Error "tagName mismatch \n\
      #{a.tagName} \n#{b.tagName}"

  unless a.getAttribute('xmlns:xlink') is b.getAttribute('xmlns:xlink')
    throw new Error "namespace mismatch \n\
      #{a.getAttribute('xmlns:xlink')} \n#{b.getAttribute('xmlns:xlink')}"

  unless a.attributes.length is b.attributes.length
    throw new Error "attribute length mismatch \n\
      #{a.attributes.length} \n#{b.attributes.length}"

  for key, attrA of a.attributes
    attrB = b.attributes[key]
    unless attrA.name is attrB.name and attrA.value is attrB.value
      throw new Error "attribute mismatch #{attrA.name} \n\
        #{attrA.value} \n #{attrB.value}"

  unless a.children.length is b.children.length
    throw new Error "children length mismatch \n\
      #{a.children.length} \n#{b.children.length}"

  i = a.children.length - 1
  while i >= 0
    assertDOM(a.children[i], b.children[i])
    i -= 1

  return null

module.exports =
  htmlToNode: (html) ->
    root = document.createElement 'div'
    root.innerHTML = html
    return root.firstChild

  deferred: ->
    resolve = null
    reject = null
    promise = new Promise (_resolve, _reject) ->
      resolve = _resolve
      reject = _reject
    promise.resolve = resolve
    promise.reject = reject

    return promise

  assertDOM: assertDOM
