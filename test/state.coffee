_ = require 'lodash'
b = require 'b-assert'
Rx = require 'rxjs/Rx'

State = require '../src/state'

describe 'State', ->
  it 'obesrves state, returning an observable', ->
    subject = new Rx.BehaviorSubject(null)
    promise = Promise.resolve 'b'
    state = State
      a: 'a'
      b: Rx.Observable.fromPromise promise
      c: subject

    b _.isFunction(state.subscribe), true

    state.subscribe (update) ->
      b update.a, 'a'

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
    state = State
      a: 'a'
      b: false
      c: 123

    b state.getValue(), {a: 'a', b: false, c: 123}

  it 'errors when setting observable values in diff', ->
    subject = new Rx.BehaviorSubject(null)

    state = State
      subject: subject

    try
      state.set subject: 'subject'
      b false
    catch err
      b err?

  it 'throws errors', ->
    subject = new Rx.BehaviorSubject(null)

    state = State
      subject: subject
    disposable = state.subscribe -> null

    try
      subject.error new Error 'err'
      b false
    catch err
      b err?

    disposable.unsubscribe()

  it 'lazy subscribes', ->
    lazyRuns = 0

    cold = Rx.Observable.defer ->
      lazyRuns += 1
      Rx.Observable.of lazyRuns

    state = State
      lazy: cold

    b lazyRuns, 0

    state.subscribe()
    b lazyRuns, 1

    state.set a: 'b'
    b lazyRuns, 1

    state2 = State
      lazy: cold

    b lazyRuns, 1

    state2.subscribe()
    b lazyRuns, 2

    b state.getValue().lazy, 1
    b state2.getValue().lazy, 2

  it 'updates observable values to "undefined"', ->
    subject = new Rx.BehaviorSubject('abc')

    state = State
      subject: subject
    state.subscribe()
    b state.getValue(), {subject: 'abc'}
    subject.next undefined
    b state.getValue(), {subject: undefined}

  it 'updates efficiently', (done) ->
    updates = 0
    s = new Rx.BehaviorSubject 's'
    state = State
      a: 'a'
      s: s

    unsub = state.subscribe ->
      updates += 1

    b updates, 1
    setTimeout ->
      b updates, 1
      s.next 'ss'
      setTimeout ->
        b updates, 2
        state.set {a: 'x'}
        setTimeout ->
          b updates, 3
          unsub.unsubscribe()
          done()

  it 'does not re-emit value when re-subscribing', ->
    subject = new Rx.BehaviorSubject 'abc'
    state = State
      static: new Rx.BehaviorSubject 'xxx'
      cold: Rx.Observable.defer -> subject
      never: Rx.Observable.fromPromise new Promise(-> null)

    b state.getValue().cold, null
    callbackCounter = 0
    state.subscribe (currentState) ->
      callbackCounter += 1
      b currentState.cold, 'abc'
      b state.getValue() is currentState
    .unsubscribe()
    b callbackCounter, 1

    callbackCounter = 0
    state.subscribe (currentState) ->
      callbackCounter += 1
      b currentState.cold, 'abc'
      b state.getValue() is currentState
    b callbackCounter, 1
