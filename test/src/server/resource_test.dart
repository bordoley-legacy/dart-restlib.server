part of restlib.server_test;

authorizedResourceTests() {
  Resource mockAuthenticateTrueResource =
      new Resource.authorizingResource(
          new MockResource()
          ..when(callsTo("handle")).alwaysReturn(SUCCESS_OK),
          [new MockAuthorizer()
          ..when(callsTo("authenticate")).alwaysReturn(new Future.value(true))
          ..when(callsTo("get scheme")).alwaysReturn("basic")
          ..when(callsTo("get authenticationChallenge"))
          .alwaysReturn(
              ChallengeMessage.parse("basic realm=\"test\", encoding=\"UTF-8\""))]);

  Resource mockAuthenticateFalseResource =
      new Resource.authorizingResource(
          new MockResource()
          ..when(callsTo("handle")).alwaysReturn(SUCCESS_OK),
          [new MockAuthorizer()
          ..when(callsTo("authenticate")).alwaysReturn(new Future.value(false))
          ..when(callsTo("get scheme")).alwaysReturn("basic")
          ..when(callsTo("get authenticationChallenge"))
          .alwaysReturn(
              ChallengeMessage.parse("basic realm=\"test\", encoding=\"UTF-8\""))]);

  test("Request missing Authorization header", () {
    Request request = new Request(Method.GET, URI_.parseValue("http://www.example.com"));
    Future<Response> authResponse = mockAuthenticateTrueResource.handle(request);
    authResponse.then((Response response){
      expect(response.status, equals(Status.CLIENT_ERROR_UNAUTHORIZED));
    });
    expect(authResponse, completes);
  });

  test("Request authorization credentials with unsupported scheme", () {
    Request request =
        new Request(
            Method.GET,
            URI_.parseValue("http://www.example.com"),
            authorizationCredentials : ChallengeMessage.parse("INVALID ABCD=="));
    Future<Response> authResponse = mockAuthenticateTrueResource.handle(request);
    authResponse.then((Response response){
      expect(response.status, equals(Status.CLIENT_ERROR_UNAUTHORIZED));
    });
    expect(authResponse, completes);
  });

  test("Request authorization with valid credentials", (){
    Request request =
        new Request(
            Method.GET,
            URI_.parseValue("http://www.example.com"),
            authorizationCredentials : ChallengeMessage.parse("basic abcd=="));
    Future<Response> authResponse = mockAuthenticateTrueResource.handle(request);
    authResponse.then((Response response){
      expect(response.status, equals(Status.SUCCESS_OK));
    });
    expect(authResponse, completes);
  });

  test("Request authorization with invalid credentials", (){
    Request request =
        new Request(
            Method.GET,
            URI_.parseValue("http://www.example.com"),
            authorizationCredentials : ChallengeMessage.parse("basic abcd=="));
    Future<Response> authResponse = mockAuthenticateFalseResource.handle(request);
    authResponse.then((Response response){
      expect(response.status, equals(Status.CLIENT_ERROR_FORBIDDEN));
    });
    expect(authResponse, completes);
  });
}