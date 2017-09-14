# TODO: deprecate
module.exports = (fn) ->
  (e) ->
    $$el = e.currentTarget
    fn(e, $$el)
