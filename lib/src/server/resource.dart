part of restlib.server;

abstract class Resource<T> {
  static const Resource NOT_FOUND = const _NotFoundResource();
  
  factory Resource.authorizingResource(Resource<T> next, Iterable<Authorizer> authorizer) {
    ImmutableDictionary<String, Authorizer> authorizerMap = 
        Persistent.EMPTY_DICTIONARY.insertAll(authorizer.map((final Authorizer authorizer) =>
            new Pair(authorizer.scheme, authorizer)));
    
    return new _AuthorizingResource<T> (next, authorizerMap);
  }
  
  factory Resource.byteRangeResource(delegate) =>
      new _ByteRangeResource(delegate);
  
  Route get route;

  Future<Response> handle(Request request);
  Future<Response> acceptMessage(Request<T> request);
}

class _NotFoundResource implements Resource {
  const _NotFoundResource();
  
  Route get route => null;
  
  Future<Response> handle(Request request) => CLIENT_ERROR_NOT_FOUND;
  Future<Response> acceptMessage(Request request) => CLIENT_ERROR_NOT_FOUND;
}

abstract class ForwardingResource<T> implements Forwarder, Resource<T> {    
  Route get route => delegate.route;

  Future<Response> handle(final Request request) => delegate.handle(request);
  Future<Response> acceptMessage(final Request<T> request) => delegate.acceptMessage(request);
}

class _AuthorizingResource<T> extends Object with ForwardingResource<T> {
  final ImmutableDictionary<String, Authorizer> _authorizerMap;
  final Future<Response> _unauthorizedResponse;
  final Resource<T> delegate;
  
  _AuthorizingResource(final Resource<T> next, final ImmutableDictionary<String, Authorizer> authorizerMap) : 
    this._authorizerMap = authorizerMap,
    this._unauthorizedResponse =  
      new Future.value(
        (new ResponseBuilder()
        ..entity = Status.CLIENT_ERROR_UNAUTHORIZED.reason
        ..status = Status.CLIENT_ERROR_UNAUTHORIZED
        ..addAuthenticationChallenges(
            authorizerMap.map((final Pair<String, Authorizer> pair) =>
                pair.snd.authenticationChallenge))
        ).build()),
    this.delegate = next;
  
  Future<Response> handle(final Request request) =>
      request.authorizationCredentials
        .flatMap((final ChallengeMessage message) => 
          _authorizerMap[message.scheme.toLowerCase()]
            .map((final Authorizer authorizer) => 
                authorizer
                  .authenticate(message)
                  .then((final bool authenticated) => 
                      authenticated ? super.handle(request) : CLIENT_ERROR_FORBIDDEN ))
                  // Intentionally let the error be thrown. Connectors catch 
                  // exception and return SERVER_ERROR_INTERNAL         
        ).orElse(_unauthorizedResponse);     
}

