part of restlib.server;

abstract class Application {
  factory Application(final Iterable<Resource> resources, [final Resource defaultResource = Resource.NOT_FOUND]) =>
      new _ApplicationImpl(resources, defaultResource);
  
  Request filterRequest(final Request request);
  Response filterResponse(final Response response);
  Resource route(final Request request);
}


class _ApplicationImpl implements Application {  
  final Resource _defaultResource;
  final ImmutableSequence<Resource> _resources;
  
  _ApplicationImpl(final Iterable<Resource> resources, final Resource defaultResource):
    _resources = Persistent.EMPTY_SEQUENCE.addAll(resources),
    _defaultResource = (defaultResource == null) ? resources.first : defaultResource;
  
  Request filterRequest(final Request request) => 
      request;
  
  Response filterResponse(final Response response) => 
      response;
  
  Resource route(final Request request) {
    return _resources.firstWhere(
        (Resource resource) => resource.route.matches(new RoutableUri.wrap(request.uri)),
        orElse: () => _defaultResource);

  }
}

abstract class ForwardingApplication implements Forwarder, Application {
  Request filterRequest(final Request request) =>
      delegate.filterRequest(request);
  
  Response filterResponse(final Response response) =>
      delegate.filterResponse(response);
  
  Resource rout(final Request request) =>
      delegate.route(request);
}