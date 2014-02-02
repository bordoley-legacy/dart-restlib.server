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
  
  final Option<IOResource> value;
  final ImmutableDictionary<String, Router> children;
  
  const Router._internal(this.value, this.children);

  int get hashCode =>
      computeHashCode([value, children]);
  
  bool operator==(other) {
    if (identical(this, other)) {
      return true;
    } else if (other is Router) {
      return this.value == other.value &&
          this.children == other.children;
    }
  }
  
  Option<IOResource> operator[](final Sequence<String> path) {
    if (path.isEmpty) {
      return value;
    } else {
      Sequence<String> tail = path.subSequence(1, path.length - 1);
      
      Option<Router> nextRouter = children[path.first];
      if (nextRouter.isNotEmpty) {
        for(final IOResource resource in nextRouter.value[tail]) {
          return new Option(resource);
        }       
      }
      
      nextRouter = children[":"];
      if (nextRouter.isNotEmpty) {
        for (final IOResource resource in nextRouter.value[tail]) {
          return new Option(resource);
        }
      }
      
      nextRouter = children["*"];
      if (nextRouter.isNotEmpty) { 
        while(tail.length > 0) {
          final Sequence<String> newTail = tail.subSequence(1, tail.length - 1); 
          
          if (nextRouter.value.children.containsKey(tail.first)) {
            return nextRouter.value.children[tail.first].value[newTail];
          }

          tail = newTail;
        }
        return this.value;
      }
      
      return Option.NONE;
    }
  }
  
  Option<IOResource> call(final Sequence<String> path) =>
      this[path];
  
  Router put(final Sequence<String> route, final IOResource resource) {
    checkNotNull(route);
    checkNotNull(resource);
    
    if (route.isEmpty) {
      return new Router._internal(new Option(resource), this.children);
    } else {
      final String key = _routeSegmentToKey(route.first);
      // FIXME: length should be optional;
      // FIXME: subsequence should return ImmutableSequence
      final Sequence<String> tail = route.subSequence(1, route.length-1);
      
      final Router newChild = children[key]
        .map((final Router next) =>
          next.put(tail, resource))
        .orCompute(() =>
            Router.EMPTY.put(tail, resource));
      return new Router._internal(this.value, children.put(key, newChild));
    }
  }
  
  String toString() =>
      "\nRouter($children)";
}