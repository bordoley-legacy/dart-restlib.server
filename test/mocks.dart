library reslib.mocks;

import "package:unittest/mock.dart";
import "package:restlib_server/server.dart";

class MockAuthorizer extends Mock implements Authorizer {
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
class MockResource extends Mock implements Resource {
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}


