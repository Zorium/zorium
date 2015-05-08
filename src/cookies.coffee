_ = require 'lodash'
cookie = require 'cookie'
Rx = require 'rx-lite'

class Cookies
  constructor: ->
    @cookieSubjects = {}
    @cookieConstructors = {}

  # Avoid triggering the cookieConstructor
  # Important because the {opts} for cookies are no longer accessible
  populate: (cookies) =>
    cookies = cookie.parse cookies or ''
    _.forEach cookies, (val, key) =>
      @cookieSubjects[key] = new Rx.BehaviorSubject(val)

  getConstructors: => @cookieConstructors

  reset: =>
    @cookieSubjects = {}
    @cookieConstructors = {}

  set: (key, value, opts) =>
    if @cookieSubjects[key]
      @cookieSubjects[key].onNext value
    else
      @cookieSubjects[key] = new Rx.BehaviorSubject(value)

    @cookieConstructors[key] = {
      value
      opts
    }
    if window?
      document.cookie = cookie.serialize key, value, opts

  get: (key) =>
    if @cookieSubjects[key]
      return @cookieSubjects[key]
    else
      value = if window?
        cookie.parse(document.cookie or '')?[key] or null
      else
        null

      @cookieSubjects[key] = new Rx.BehaviorSubject(value)
      return @cookieSubjects[key]

module.exports = new Cookies()
