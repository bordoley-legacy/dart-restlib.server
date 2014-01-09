part of restlib.server.connector;

class _ToStringResponseWriter implements ResponseWriter {
  final MediaRange mediaRange;
  
  _ToStringResponseWriter(this.mediaRange);
  
  Response withContentInfo(final Response response) =>
      response.with_(contentInfo: response.contentInfo.with_(mediaRange: mediaRange));
  
  Future write(final Request request, final Response response, final IOSink msgSink) =>
      writeString(request, response, msgSink);
}

class _ContentTypeResponseWriter implements ResponseWriter {
  final MediaRange mediaRange;
  final ResponseEntityWriter responseEntityWriter;
 
  _ContentTypeResponseWriter(this.mediaRange, this.responseEntityWriter);
  
  Response withContentInfo(Response response) =>
      response.with_(contentInfo: response.contentInfo.with_(mediaRange: mediaRange));
  
  Future write(Request request, Response response, IOSink msgSink) =>
      responseEntityWriter(request, response, msgSink);
}

class _AlwaysProvidesResponseWriterProvider implements ResponseWriterProvider {
  final Option<ResponseWriter> responseWriter;
  final FiniteSet<Header> variesOn = Persistent.EMPTY_SET;
  
  _AlwaysProvidesResponseWriterProvider(final ResponseWriter responseWriter) :
    this.responseWriter = new Option(responseWriter);
  
  Option<ResponseWriter> apply(Request request, entity) =>
      responseWriter;
}

typedef Option<Dictionary<MediaRange,ResponseWriter>> _ResponseWritersForEntity(entity);

class _ContentTypeResponseWriterProvider implements ResponseWriterProvider {
  final _ResponseWritersForEntity responseWritersForEntity;
  
  _ContentTypeResponseWriterProvider(this.responseWritersForEntity);
  
  FiniteSet<Header> variesOn = Persistent.EMPTY_SET.add(Header.ACCEPT);
  
  Option<ResponseWriter> apply(Request request, entity) =>
      responseWritersForEntity(entity)
        .flatMap((final Dictionary<MediaRange, ResponseWriter> writers) =>
            Preference.bestMatch(request.preferences.acceptedMediaRanges, writers.keys)
              .map((final MediaRange bestMediaRangeChoice) =>
                  writers[bestMediaRangeChoice].value));
}