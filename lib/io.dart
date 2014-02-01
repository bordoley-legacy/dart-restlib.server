library restlib.server.io;

import "dart:async";
import "dart:convert";

import "package:restlib_common/collections.dart";
import "package:restlib_common/collections.immutable.dart";
import "package:restlib_common/io.dart";
import "package:restlib_common/objects.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/multipart.dart";
import "package:restlib_core/net.dart";
import "package:restlib_server/server.dart";

part "src/io/application.dart";
part "src/io/conneg_resource.dart";
part "src/io/conneg_resource_impl.dart";
part "src/io/io_resource.dart";

typedef Application ApplicationSupplier(Request);

ApplicationSupplier virtualHostApplicationSupplier(Option<Application> applicationForHost(Either<DomainName, IPAddress> host), final Application fallback) =>
    (final Request request) =>
        applicationForHost(request.uri.authority.value.host)
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

Future writeMultipart(final Request request, final Response<ByteStreamableMultipart> response, final StreamSink<List<int>> msgSink) =>
    msgSink.addStream(response.entity.value.asByteStream());

Future<Request<Multipart>> parseMultipart(
    final Request request, 
    final Stream<List<int>> msgStream, 
    Option<PartParser> partParserProvider(ContentInfo contentInfo)){
  final String boundary = request.contentInfo.mediaRange.value.parameters["boundary"].value;
  
  return parseMultipartStream(msgStream, boundary, partParserProvider)
      .then((final Multipart multipart) =>
          request.with_(entity: multipart));          
}

Future<Request<Form>> parseForm(final Request request, final Stream<List<int>> msgStream) =>
    parseString(request, msgStream)
      .then((final Request<String> request) =>
          FORM.parse(request.entity.value)
            .map((final Form form) =>
                request.with_(entity: form))
            .orCompute(() => 
                new Future.error("unable to parse form encoded data")));
