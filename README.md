[![Zorium](./zorium_logo.png)](https://zorium.org/)

## [Zorium](https://zorium.org/) - The Functional Reactive CoffeeScript Web

#### [zorium.org](https://zorium.org/)

(╯°□°)╯︵ ┻━┻  
v1.0.0-rc12

### Features

  - First Class [RxJS Observables](https://github.com/Reactive-Extensions/RxJS)
  - Built for Isomorphism (server-side rendering)
  - Fast! - [virtual-dom](http://vdom-benchmark.github.io/vdom-benchmark/)
  - Standardized [Best Practices](https://zorium.org/best-practices)
  - [Material Design Components](https://zorium.org/paper)
  - Production-ready [Seed Project](https://github.com/Zorium/zorium-seed)
  - It's just CoffeeScript, no magic

### Example

```coffee
z = require 'zorium'

class AppComponent
  constructor: ->
    @state = z.state
      name: 'Zorium'

  render: =>
    {name} = @state.getValue()

    z '.zorium',
      z 'p.text',
        "The Future -#{name}"

z.render document.body, new AppComponent()
```

### Documentation

[zorium.org](https://zorium.org/)

### Installation

```bash
npm install --save zorium
```

### Contribute

```bash
npm install
npm test
```

Documentation -  [zorium-site](https://github.com/Zorium/zorium-site)

IRC: `#zorium` - chat.freenode.net
