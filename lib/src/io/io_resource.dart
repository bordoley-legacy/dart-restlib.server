part of restlib.server.io;

abstract class IOResource<T> implements Resource<T> {
  static const IOResource NOT_FOUND = const _NotFoundIOResource();
  
  factory IOResource.conneg(
      final Resource<T> delegate, 
      final RequestParserProvider requestParserProvider,
      final ResponseWriterProvider responseWriterProvider) =>
          new _ConnegResource(delegate, requestParserProvider, responseWriterProvider);
  
  Future<Request<T>> parse(Request request, Stream<List<int>> msgStream);
  Future write(Request request, Response response, StreamSink<List<int>> msgSink);
}

abstract class ForwardingIOResource<T> implements Forwarder, IOResource<T> {
  Future<Request<T>> parse(Request request, Stream<List<int>> msgStream) =>
      delegate.parse(request, msgStream);
  
  Future write(Request request, Response response, StreamSink<List<int>> msgSink) =>
      delegate.write(request, response, msgSink);
}

class _NotFoundIOResource implements IOResource {
  const _NotFoundIOResource();

  Route get route => 
      Resource.NOT_FOUND.route;
  
  Future<Response> handle(final Request request) => 
      Resource.NOT_FOUND.handle(request);
  
  Future<Response> acceptMessage(final Request request) => 
      Resource.NOT_FOUND.acceptMessage(request);
  
  // Strictly speaking this method should never be called, but add implementation as prevention.
  Future<Request> parse(final Request request, final Stream<List<int>> msgStream) =>
      throw new UnimplementedError("parse() methods called on IOResource.NOT_FOUND");
  
  Future write(final Request request, final Response response, final StreamSink<List<int>> msgSink) => 
      writeString(request, response, msgSink);
}