![Zorium](./zorium.png)

(╯°□°)╯︵ ┻━┻

## Examples

Javascript

```js
z = require('zorium')

function AppComponent() {
  var name = 'Zorium'
  var clicker = function (e) {
    console.log('Click!')
    z.redraw()
  }

  return {
    render: function () {
      return z('a.zorium-link[href=/]', [
        z('img[src=' + name + '.png]',
          {onclick: clicker})
      ])
    }
  }
}

z.render(document.body, new AppComponent())
```

CoffeeScript

```coffee
z = require 'zorium'

class AppComponent
  constructor: ->
    @name = 'Zorium'

  clicker: ->
    console.log 'Click!'
    z.redraw()

  render: ->
    z 'a.zorium-link[href=/]',
      z "img[src=#{@name}.png]", onclick: @clicker

z.render document.body, new AppComponent()
```

## API

### z()

```js
z('.container') //yields <div class='container'></div>

z('#layout') //yields <div id='layout'></div>

z('a[name=top]') //yields <a name='top'></a>

z('[contenteditable]') //yields <div contenteditable='true'></div>

z('a#google.external[href='http://google.com']', 'Google') //yields <a id='google' class='external' href='http://google.com'>Google</a>

z('div', {style: {border: '1px solid red'}}) //yields <div style='border:1px solid red;'></div>
```

```coffee
z 'ul',
  z 'li', 'item 1'
  z 'li', 'item 2'

###
yields
<ul>
    <li>item 1</li>
    <li>item 2</li>
</ul>
###
```

### Zorium Components

Zorium components can be used in place of a virtual-dom node.  
Zorium components must have a `render()` method

```js
function HelloWorldComponent() {
  return {
    render: function() {
      return z('span', 'Hello World');
    }
  }
}

hello = new HelloWorldComponent();

z('div', hello); // <div><span>Hello World</span></div>
```

```coffee
class HelloWorldComponent
  render: ->
    z 'span', 'Hello World'

hello = new HelloWorldComponent()

z 'div', hello # <div><span>Hello World</span></div>
```

#### Lifecycle Hooks

If a component has a hook method defined, it will be called

```js
function BindComponent() {
  return {
    onMount: function($el) {
      // called after $el has been inserted into the DOM
      // $el is the rendered DOM node
    },
    onBeforeUnmount: function() {
      // called before the element is removed from the DOM
    },
    render: function() {
      return z('div',
                z('span', 'Hello World'),
                z('span', 'Goodbye'));
    }
  }
}
```

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
    @key = params.key or 'none'

  render: =>
    z 'div', 'Hello ' + @key

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
    @key = params.key or 'none'

```

#### z.router.go()

Navigate to a route

```coffee
z.router.go '/test/one'
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
Call this whenever something changes the DOM state

```coffee
z.render z 'div'
z.redraw()
```
