part of restlib.server;

// FIXME: Wrong = 
final Parser _PCHAR = noneOf("/").many1().map(objectToString);

final Parser<_GlobSegment> _GLOB =
  (GLOB + _PCHAR)
    .map((final Iterable e) =>
        new _GlobSegment(e.elementAt(1)));

final Parser<_ParameterSegment> _PARAMETER =
  (COLON + _PCHAR)
    .map((final Iterable e) =>
      new _ParameterSegment(e.elementAt(1)));

final Parser<_ValueSegment> _VALUE =
  _PCHAR.optional().map((final Option<String> seg) =>
      seg.isEmpty ? _EMPTY_SEGMENT : new _ValueSegment(seg.value));  

// FIXME: Clearly Either<> needs to provide methods to make this easier to unfold.
final Parser<_RouteSegment> _ROUTE_SEGMENT =
  (_GLOB ^ _PARAMETER ^ _VALUE)
    .map((final Either segment) => 
        segment.fold(
            (final Either left) => left.value,
            (final _RouteSegment right) => right));

Parser<Route> ROUTE =
  _ROUTE_SEGMENT.sepBy(FORWARD_SLASH)
    .map((final Iterable<_RouteSegment> e) {
      // FIXME: Fix MutableHashSet and use it.
      final Set<String> keys = new Set();
      
      _RouteSegment previous = null;
      
      for (final _RouteSegment seg in e) {
        // Prevent duplicate keys in the route
        if (((seg is _GlobSegment) || (seg is _ParameterSegment)) &&
            keys.contains(seg.name)) {
          return null; 
        }
        
        // Prevent multiple glob segments one after another
        if ((seg is _GlobSegment) && (previous is _GlobSegment)) {
          return null;
        }
        
        previous = seg;
        keys.add(seg.name);
      }
      
      return new Route._internal(e);
    });
            

const _RouteSegment _EMPTY_SEGMENT = const _ValueSegment("");    

abstract class _RouteSegment {
  String get name;
}

class _GlobSegment implements _RouteSegment {
  final String name;
  const _GlobSegment(this.name);
  
  String toString() => "*$name";
}

class _ParameterSegment implements _RouteSegment {
  final String name;
  const _ParameterSegment(this.name);
  
  String toString() => ":$name";
}

class _ValueSegment implements _RouteSegment {
  final String name;
  const _ValueSegment(this.name);
  
  String toString() => name;
}

class Route {    
  final Iterable<_RouteSegment> _segments;
  
  const Route._internal(this._segments);
  
  bool matches(Uri uri) {
    try {
      parsePathParameters(uri);
      return true;
    } on ArgumentError {
      return false;
    }
  }
  
  Dictionary<String, String> parsePathParameters(RoutableUri uri) {    
    Map<String, String> retval = new Map();

    ImmutableSequence uriSegments = uri._pathSegments.canonicalize().segments;
    
    int i = 0, j = 0;
    for (; i < _segments.length && j < uriSegments.length; i++, j++) {
      _RouteSegment routeSegment = _segments.elementAt(i);
      String pathSegment = uriSegments.elementAt(j);
      
      if (routeSegment is _GlobSegment) {
        String key = routeSegment.name;
        
        String stopSegment = (i+1 < _segments.length) ? _segments.elementAt(i+1).name : "";
        StringBuffer buffer = new StringBuffer("$pathSegment");
        
        for(j++; j < uriSegments.length; j++) {
          if (uriSegments.elementAt(j) != stopSegment) {
            buffer.write("/${uriSegments.elementAt(j)}");
          } else {
            j--;
            break;
          }
        }
        
        retval[key] = buffer.toString();
        
      } else if (routeSegment is _ParameterSegment) {
        String key = routeSegment.name;
        retval[key] = pathSegment;
        
      } else if (routeSegment.name != pathSegment) {
        throw new ArgumentError("$uri does not match route $this");
      }  
    }
    
    if (i < _segments.length || j < uriSegments.length) {
      throw new ArgumentError("$uri does not match route $this");
    }
    
    return Persistent.EMPTY_DICTIONARY.insertAllFromMap(retval);
  }
  
  String toString() => _segments.join("/");
}