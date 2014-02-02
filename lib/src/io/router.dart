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
  
  final Option<IOResource> _value;
  final ImmutableDictionary<String, Router> _children;
  
  const Router._internal(this._value, this._children);

  int get hashCode =>
      computeHashCode([_value, _children]);
  
  bool operator==(other) {
    if (identical(this, other)) {
      return true;
    } else if (other is Router) {
      return this._value == other._value &&
          this._children == other._children;
    }
  }
  
  Option<IOResource> operator[](final Sequence<String> path) {
    if (path.isEmpty) {
      return _value;
    } else {
      Sequence<String> tail = path.subSequence(1, path.length - 1);
      
      Option<Router> nextRouter = _children[path.first];
      if (nextRouter.isNotEmpty) {
        for(final IOResource resource in nextRouter.value[tail]) {
          return new Option(resource);
        }       
      }
      
      nextRouter = _children[":"];
      if (nextRouter.isNotEmpty) {
        for (final IOResource resource in nextRouter.value[tail]) {
          return new Option(resource);
        }
      }
      
      nextRouter = _children["*"];
      if (nextRouter.isNotEmpty) { 
        while(tail.length > 0) {
          final Sequence<String> newTail = tail.subSequence(1, tail.length - 1); 
          
          if (nextRouter.value._children.containsKey(tail.first)) {
            return nextRouter.value._children[tail.first].value[newTail];
          }

          tail = newTail;
        }
        return this._value;
      }
      
      return Option.NONE;
    }
  }
  
  Option<IOResource> call(final Sequence<String> path) =>
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
      return new Router._internal(this._value, _children.put(key, newChild));
    }
  }
  
  String toString() =>
      "\nRouter($_children)";
}