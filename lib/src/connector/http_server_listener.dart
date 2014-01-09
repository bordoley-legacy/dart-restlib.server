part of restlib.server.connector;

typedef IOApplication IOApplicationSupplier(Request);
typedef HttpServerListener(HttpServer);

final Logger _logger = new Logger("restlib.connector.connector");

void _logError(final e) { 
  if (e is Error) {
   _logger.severe("${e.toString()}\n${e.stackTrace.toString()}");
  } else {
    _logger.severe(e.toString());
  }
}

Response _internalServerError(final e) {
  _logError(e);
  return (new ResponseBuilder()
    ..status = Status.SERVER_ERROR_INTERNAL
    ..entity = e
  ).build();
}

HttpServerListener httpServerListener(final IOApplicationSupplier applicationSupplier, final String scheme) =>
    (final HttpServer server) {  
      _logger.info("Listening on port: ${server.port}");

      server.listen((final HttpRequest serverRequest) =>
          processRequest(serverRequest, applicationSupplier, scheme),
          onError: _logError);
    };

@visibleForTesting
Future processRequest(final HttpRequest serverRequest, final IOApplicationSupplier applicationSupplier, final String scheme) {  
  Future _writeResponse(final Request request, final Response response, Future write(Request request, Response response, IOSink msgSink)) {
    checkNotNull(response);
    
    writeHttpResponse(response, serverRequest.response);
    
    if (response.entity.isNotEmpty) {
      return write(request, response, serverRequest.response);
    } else {
      return new Future.value();
    }
  }
  
  Future _doProcessRequest(Request request) {
    Future<Response> response;
    
    try {
      final IOApplication application = applicationSupplier(request);
      
      try {
        request = application.filterRequest(request);
        final IOResource resource = application.route(request);
        response = resource
            .handle(request)
            .then((final Response response) {
              if (response.status != Status.INFORMATIONAL_CONTINUE) {
                return response;
              }
                
              return resource
                  .parse(request, serverRequest)
                  .then((final Request requestWithEntity) {
                    request = requestWithEntity;
                    return resource.acceptMessage(request);
                  }, onError: (final e) => 
                      CLIENT_ERROR_BAD_REQUEST);
            }).then(application.filterResponse,
                onError:(final e) =>  
                    // Catch any uncaught exceptions in the Future chain.
                    application.filterResponse(_internalServerError(e)))
            .catchError(_internalServerError)
            .then((final Response response) =>
                _writeResponse(request, response, resource.write));
      } catch (e) {
        // Synchronous catch block for when application.filterReuqest(), application.route() or resource.handle() throw exceptions
        // Still attempt to filter the response first.
        try {
          response = _writeResponse(request,_internalServerError(e), application.writeError);
        } catch (e) {
          response = new Future.error(e);
        }
      }
    } catch (e) {
      // Synchronous catch block for when applicationSupplier throws exception
      // Also called if application.filterReuqest(), application.route() or resource.handle() throw exceptions and
      // application.filterResponse throws an exception.
      try {
        response = _writeResponse(request,_internalServerError(e), writeString);
      } catch (e) {
        response = new Future.error(e);
      }
    }
    
    return response;
  }
  
  _logger.finest("Received request from ${serverRequest.connectionInfo.remoteAddress}");
  
  final Request request = wrapHttpRequest(serverRequest, scheme);
  _logger.finest(request.toString());
  
  return _doProcessRequest(request)
      .then((_) => 
          serverRequest.response.close(),
          onError: (final e) {
            _logError(e);
            serverRequest.response.close();
          })
      .catchError(_logError);
}