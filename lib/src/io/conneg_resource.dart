part of restlib.server.io;

typedef Future<Request> RequestParser(final Request request, final Stream<List<int>> msgStream);
typedef Option<RequestParser> RequestParserProvider(ContentInfo contentInfo);
typedef Future ResponseEntityWriter(Request request, Response response, StreamSink<List<int>> msgSink);
typedef Option<ResponseWriter> ResponseWriterForMediaRange(MediaRange mediaRange);

abstract class ResponseWriter {
  factory ResponseWriter.forContentType(final MediaRange mediaRange, Future write(Request request, Response response, StreamSink<List<int>> msgSink)) =>
      new _ContentTypeResponseWriter(mediaRange, write);
  
  factory ResponseWriter.string(final MediaRange contentType) =>
      new _ToStringResponseWriter(contentType);
  
  Response withContentInfo(Response response);
  
  Future write(Request request, Response response, StreamSink<List<int>> msgSink);
}

abstract class ResponseWriterProvider {
  factory ResponseWriterProvider.onContentType(Option<Dictionary<MediaRange,ResponseWriter>> responseWritersForEntity(Request request, Response response)) =>
      new _ContentTypeResponseWriterProvider(responseWritersForEntity);
  
  factory ResponseWriterProvider.alwaysProvides(final ResponseWriter responseWriter) =>
      new _AlwaysProvidesResponseWriterProvider(responseWriter);
  
  FiniteSet<Header> get variesOn;
  
  Option<ResponseWriter> apply(Request request, Response response); 
}

class _ConnegResource<T> 
    extends Object
    with ForwardingResource<T>
    implements IOResource<T> { 
      
  final Resource<T> delegate;
  final RequestParserProvider requestParserProvider;
  final ResponseWriterProvider responseWriterProvider;
  
  final Response notAcceptableResponse;
  
  _ConnegResource(this.delegate, this.requestParserProvider, final ResponseWriterProvider responseWriterProvider) :
    this.responseWriterProvider = responseWriterProvider,
    this.notAcceptableResponse = 
      (new ResponseBuilder()
        ..entity = Status.CLIENT_ERROR_NOT_ACCEPTABLE.reason
        ..status = Status.CLIENT_ERROR_NOT_ACCEPTABLE
        ..addVaryHeaders(responseWriterProvider.variesOn)
      ).build();
  
Response addContentInfoToResponse(final Request request, final Response response) =>
    response.entity
      .map((final entity) =>
          responseWriterProvider.apply(request, response)
            .map((final ResponseWriter writer) =>
                writer.withContentInfo(response))
            .orElse(notAcceptableResponse)     
       ).orElse(response);
  
  Future<Response> acceptMessage(final Request<T> request) =>
      delegate.acceptMessage(request)
        .then((final Response response) =>
            addContentInfoToResponse(request, response));
  
  Future<Response> handle(final Request request) =>
      delegate.handle(request)
        .then((final Response response) { 
          if (response.status == Status.INFORMATIONAL_CONTINUE) {
            return requestParserProvider(request.contentInfo)
              .map((_) =>
                  response)
              .orElse(CLIENT_ERROR_UNSUPPORTED_MEDIA_TYPE);
          }
          
          return addContentInfoToResponse(request, response);
        });

  Future<Request<String>> parse(final Request request, final Stream<List<int>> msgStream) =>
      requestParserProvider(request.contentInfo)
        .map((final RequestParser parse) => 
            parse(request, msgStream))
        .orCompute(() => 
            new Future.error("No parser provided to parse the request entity"));
  
  Future write(final Request request, final Response response, final StreamSink<List<int>> msgSink) =>
      response.entity
        .map((final entity) =>
            responseWriterProvider.apply(request, response)
              .map((final ResponseWriter writer) =>
                  writer.write(request, response, msgSink))
              .orCompute(() =>
                  new Future.error("No ResponseWriter available for entity type")))
       .orCompute(() => 
           new Future.error("Response does not contain an entity"));
}