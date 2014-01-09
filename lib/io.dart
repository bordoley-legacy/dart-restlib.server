library restlib.server.io;

import "dart:async";
import "dart:convert";

import "package:restlib_common/collections.dart";
import "package:restlib_common/objects.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
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

Future writeMultipart(final Request request, final Response<Multipart> response, final StreamSink<List<int>> msgSink) {
  final Multipart entity = response.entity.value;
  final Iterable<Part> parts = entity.parts;
  final String boundary = entity.boundary;
  
  return parts
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