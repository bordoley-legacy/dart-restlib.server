library restlib.server.io;

import "dart:async";
import "dart:convert";
import "package:mime/mime.dart";

import "package:restlib_common/collections.dart";
import "package:restlib_common/objects.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/multipart.dart";
import "package:restlib_server/server.dart";

part "src/io/application.dart";
part "src/io/conneg_resource.dart";
part "src/io/conneg_resource_impl.dart";
part "src/io/io_resource.dart";

typedef Application ApplicationSupplier(Request);

ApplicationSupplier virtualHostApplicationSupplier(Option<Application> applicationForHost(String host), final Application fallback) =>
    (final Request request) =>
        applicationForHost(request.uri.host)
          .orElse(fallback);

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

Future writeMultipart(final Request request, final Response<Multipart<Streamable>> response, final StreamSink<List<int>> msgSink) {
  final Multipart<Streamable> entity = response.entity.value;
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




typedef Future<Part> PartParser(ContentInfo contentInfo, final Stream<List<int>> msgStream);

Future<Request<Multipart>> parseMultipartInput(final Request request, final Stream<List<int>> msgStream, Option<PartParser> partParserProvider(ContentInfo contentInfo)){
  final String boundary = request.contentInfo.mediaRange.value.parameters["boundary"].value;
  
  return new MimeMultipartTransformer(boundary)
    .bind(msgStream)
    .map((final MimeMultipart multipart) => 
        new Part(new ContentInfo.wrapHeaders(
            (final Header header) => 
                new Option(multipart.headers[header.toString()])), 
            multipart))
    .fold(Persistent.EMPTY_SEQUENCE, (final ImmutableSequence<Future> futureResults, final Part<Stream<List<int>>> part) => 
        partParserProvider(part.contentInfo)
          .map((final PartParser parser) =>
              futureResults.add(parser(part.contentInfo, part.entity)))
          .orCompute(() =>
              futureResults.add(part.entity.drain()))
     .then(Future.wait)
     .then((final List parts) => 
         parts.where((final e) =>
             e is Part))
     .then((final List<Part> parts) =>
         request.with_(entity: new Multipart(parts))));              
}

