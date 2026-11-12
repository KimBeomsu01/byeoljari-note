// 기기 안 저장. 앱 상태 전체를 JSON 한 덩어리로 저장한다.
// 폰: 앱 저장소(SharedPreferences), 웹: 브라우저 저장소(localStorage).
// [주의] 가상 데이터 전용. 실제 별님 정보를 넣으려면 암호화와 서버 결정(G5)이 먼저다.
import 'package:shared_preferences/shared_preferences.dart';

abstract class SnapshotStore {
  Future<String?> load();
  Future<void> save(String json);
  Future<void> clear();
}

class PrefsSnapshotStore implements SnapshotStore {
  PrefsSnapshotStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'byeoljari.snapshot.v1';

  static Future<PrefsSnapshotStore> open() async => PrefsSnapshotStore(await SharedPreferences.getInstance());

  @override
  Future<String?> load() async => _prefs.getString(_key);
  @override
  Future<void> save(String json) => _prefs.setString(_key, json);
  @override
  Future<void> clear() => _prefs.remove(_key);
}

/// 테스트용.
class MemorySnapshotStore implements SnapshotStore {
  String? value;
  @override
  Future<String?> load() async => value;
  @override
  Future<void> save(String json) async => value = json;
  @override
  Future<void> clear() async => value = null;
}
