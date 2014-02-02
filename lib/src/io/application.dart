part of restlib.server.io;

abstract class Application {
  factory Application(
      Option<IOResource> resourceForPath(final Sequence<String> path),
      {final IOResource defaultResource : IOResource.NOT_FOUND,
       Request requestFilter(Request request) : identity,
       Response responseFilter(Response response) : identity}) =>
      new _ApplicationImpl(
          resourceForPath, defaultResource,
          requestFilter, responseFilter);
  
  Request filterRequest(final Request request);
  Response filterResponse(final Response response);
  IOResource route(final Request request);
  Future writeError(Request request, Response response, StreamSink<List<int>> msgSink);
}

abstract class ForwardingApplication implements Forwarder, Application {
  Request filterRequest(final Request request) =>
      delegate.filterRequest(request);
  
  Response filterResponse(final Response response) =>
      delegate.filterResponse(response);
      
  IOResource route(final Request request) =>
      delegate.route(request);
  
  Future writeError(Request request, Response response, StreamSink<List<int>> msgSink) =>
      delegate.writeError(request, response, msgSink);
}

typedef Request _RequestFilter(Request request);
typedef Response _ResponseFilter(Response response);
typedef Option<IOResource> _ResourceForPath(final Sequence<String> path);
class _ApplicationImpl implements Application {  
  final IOResource _defaultResource;
  final _ResourceForPath _resourceForPath;
  final _RequestFilter requestFilter;
  final _ResponseFilter responseFilter;
  
  _ApplicationImpl(this._resourceForPath, this._defaultResource, this.requestFilter, this.responseFilter);
  
  Request filterRequest(final Request request) => 
      requestFilter(request);
  
  Response filterResponse(final Response response) => 
      responseFilter(response);
  
  IOResource route(final Request request) =>
      _resourceForPath(request.uri.path).orElse(_defaultResource);
  
  Future writeError(final Request request, final Response response, final StreamSink<List<int>> msgSink) =>
      writeString(request, response, msgSink);
}