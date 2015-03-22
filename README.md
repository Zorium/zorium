![Zorium](./zorium.png)

## Zorium - The Coffeescript Web
#### [zorium.org](https://zorium.org/)

(╯°□°)╯︵ ┻━┻  
v0.8.0

## Examples

```coffee
z = require 'zorium'

class AppComponent
  constructor: (params) ->
    @state = z.state
      zoo: 'Zorium'

  clicker: (e) =>
    console.log 'Click!'
    @state.set
      zoo: 'AllOfTheThings'

  render: =>
    {zoo} = @state.getValue()

    z 'a.zorium-link[href=/]',
      z "img[src=#{zoo}.png]", onclick: @clicker

z.render document.body, new AppComponent()
```

## API

### z()

```coffee
z '.container' # <div class='container'></div>

z '#layout' # <div id='layout'></div>

z 'a[name=top]' # <a name='top'></a>

z '[contenteditable]' # <div contenteditable='true'></div>

z 'a#google.external[href=http://google.com]', 'Google' # <a id='google' class='external' href='http://google.com'>Google</a>

z 'div', {style: {border: '1px solid red'}}  # <div style='border:1px solid red;'></div>
```

```coffee
z 'ul',
  z 'li', 'item 1'
  z 'li', 'item 2'

###
<ul>
    <li>item 1</li>
    <li>item 2</li>
</ul>
###
```

### Zorium Components

Zorium components can be used in place of a dom tag.  
Zorium components must have a `render()` method

```coffee
class HelloWorldComponent
  render: ->
    z 'span', 'Hello World'

$hello = new HelloWorldComponent()

z 'div',
  z $hello # <div><span>Hello World</span></div>
```

Parameters can also be passed to the render method

```coffee
class A
  render: ({world}) ->
    z 'div', 'hello ' + world

class B
  constructor: ->
    @state = z.state
      $a: new A()
  render: =>
    {$a} = @state.getValue()
    z $a, {world: 'world'}

$b = new B()
root = document.createElement 'div'
z.render root, $b # <div><div>hello world</div></div>
```

#### Lifecycle Hooks

If a component has a hook method defined, it will be called

```coffee
class BindComponent
  onMount: ($el) ->
    # called after $el has been inserted into the DOM
    # $el is the rendered DOM node

  onBeforeUnmount: ->
    # called before the element is removed from the DOM

  render: ->
    z 'div',
      z 'span', 'Hello World'
      z 'span', 'Goodbye'
```

### Routing

#### Example

```coffee
class App
  constructor: (params) ->
    @state = z.state
      key: params.key or 'none'

  render: =>
    {key} = @state.getValue()
    z 'div', 'Hello ' + key

root = document.createElement 'div'

z.router.setMode 'pathname' # 'pathname' or 'hash' (default is 'hash')

z.router.setRoot root
z.router.add '/test', App
z.router.add '/test/:key', App

z.router.go '/test'
```


#### z.router.setMode()

```coffee
z.router.setMode 'hash' # (default) clay.io/#/path
z.router.setMode 'pathname' # clay.io/pathname
```


#### z.router.setRoot()

Accepts a DOM node to append to

```coffee
###
@param {HtmlElement}
###
z.router.setRoot(document.body)
```

#### z.router.add()

Variables will be passed into the component constructor.  
pathTransform will be called if provided, and may return a promise.
If the path returned by pathTransform differs from the original route, a redirect to the new route will occur.

```coffee
###
@param {String} path
@param {ZoriumComponent} App
@param {Function<String, Promise<String>>} [pathTransform=((path) -> path)]
###
z.router.add '/test/:key', App, pathTransform

class App
  constructor: (params) -> null

pathTransform = (path) ->
  isLoggedIn = new Promise (resolve) -> resolve false

  return isLoggedIn.then (isLoggedIn) ->
    unless isLoggedIn
      return '/login'

    return path
```

#### z.router.go()

Navigate to a route

```coffee
z.router.go '/test/one'
```

### z.router.link()

automatically route anchor `<a>` tag elements
It is a mistake to use `onclick` on the element

```coffee
z 'div',
  z.router.link z 'a.myclass[href=/abc]', 'click me'
```


### z.router.getCurrentPath()

Returns the currently routed path that the router has routed to.

