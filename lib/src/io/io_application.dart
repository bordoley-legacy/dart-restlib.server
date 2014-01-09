part of restlib.server.io;

abstract class IOApplication implements Application {
  factory IOApplication(final Iterable<IOResource> resources, [final IOResource defaultResource = IOResource.NOT_FOUND]) =>
      new _IOApplicationImpl(resources, defaultResource);
  
  IOResource route(final Request request);
  
  Future writeError(Request request, Response response, IOSink msgSink);
}

// FIXME: Ideally this would inherit from ForwardingApplication
abstract class ForwardingIOApplication implements Forwarder, IOApplication {
  Request filterRequest(final Request request) =>
      delegate.filterRequest(request);
  
  Response filterResponse(final Response response) =>
      delegate.filterResponse(response);
      
  IOResource route(final Request request) =>
      delegate.route(request);
  
  Future writeError(Request request, Response response, IOSink msgSink) =>
      delegate.writeError(request, response, msgSink);
}

class _IOApplicationImpl 
    extends Object
    with ForwardingApplication
    implements IOApplication {
  
  final Application delegate;
  
  _IOApplicationImpl(final Iterable<IOResource> resources, final IOResource defaultResource) :
    delegate = new Application(resources, defaultResource);
  
  IOResource route(final Request request) =>
      delegate.route(request);
  
  Future writeError(Request request, Response response, IOSink msgSink) =>
      writeString(request, response, msgSink);
}