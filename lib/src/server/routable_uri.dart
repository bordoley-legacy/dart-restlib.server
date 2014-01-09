part of restlib.server;

@proxy
class RoutableUri extends NoSuchMethodForwarder implements Uri {
  static RoutableUri parse(String uri) {
    return new RoutableUri.wrap(Uri.parse(uri));
  }
  
  factory RoutableUri.wrap(Uri uri){
    if (uri is RoutableUri) {
      return uri;
    } else {
      return new RoutableUri._internal(uri);
    }
  }
  
  _Path _pathSegmentsInternal = null;

  RoutableUri._internal(uri) : super(uri);
  
  int get hashCode =>
      delegate.hashCode;

  _Path get _pathSegments {
    if(_pathSegmentsInternal == null) {
      _pathSegmentsInternal = _Path.parse(this.path);
    }
    return _pathSegmentsInternal;
  }
  
  bool operator==(other) =>
      delegate == other;
}

class _Path {
  static final _Path _FORWARD_SLASH_PATH = parse("/");
  
  static _Path parse(String path) {
    return new _Path._internal(Persistent.EMPTY_SEQUENCE.addAll(path.split("/")));
  }
  
  final ImmutableSequence<String> segments;
  
  _Path._internal(this.segments);
  
  _Path canonicalize() {
    if (segments.isEmpty) {
      return _FORWARD_SLASH_PATH;
    } else if (segments.length == 2) {
      if (segments.every((String str) => str.isEmpty)) {
        return _FORWARD_SLASH_PATH;
      } else if (segments.elementAt(1).isEmpty) {
        return new _Path._internal(segments.take(1));
      } else {
        return this;
      }           
    } else {
      List<String> buffer = []..addAll(segments);
      for (int i = 1; i < buffer.length-1; i++) {
        if (buffer[i].isEmpty) {
          buffer.removeAt(i);
          i--;
        }
      }

      if (equal(buffer, _FORWARD_SLASH_PATH.segments)) {
        return _FORWARD_SLASH_PATH;
      }
      
      if (buffer.elementAt(buffer.length -1).isEmpty) {
        buffer.remove(buffer.length - 1);
      }
      
      if (equal(buffer, segments)) {
        return this;
      }
      return new _Path._internal(Persistent.EMPTY_SEQUENCE.addAll(buffer));
    }  
  }
  
  String toString() => segments.join("/");
}