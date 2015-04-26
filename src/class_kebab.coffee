_ = require 'lodash'

module.exports = (classes) ->
  _.map _.keys(_.pick classes, _.identity), _.kebabCase
  .join ' '
