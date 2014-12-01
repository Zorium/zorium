_ = require 'lodash'
del = require 'del'
gulp = require 'gulp'
karma = require('karma').server
rename = require 'gulp-rename'
webpack = require 'gulp-webpack'
coffeelint = require 'gulp-coffeelint'
RewirePlugin = require 'rewire-webpack'
webpackSource = require 'webpack'

karmaConf = require './karma.defaults'
packangeConf = require './package.json'

paths =
  coffee: ['./src/**/*.coffee', './*.coffee', './test/**/*.coffee']
  rootScripts: './src/zorium.coffee'
  rootTests: './test/zorium.coffee'
  dist: './dist/'
  build: './build/'

webpackProdConfig =
  module:
    postLoaders: [
      { test: /\.coffee$/, loader: 'transform/cacheable?envify' }
    ]
    loaders: [
      { test: /\.coffee$/, loader: 'coffee' }
      { test: /\.json$/, loader: 'json' }
    ]
  resolve:
    extensions: ['.coffee', '.js', '.json', '']

gulp.task 'build', ['clean:dist', 'scripts:dist', 'scripts:dist-min']

gulp.task 'test', ['scripts:test', 'lint'], (cb) ->
  karma.start _.defaults(singleRun: true, karmaConf), cb

gulp.task 'watch', ->
  gulp.watch paths.coffee, ['test:phantom']

gulp.task 'lint', ->
  gulp.src paths.coffee
    .pipe coffeelint()
    .pipe coffeelint.reporter()

gulp.task 'test:phantom', ['scripts:test'], (cb) ->
  karma.start _.defaults({
    singleRun: true,
    browsers: ['PhantomJS']
  }, karmaConf), cb

gulp.task 'scripts:test', ->
  gulp.src paths.rootTests
  .pipe webpack
    devtool: '#inline-source-map'
    module:
      postLoaders: [
        { test: /\.coffee$/, loader: 'transform/cacheable?envify' }
      ]
      loaders: [
        { test: /\.coffee$/, loader: 'coffee' }
        { test: /\.json$/, loader: 'json' }
      ]
    plugins: [
      new RewirePlugin()
    ]
    resolve:
      extensions: ['.coffee', '.js', '.json', '']
      modulesDirectories: ['node_modules', './src']
  .pipe rename 'tests.js'
  .pipe gulp.dest paths.build

gulp.task 'clean:dist', (cb) ->
  del paths.dist, cb

gulp.task 'watch:test', ->
  gulp.watch paths.scripts.concat([paths.tests]), ['test:phantom']

gulp.task 'scripts:dist', ->
  gulp.src paths.rootScripts
  .pipe webpack _.defaults
    output:
      library: 'zorium'
      libraryTarget: 'commonjs2'
  , webpackProdConfig

  .pipe rename 'zorium.js'
  .pipe gulp.dest paths.dist

gulp.task 'scripts:dist-min', ->
  gulp.src paths.rootScripts
  .pipe webpack _.defaults {
    output:
      library: 'zorium'
    plugins: [
      new webpackSource.optimize.UglifyJsPlugin()
    ]
  }, webpackProdConfig
  .pipe rename 'zorium.min.js'
  .pipe gulp.dest paths.dist
