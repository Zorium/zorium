_ = require 'lodash'
gulp = require 'gulp'
rename = require 'gulp-rename'
clean = require 'gulp-clean'
runSequence = require 'gulp-run-sequence'
coffeelint = require 'gulp-coffeelint'
karma = require('karma').server
RewirePlugin = require 'rewire-webpack'
webpack = require 'gulp-webpack'
webpackSource = require 'webpack'
merge = require 'merge-stream'

karmaConf = require './karma.defaults'

outFiles =
  scripts: 'bundle.js'

paths =
  scripts: ['./src/**/*.coffee', './*.coffee']
  tests: './test/**/*.coffee'
  root: './src/zorium.coffee'
  rootTests: './test/zorium.coffee'
  dist: './dist/'
  build: './build/'

gulp.task 'demo', ->
  gulp.start 'server'

# compile sources: src/* -> dist/*
gulp.task 'assets:prod', [
  'scripts:prod'
  'scripts:prod-min'
]

# build for production
gulp.task 'build', (cb) ->
  runSequence 'clean:dist', 'assets:prod', cb

# tests
gulp.task 'test', [
    'scripts:test'
    'lint:tests'
    'lint:scripts'
  ], (cb) ->
  karma.start _.defaults(singleRun: true, karmaConf), cb

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
      # browser-builtins is for modules requesting native node modules
      modulesDirectories: ['web_modules', 'node_modules', './src',
      './node_modules/browser-builtins/builtin']
  .pipe rename 'tests.js'
  .pipe gulp.dest paths.build


# run coffee-lint
gulp.task 'lint:tests', ->
  gulp.src paths.tests
    .pipe coffeelint()
    .pipe coffeelint.reporter()

#
# Dev watcher
#

gulp.task 'watch:test', ->
  gulp.watch paths.scripts.concat([paths.tests]), ['test:phantom']

# run coffee-lint
gulp.task 'lint:scripts', ->
  gulp.src paths.scripts
    .pipe coffeelint()
    .pipe coffeelint.reporter()

#
# Production compilation
#

# rm -r dist
gulp.task 'clean:dist', ->
  gulp.src paths.dist, read: false
    .pipe clean()

webpackProdConfig =
  output:
    library: 'zorium'
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

gulp.task 'scripts:prod', ->
  gulp.src paths.root
  .pipe webpack webpackProdConfig
  .pipe rename 'zorium.js'
  .pipe gulp.dest paths.dist

gulp.task 'scripts:prod-min', ->
  gulp.src paths.root
  .pipe webpack _.defaults {
    plugins: [
      new webpackSource.optimize.UglifyJsPlugin()
    ]
  }, webpackProdConfig
  .pipe rename 'zorium.min.js'
  .pipe gulp.dest paths.dist
  .pipe gulp.src paths.root
