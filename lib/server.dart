library restlib.server;

import "dart:async";
import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";

import "package:restlib_common/collections.dart";
import "package:restlib_common/objects.dart";
import "package:restlib_common/preconditions.dart";
import "package:restlib_parsing/parsing.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/multipart.dart";

part "src/server/application.dart";
part "src/server/authorizer.dart";
part "src/server/byte_range_resource.dart";
part "src/server/future_responses.dart";
part "src/server/resource.dart";
part "src/server/routable_uri.dart";
part "src/server/route.dart";
part "src/server/uniform_resource.dart";

typedef Application ApplicationSupplier(Request);

ApplicationSupplier virtualHostApplicationSupplier(Map<String,Application> applications, [Application fallback]) {
  checkArgument(applications.isNotEmpty);

  fallback = (fallback != null) ? fallback : applications.values.first;

  return (Request request){
    Application app = applications[request.uri.host];
    return (app != null) ? app : fallback;
  };
}

