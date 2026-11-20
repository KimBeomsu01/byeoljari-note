import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/repository.dart';
import 'core/storage.dart';
import 'server_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final path = kIsWeb ? Uri.base.path : '/';
  final kind = screenKindOf(path);
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) {
    // 웹은 같은 주소의 /api/, 설치형 앱은 서버 전체 주소 (예: http://<서버 PC IP>:8093/api/). 끝의 / 는 꼭 있어야 한다.
    final base = configured.endsWith('/') ? configured : '$configured/';
    final api = kIsWeb ? Uri.base.resolve(base) : Uri.parse(base);
    runApp(ServerApp(api: api, path: path));
    return;
  }
  // 서버 없이 실행 (개발용): 기기 안에 시연 자료를 저장한다.
  final store = await PrefsSnapshotStore.open();
  final snapshot = await store.load();
  final repo = InMemoryRepository(dataset: Dataset.demo, snapshot: snapshot, store: store);
  runApp(ProviderScope(
    overrides: [
      repoProvider.overrideWith((ref) => repo),
      screenKindProvider.overrideWithValue(kind),
    ],
    child: ByeoljariApp(pc: kind != 'mobile'),
  ));
}
