import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/ds.dart';
import 'core/photo.dart';
import 'core/providers.dart';
import 'core/repository.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'passkeys_stub.dart' if (dart.library.js_interop) 'passkeys_web.dart';
import 'server_feedback_stub.dart' if (dart.library.js_interop) 'server_feedback_web.dart';
import 'tab_token_stub.dart' if (dart.library.js_interop) 'tab_token_web.dart';

/// 서버(도커) 연결 앱. 로그인한 계정에 따라 서버가 알려 준 DB(시연 · 개발)를 연다.
/// 주소가 /pc 로 시작하면 PC 화면(오피스 웹), /doctor 는 의료진 협진 포털, 그 밖에는 모바일 화면.
class ServerApp extends StatefulWidget {
  const ServerApp({super.key, required this.api, required this.path});

  final Uri api;
  final String path;

  @override
  State<ServerApp> createState() => _ServerAppState();
}

enum _LoginMode { restore, password, register, passkey }

class _ServerAppState extends State<ServerApp> {
  late _ServerStore store = _ServerStore(widget.api);
  final login = TextEditingController();
  final password = TextEditingController();
  InMemoryRepository? repository;
  bool busy = false;
  String? error;

  String get kind => screenKindOf(widget.path);
  bool get isPc => kind != 'mobile';

  @override
  void initState() {
    super.initState();
    if (widget.path != '/login' && widget.path != '/login/') _open();
  }

  @override
  void dispose() {
    login.dispose();
    password.dispose();
    store.client.close();
    super.dispose();
  }

  // ── 로그인 유지: 웹은 탭마다(sessionStorage), 설치형 앱은 기기에(shared_preferences) 토큰을 둔다.
  // 웹에서 탭마다 따로 두는 까닭: 같은 브라우저에서 /pc 와 /doctor 를 다른 계정으로 같이 연다.
  static const _tokenKey = 'byeoljari_server_token';

