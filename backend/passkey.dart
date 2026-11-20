part of 'server.dart';

const loginDuration = Duration(hours: 12);
String randomId() =>
    base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');

/// 새 로그인. 이전 로그인은 지우지 않는다: 같은 브라우저의 다른 탭이 다른 계정으로
/// (예: /pc 간호사 · /doctor 의료진) 각자 토큰을 쓰고 있을 수 있다. 끝난 로그인은 12시간 뒤 정리된다.
void startSession(HttpRequest req, String login, Cookie? previous) {
  final token = randomId();
  sessions[token] = (login: login, expires: DateTime.now().add(loginDuration));
  req.response.cookies.add(
    Cookie('byeoljari_new2', token)
      ..path = '/api/'
      ..httpOnly = true
      ..sameSite = SameSite.strict
      ..secure = req.requestedUri.scheme == 'https'
      ..maxAge = loginDuration.inSeconds,
  );
  json(req.response, 200, {'token': token});
}

Future<void> createPasskeyTable(Connection db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS byeoljari_new2.passkey (
      id text PRIMARY KEY,
      public_key text NOT NULL,
      counter bigint NOT NULL CHECK (counter >= 0)
    )
  ''');
}

typedef PasskeyChallenge = ({
  String login,
  String purpose,
  String challenge,
  String? session,
  DateTime expires,
});
final challenges = <String, PasskeyChallenge>{};
final passkeyOrigin = Platform.environment['PASSKEY_ORIGIN'];

class PasskeyError implements Exception {
  const PasskeyError(this.status, this.message);
  final int status;
  final String message;
}

Future<Map<String, dynamic>> verifier(
  String endpoint,
  Map<String, Object?> input,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final uri = Uri.parse('http://passkey-verifier:8081/' + endpoint);
    final req = await client.postUrl(uri).timeout(const Duration(seconds: 8));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(input));
    final response = await req.close().timeout(const Duration(seconds: 8));
    final output = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw const PasskeyError(401, '패스키를 확인하지 못했어요. 다시 시도해 주세요.');
    }
    return jsonDecode(output) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Future<void> handlePasskey(
  HttpRequest req,
  Map<String, Connection> dbs,
  String password,
  Cookie? cookie,
) async {
  final res = req.response;
  try {
    if (passkeyOrigin == null ||
        req.requestedUri.origin != passkeyOrigin ||
        req.headers.value('origin') != passkeyOrigin) {
      throw const PasskeyError(403, '패스키는 설정된 접속 주소에서 사용할 수 있어요.');
    }
    final segments = req.uri.pathSegments;
    if (segments.length != 4 ||
        !const {'register', 'login'}.contains(segments[2]) ||
        !const {'options', 'verify'}.contains(segments[3])) {
      throw const PasskeyError(404, '요청을 찾을 수 없어요.');
    }
    final purpose = segments[2], operation = segments[3];
    final registering = purpose == 'register';
    final input = await readJson(req);
    final now = DateTime.now();
    challenges.removeWhere((_, value) => !now.isBefore(value.expires));

    if (operation == 'options') {
      final login = input['login'];
      if (login is! String || !dbs.containsKey(login)) {
        throw const PasskeyError(400, '테스트 계정의 아이디를 입력해 주세요.');
      }
      if (registering &&
          (sessions[cookie?.value]?.login != login ||
              input['password'] != password)) {
        throw const PasskeyError(401, '패스키를 등록하려면 먼저 비밀번호를 확인해 주세요.');
      }
      if (challenges.length >= 128) {
        throw const PasskeyError(429, '잠시 후 다시 시도해 주세요.');
      }
      final ids = await dbs[login]!.execute(
        'SELECT id FROM byeoljari_new2.passkey ORDER BY id',
      );
      if (!registering && ids.isEmpty) {
        throw const PasskeyError(404, '등록한 패스키가 없어요. 비밀번호로 먼저 등록해 주세요.');
      }
      if (registering && ids.length >= 16) {
        throw const PasskeyError(409, '이 계정의 테스트 패스키 등록 한도에 도달했어요.');
      }
      final options = await verifier(purpose + '/options', {
        'login': login,
        'credentialIDs': [for (final row in ids) row[0]],
      });
      final ticket = randomId();
      challenges[ticket] = (
        login: login,
        purpose: purpose,
        challenge: options['challenge'] as String,
        session: registering ? cookie!.value : null,
        expires: now.add(const Duration(minutes: 3)),
      );
      json(res, 200, {'ticket': ticket, 'options': options});
      return;
    }

    final proof = challenges.remove(input['ticket']);
    final credentialResponse = input['credential'];
    if (proof == null ||
        proof.purpose != purpose ||
        credentialResponse is! Map<String, dynamic>) {
      throw const PasskeyError(401, '패스키 요청이 만료됐어요. 다시 시도해 주세요.');
    }
    final db = dbs[proof.login]!;
    final payload = <String, Object?>{
      'challenge': proof.challenge,
      'response': credentialResponse,
    };

    if (registering) {
      if (cookie?.value != proof.session ||
          sessions[cookie?.value]?.login != proof.login) {
        throw const PasskeyError(401, '패스키 등록 세션이 만료됐어요.');
      }
      final result = await verifier('register/verify', payload);
      final added = await db.execute(
        Sql.named('''
        INSERT INTO byeoljari_new2.passkey(id,public_key,counter) VALUES(@id,@key,@counter)
        ON CONFLICT DO NOTHING RETURNING id
      '''),
        parameters: {
          'id': result['id'],
          'key': result['publicKey'],
          'counter': result['counter'],
        },
      );
      if (added.isEmpty) throw const PasskeyError(409, '이미 등록된 패스키예요.');
      json(res, 200, {'ok': true});
      return;
    }

    final id = credentialResponse['id'];
    if (id is! String) throw const FormatException('Missing credential');
    final rows = await db.execute(
      Sql.named(
        'SELECT id,public_key,counter FROM byeoljari_new2.passkey WHERE id=@id',
      ),
      parameters: {'id': id},
    );
    if (rows.isEmpty) throw const PasskeyError(401, '이 계정에 등록된 패스키를 선택해 주세요.');
    final stored = rows.single.toColumnMap();
    final result = await verifier('login/verify', {
      ...payload,
      'credential': stored,
    });
    final updated = await db.execute(
      Sql.named('''
      UPDATE byeoljari_new2.passkey SET counter=@new WHERE id=@id AND counter=@previous RETURNING id
    '''),
      parameters: {
        'id': id,
        'new': result['counter'],
        'previous': stored['counter'],
      },
    );
    if (updated.isEmpty) throw const PasskeyError(409, '패스키 로그인을 다시 시도해 주세요.');
    startSession(req, proof.login, cookie);
  } on PasskeyError catch (e) {
    json(res, e.status, {'error': e.message});
  } on IOException {
    json(res, 503, {'error': '패스키 서버에 연결하지 못했어요.'});
  } on TimeoutException {
    json(res, 503, {'error': '패스키 응답이 지연됐어요. 다시 시도해 주세요.'});
  }
}
