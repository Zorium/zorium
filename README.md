![Zorium](./zorium.png)

(╯°□°)╯︵ ┻━┻  
v0.3.0

## Examples

CoffeeScript

```coffee
z = require 'zorium'

class AppComponent
  constructor: (params) ->
    @state = z.observe
      z: 'Zorium'

  clicker: (e) =>
    console.log 'Click!'
    @state.set
      z: 'AllOfTheThings'

  render: =>
    z 'a.zorium-link[href=/]',
      z "img[src=#{@state.z()}.png]", onclick: @clicker

z.render document.body, new AppComponent()
```

## API

### z()

```js
z '.container'  // <div class='container'></div>

z '#layout'  // <div id='layout'></div>

z 'a[name=top]'  // <a name='top'></a>

z '[contenteditable]'  // <div contenteditable='true'></div>

z 'a#google.external[href=http://google.com]', 'Google'  // <a id='google' class='external' href='http://google.com'>Google</a>

z 'div', {style: {border: '1px solid red'}}  // <div style='border:1px solid red;'></div>
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

Zorium components can be used in place of a virtual-dom node.  
Zorium components must have a `render()` method

```coffee
class HelloWorldComponent
  render: ->
    z 'span', 'Hello World'

hello = new HelloWorldComponent()

z 'div', hello # <div><span>Hello World</span></div>
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
    @state = z.observe
      key: params.key or 'none'

  render: =>
    z 'div', 'Hello ' + @state.key()

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
z.router.setRoot document.body
```

#### z.router.add()

Variables will be passed into the component constructor

```coffee
###
@param {String} path
@param {ZoriumComponent} App
###
z.router.add '/test/:key', App

class App
  constructor: (params) ->
```

#### z.router.go()

Navigate to a route

```coffee
z.router.go '/test/one'
```

### z.router.a()

automatically route anchor `<a>` tags

```coffee
z 'div',
  z.router.a '.myclass[href=/abc]', 'click me'
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

Redraw all previously rendered elements  
This is called whenever a component's `state` is changed  
Call this whenever something changes the DOM state

```coffee
z.render document.body, z 'div'
z.redraw()
```

### State

#### z.observe()

When set as a property of a Zorium Component, `z.redraw()` will automatically be called  
If passed a `Promise`, the value will be set to `null` until the promise resolves (causing an update). If the promise rejects, the value stays `null`

```coffee
promise = new Promise (@resolve, reject) -> null
value = z.observe
  a: 'abc'
  b: 123
  c: [1, 2, 3]
  d: promise

value.a() == 'abc'
value.b() == 123
value.c() == [1, 2, 3]
value.d() == null

value.d.resolve(123)

value.d() == 123

value (value) ->
  value.a == 'def'

value.a.set 'def'
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

Components should set `@state` as a `z.observe` when using local state
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

Model methods should wrap their returned values in a `z.observe`, including promises  
e.g.

```coffee
return z.observe new Promise (resolve) -> resolve {abc: 'def'}
```

### Pages

Pages are components which are routed to via the router.  
They should contain as little logic as possible, and are responsible for laying out
components on the page.

```coffee
module.exports = class HomePage
  constructor: (params) ->
    @state = z.observe
      nav: new require('../components/nav')()
      body: new require('../components/body')(params.key)

  render: =>
    z 'div',
      @state.nav()
      @state.body()
```

##### Page Extension

If extending a root page with sub-pages is desired, subclass.

```coffee
class RootPage
  constructor: ->
    @state = z.observe
        nav: new require('../components/nav')()
        footer: new require('../components/footer')()

  render: =>
    z 'div',
      @state.nav()
      @state.footer()

class APage extends RootPage
  constructor: (params) ->
    super(params)

    @state.set
      footer: new require('../components/otherFooter')()
```


### Services

Services are singletons of the form

```coffee
class AbcService
  # define service methods

module.exports = new AbcService()
```