  Future<String?> _savedToken() async =>
      kIsWeb ? readTabToken() : (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<void> _saveToken(String? token) async {
    if (kIsWeb) return writeTabToken(token);
    final prefs = await SharedPreferences.getInstance();
    token == null ? await prefs.remove(_tokenKey) : await prefs.setString(_tokenKey, token);
  }

  bool get passkeyButtonAvailable =>
      kIsWeb && passkeysAvailable() && (Uri.base.host == 'localhost' || Uri.base.scheme == 'https');

  Future<void> _exchangePasskey(String name, {required bool registering}) async {
    final path = registering ? 'passkey/register' : 'passkey/login';
    final request = await store.request('$path/options', 'POST', {
      'login': name,
      if (registering) 'password': password.text,
    });
    final String response;
    try {
      response = await passkeyCeremony(registering, jsonEncode(request['options']));
    } catch (_) {
      throw const _ServerError(400, '기기 인증을 완료하지 못했어요. 패스키를 다시 선택해 주세요.');
    }
    final verified =
        await store.request('$path/verify', 'POST', {'ticket': request['ticket'], 'credential': jsonDecode(response)});
    if (verified['token'] case final String token) {
      store.token = token;
      await _saveToken(token);
    }
  }

  Future<void> _open([_LoginMode mode = _LoginMode.restore]) async {
    if (busy) return;
    setState(() {
      error = null;
      busy = true;
    });
    try {
      final name = login.text.trim();
      // 저장해 둔 토큰으로 이어서 연다 (웹은 이 탭의 토큰, 없으면 브라우저 쿠키).
      if (mode == _LoginMode.restore && store.token == null) {
        store.token = await _savedToken();
        if (store.token == null && !kIsWeb) return;
      }
      if (mode == _LoginMode.password || mode == _LoginMode.register) {
        final session = await store.request('login', 'POST', {
          'login': name,
          'password': password.text,
          'screen': kind,
        });
        store.token = session['token'] as String;
        await _saveToken(store.token);
      }
      if (mode == _LoginMode.register || mode == _LoginMode.passkey) {
        await _exchangePasskey(name, registering: mode == _LoginMode.register);
      }
      final snapshot = await store.load();
      if (!mounted) return;
      // 의료진 계정은 의료진 협진 포털(/doctor)에서만, 그 포털은 의료진 계정만.
      if (store.doctor != (kind == 'doctor')) {
        if (mode == _LoginMode.restore) {
          // 이 브라우저의 다른 탭 로그인(쿠키)이 이 화면용이 아니다: 오류 없이 빈 로그인 화면으로.
          store.client.close();
          store = _ServerStore(widget.api);
          return;
        }
        throw _ServerError(
          403,
          kind == 'doctor' ? '의료진 협진 포털은 의료진 계정으로 로그인해 주세요.' : '의료진 계정은 의료진 협진 포털(주소 끝 /doctor)에서 로그인해 주세요.',
        );
      }
      // 서버가 알려 준 자료 종류 (demo 시연 DB · dev 개발 DB)
      final dataset = store.dataset == 'demo' ? Dataset.demo : Dataset.dev;
      final repo = InMemoryRepository(dataset: dataset, snapshot: snapshot, store: store);
      // 처음 여는 DB(비어 있음)면 처음 상태를 바로 저장해 둔다.
      if (snapshot == null) await store.save(repo.toSnapshot());
      store.repo = repo;
      store.onSessionLost = _sessionLost;
      store.startSync();
      repository = repo;
      password.clear();
    } on _ServerError catch (e) {
      if (e.status == 401) {
        // 로그인이 끝났다 (12시간 지남 · 서버 재시작): 저장한 토큰을 지운다.
        store.token = null;
        await _saveToken(null);
      }
      if (mode != _LoginMode.restore || e.status != 401) error = e.message;
    } catch (_) {
      error = '서버에 연결하지 못했어요.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// 동기화 중 로그인이 끊겼다: 로그인 화면으로 돌리고 이유를 보여준다.
  Future<void> _sessionLost(String message) async {
    await _saveToken(null);
    if (!mounted) return;
    setState(() {
      store.stopSync();
      repository?.dispose();
      repository = null;
      store.client.close();
      store = _ServerStore(widget.api);
      error = message;
    });
  }

  Future<void> _logout() async {
    try {
      await store.request('logout', 'POST', const {});
    } catch (_) {
      // 서버가 응답하지 않아도 화면은 로그인으로 돌아간다.
    }
    await _saveToken(null);
    if (!mounted) return;
    setState(() {
      store.stopSync();
      repository?.dispose();
      repository = null;
      store.client.close();
      store = _ServerStore(widget.api);
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = repository;
    if (current != null) {
      return ProviderScope(
        key: ValueKey(current),
        overrides: [
          repoProvider.overrideWith((_) => current),
          screenKindProvider.overrideWithValue(kind),
          logoutProvider.overrideWithValue(_logout),
          photoUploadProvider.overrideWithValue(store.uploadPhoto),
          // 설치형 앱은 사진을 서버 주소 + 로그인 토큰으로 받는다
          photoAccessProvider.overrideWithValue(
            () => (base: store.api, headers: {if (store.token != null) 'Authorization': 'Bearer ${store.token}'}),
          ),
        ],
        child: ByeoljariApp(pc: isPc),
      );
    }
    return MaterialApp(
      title: switch (kind) {
        'doctor' => '별자리노트 · 의료진 협진 포털',
        'pc' => '별자리노트 · 오피스 웹',
        _ => '별자리노트',
      },
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: _LoginPage(
        pc: isPc,
        doctor: kind == 'doctor',
        login: login,
        password: password,
        busy: busy,
        error: error,
        onPassword: () => _open(_LoginMode.password),
        onPasskey: passkeyButtonAvailable ? () => _open(_LoginMode.passkey) : null,
        onRegister: passkeyButtonAvailable ? () => _open(_LoginMode.register) : null,
        passkeyHint: !passkeyButtonAvailable && kIsWeb && Uri.base.host == '127.0.0.1'
            ? '패스키는 http://localhost:8093/login 에서 사용할 수 있어요.'
            : null,
      ),
    );
  }
}

/// 로그인 (모바일 · PC 공통). 다른 화면과 같은 토큰: 회색 바탕, 흰 카드(24), violet 주요 버튼.
class _LoginPage extends StatelessWidget {
  const _LoginPage({
    required this.pc,
    this.doctor = false,
    required this.login,
    required this.password,
    required this.busy,
    required this.error,
    required this.onPassword,
    this.onPasskey,
    this.onRegister,
    this.passkeyHint,
  });
  final bool pc;

  /// 의료진 협진 포털 주소(/doctor)로 들어왔을 때.
  final bool doctor;
  final TextEditingController login;
  final TextEditingController password;
  final bool busy;
  final String? error;
  final VoidCallback onPassword;
  final VoidCallback? onPasskey;
  final VoidCallback? onRegister;
  final String? passkeyHint;

  @override
  Widget build(BuildContext context) {
    final primary = pc ? DsButtonKind.blue : DsButtonKind.violet;
    final accent = pc ? Ds.blue500 : Ds.violet500;
    InputDecoration field(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Ds.gray500),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    );

    return Scaffold(
      backgroundColor: Ds.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.36),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '별자리노트',
                          style: TextStyle(fontSize: T.headline, fontWeight: FontWeight.w700, letterSpacing: -0.6),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '|',
                          style: TextStyle(fontSize: T.caption, color: Ds.gray300),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          doctor ? '의료진 협진 포털' : (pc ? '오피스 웹' : '생활관'),
                          style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: Ds.gray600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '울산 혜진원 장애인거주시설',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: T.caption, color: Ds.gray500),
                    ),
                    const SizedBox(height: 24),
                    DsCard(
                      shadow: Ds.shadowCard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '로그인',
                            style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '테스트 계정으로 들어가요.',
                            style: TextStyle(fontSize: T.caption, color: Ds.gray500),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: login,
                            enabled: !busy,
                            autofillHints: const [AutofillHints.username],
                            decoration: field('아이디', Icons.person_outline_rounded),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: password,
                            enabled: !busy,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: field('비밀번호', Icons.lock_outline_rounded),
                            onSubmitted: (_) => onPassword(),
                          ),
                          if (error case final String message) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Ds.red50,
                                borderRadius: BorderRadius.circular(Radii.button),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 18, color: Ds.red500),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: const TextStyle(
                                        fontSize: T.label,
                                        color: Ds.red500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          DsButton(
                            busy ? '연결 중…' : '로그인',
                            kind: primary,
                            height: 52,
                            expand: true,
                            onPressed: busy ? null : onPassword,
                          ),
                          if (onPasskey != null) ...[
                            const SizedBox(height: 8),
                            DsButton(
                              '패스키로 로그인',
                              kind: DsButtonKind.outline,
                              icon: Icons.fingerprint_rounded,
                              height: 52,
                              expand: true,
                              onPressed: busy ? null : onPasskey,
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: busy ? null : onRegister,
                              child: const Text('비밀번호로 로그인하고 패스키 등록', style: TextStyle(fontSize: T.label)),
                            ),
                          ] else if (passkeyHint != null) ...[
                            const SizedBox(height: 12),
                            SelectableText(
                              passkeyHint!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: T.caption, color: Ds.gray500),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 주소 안내는 웹에서만 (설치형 앱은 주소가 없다)
                    if (kIsWeb) ...[
                      const SizedBox(height: 16),
                      Text(
                        doctor
                            ? '의료진 전용 주소예요. 오피스 웹은 주소 끝에 /pc 를 붙여서 열어요.'
                            : (pc ? '모바일 화면은 주소 끝의 /pc 를 빼고 열어요.' : 'PC 화면은 주소 끝에 /pc 를 붙여서 열어요.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: T.caption, color: Ds.gray500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerError implements Exception {
  const _ServerError(this.status, this.message);
  final int status;
  final String message;
}

class _ServerStore implements SnapshotStore {
  _ServerStore(this.api);
  final Uri api;
  final client = http.Client();
  String? token;

  /// 서버가 알려 준 로그인 계정 · 자료 종류(demo 시연 / dev 개발) · 의료진 계정인지. 계정 목록은 서버 .env 에만 있다.
  String? login;
  String? dataset;
  bool doctor = false;
  int _version = 0;
  bool _conflict = false;
  Future<void> _pending = Future.value();

  Future<Map<String, dynamic>> request(String path, [String method = 'GET', Map<String, Object?>? body]) async {
    final req = http.Request(method, api.resolve(path));
    if (token != null) req.headers['Authorization'] = 'Bearer ${token!}';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }
    final streamed = await client.send(req).timeout(const Duration(seconds: 8));
    final res = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 8));
    final value = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) throw _ServerError(res.statusCode, value['error'] as String? ?? '요청을 처리하지 못했어요.');
    return value;
  }

  /// 프로필 사진 올리기: 사진 파일은 서버 photo 표에, 앱 상태에는 돌려받은 주소만 저장한다.
  Future<String> uploadPhoto(String dataUrl) async {
    final (mime, bytes) = decodeDataUrl(dataUrl);
    final req = http.Request('POST', api.resolve('photo'));
    if (token != null) req.headers['Authorization'] = 'Bearer ${token!}';
    req.headers['Content-Type'] = mime;
    req.bodyBytes = bytes;
    final streamed = await client.send(req).timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 30));
    final value = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) throw _ServerError(res.statusCode, value['error'] as String? ?? '사진을 올리지 못했어요.');
    return value['url'] as String;
  }

