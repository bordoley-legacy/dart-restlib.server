part of restlib.server.io;

class Router {
  static const Router EMPTY = const Router._internal(Option.NONE, Persistent.EMPTY_DICTIONARY);
  
  static String _routeSegmentToKey(final String segment) {
    if (segment.startsWith("*")) {
      return "*";
    } else if (segment.startsWith(":")) {
      return ":";
    } else {
      return segment;
    }
  }
  
  final Option<IOResource> _resource;
  final ImmutableDictionary<String, Router> _children;
  
  const Router._internal(this._resource, this._children);

  int get hashCode =>
      computeHashCode([_resource, _children]);
  
  bool operator==(other) {
    if (identical(this, other)) {
      return true;
    } else if (other is Router) {
      return this._resource == other._resource &&
          this._children == other._children;
    }
  }
  
  Option<IOResource> operator[](final Path path) =>
      _doPathLookup(path);

  Option<IOResource> _doPathLookup(final Sequence<String> path) {
    if (path.isEmpty) {
      return _resource;
    } else {
      Sequence<String> tail = path.subSequence(1, path.length - 1);

      for(final Router nextRouter in _children[path.first]) {
        for(final IOResource resource in nextRouter._doPathLookup(tail)) {
          return new Option(resource);
        }       
      }
      
      for(final Router nextRouter in _children[":"]) {
        for (final IOResource resource in nextRouter._doPathLookup(tail)) {
          return new Option(resource);
        }
      }
      
      for(final Router nextRouter in _children["*"]) {
        while(tail.length > 0) {
          final Sequence<String> newTail = tail.subSequence(1, tail.length - 1); 
          
          for(final Router childRouter in nextRouter._children[tail.first]){
            return childRouter._doPathLookup(newTail);
          }

          tail = newTail;
        }
        return nextRouter._resource;
      }
      
      return Option.NONE;
    }
  }
  
  Option<IOResource> call(final Path path) =>
      this[path];
  
  Router put(final IOResource resource) =>
      _doPut(checkNotNull(checkNotNull(resource).route), resource);
  
  Router putAll(Iterable<IOResource> resources) =>
      resources.fold(this, (final Router acc, final IOResource resource) => 
          acc.put(resource)); 
  
  Router _doPut(final Sequence<String> route, final IOResource resource) {    
    if (route.isEmpty) {
      return new Router._internal(new Option(resource), this._children);
    } else {
      final String key = _routeSegmentToKey(route.first);
      // FIXME: length should be optional;
      // FIXME: subsequence should return ImmutableSequence
      final Sequence<String> tail = route.subSequence(1, route.length-1);
      
      final Router newChild = _children[key]
        .map((final Router next) =>
          next._doPut(tail, resource))
        .orCompute(() =>
            Router.EMPTY._doPut(tail, resource));
      return new Router._internal(this._resource, _children.put(key, newChild));
    }
  }
  
  String toString() =>
      "\nRouter($_children)";
}