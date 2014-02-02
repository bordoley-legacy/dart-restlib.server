part of restlib.server;

final RuneMatcher _NOT_SLASH = FORWARD_SLASH.negate();

final Parser<String> _GLOB_SEGMENT = 
  (ASTERISK + _NOT_SLASH.many1()).map((final Iterable e) => 
      "*${e.elementAt(1)}");

final Parser<String> _PARAMETER_SEGMENT =
  (COLON + _NOT_SLASH.many1()).map((final Iterable e) =>
      ":${e.elementAt(2)}");

final Parser<Route> ROUTE = 
  (PCHAR.orElse("") | _GLOB_SEGMENT | _PARAMETER_SEGMENT).sepBy(FORWARD_SLASH).map((final Iterable<String> e) {    
    if (e.length == 1 && e.first.isEmpty) {
      return Route.EMPTY;
    }
    
    final MutableSet<String> keys = new MutableSet.hash();
    Option<String> previous = Option.NONE;
    
    for (final String seg in e) {
      // Prevent duplicate keys in the route
      final Option<String> glob = _globSegment(seg);
      final Option<String> parameter = _parameterSegment(seg);

      if ((glob.isNotEmpty || parameter.isNotEmpty) && keys.contains(seg.substring(1))) {
        return null; 
      }
      
      glob.map(keys.add);
      parameter.map(keys.add);
      
      // Prevent multiple glob segments one after another
      if ((glob.isNotEmpty || parameter.isNotEmpty) && previous.isNotEmpty) {
        return null;
      }
      
      previous = glob;
    }
    
    return new _Route(Persistent.EMPTY_SEQUENCE.addAll(e));
  });


Option<String> _globSegment(final String segment) =>
    segment.startsWith("*") ? new Option(segment.substring(1)) : Option.NONE;
    
Option<String> _parameterSegment(final String segment) =>
    segment.startsWith(":") ? new Option(segment.substring(1)) : Option.NONE;     

abstract class Route implements ImmutableSequence<String> {
  static final Route EMPTY = new _Route(Persistent.EMPTY_SEQUENCE);
  
  Route add(String value);
  Route addAll(Iterable<String> elements);
  ImmutableDictionary<String, String> parsePathParameters(URI uri);
  Route push(String value);
  Route put(int key, String value);
  Route putAll(Iterable<Pair<int, String>> other);
  Route putPair(Pair<int, String> pair);
  Route remove(String element);
  Route removeAt(int key);
}

class _Route
    extends Object
    with ForwardingSequence<String>,
      ForwardingAssociative<int, String>,
      ForwardingIterable<String>
    implements Route {
  final ImmutableSequence<String> delegate;
  
  _Route(this.delegate);
  
  Route get tail =>
      new _Route(delegate.tail);
  
  Route add(final String value) =>
      // FIXME: validate
      new _Route(delegate.add(value));
  
  Route addAll(final Iterable<String> elements) =>
      new _Route(delegate.addAll(elements.map((final String segment) {
        // FIXME: validate segment
        return segment;
      })));
  
  ImmutableDictionary<String, dynamic> parsePathParameters(final URI uri) {  
    ImmutableDictionary<String, dynamic> retval = Persistent.EMPTY_DICTIONARY;
    final Path path = uri.path.canonicalize();
    
    int i = 0, j = 0;
    for (; i < length && j < path.length; i++, j++) {
      final String routeSegment = this.elementAt(i);
      final String pathSegment = path.elementAt(j);
      
      retval = _globSegment(routeSegment)
        .map((final String name) {
          final Option<String> stopSegment = this[i+1];
          Path globPath = Path.EMPTY.add(pathSegment);
          
          for(j++; j < path.length; j++) {
            final String segment = path.elementAt(j);
            if (!stopSegment.contains(segment)) {
              globPath = globPath.add(segment);
            } else {
              j--;
              break;
            }
          }
          
          // FIXME: Actually returning a path could be a nice feature
          return retval.put(name, globPath.toString());      
        }).orCompute(() =>
            _parameterSegment(routeSegment)
              .map((final String name) =>
                  retval.put(name, pathSegment))
              .orCompute(() =>
                  routeSegment == pathSegment ? 
                      retval : throw new ArgumentError("$uri does not match route $this")));
    }
    
    if (i < length || j < path.length) {
      throw new ArgumentError("$uri does not match route $this");
    }
    
    return retval;
  }
  
  Route push(final String value) =>
      add(value);
  
  Route pushAll(final Iterable<String> elements) =>
      new _Route(delegate.pushAll(elements.map((final String segment) {
        // FIXME: validate segment
        return segment;
      })));

  Route put(final int key, final String segment) {
    // FIXME: validate segment
    new _Route(delegate.put(key, segment));
  }
  
  Route putAll(final Iterable<Pair<int, String>> other) {
    checkNotNull(other);
    return other.fold(this, (final Route route, final Pair<int,String> pair) =>
        route.putPair(pair));
  }
  
  Route putAllFromMap(final Map<int, String> map) =>
      putAll(new Dictionary.wrapMap(map));
  
  Route putPair(final Pair<int, String> pair) {
    checkNotNull(pair);
    return put(pair.fst, pair.snd);
  }
      
  Route remove(final String element) =>
      new _Route(delegate.remove(element));
  
  Route removeAt(final int key) =>
      new _Route(delegate.removeAt(key));

  String toString() => 
      join("/");
}