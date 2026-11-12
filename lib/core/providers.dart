import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'repository.dart';
import 'seed.dart';

/// 저장소. 서버가 생기면 구현만 바꾼다.
final repoProvider = ChangeNotifierProvider<InMemoryRepository>((ref) => InMemoryRepository());

/// 지금 앱을 쓰는 사람 (시연에서는 역할 바꾸기로 바뀜).
final currentUserProvider = StateProvider<String>((ref) => demoUserId);

/// 시연 시계: 10/28 09:41에서 시작해 실제 시간만큼 흐른다.
final clockProvider = Provider<DateTime Function()>((ref) {
  final startedAt = DateTime.now();
  return () => demoStart.add(DateTime.now().difference(startedAt));
});

/// 체온을 잴 수 있는 반 (ClassPermission). 금요일은 시드로 고정.
const measurePermission = <String, Set<String>>{
  'kim_haneul': {'milkyway'},
  'choi_minho': {'whale'},
  'oh_jimin': {'aries'},
  'park_jieun': {'aquarius', 'milkyway'},
  'lee_sujin': {'milkyway'},
  'park_soyeon': {'aquarius', 'pisces', 'bear', 'milkyway', 'aries', 'whale'},
};

Set<String> measurableClasses(String staffId) => measurePermission[staffId] ?? const {};