  @override
  Future<String?> load() async {
    final stored = await request('state');
    _version = stored['version'] as int;
    login = stored['login'] as String?;
    dataset = stored['dataset'] as String?;
    doctor = stored['doctor'] == true;
    final state = stored['state'];
    // 예전 형식(명단이 코드에 있던 때)은 새로 채운다.
    if (state is! Map || state['schema'] != 2) return null;
    return jsonEncode(state);
  }

  // ── 모바일 ↔ PC 실시간 맞추기: 4초마다 서버 버전을 보고, 바뀌었으면 받아온다.
  InMemoryRepository? repo;
  Timer? _sync;
  bool _writing = false;

  /// 로그인이 끊겼을 때 (서버 재시작 · 12시간 지남 · 같은 브라우저 다른 탭에서 다른 계정으로 로그인).
  /// 조용히 동기화가 멈추지 않게 화면을 로그인으로 돌린다.
  void Function(String message)? onSessionLost;

  void _lost(String message) {
    stopSync();
    final f = onSessionLost;
    onSessionLost = null;
    f?.call(message);
  }

  void startSync() {
    _sync?.cancel();
    _sync = Timer.periodic(const Duration(seconds: 4), (_) => _pull());
  }

  void stopSync() {
    _sync?.cancel();
    _sync = null;
  }

