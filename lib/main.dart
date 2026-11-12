import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/repository.dart';
import 'core/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 기기 안에 저장된 상태가 있으면 이어서 연다. 없으면 시연 시작 상태.
  final store = await PrefsSnapshotStore.open();
  final snapshot = await store.load();
  final repo = InMemoryRepository(snapshot: snapshot, store: store);
  runApp(ProviderScope(
    overrides: [repoProvider.overrideWith((ref) => repo)],
    child: const ByeoljariApp(),
  ));
}
