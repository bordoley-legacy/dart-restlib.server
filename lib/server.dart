library restlib.server;

import "dart:async";
import "dart:convert";

import "package:crypto/crypto.dart";

import "package:restlib_common/collections.dart";
import "package:restlib_common/objects.dart";
import "package:restlib_common/preconditions.dart";
import "package:restlib_parsing/parsing.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";

part "src/application.dart";
part "src/authorizer.dart";
part "src/future_responses.dart";
part "src/resource.dart";
part "src/routable_uri.dart";
part "src/route.dart";
part "src/uniform_resource.dart";

typedef Application ApplicationSupplier(Request);

ApplicationSupplier virtualHostApplicationSupplier(Map<String,Application> applications, [Application fallback]) {
  checkArgument(applications.isNotEmpty);

  fallback = (fallback != null) ? fallback : applications.values.first;

  return (Request request){
    Application app = applications[request.uri.host];
    return (app != null) ? app : fallback;
  };
}

