part of restlib.connector_test;

/*
class _SettableMockHttpResponse extends MockHttpResponse {
  int statusCode;
}*/

const String _SCHEME = "https";

HttpRequest _newHttpRequest() { 
  final HttpConnectionInfo httpConnectionInfo =
      new MockHttpConnectionInfo()
        ..when(callsTo("get remoteAddress")).alwaysReturn(InternetAddress.LOOPBACK_IP_V4);
  
  final HttpHeaders responseHeaders =
      new MockHttpHeaders()
        ..when(callsTo("add"));
  
  final HttpResponse httpResponse =
      new MockHttpResponse()
        ..when(callsTo("get headers")).alwaysReturn(responseHeaders);
  
  final HttpHeaders requestHeaders =
      new MockHttpHeaders()
        ..when(callsTo("value")).alwaysCall((final String header) =>
            {HttpHeaders.HOST : "www.example.com"}[header]);
  
  return new MockHttpRequest()
    ..when(callsTo("get connectionInfo")).alwaysReturn(httpConnectionInfo)
    ..when(callsTo("get contentLength")).alwaysReturn(10)
    ..when(callsTo("get headers")).alwaysReturn(requestHeaders)
    ..when(callsTo("get method")).alwaysReturn(Method.GET.toString())
    ..when(callsTo("get response")).alwaysReturn(httpResponse)
    ..when(callsTo("get uri")).alwaysReturn(Uri.parse("/test"));
}

Request _requestWithEntity() =>
  (new RequestBuilder()
    ..entity=""
    ..method = Method.GET
    ..uri = Uri.parse("http://example.com")
  ).build();

void _testProcessRequest(final ApplicationSupplier applicationSupplier, final Status expectedStatus) {
  final HttpRequest httpRequest = _newHttpRequest();
  final Future result = processRequest(httpRequest, applicationSupplier, _SCHEME);
  expectOnCompletion(result, (_) => 
      (httpRequest.response as Mock)
        .getLogs(callsTo("set statusCode", expectedStatus.code))
        .verify(happenedOnce));
}

IOApplicationSupplier _applicationSupplierFor(final IOResource resource) =>
    (final Request request) =>
        new IOApplication([resource]);

void httpServerListenerTestGroup() {
  group("class:RequestProcessor", () {
    group("processRequest()", () {      
      final Route route = 
          new MockRoute()
            ..when(callsTo("matches")).alwaysReturn(true);
      
      test("with IOApplication supplier throwing exception", () =>
          _testProcessRequest((final Request request) => throw new Error(), Status.SERVER_ERROR_INTERNAL));
      
      test("with Resource.handle() method throwing an exception and IOApplication.filterResponse() throwing an exception", () {
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysThrow(new Error());
        final IOApplication application =
            new MockIOApplication()
              ..when(callsTo("route")).alwaysReturn(resource)
              ..when(callsTo("filterRequest")).alwaysCall((final Request request) => request)
              ..when(callsTo("filterResponse")).alwaysThrow(new Error())
              ..when(callsTo("get writeError")).alwaysReturn(writeString);
        
        _testProcessRequest((final Request request) => application, Status.SERVER_ERROR_INTERNAL);
      });
               
      test("with successful GET request", () {  
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysReturn(SUCCESS_OK);
        
        final IOApplicationSupplier applicationSupplier = _applicationSupplierFor(resource); 
        
        _testProcessRequest(applicationSupplier, Status.SUCCESS_OK);
      });
      
      test("with Resource.handle() method throwing an exception", () {
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysThrow(new Error());

        final IOApplicationSupplier applicationSupplier = _applicationSupplierFor(resource); 
        
        _testProcessRequest(applicationSupplier, Status.SERVER_ERROR_INTERNAL);
      });
      
      
      test("with Resource.handle() method returning a Future.error", () {
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysCall((a) => new Future.error(new Error()));
        
        final IOApplicationSupplier applicationSupplier = _applicationSupplierFor(resource); 
        
        _testProcessRequest(applicationSupplier, Status.SERVER_ERROR_INTERNAL);
      });
      
      test("with Resource.parse() method throwing an exception", () {
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysReturn(INFORMATIONAL_CONTINUE)
              ..when(callsTo("parse")).alwaysThrow(new Error());

        final IOApplicationSupplier applicationSupplier = _applicationSupplierFor(resource); 
        
        _testProcessRequest(applicationSupplier, Status.SERVER_ERROR_INTERNAL);
      });
      
      test("with Resource.parse() method returning a Future.error", () {
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysReturn(INFORMATIONAL_CONTINUE)
              ..when(callsTo("parse")).alwaysCall((a,b) => new Future.error(new Error()));

        final IOApplicationSupplier applicationSupplier = _applicationSupplierFor(resource); 
        
        _testProcessRequest(applicationSupplier, Status.CLIENT_ERROR_BAD_REQUEST);
      });
      
      test("with Resource.acceptMessage() method throwing an exception", () {
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysReturn(INFORMATIONAL_CONTINUE)
              ..when(callsTo("parse")).alwaysReturn(new Future.value(_requestWithEntity()))
              ..when(callsTo("acceptMessage")).alwaysThrow(new Error());

        final IOApplicationSupplier applicationSupplier = _applicationSupplierFor(resource); 
        
        _testProcessRequest(applicationSupplier, Status.SERVER_ERROR_INTERNAL);
      });
      
      test("with Resource.acceptMessage() method returning a Future.error", () {
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysReturn(INFORMATIONAL_CONTINUE)
              ..when(callsTo("parse")).alwaysReturn(new Future.value(_requestWithEntity()))
              ..when(callsTo("acceptMessage")).alwaysCall((a,b) => new Future.error(new Error()));

        final IOApplicationSupplier applicationSupplier = _applicationSupplierFor(resource); 
        
        _testProcessRequest(applicationSupplier, Status.SERVER_ERROR_INTERNAL);
      });
      
      test("with successful PUT request", () {
        final IOResource resource = 
            new MockIOResource()
              ..when(callsTo("get route")).alwaysReturn(route)
              ..when(callsTo("handle")).alwaysReturn(INFORMATIONAL_CONTINUE)
              ..when(callsTo("parse")).alwaysReturn(new Future.value(_requestWithEntity()))
              ..when(callsTo("acceptMessage")).alwaysReturn(SUCCESS_OK);

        final IOApplicationSupplier applicationSupplier = _applicationSupplierFor(resource); 
        
        _testProcessRequest(applicationSupplier, Status.SUCCESS_OK);
      });
    });
  });
}