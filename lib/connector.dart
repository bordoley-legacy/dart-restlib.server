library restlib.server.connector;

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:logging/logging.dart";
import "package:restlib_common/collections.dart";
import "package:restlib_common/objects.dart";
import "package:restlib_common/preconditions.dart";
import "package:restlib_parsing/parsing.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_server/server.dart";

part "src/connector/conneg_resource.dart";
part "src/connector/conneg_resource_impl.dart";
part "src/connector/http_request_wrapper.dart";
part "src/connector/http_response_writer.dart";
part "src/connector/http_server_listener.dart";
part "src/connector/io_application.dart";
part "src/connector/io_resource.dart";

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

Future writeString(final Request<String> request, final Response response, final IOSink msgSink) {
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