library restlib.server.io;

import "dart:async";
import "dart:convert";
import "package:mime/mime.dart";

import "package:restlib_common/collections.dart";
import "package:restlib_common/objects.dart";
import "package:restlib_common/preconditions.dart";
import "package:restlib_parsing/parsing.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/multipart.dart";
import "package:restlib_server/server.dart";

part "src/io/conneg_resource.dart";
part "src/io/conneg_resource_impl.dart";
part "src/io/io_application.dart";
part "src/io/io_resource.dart";

Future<Request<String>> parseString(final Request request, final Stream<List<int>> msgStream){
  final Charset charset = 
      request.contentInfo.mediaRange
        .flatMap((final MediaRange mediaRange) => 
            mediaRange.charset)
        .orElse(Charset.UTF_8);
  
  return charset.codec
    .map((final Encoding codec) => 
        codec.decodeStream(msgStream)
          .then((final String requestBody) => 
              request.with_(entity: requestBody)))
    .orCompute(() => 
        new Future.error("Request charset preference is unsupported."));
}

Future writeString(final Request<String> request, final Response response, final StreamSink<List<int>> msgSink) {
  final Charset charset = 
      response.contentInfo.mediaRange
        .flatMap((final MediaRange mr) => 
            mr.charset)
        .orElse(Charset.UTF_8);
   
  return charset.codec
      .map((final Encoding codec) {
        msgSink.add(codec.encode(response.entity.value.toString()));
        return new Future.value();   
      }).orCompute(() => 
          new Future.error("${charset.toString()} is unsupported"));
}

Future writeMultipart(final Request request, final Response<MultipartOutput> response, final StreamSink<List<int>> msgSink) {
  final MultipartOutput entity = response.entity.value;
  final String boundary = response.contentInfo.mediaRange.value.parameters["boundary"].first;
  
  return entity
    .fold(new Future.value(), (final Future future, final Part part) => 
        future
          .then((_) {
            msgSink.add(ASCII.encode("--$boundary\r\n"));
            msgSink.add(ASCII.encode(part.contentInfo.toString()));
            return msgSink
                .addStream(part.entity.asStream())
                .then((_) =>
                    msgSink.add(ASCII.encode("\r\n\r\n")));
          }))
   .then((_) =>
       msgSink.add(ASCII.encode("--$boundary--\r\n")));   
}


typedef Option<PartParser> PartParserProvider(ContentInfo contentInfo);
typedef Future<Part> PartParser(ContentInfo contentInfo, final Stream<List<int>> msgStream);

class MultipartInputProcessor {
  final PartParserProvider partParserProvider;
  
  MultipartInputProcessor(this.partParserProvider);

  Future<Request<Multipart>> parseMultipartInput(final Request request, final Stream<List<int>> msgStream){
    final String boundary = request.contentInfo.mediaRange.value.parameters["boundary"].value;
    
    return new MimeMultipartTransformer(boundary)
      .bind(msgStream)
      .map((final MimeMultipart multipart) => 
              new Part(new _MimeContentInfo(multipart), multipart))
      .fold(Persistent.EMPTY_SEQUENCE, (final ImmutableSequence<Future> futureResults, final Part<Stream<List<int>>> part) => 
          partParserProvider(part.contentInfo)
            .map((final PartParser parser) =>
                futureResults.add(
                    parser(part.contentInfo, part.entity)))
            .orCompute(() =>
                futureResults.add(part.entity.drain()))
      .then(Future.wait)
      .then((final List parts) => 
          parts.where((final e) =>
              e is Part))
      .then((final List<Part> parts) =>
          request.with_(entity: new Multipart(parts))));              
   }
}

// Copied pretty much verbatim from http_request_wrapper
class _MimeContentInfo 
    extends Object
    with ContentInfoWith_
    implements PartContentInfo {
  final MimeMultipart delegate;
  
  ImmutableSequence<ContentEncoding> _encodings;
  ImmutableSet<Language> _languages;
  Option<int> _length;
  Option<Uri> _location;
  Option<MediaRange> _mediaRange;
  Option<ContentRange> _range;
  
  _MimeContentInfo(this.delegate);
  
  Option _parse(final Parser parser, final Header header) =>
      // FIXME: If the same headers is used more than once this doesn't work
      parser.parse(nullToEmpty(delegate.headers[header.toString()]));
  
  ImmutableSequence<ContentEncoding> get encodings =>
      computeIfNull(_encodings, () {
        _encodings = 
            _parse(CONTENT_ENCODING_HEADER, Header.CONTENT_ENCODING)
              .map((final Iterable<ContentEncoding> encodings) => 
                  Persistent.EMPTY_SEQUENCE.addAll(encodings))
              .orElse(Persistent.EMPTY_SEQUENCE);
            
        return _encodings;
      });
  
  ImmutableSet<Language> get languages =>
      computeIfNull(_languages, () {
        _languages = 
            _parse(CONTENT_LANGUAGE, Header.CONTENT_LANGUAGE)
              .map((final Iterable<Language> languages) => 
                  Persistent.EMPTY_SET.addAll(languages))
              .orElse(Persistent.EMPTY_SET);    
            
        return _languages;
      });
 
  Option<int> get length =>
      computeIfNull(_length, () {
        _length = _parse(INTEGER, Header.CONTENT_LENGTH);
        return _length;
      });
  
  Option<Uri> get location =>
      computeIfNull(_location, () {
        _location = _parseUri(nullToEmpty(delegate.headers[Header.CONTENT_LOCATION.toString()]));
        return _location;
      });
  
  Option<MediaRange> get mediaRange =>
      computeIfNull(_mediaRange, () {
        _mediaRange = _parse(MEDIA_RANGE, Header.CONTENT_TYPE);
        return _mediaRange;
      });
  
  Option<ContentRange> get range =>
      computeIfNull(_range, () {
        _range = _parse(CONTENT_RANGE, Header.CONTENT_RANGE);
        return _range;
      });
}

// Copied pretty much verbatim from http_request_wrapper
Option<Uri> _parseUri(final String uri) {
  checkNotNull(uri);

  if (uri.isEmpty) {
    return Option.NONE;
  } else {
    // FIXME: Try catch for exceptions.
    final Uri result = Uri.parse(uri);
    return new Option(result);
  }
}
