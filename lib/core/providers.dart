import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'repository.dart';
import 'seed.dart';

/// 저장소. main.dart에서 기기 안 저장소를 붙인 것으로 덮어쓴다 (overrideWith).
/// 서버가 생기면 구현만 바꾼다.
final repoProvider = ChangeNotifierProvider<InMemoryRepository>((ref) => InMemoryRepository());

/// 지금 앱을 쓰는 사람 (시연에서는 역할 바꾸기로 바뀜).
final currentUserProvider = StateProvider<String>((ref) => demoUserId);

/// 시연 시계: 저장소의 시계를 쓴다 (10/28 09:41 시작, 껐다 켜면 이어서).
final clockProvider = Provider<DateTime Function()>((ref) => ref.read(repoProvider).now);

/// 체온을 잴 수 있는 반 (ClassPermission). 금요일은 시드로 고정.
const measurePermission = <String, Set<String>>{
  'kim_haneul': {'milkyway'},
  'choi_minho': {'whale'},
  'oh_jimin': {'aquarius', 'pisces', 'bear', 'milkyway', 'aries', 'whale'}, // 야간 당직은 전체
  'park_jieun': {'aquarius', 'milkyway'},
  'lee_sujin': {'milkyway'},
  'park_soyeon': {'aquarius', 'pisces', 'bear', 'milkyway', 'aries', 'whale'},
};

Set<String> measurableClasses(String staffId) => measurePermission[staffId] ?? const {};
