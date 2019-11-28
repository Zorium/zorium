module.exports = (config) ->
  config.set
    singleRun: process.env.WATCH isnt '1'
    frameworks: ['mocha']
    client:
      useIframe: true
      captureConsole: true
      mocha:
        timeout: 300
    browsers: if process.env.ALL_BROWSERS is '1'
      ['Chrome', 'Firefox']
    else
      ['ChromeHeadless']
    files: [
      'test/**/*.coffee'
    ]
    preprocessors:
      '**/*.coffee': ['webpack']
    webpack:
      mode: 'development'
      devtool: 'inline-source-map'
      module:
        exprContextRegExp: /$^/
        exprContextCritical: false
        rules: [
          {
            test: /\.coffee$/
            use: ['zolmeister-coffee-coverage-loader']
          }
        ]
      resolve:
        extensions: ['.coffee', '.js']
    webpackMiddleware:
      noInfo: true
      stats: 'errors-only'
    reporters: ['progress', 'coverage-istanbul']
    coverageIstanbulReporter:
      reports: ['json']
      combineBrowserReports: true
      fixWebpackSourcePaths: true
      skipFilesWithNoCoverage: false
      instrumentation:
        excludes: ['**/test/**']
