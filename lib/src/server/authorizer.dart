part of restlib.server;

abstract class Authorizer {
  ChallengeMessage get authenticationChallenge;
  String get scheme;
  
  Future<bool> authenticate(ChallengeMessage credentials) ;
}

abstract class BasicAuthorizer implements Authorizer {
  static final Future<bool> falseFuture = new Future.value(false);
  
  final String scheme = "basic";
  final ChallengeMessage authenticationChallenge;
  
  BasicAuthorizer(final String realm): 
    authenticationChallenge = 
      CHALLENGE_MESSAGE.parse("basic realm=\"$realm\", encoding=\"UTF-8\"").value;
  
  Future<bool> authenticate(final ChallengeMessage credentials) {
    if(credentials is Base64ChallengeMessage) {
      final String userPwd = UTF8.decode(CryptoUtils.base64StringToBytes(credentials.data));
      
      final int splitCharIndex = userPwd.indexOf(":");
      if(splitCharIndex > 0 && splitCharIndex < (userPwd.length -1)) {
        final String user = userPwd.substring(0, splitCharIndex);
        final String pwd = userPwd.substring(splitCharIndex + 1);
        return authenticateUserAndPwd(user, pwd);
      } else {
        return falseFuture;
      }  
    } else {
      return falseFuture;
    }
  }

  Future<bool> authenticateUserAndPwd(String user, String pwd);
}