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
