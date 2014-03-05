part of server;

abstract class Resource<T> {
  factory Resource.authorizingResource(final Resource<T> delegate, final Iterable<Authorizer> authorizer) {
    final ImmutableDictionary<String, Authorizer> authorizerMap =
        EMPTY_DICTIONARY.putAll(authorizer.map((final Authorizer authorizer) =>
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

abstract class ForwardingResource<T> implements Forwarder, Resource<T> {
  Route get route => delegate.route;

  Request filterRequest(final Request request) =>
      delegate.filterRequest(request);

  Response filterResponse(final Response response) =>
      delegate.filterResponse(response);

  Future<Response> handle(final Request request) => delegate.handle(request);

  Future<Response> acceptMessage(final Request<T> request) => delegate.acceptMessage(request);
}
