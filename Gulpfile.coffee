_ = require 'lodash'
gulp = require 'gulp'
mocha = require 'gulp-mocha'
karma = require 'karma'
webpack = require 'gulp-webpack'
coffeelint = require 'gulp-coffeelint'
webpackSource = require 'webpack'

paths =
  coffee: ['./src/**/*.coffee', './*.coffee', './test/**/*.coffee']
  tests: './test/**/*.coffee'
  rootScripts: './src/zorium.coffee'
  rootServerTests: './test/zorium_server.coffee'
  build: './build'
  output:
    tests: 'tests.js'

gulp.task 'test', ['test:lint', 'test:server', 'test:browser']

gulp.task 'watch', ->
  gulp.watch paths.coffee, ['test:browser', 'test:server']

gulp.task 'test:lint', ->
  gulp.src paths.coffee
    .pipe coffeelint()
    .pipe coffeelint.reporter()

gulp.task 'test:server', ->
  gulp.src paths.rootServerTests
    .pipe mocha
      compilers: 'coffee:coffee-script/register'
      timeout: 400
      useColors: true

gulp.task 'test:browser', ['scripts:test'], (cb) ->
  new karma.Server({
    singleRun: true
    frameworks: ['mocha']
    client:
      useIframe: true
      captureConsole: true
      mocha:
        timeout: 300
    files: [
      "#{paths.build}/#{paths.output.tests}"
    ]
    browsers: ['ChromeHeadless']
  }, cb).start()

gulp.task 'scripts:test', ->
  gulp.src paths.tests
  .pipe webpack
    devtool: '#inline-source-map'
    output:
      filename: paths.output.tests
    module:
      exprContextRegExp: /$^/
      exprContextCritical: false
      loaders: [
        {test: /\.coffee$/, loader: 'coffee-loader'}
      ]
    resolve:
      extensions: ['.coffee', '.js', '']
  .pipe gulp.dest paths.build
