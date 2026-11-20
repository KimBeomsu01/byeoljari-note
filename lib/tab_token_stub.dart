/// 웹이 아니면 탭이 없다 (설치형 앱은 shared_preferences 에 토큰을 저장한다).
String? readTabToken() => null;

void writeTabToken(String? token) {}
