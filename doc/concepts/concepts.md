Delegates, annotation, and aspects.

Composites may delegate variables and actions to components. Multiple aspects can be woven into a single delegate.

```

stella NamedLocations {
    stella Element {
        lat: float
        lon: float
        name: string
        set * by default, injection
        injection
    }

    places: KDTree(2, Element) {
        {dimensions...} by Element.{lat, lon}
    }
    names: HashMap(Element) {
        key by Element.name
    }

    insert by places:insert, names:insert
    remove by places:remove, names:remove

    update by places:update, names:update

    nearest by places:find

    name by names:find

}

var tenNearest = locs:nearest(44, -103):take(10):toList()

var school = locs:name "SDSM&T" :first()

```

The hybrid collection NamedLocations allows places to be looked up by their locations or their names
by delegating the operations into a KDTree and a HashMap over an element type. Element delegates setting
to both the default set action and to permit the collections to inject custom handling for modifications.
This allows edited elements to instantly reflect their changes in the collection's lookups.

```
var nearestGasStation = from l in locs:nearest(44, -103) filter l.name == "gas station" first end
```

Use a query over the nearest neighbors to find a named point nearby.

```
from click in map:clicks() map coords = map:screenToGeo(click.pos) flatmap loc = locs:nearest(coords) each print(loc) end
```

Handle events with an asynchronous query stream.