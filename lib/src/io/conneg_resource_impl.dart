part of restlib.server.io;

class _ToStringResponseWriter implements ResponseWriter {
  final MediaRange mediaRange;
  
  _ToStringResponseWriter(this.mediaRange);
  
  Response withContentInfo(final Response response) =>
      response.with_(contentInfo: response.contentInfo.with_(mediaRange: mediaRange));
  
  Future write(final Request request, final Response response, final StreamSink<List<int>> msgSink) =>
      writeString(request, response, msgSink);
}

class _ContentTypeResponseWriter implements ResponseWriter {
  final MediaRange mediaRange;
  final ResponseEntityWriter responseEntityWriter;
 
  _ContentTypeResponseWriter(this.mediaRange, this.responseEntityWriter);
  
  Response withContentInfo(Response response) =>
      response.with_(contentInfo: response.contentInfo.with_(mediaRange: mediaRange));
  
  Future write(Request request, Response response, StreamSink<List<int>> msgSink) =>
      responseEntityWriter(request, response, msgSink);
}

class _AlwaysProvidesResponseWriterProvider implements ResponseWriterProvider {
  final Option<ResponseWriter> responseWriter;
  final FiniteSet<Header> variesOn = EMPTY_SET;
  
  _AlwaysProvidesResponseWriterProvider(final ResponseWriter responseWriter) :
    this.responseWriter = new Option(responseWriter);
  
  Option<ResponseWriter> apply(Request request, Response response) =>
      responseWriter;
}

typedef Option<Dictionary<MediaRange,ResponseWriter>> _ResponseWritersForEntity(Request request, Response response);

class _ContentTypeResponseWriterProvider implements ResponseWriterProvider {
  final _ResponseWritersForEntity responseWritersForEntity;
  
  _ContentTypeResponseWriterProvider(this.responseWritersForEntity);
  
  FiniteSet<Header> variesOn = EMPTY_SET.add(Header.ACCEPT);
  
  Option<ResponseWriter> apply(Request request, Response response) =>
      responseWritersForEntity(request, response)
        .flatMap((final Dictionary<MediaRange, ResponseWriter> writers) =>
            Preference.bestMatch(request.preferences.acceptedMediaRanges, writers.keys)
              .map((final MediaRange bestMediaRangeChoice) =>
                  writers[bestMediaRangeChoice].value));
}