### z.router.on()

Listen for events. Currently the only event is `route`, which emits the path.

```coffee
###
@param {String} key
@param {Function} callback
###
z.router.on 'route', (path) -> null
```

### Rendering

#### z.render()

```coffee
###
@param {HtmlElement} root
@param {ZoriumComponent} App
###
z.render document.body, App
```

#### z.redraw()

Redraw all previously rendered elements, batched by requestAnimationFrame  
This is called whenever a component's `state` is changed  
Call this whenever something changes the DOM state

```coffee
z.render document.body, z 'div'
z.redraw()
```

### State

#### z.state({initialValue})

returns an `Rx.BehaviorSubject`, with a `set()` method for partial updates  
When set as a property of a Zorium Component, `z.redraw()` will automatically be called  
If passed an `Rx.Observable`, an update is triggered on child updates

```coffee
promise = new Promise()

state = z.state
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: new Rx.Observable.fromPromise promise

state.getValue() is {
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: null
}

promise.resolve(123)

# promise resolved
state.getValue().d is 123

# watch for changes
state.subscribe (state) ->
  state.b is 321

# partial update
state.set
  b: 321

state.getValue() is {
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: 123
}
```

#### WARNING: WILL BE REMOVED in 1.0
#### z.oldState()

Previously z.state  
Partial updating state object  
When set as a property of a Zorium Component, `z.redraw()` will automatically be called  
If passed a `z.observe`, an update is triggered on child updates

```coffee
promise = new Promise()

state = z.state
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: z.observe promise

state() is {
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: null
}

promise.resolve(123)

# promise resolved
state().d is 123

# watch for changes
state (state) ->
  state.b is 321

# partial update
state.set
  b: 321

state() is {
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: 123
}
```

#### WARNING: WILL BE REMOVED in 1.0
#### z.observe()

Create an observable  
Promises observe to `null` until resolved (but still have promise methods)

```coffee
a = z.observe 'a'
a() is 'a'

a (change) ->
  change is 'b'

a.set('b')

resolve = null
promise = new Promise (_resolve) -> resolve = _resolve
p = z.observe(promise)
p() is null
resolve(1)

p.then ->
  p() is 1

```

### Helpers

#### z.ev()

pass event context to callback fn

```coffee
z 'div',
  onclick: z.ev (e, $$el) ->
    # `e` is the original event
    # $$el is the event source element which triggered the event
```

## Architecture

### Folder structure

```
/src
  /components
  /models
  /pages
  /services
  root.coffee
/test
  /components
  /models
  ...
```

### root.coffee

This file serves as the initialization point for the application.  
Currently, routing goes here, along with other miscellaneous things.

### Components

Components should set `@state` as a `z.state` when using local state
Components are classes of the form:

```coffee
module.exports = class MyAbc
  render: ->
    # define view
```

### Models

Models are used for storing application state, as well as making resource API requests
Models are singletons of the form  

```coffee
class AbcModel
  # define model methods

module.exports = new AbcModel()
```

### Pages

Pages are components which are routed to via the router.  
They should contain as little logic as possible, and are responsible for laying out
components on the page.

```coffee
Nav = require('../components/nav')
Body = require('../components/body')

module.exports = class HomePage
  constructor: (params) ->
    @state = z.state
      $nav: new Nav()
      $body: new Body(params.key)

  render: =>
    {$nav, $body} = @state.getValue()
    z 'div',
      z $nav
      z $body
```

##### Page Extension

If extending a root page with sub-pages is desired, subclass.

```coffee
Nav = require('../components/nav')
Footer = require('../components/footer')
OtherFooter = require('../components/otherFooter')

class RootPage
  constructor: ->
    @state = z.state
        $nav: new Nav()
        $footer: new Footer()

  render: =>
    {$nav, $footer} = @state.getValue()
    z 'div',
      z $nav
      z $footer

class APage extends RootPage
  constructor: ->
    super

    @state.set
      $footer: new OtherFooter()
```


### Services

Services are singletons of the form

```coffee
class AbcService
  # define service methods

module.exports = new AbcService()
```


### Changelog

0.8.0

  - z.state() -> z.oldState()
  - z.router.currentPath -> z.router.getCurrentPath()
  - z.redraw() is no longer synchronous
