import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'repository.dart';

/// 저장소. main.dart / server_app.dart에서 서버 저장소를 붙인 것으로 덮어쓴다 (overrideWith).
final repoProvider = ChangeNotifierProvider<InMemoryRepository>((ref) => InMemoryRepository());

/// 지금 화면이 모바일(mobile)인지 PC(pc)인지. PC 셸에서 덮어쓴다.
final screenKindProvider = Provider<String>((ref) => 'mobile');

/// 주소 → 화면 종류: `/doctor` 의료진 협진 포털, `/pc` 오피스 웹(PC), 그 밖 모바일.
String screenKindOf(String path) {
  bool under(String p) => path == p || path.startsWith('$p/');
  if (under('/doctor')) return 'doctor';
  if (under('/pc')) return 'pc';
  return 'mobile';
}

/// 지금 앱을 쓰는 사람. 처음엔 그 화면의 기본 사용자 (모바일 = 생활관 선생님, PC = 수석간호사).
final currentUserProvider = StateProvider<String>((ref) => ref.read(repoProvider).defaultUser(ref.read(screenKindProvider)));

/// 시계 (실제 시각).
final clockProvider = Provider<DateTime Function()>((ref) => ref.read(repoProvider).now);
