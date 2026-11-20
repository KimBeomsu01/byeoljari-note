import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';

part 'passkey.dart';

/// 로그인 계정 하나: 쓰는 DB · 자료 종류(demo 시연 / dev 개발) · 의료진 계정인지.
typedef Account = ({String database, String dataset, bool doctor});

/// 계정은 저장소에 두지 않고 backend/.env 의 APP_ACCOUNTS 에서 읽는다 (공개 저장소).
/// 형식: `아이디:DB이름:demo|dev[:doctor]` 를 쉼표로. doctor 계정은 의료진 협진 포털(/doctor)에서만 로그인한다.
late final Map<String, Account> accounts;

Map<String, Account> parseAccounts(String? raw) {
  final out = <String, Account>{};
  for (final item in (raw ?? '').split(',')) {
    final parts = item.trim().split(':');
    if (parts.length < 3 || parts[0].isEmpty || parts[1].isEmpty) continue;
    if (parts[2] != 'demo' && parts[2] != 'dev') continue;
    out[parts[0]] = (database: parts[1], dataset: parts[2], doctor: parts.length > 3 && parts[3] == 'doctor');
  }
  if (out.isEmpty) throw StateError('backend/.env 에 APP_ACCOUNTS 를 적어 주세요 (아이디:DB이름:demo|dev[:doctor]).');
  return out;
}
final sessions = <String, ({String login, DateTime expires})>{};
final random = Random.secure();
const photoTypes = {'image/jpeg', 'image/png', 'image/webp'};
const maxPhotoBytes = 5 * 1024 * 1024;

