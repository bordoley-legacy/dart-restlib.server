part of restlib.server_test;

routeTests() { 
  doParsePathParameters(String route, String uri, Dictionary<String, String> expected) {
    test("$route.parsePathParameters($uri)", (){
      Route testRoute = ROUTE.parseValue(route);
      URI testUri = URI_.parseValue(uri);
      Dictionary result = testRoute.parsePathParameters(testUri);
      expect(result, equals(expected));
    });  
  }
  
  doTestParseInvalid(String testCase) {
    test("ROUTE.parse($testCase) throws StateError", (){
      expect(() => 
          ROUTE.parseValue(testCase), throwsStateError);
    });
  }
  
  doTestParseValid(String testCase, String expected) {
    test("ROUTE.parse($testCase)", (){
      expect(ROUTE.parseValue(testCase).toString(), equals(expected));
    });
  }
  
  doParsePathParameters("/a/:b/c/:d", "/a/b/c/d",
                        Persistent.EMPTY_DICTIONARY.putAllFromMap({"b" : "b", "d" : "d"}));
  doParsePathParameters("/a/:b/c/:d", "/a/b/c/d/",
                        Persistent.EMPTY_DICTIONARY.putAllFromMap({"b" : "b", "d" : "d"}));
  doParsePathParameters("/a/*b", "/a/b/c/d/e/f/g/h/i",
                        Persistent.EMPTY_DICTIONARY.putAllFromMap({"b" : "b/c/d/e/f/g/h/i"}));
  
  doTestParseInvalid("/a/*b/:c/:d/*c/e");
  doTestParseInvalid("/a/*b/*d");
  doTestParseInvalid("/a/*b/c/*b");
  doTestParseInvalid("/a/*b/c/:b");
  
  doTestParseValid("/a/c/d/e", "/a/c/d/e");
}