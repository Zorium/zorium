_ = require 'lodash'
del = require 'del'
gulp = require 'gulp'
mocha = require 'gulp-mocha'
karma = require('karma').server
rename = require 'gulp-rename'
webpack = require 'gulp-webpack'
coffeelint = require 'gulp-coffeelint'
RewirePlugin = require 'rewire-webpack'
webpackSource = require 'webpack'
clayLintConfig = require 'clay-coffeescript-style-guide'

packangeConf = require './package.json'

karmaConf =
  frameworks: ['mocha']
  client:
    useIframe: true
    captureConsole: true
    mocha:
      timeout: 300
  files: [
    'build/tests.js'
  ]
  browsers: ['Chrome', 'Firefox']

paths =
  coffee: ['./src/**/*.coffee', './*.coffee', './test/**/*.coffee']
  rootScripts: './src/zorium.coffee'
  rootTests: './test/zorium.coffee'
  rootServerTests: './test/zorium_server.coffee'
  build: './build/'

webpackProdConfig =
  module:
    exprContextRegExp: /$^/
    exprContextCritical: false
    postLoaders: [
      { test: /\.coffee$/, loader: 'transform/cacheable?envify' }
    ]
    loaders: [
      { test: /\.coffee$/, loader: 'coffee' }
      { test: /\.json$/, loader: 'json' }
    ]
  resolve:
    extensions: ['.coffee', '.js', '.json', '']

gulp.task 'test', ['scripts:test', 'lint', 'test:server'], (cb) ->
  karma.start _.defaults(singleRun: true, karmaConf), cb

gulp.task 'test:server', ->
  gulp.src paths.rootServerTests
    .pipe mocha()

gulp.task 'watch', ->
  gulp.watch paths.coffee, ['test:phantom']

gulp.task 'watch:server', ->
  gulp.watch paths.coffee, ['test:server']

gulp.task 'lint', ->
  gulp.src paths.coffee
    .pipe coffeelint(null, clayLintConfig)
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
      exprContextRegExp: /$^/
      exprContextCritical: false
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

gulp.task 'watch:test', ->
  gulp.watch paths.scripts.concat([paths.tests]), ['test:phantom']
