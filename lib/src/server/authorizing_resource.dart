part of restlib.server;

class _AuthorizingResource<T> extends Object with ForwardingResource<T> {
  final ImmutableDictionary<String, Authorizer> _authorizerMap;
  final Future<Response> _unauthorizedResponse;
  final Resource<T> delegate;
  
  _AuthorizingResource(this.delegate, final ImmutableDictionary<String, Authorizer> authorizerMap) : 
    this._authorizerMap = authorizerMap,
    this._unauthorizedResponse =  
      new Future.value(
        new Response(
            Status.CLIENT_ERROR_UNAUTHORIZED, 
            entity : Status.CLIENT_ERROR_UNAUTHORIZED.reason,
            authenticationChallenges : authorizerMap.map((final Pair<String, Authorizer> pair) =>
                pair.snd.authenticationChallenge)));
  
  Future<Response> handle(final Request request) =>
      request.authorizationCredentials
        .flatMap((final ChallengeMessage message) => 
          _authorizerMap[message.scheme.toLowerCase()]
            .map((final Authorizer authorizer) => 
                authorizer
                  .authenticate(request)
                  .then((final bool authenticated) => 
                      authenticated ? super.handle(request) : CLIENT_ERROR_FORBIDDEN ))
                  // Intentionally let the error be thrown. Connectors catch 
                  // exception and return SERVER_ERROR_INTERNAL         
        ).orElse(_unauthorizedResponse);     
}