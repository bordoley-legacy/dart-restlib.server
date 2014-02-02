part of restlib.server_test;

routeTests() { 
  doParsePathParameters(String route, String uri, Dictionary<String, String> expected) {
    test("$route.parsePathParameters($uri)", (){
      Route testRoute = ROUTE.parse(route).value;
      URI testUri = URI_.parse(uri).value;
      Dictionary result = testRoute.parsePathParameters(testUri);
      expect(result, equals(expected));
    });  
  }
  
  doTestMatches(String route, String uri, bool expected) {
    test("$route.matches($uri) == $expected", (){
      Route testRoute = ROUTE.parse(route).value;
      URI testUri = URI_.parse(uri).value;
      expect(testRoute.matches(testUri), equals(expected));
    });
  }
  
  doTestParseInvalid(String testCase) {
    test("ROUTE.parse($testCase) throws StateError", (){
      expect(() => 
          ROUTE.parse(testCase).value, throwsStateError);
    });
  }
  
  doTestParseValid(String testCase, String expected) {
    test("ROUTE.parse($testCase)", (){
      expect(ROUTE.parse(testCase).value.toString(), equals(expected));
    });
  }
  
  doParsePathParameters("/a/:b/c/:d", "/a/b/c/d",
                        Persistent.EMPTY_DICTIONARY.putAllFromMap({"b" : "b", "d" : "d"}));
  doParsePathParameters("/a/:b/c/:d", "/a/b/c/d/",
                        Persistent.EMPTY_DICTIONARY.putAllFromMap({"b" : "b", "d" : "d"}));
  doParsePathParameters("/a/*b", "/a/b/c/d/e/f/g/h/i",
                        Persistent.EMPTY_DICTIONARY.putAllFromMap({"b" : "b/c/d/e/f/g/h/i"}));
  
  doTestMatches("/a/:b/c/:d", "/a/b/c/d", true);
  doTestMatches("/a/:b/c/:d", "/a/b/c/d/", true);
  doTestMatches("/a/*b", "/a/b/c/d/e/f/g/h/i", true);
  doTestMatches("/a/b/c/d", "/a/b/c/d", true);
  
  doTestParseInvalid("/a/*b/:c/:d/*c/e");
  doTestParseInvalid("/a/*b/*d");
  doTestParseInvalid("/a/*b/c/*b");
  doTestParseInvalid("/a/*b/c/:b");
  
  doTestParseValid("/a/c/d/e", "/a/c/d/e");
}