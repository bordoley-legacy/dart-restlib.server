part of restlib.server;

abstract class Resource<T> {
  static const Resource NOT_FOUND = const _NotFoundResource();
  
  factory Resource.authorizingResource(final Resource<T> delegate, final Iterable<Authorizer> authorizer) {
    final ImmutableDictionary<String, Authorizer> authorizerMap = 
        Persistent.EMPTY_DICTIONARY.insertAll(authorizer.map((final Authorizer authorizer) =>
            new Pair(authorizer.scheme, authorizer)));
    
    return new _AuthorizingResource<T> (delegate, authorizerMap);
  }
  
  factory Resource.byteRangeResource(final Resource<T> delegate) =>
      new _ByteRangeResource(delegate);
  
  factory Resource.uniform(final UniformResourceDelegate<T> delegate) {
    final ImmutableSet<Method> allowedMethods = UniformResourceDelegate._getImplementedMethods(delegate);
    return new _UniformResource._internal(delegate, allowedMethods);
  }
  
  Route get route;

  Request filterRequest(final Request request);
  Response filterResponse(final Response response);
  Future<Response> handle(Request request);
  Future<Response> acceptMessage(Request<T> request);
}

class _NotFoundResource implements Resource {
  const _NotFoundResource();
  
  Route get route => null;
  
  Request filterRequest(final Request request) =>
      request;
  
  Response filterResponse(final Response response) =>
      response;
  
  Future<Response> handle(Request request) => 
      CLIENT_ERROR_NOT_FOUND;
  
  Future<Response> acceptMessage(Request request) => 
      CLIENT_ERROR_NOT_FOUND;
}

abstract class ForwardingResource<T> implements Forwarder, Resource<T> {    
  Route get route => delegate.route;

  Request filterRequest(final Request request) =>
      delegate.filterRequest(request);
  
  Response filterResponse(final Response response) =>
      delegate.filterResponse(response);
  
  Future<Response> handle(final Request request) => delegate.handle(request);
  
  Future<Response> acceptMessage(final Request<T> request) => delegate.acceptMessage(request);
}
