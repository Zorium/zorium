![Zorium](./zorium.png)

## Zorium - The Coffeescript Web
#### [zorium.org](https://zorium.org/)

(╯°□°)╯︵ ┻━┻  
v1.0.0-rc12

## Examples

```coffee
z = require 'zorium'

class AppComponent
  constructor: (params) ->
    @state = z.state
      name: 'Zorium'

  render: =>
    {name} = @state.getValue()

    z '.zorium',
      z 'p.text',
        "The Future -#{name}"

z.render document.body, new AppComponent()
```

## API

### z()

```coffee
z '.container' # <div class='container'></div>

z '#layout' # <div id='layout'></div>

z 'button' # <button></button>

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

  - Can be used in place of a dom tag.  
  - Must have a `render()` method  
  - Must be `pure` - `render()` updates must only rely on `@state` and props

```coffee
class HelloWorldComponent
  constructor: ->
    @state = z.state({x: 'x'})
  render: ({name}) ->
    z 'span', "Hello #{name}!"

$hello = new HelloWorldComponent()

z 'div',
  z $hello, {name: 'Jim'} # <div><span>Hello Jim!</span></div>
```

Props can also be passed to the render method

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
  constructor: ->
    @state = z.state
      key: 'Zorium'

  render: ({path}) =>
    {key} = @state.getValue()

    if path is '/'
      z 'div', 'Hello ' + key
    else
      z 'div', '404'

root = document.createElement 'div'

factory = ->
  new App()

z.server.set
  mode: 'pathname'
  $$root: root
  factory: factory


z.router.go '/test'
```


#### z.server.set()

```coffee

###
@param {Object} config
@param {'pathname'|'hash'} config.mode  - defaults to 'pathname' if possible
@param {Function} factory - method when called returns a new app root component
###
z.server.set {
  mode
  $$root
  factory
}

z.server.setMode 'hash' # (default) clay.io/#/path
z.server.setMode 'pathname' # clay.io/pathname
```

#### z.server.go()

Navigate to a route

```coffee
z.server.go '/test/one'
```

### z.server.link()

automatically route anchor `<a>` tag elements
It is a mistake to use `onclick` on the element

```coffee
z 'div',
  z.router.link z 'a.myclass[href=/abc]', 'click me'
```

### z.server.on()

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

### State

#### z.state({initialValue})

returns an [`Rx.BehaviorSubject`](https://github.com/Reactive-Extensions/RxJS/blob/master/doc/api/subjects/behaviorsubject.md),
with a `set()` method for partial updates  
Your component will be updated whenever state changes  
If passed an `Rx.Observable`, updates propagate automatically

```coffee
Rx = require 'rx-lite'
promise = new Promise()

state = z.state
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: Rx.Observable.fromPromise promise

state.getValue() is {
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: null
}

promise.resolve(123)

# promise resolved
state.getValue().d is 123

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
  root_factory.coffee
  root.coffee
/test
  /components
  /models
  ...
```

### root.coffee

This file serves as the initialization point for the application.  

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
  constructor: ->
    @state = z.state
      $nav: new Nav()
      $body: new Body()

  render: =>
    {$nav, $body} = @state.getValue()
    z 'div',
      z $nav
      z $body
```

### Services

Services are singletons of the form

```coffee
class AbcService
  # define service methods

module.exports = new AbcService()
```


### Changelog

1.0.0-rc1 -> 1.0.0-rc12
  - almost all of `z.server`
  - removed z.Router
  - server-side rendering!
  - lazy state subscriptions

0.8.x -> 1.0.0-rc1
  - removed z.oldState()
  - removed z.observe()
  - z.router was split between z.Router and z.server

0.7.x -> 0.8.0

  - z.state() -> z.oldState()
  - z.router.currentPath -> removed
  - z.redraw() is no longer synchronous
  - z.router.add() requires a component from a function - use `({params, query}) -> new Component(params, query)`
  - z.router.add() removed pathTransform param
  - components must be `pure`