  Future<bool> _pull() async {
    final r = repo;
    if (r == null || _writing || r.hasPendingSave) return false;
    try {
      final stored = await request('state');
      if (login != null && stored['login'] != login) {
        _lost('이 브라우저의 다른 탭에서 다른 계정으로 로그인했어요. 다시 로그인해 주세요.');
        return false;
      }
      final version = stored['version'] as int;
      final state = stored['state'];
      if (version == _version || _writing || r.hasPendingSave) return false;
      if (state is! Map || state['schema'] != 2) return false;
      _version = version;
      _conflict = false;
      return r.loadRemote(jsonEncode(state));
    } on _ServerError catch (e) {
      if (e.status == 401) _lost(sessionEndedText);
      return false;
    } catch (_) {
      return false;
    }
  }

  static const sessionEndedText = '로그인이 끝났어요 (서버를 다시 켰거나 12시간이 지났어요). 다시 로그인해 주세요.';

  Future<void> _write(Object? state, {required bool reset}) {
    final write = _pending.then((_) async {
      _writing = true;
      try {
        if (_conflict) {
          throw const _ServerError(409, '다른 화면에서 먼저 저장했어요.');
        }
        final saved = await request('state', 'PUT', {'version': _version, 'state': state});
        _version = saved['version'] as int;
      } on _ServerError catch (error) {
        _conflict = error.status == 409;
        if (_conflict) {
          // 다른 화면(모바일 ↔ PC)이 먼저 저장했다: 최신 상태를 받아오고 다시 해 달라고 알린다.
          _writing = false;
          final pulled = await _pull();
          saveError(pulled ? '다른 화면에서 바뀐 내용을 불러왔어요. 방금 한 일을 한 번 더 해 주세요.' : '저장하지 못했어요. 새로고침해 주세요.');
          if (reset) rethrow;
          return;
        }
        if (error.status == 401) {
          saveError('저장하지 못했어요. $sessionEndedText');
          _lost(sessionEndedText);
          if (reset) rethrow;
          return;
        }
        saveError('저장하지 못했어요. ${error.message}');
        if (reset) rethrow;
      } catch (_) {
        saveError('서버 연결을 확인해 주세요. 기록을 저장하지 못했어요.');
        if (reset) rethrow;
      } finally {
        _writing = false;
      }
    });
    _pending = write.catchError((Object _) {});
    return write;
  }

  @override
  Future<void> save(String json) => _write(jsonDecode(json), reset: false);

  @override
  Future<void> clear() => _write(null, reset: true);
}