Future<void> main() async {
  final env = Platform.environment;
  accounts = parseAccounts(env['APP_ACCOUNTS']);
  final databases = <String, Connection>{};
  final byName = <String, Connection>{}; // 같은 DB를 쓰는 계정은 연결 하나를 같이 쓴다
  for (final account in accounts.entries) {
    final opened = byName[account.value.database];
    if (opened != null) {
      databases[account.key] = opened;
      continue;
    }
    final db = await Connection.open(
      Endpoint(
        host: env['POSTGRES_HOST']!,
        database: account.value.database,
        username: 'postgres',
        password: env['POSTGRES_PASSWORD']!,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    await db.execute('CREATE SCHEMA IF NOT EXISTS byeoljari_new2');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS byeoljari_new2.snapshot (
        id integer PRIMARY KEY CHECK (id = 1),
        version integer NOT NULL DEFAULT 0,
        state jsonb
      )
    ''');
    await db.execute(
      'INSERT INTO byeoljari_new2.snapshot (id) VALUES (1) ON CONFLICT DO NOTHING',
    );
    await createPasskeyTable(db);
    // 별님 프로필 사진 파일. 누가·언제 올렸는지는 앱 상태(snapshot)에 있다.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS byeoljari_new2.photo (
        id text PRIMARY KEY,
        mime text NOT NULL,
        bytes bytea NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
      )
    ''');
    databases[account.key] = db;
    byName[account.value.database] = db;
  }
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  final password = env['APP_TEST_PASSWORD']!;
  await for (final req in server) {
    unawaited(handle(req, databases, password));
  }
}

Future<Map<String, dynamic>> readJson(HttpRequest req) async {
  if (req.headers.contentType?.mimeType != 'application/json') {
    throw const FormatException('JSON required');
  }
  final buffer = <int>[];
  await for (final bytes in req) {
    if (buffer.length + bytes.length > 4 * 1024 * 1024) {
      throw const FormatException('Request too large');
    }
    buffer.addAll(bytes);
  }
  final value = jsonDecode(utf8.decode(buffer));
  if (value is! Map<String, dynamic>)
    throw const FormatException('Malformed JSON');
  return value;
}

void json(HttpResponse response, int status, Map<String, Object?> body) {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
}

Future<void> serveWeb(HttpRequest req) async {
  final path = req.uri.path;
  final segments = req.uri.pathSegments;
  if (!const {'GET', 'HEAD'}.contains(req.method) ||
      segments.any(
        (s) =>
            s.startsWith('.') ||
            s.contains('/') ||
            s.contains(r'\') ||
            s.contains(':'),
      )) {
    req.response.statusCode = 404;
    return;
  }
  final file = File(
    '/web/' +
        (const {'/', '/pc', '/pc/', '/doctor', '/doctor/', '/login', '/login/'}.contains(path)
            ? 'index.html'
            : segments.join('/')),
  );
  if (!await file.exists()) {
    req.response.statusCode = 404;
    return;
  }
  req.response.headers.contentType = switch (file.path.split('.').last) {
    'html' => ContentType.html,
    'js' || 'mjs' => ContentType('application', 'javascript'),
    'wasm' => ContentType('application', 'wasm'),
    'json' => ContentType.json,
    'png' => ContentType('image', 'png'),
    'svg' => ContentType('image', 'svg+xml'),
    _ => ContentType.binary,
  };
  if (req.method == 'GET') await req.response.addStream(file.openRead());
}

Future<void> handle(
  HttpRequest req,
  Map<String, Connection> dbs,
  String password,
) async {
  final res = req.response;
  res.headers.set('Cache-Control', 'no-store');
  res.headers.set('X-Content-Type-Options', 'nosniff');
  final path = req.uri.path;
  try {
    if (!path.startsWith('/api/')) {
      await serveWeb(req);
      return;
    }
    final origin = req.headers.value('origin');
    if (req.method != 'GET' &&
        origin != null &&
        origin != req.requestedUri.origin) {
      json(res, 403, {'error': '같은 앱 주소에서 요청해 주세요.'});
      return;
    }
    final cookie = req.cookies
        .where((c) => c.name == 'byeoljari_new2')
        .firstOrNull;
    final now = DateTime.now();
    sessions.removeWhere((_, session) => !now.isBefore(session.expires));
    if (path == '/api/login' && req.method == 'POST') {
      final body = await readJson(req);
      final login = body['login'];
      if (login is! String ||
          !accounts.containsKey(login) ||
          body['password'] != password) {
        json(res, 401, {'error': '아이디와 비밀번호를 확인해 주세요.'});
        return;
      }
      // 의료진 계정은 의료진 협진 포털에서만, 의료진 협진 포털은 의료진 계정만
      final doctorScreen = body['screen'] == 'doctor';
      if (accounts[login]!.doctor != doctorScreen) {
        json(res, 403, {
          'error': doctorScreen
              ? '의료진 협진 포털은 의료진 계정으로만 로그인할 수 있어요.'
              : '의료진 계정은 의료진 협진 포털(/doctor)에서만 로그인할 수 있어요.',
        });
        return;
      }
      startSession(req, login, cookie);
      return;
    }

    if (path.startsWith('/api/passkey/') && req.method == 'POST') {
      await handlePasskey(req, dbs, password, cookie);
      return;
    }

    final authorization = req.headers.value('authorization');
    final token = authorization != null && authorization.startsWith('Bearer ')
        ? authorization.substring(7)
        : cookie?.value;
    final session = sessions[token];
    if (session == null) {
      json(res, 401, {'error': '로그인해 주세요.'});
      return;
    }
    final db = dbs[session.login]!;
    if (path == '/api/logout' && req.method == 'POST') {
      sessions.remove(token);
      res.cookies.add(
        Cookie('byeoljari_new2', '')
          ..path = '/api/'
          ..httpOnly = true
          ..sameSite = SameSite.strict
          ..maxAge = 0,
      );
      json(res, 200, {'ok': true});
      return;
    }
    if (path == '/api/state' && req.method == 'GET') {
      final row = (await db.execute(
        'SELECT version,state FROM byeoljari_new2.snapshot WHERE id=1',
      )).single;
      final account = accounts[session.login]!;
      json(res, 200, {
        ...row.toColumnMap(),
        'login': session.login,
        'dataset': account.dataset,
        'doctor': account.doctor,
      });
      return;
    }
    if (path == '/api/state' && req.method == 'PUT') {
      final body = await readJson(req);
      final version = body['version'], state = body['state'];
      if (version is! int ||
          !body.containsKey('state') ||
          (state != null && (state is! Map || state['v'] != 1))) {
        json(res, 400, {'error': '저장 형식을 확인해 주세요.'});
        return;
      }
      final updated = await db.execute(
        Sql.named('''
        UPDATE byeoljari_new2.snapshot SET version=version+1,state=@state::jsonb
        WHERE id=1 AND version=@version RETURNING version
      '''),
        parameters: {
          'version': version,
          'state': state == null ? null : jsonEncode(state),
        },
      );
      if (updated.isEmpty) {
        json(res, 409, {'error': '다른 창에서 먼저 저장했어요. 최신 기록을 불러오려면 새로고침해 주세요.'});
        return;
      }
      json(res, 200, updated.single.toColumnMap());
      return;
    }
    if (path == '/api/photo' && req.method == 'POST') {
      final mime = req.headers.contentType?.mimeType;
      if (!photoTypes.contains(mime)) {
        json(res, 400, {'error': '사진 파일(JPG·PNG·WEBP)만 올릴 수 있어요.'});
        return;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in req) {
        if (bytes.length + chunk.length > maxPhotoBytes) {
          json(res, 413, {'error': '사진이 너무 커요.'});
          return;
        }
        bytes.add(chunk);
      }
      if (bytes.isEmpty) throw const FormatException('Empty photo');
      final id = randomId();
      await db.execute(
        Sql.named(
          'INSERT INTO byeoljari_new2.photo (id,mime,bytes) VALUES (@id,@mime,@bytes)',
        ),
        parameters: {
          'id': id,
          'mime': mime,
          'bytes': TypedValue(Type.byteArray, bytes.takeBytes()),
        },
      );
      json(res, 200, {'id': id, 'url': '/api/photo/$id'});
      return;
    }
    if (path.startsWith('/api/photo/') && req.method == 'GET') {
      final id = path.substring('/api/photo/'.length);
      final rows = await db.execute(
        Sql.named('SELECT mime,bytes FROM byeoljari_new2.photo WHERE id=@id'),
        parameters: {'id': id},
      );
      if (rows.isEmpty) {
        json(res, 404, {'error': '사진을 찾을 수 없어요.'});
        return;
      }
      final row = rows.single.toColumnMap();
      final mime = (row['mime'] as String).split('/');
      res.headers.contentType = ContentType(mime.first, mime.last);
      // 사진은 한 번 올리면 바뀌지 않는다.
      res.headers.set('Cache-Control', 'private, max-age=31536000, immutable');
      res.add(row['bytes'] as List<int>);
      return;
    }
    json(res, 404, {'error': '요청을 찾을 수 없어요.'});
  } on FormatException {
    json(res, 400, {'error': '입력 형식을 확인해 주세요.'});
  } catch (error) {
    stderr.writeln(error.runtimeType);
    if (path.startsWith('/api/')) json(res, 503, {'error': 'DB에 연결하지 못했어요.'});
  } finally {
    await res.close();
  }
}
