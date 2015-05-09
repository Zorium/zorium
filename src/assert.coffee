module.exports = (value, message) ->
  unless value
    throw new Error message
