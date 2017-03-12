_ = require 'lodash'

module.exports = (classes) ->
  _.map _.keys(_.pickBy classes, _.identity), _.kebabCase
  .join ' '
