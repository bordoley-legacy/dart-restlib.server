library restlib.server_test;

import "dart:async";
import "package:unittest/mock.dart";
import "package:unittest/unittest.dart";

import "package:restlib_common/collections.dart";
import "package:restlib_common/collections.immutable.dart";

import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/http.future_responses.dart";
import "package:restlib_core/http.methods.dart";
import "package:restlib_core/http.statuses.dart" as Status;
import "package:restlib_core/net.dart";
import "package:restlib_server/server.dart";

import "mocks.dart";

part "src/server/resource_test.dart";
part "src/server/route_test.dart";

serverTestGroups() {
  group("class _AuthorizedResource", authorizedResourceTests);
  group("class Route", routeTests);
}

main() {
  serverTestGroups();
}