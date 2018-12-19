gulp = require 'gulp'
mocha = require 'gulp-mocha'
karma = require 'karma'
webpackStream = require 'webpack-stream'

paths =
  coffee: ['./src/**/*.coffee', './*.coffee', './test/**/*.coffee']
  tests: './test/**/*.coffee'
  rootScripts: './src/index.coffee'
  rootServerTests: './test/zorium_server.coffee'
  build: './build'
  output:
    tests: 'tests.js'

gulp.task 'scripts:test', ->
  gulp.src paths.tests
  .pipe webpackStream
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
      extensions: ['.coffee', '.js']
  .pipe gulp.dest paths.build

gulp.task 'test:server', ->
  gulp.src paths.rootServerTests
    .pipe mocha
      require: 'coffeescript/register'
      timeout: 400
      color: true

gulp.task 'test:browser', gulp.series ['scripts:test'], (cb) ->
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

gulp.task 'test', gulp.parallel ['test:server', 'test:browser']

gulp.task 'watch', ->
  # gulp.watch paths.coffee, gulp.parallel ['test:browser', 'test:server']
  # FIXME
  gulp.watch paths.coffee, gulp.series ['test:server']
