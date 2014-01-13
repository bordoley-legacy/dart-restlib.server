part of restlib.server.io;

abstract class Application {
  factory Application(final Iterable<IOResource> resources, [final IOResource defaultResource = IOResource.NOT_FOUND]) =>
      new _ApplicationImpl(resources, defaultResource);
  
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

class _ApplicationImpl implements Application {  
  final IOResource _defaultResource;
  final ImmutableSequence<IOResource> _resources;
  
  _ApplicationImpl(final Iterable<IOResource> resources, final IOResource defaultResource):
    _resources = Persistent.EMPTY_SEQUENCE.addAll(resources),
    _defaultResource = (defaultResource == null) ? resources.first : defaultResource;
  
  Request filterRequest(final Request request) => 
      request;
  
  Response filterResponse(final Response response) => 
      response;
  
  IOResource route(final Request request) =>
      _resources.firstWhere((final IOResource resource) => 
          resource.route.matches(new RoutableUri.wrap(request.uri)),
        orElse: () => 
            _defaultResource);
  
  Future writeError(final Request request, final Response response, final StreamSink<List<int>> msgSink) =>
      writeString(request, response, msgSink);
}