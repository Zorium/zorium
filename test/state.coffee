b = require 'b-assert'
Rx = require 'rxjs/Rx'

z = require '../src/zorium'

describe 'z.state', ->
  it 'obesrves state, returning an observable', ->
    subject = new Rx.BehaviorSubject(null)
    promise = Promise.resolve 'b'
    state = z.state
      a: 'a'
      b: Rx.Observable.fromPromise promise
      c: subject

    b _.isFunction(state.subscribe), true

    state.subscribe (state) ->
      b state.a, 'a'

    b state.getValue(), {a: 'a', b: null, c: null}

    promise.then ->
      b state.getValue(), {a: 'a', b: 'b', c: null}
      subject.next 'c'
      b state.getValue(), {a: 'a', b: 'b', c: 'c'}

      state.set x: 'x'
      b state.getValue().x, 'x'
      state.set x: 'X'
      b state.getValue().x, 'X'

  it 'sets state with false values', ->
    state = z.state
      a: 'a'
      b: false
      c: 123

    b state.getValue(), {a: 'a', b: false, c: 123}

  it 'errors when setting observable values in diff', ->
    subject = new Rx.BehaviorSubject(null)

    state = z.state
      subject: subject

    try
      state.set subject: 'subject'
      b false
    catch err
      b err?

  it 'throws errors', ->
    subject = new Rx.BehaviorSubject(null)

    state = z.state
      subject: subject

    try
      subject.error new Error 'err'
      b false
    catch err
      b err?

  it 'lazy subscribes', ->
    lazyRuns = 0

    cold = Rx.Observable.defer ->
      lazyRuns += 1
      Rx.Observable.of lazyRuns

    state = z.state
      lazy: cold

    b lazyRuns, 0

    state.subscribe()
    b lazyRuns, 1

    state.set a: 'b'
    b lazyRuns, 1

    state2 = z.state
      lazy: cold

    b lazyRuns, 1

    state2.subscribe()
    b lazyRuns, 2

    b state.getValue().lazy, 1
    b state2.getValue().lazy, 2

  # TODO
  # it.only 'updates efficiently', (done) ->
  #   updates = 0
  #   s = new Rx.BehaviorSubject 's'
  #   state = z.state
  #     a: 'a'
  #     s: s
  #
  #   unsub = state.subscribe ->
  #     updates += 1
  #
  #   b updates, 1
  #   setTimeout ->
  #     b updates, 1
  #     s.next 'ss'
  #     setTimeout ->
  #       b updates, 2
  #       state.set {a: 'x'}
  #       setTimeout ->
  #         b updates, 3
  #         unsub.unsubscribe()
  #         done()
