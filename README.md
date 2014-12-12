![Zorium](./zorium.png)

(╯°□°)╯︵ ┻━┻  
v0.3.0

## Examples

CoffeeScript

```coffee
z = require 'zorium'

class AppComponent
  constructor: (params) ->
    @state = z.state
      z: 'Zorium'

  clicker: (e) =>
    console.log 'Click!'
    @state.set
      z: 'AllOfTheThings'

  render: =>
    z 'a.zorium-link[href=/]',
      z "img[src=#{@state().z}.png]", onclick: @clicker

z.render document.body, new AppComponent()
```

JavaScript

```js
z = require('zorium')
function AppComponent(params) {
  var state = z.state({z: 'Zorium'})

  var clicker = function (e) {
    console.log('Click!');
    state.set({z: 'AllOfTheThings'})
  }

  return {
    state: state,
    render: function () {
      return z('a.zorium-link[href=/]',
        z('img[src=' + state().z + '.png]', {onclick: clicker})
      )
    }
  }
}

z.render(document.body, new AppComponent())
```

## API

### z()

```js
z('.container') // <div class='container'></div>

z('#layout') // <div id='layout'></div>

z('a[name=top]') // <a name='top'></a>

z('[contenteditable]') // <div contenteditable='true'></div>

z('a#google.external[href=http://google.com]', 'Google') // <a id='google' class='external' href='http://google.com'>Google</a>

z('div', {style: {border: '1px solid red'}})  // <div style='border:1px solid red;'></div>
```

```js
z('ul',
  z('li', 'item 1'),
  z('li', 'item 2')
)

/*
<ul>
    <li>item 1</li>
    <li>item 2</li>
</ul>
*/
```

### Zorium Components

Zorium components can be used in place of a virtual-dom node.  
Zorium components must have a `render()` method

CoffeeScript

```coffee
class HelloWorldComponent
  render: ->
    z 'span', 'Hello World'

hello = new HelloWorldComponent()

z 'div', hello # <div><span>Hello World</span></div>
```

JavaScript

```js
function HelloWorldComponent() {
  return {
    render: function () {
      return z('span', 'Hello World')
    }
  }
}

hello = new HelloWorldComponent()

z('div', hello) // <div><span>Hello World</span></div>
```

#### Lifecycle Hooks

If a component has a hook method defined, it will be called

CoffeeScript

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

JavaScript

```js
function HelloWorldComponent() {
  return {
    onMount: function ($el) {
      // called after $el has been inserted into the DOM
      // $el is the rendered DOM node
    },
    onBeforeUnmount: function () {
      // called before the element is removed from the DOM
    },
    render: function () {
      return z('span', 'Hello World')
    }
  }
}
```

### Routing

#### Example

CoffeeScript

```coffee
class App
  constructor: (params) ->
    @state = z.state
      key: params.key or 'none'

  render: =>
    z 'div', 'Hello ' + @state().key

root = document.createElement 'div'

z.router.setMode 'pathname' # 'pathname' or 'hash' (default is 'hash')

z.router.setRoot root
z.router.add '/test', App
z.router.add '/test/:key', App

z.router.go '/test'
```

JavaScript

```js
function App(params) {
  var state = z.state({key: params.key || 'none'})

  return {
    state: state,
    render: function () {
      return z('div', 'Hello ' + state().key)
    }
  }
}

var root = document.createElement('div');

z.router.setMode('pathname');

z.router.setRoot(root);
z.router.add('/test', App);
z.router.add('/test/:key', App);

z.router.go('/test');
```


#### z.router.setMode()

```coffee
z.router.setMode('hash') # (default) clay.io/#/path
z.router.setMode('pathname') # clay.io/pathname
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

Variables will be passed into the component constructor

CoffeeScript

```coffee
###
@param {String} path
@param {ZoriumComponent} App
###
z.router.add '/test/:key', App

class App
  constructor: (params) ->
```

JavaScript

```js
/*
@param {String} path
@param {ZoriumComponent} App
*/
z.router.add('/test/:key', App)

function App(params) {
  // ...
}
```

#### z.router.go()

Navigate to a route

```coffee
z.router.go('/test/one')
```

### z.router.a()

automatically route anchor `<a>` tags

```coffee
z('div',
  z.router.a('.myclass[href=/abc]', 'click me')
)
```


### Rendering

#### z.render()

```coffee
###
@param {HtmlElement} root
@param {ZoriumComponent} App
###
z.render(document.body, App)
```

#### z.redraw()

Redraw all previously rendered elements  
This is called whenever a component's `state` is changed  
Call this whenever something changes the DOM state

```coffee
z.render(document.body, z('div'))
z.redraw()
```

### State

#### z.state()

Partial updating state object  
When set as a property of a Zorium Component, `z.redraw()` will automatically be called  
If passed a `z.observe`, an update is triggered on child updates

```js
promise = new Promise()

state = z.state({
  a: 'abc',
  b: 123,
  c: [1, 2, 3],
  d: z.observe(promise)
})

state() == {
  a: 'abc',
  b: 123,
  c: [1, 2, 3],
  d: null
}

promise.resolve(123)

// promise resolved
state().d == 123

// watch for changes
state(function (state) {
  state.b == 321
})

// partial update
state.set({
  b: 321
})
state() == {
  a: 'abc',
  b: 123,
  c: [1, 2, 3],
  d: 123
}
```

#### z.observe()

Create an observable  
Promises observe to `null` until resolved (but still have promise methods)

```js
a = z.observe('a')
a() == 'a'

a(function (change) {
  change == 'b'
})

a.set('b')

promise = new Promise()
p = z.observe(promise)
p() == null
promise.resolve(1)

p.then(function () {
  p() == 1
})

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

CoffeeScript

```coffee
module.exports = class MyAbc
  render: ->
    # define view
```

JavaScript

```js
module.exports = function MyAbc() {
  return {
    render: function () {
      // z()
    }
  }
}
```

### Models

Models are used for storing application state, as well as making resource API requests
Models are singletons of the form  

CoffeeScript

```coffee
class AbcModel
  # define model methods

module.exports = new AbcModel()
```

JavaScript

```js
function AbcModel() {
  // ...
}

module.exports = new AbcModel()
```

### Pages

Pages are components which are routed to via the router.  
They should contain as little logic as possible, and are responsible for laying out
components on the page.

CoffeeScript

```coffee
module.exports = class HomePage
  constructor: (params) ->
    @state = z.state
      nav: new require('../components/nav')()
      body: new require('../components/body')(params.key)

  render: =>
    z 'div',
      @state().nav
      @state().body
```

JavaScript

```js
module.exports = function HomePage(params) {
  state = z.state({
    nav: new require('../components/nav')(),
    body: new require('../components/body')(params.key)
  })

  return {
    render: function () {
      z('div',
        state().nav,
        state().body
      )
    }
  }
}
```

##### Page Extension

If extending a root page with sub-pages is desired, subclass.

CoffeeScript

```coffee
class RootPage
  constructor: ->
    @state = z.state
        nav: new require('../components/nav')()
        footer: new require('../components/footer')()

  render: =>
    z 'div',
      @state().nav
      @state().footer

class APage extends RootPage
  constructor: (params) ->
    super(params)

    @state.set
      footer: new require('../components/otherFooter')()
```

JavaScript

```js
// TODO
```


### Services

Services are singletons of the form

CoffeeScript

```coffee
class AbcService
  # define service methods

module.exports = new AbcService()
```

JavaScript

```js
function AbcService() {
  // ...
}

module.exports = new AbcService()
```
