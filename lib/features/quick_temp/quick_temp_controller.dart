// 체온 측정 (QuickVital) 상태: 열림, 선택한 반·별님, 단계(level), 다이얼 값, 방금 기록.
// Claude Design QuickVital.dc.html 의 state { level, ci, ri, temp, recorded } 를 그대로 옮겼다.
// 공개 API (app.dart · 다른 화면): quickTempProvider, openFor(residentId), toggle(), close(), state.open.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/baseline.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';

/// 단계: 반 고르기 / 별님 고르기 (별님 단계에서만 체온을 기록한다).
enum QtLevel { classes, resident }

/// 좌우로 민 곳: 반 다이얼 · 별님 다이얼 · 그 아래 화면(지금 단계를 넘긴다).
enum QtZone { classes, resident, screen }

class QuickTempState {
  const QuickTempState({
    required this.open,
    required this.classId,
    required this.residentId,
    required this.level,
    required this.value,
    this.recorded,
  });
  final bool open;
  final String? classId;

  /// 별님 다이얼 위치. 반 단계에서도 자리는 남는다 (선택은 [level]로 본다).
  final String? residentId;
  final QtLevel level;

  /// 다이얼 값 (×10).
  final int value;

  /// 방금 기록한 결과. 값·별님·단계를 바꾸면 사라진다 (디자인 recorded).
  final SaveResult? recorded;

  QuickTempState copyWith({
    bool? open,
    String? classId,
    String? residentId,
    QtLevel? level,
    int? value,
    SaveResult? recorded,
    bool clearRecorded = false,
  }) =>
      QuickTempState(
        open: open ?? this.open,
        classId: classId ?? this.classId,
        residentId: residentId ?? this.residentId,
        level: level ?? this.level,
        value: value ?? this.value,
        recorded: clearRecorded ? null : (recorded ?? this.recorded),
      );
}

/// 화면이 그리는 모양 (디자인 model()): 다이얼의 반 목록과 위치, 별님 목록과 위치, 선택 별님.
class QtView {
  const QtView({
    required this.classes,
    required this.ci,
    required this.residents,
    required this.ri,
    required this.selected,
    required this.canMeasure,
  });
  final List<Class> classes;
  final int ci;
  final List<Resident> residents;

  /// 별님 다이얼 위치 (별님이 없으면 -1).
  final int ri;

  /// 별님 단계에서 고른 별님 (반 단계면 null).
  final Resident? selected;

  /// 지금 반을 잴 권한이 있는가.
  final bool canMeasure;

  Class? get cls => classes.isEmpty ? null : classes[ci];
}

class QuickTempController extends Notifier<QuickTempState> {
  InMemoryRepository get _repo => ref.read(repoProvider);
  String get _me => ref.read(currentUserProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  QuickTempState build() {
    final repo = ref.read(repoProvider);
    final me = ref.watch(currentUserProvider);
    final allowed = repo.measurableClasses(me);
    final classes = repo.classes;
    final cls = classes.where((c) => allowed.contains(c.id)).firstOrNull ?? classes.firstOrNull;
    final first = cls == null ? null : repo.residentsOf(cls.id).firstOrNull;
    return QuickTempState(
      open: false,
      classId: cls?.id,
      residentId: first?.id,
      level: QtLevel.resident,
      value: first == null ? defaultBaseline : repo.baselineOf(first.id, repo.now()).value,
    );
  }

  bool canMeasure(String classId) => _repo.measurableClasses(_me).contains(classId);

  /// 반 다이얼: 측정 권한이 있는 반만. 다른 화면에서 권한 없는 반의 별님으로 열었으면 그 반도 보인다.
  List<Class> dialClasses() {
    final repo = _repo;
    final allowed = repo.measurableClasses(_me);
    final list = repo.classes.where((c) => allowed.contains(c.id) || c.id == state.classId).toList();
    if (list.isEmpty && repo.classes.isNotEmpty) return [repo.classes.first];
    return list;
  }

  /// 지금 상태를 화면 모양으로 (지워진 반·별님은 첫 자리로).
  QtView view() {
    final repo = _repo;
    final classes = dialClasses();
    final ci = classes.isEmpty ? 0 : classes.indexWhere((c) => c.id == state.classId).clamp(0, classes.length - 1);
    final residents = classes.isEmpty ? const <Resident>[] : repo.residentsOf(classes[ci].id);
    final ri = residents.isEmpty ? -1 : residents.indexWhere((r) => r.id == state.residentId).clamp(0, residents.length - 1);
    final selected = state.level == QtLevel.resident && ri >= 0 ? residents[ri] : null;
    return QtView(
      classes: classes,
      ci: ci,
      residents: residents,
      ri: ri,
      selected: selected,
      canMeasure: classes.isNotEmpty && canMeasure(classes[ci].id),
    );
  }

  int _baseline(String residentId) => _repo.baselineOf(residentId, _now()).value;

  // ── 열고 닫기
  void toggle() => state.open ? close() : state = state.copyWith(open: true);

  /// 닫으면 방금 기록 시트는 사라진다 (값과 선택은 남는다).
  void close() => state = state.copyWith(open: false, clearRecorded: true);

  /// 다른 화면에서 별님을 지정해 연다 (인수인계 "재측정하기" 등).
  void openFor(String residentId) {
    final r = _repo.resident(residentId);
    state = QuickTempState(
      open: true,
      classId: r.classId,
      residentId: r.id,
      level: QtLevel.resident,
      value: _baseline(r.id),
    );
  }

  // ── 선택 (디자인 selectClass · selectResident · setLevel · step)
  void selectClassAt(int i) {
    final v = view();
    if (v.classes.isEmpty) return;
    final next = i.clamp(0, v.classes.length - 1);
    if (next == v.ci) {
      state = state.copyWith(classId: v.classes[next].id, level: QtLevel.classes, clearRecorded: true);
      return;
    }
    final cls = v.classes[next];
    final first = _repo.residentsOf(cls.id).firstOrNull;
    state = QuickTempState(
      open: state.open,
      classId: cls.id,
      residentId: first?.id,
      level: QtLevel.classes,
      value: state.value,
    );
  }

  void selectClass(String classId) {
    final i = view().classes.indexWhere((c) => c.id == classId);
    if (i >= 0) selectClassAt(i);
  }

  void selectResidentAt(int i) {
    final v = view();
    if (v.residents.isEmpty) return;
    final next = i.clamp(0, v.residents.length - 1);
    if (state.level == QtLevel.resident && next == v.ri) return;
    final r = v.residents[next];
    state = state.copyWith(
      classId: v.cls!.id,
      residentId: r.id,
      level: QtLevel.resident,
      value: _baseline(r.id),
      clearRecorded: true,
    );
  }

  void selectResident(String residentId) {
    final i = view().residents.indexWhere((r) => r.id == residentId);
    if (i >= 0) selectResidentAt(i);
  }

  void setLevel(QtLevel level) {
    if (level == state.level) return;
    final v = view();
    if (level == QtLevel.resident) {
      if (v.ri < 0) return;
      final r = v.residents[v.ri];
      state = state.copyWith(residentId: r.id, level: QtLevel.resident, value: _baseline(r.id), clearRecorded: true);
    } else {
      state = state.copyWith(level: QtLevel.classes, clearRecorded: true);
    }
  }

  /// 좌우 밀기 한 칸. [dir] 1 = 다음, -1 = 앞.
  void step(QtZone zone, int dir) {
    final v = view();
    final target = zone == QtZone.screen
        ? (state.level == QtLevel.classes ? QtZone.classes : QtZone.resident)
        : zone;
    if (target == QtZone.classes) {
      selectClassAt(v.ci + dir);
    } else if (state.level == QtLevel.classes) {
      selectResidentAt(v.ri);
    } else {
      selectResidentAt(v.ri + dir);
    }
  }

  // ── 체온 값
  void setValue(int v) => state = state.copyWith(value: v.clamp(minTemp, maxTemp), clearRecorded: true);

  /// 지금 값에서 delta만큼 (± 버튼 · 링 돌리기). 항상 최신 상태를 기준으로 계산한다.
  void nudge(int delta) => setValue(state.value + delta);

  // ── 기록
  /// 고른 별님에게 지금 값을 기록한다. 별님 단계가 아니거나 권한이 없으면 null.
  /// 체온 저장은 저장소의 saveMeasurement 하나뿐이다.
  SaveResult? record() {
    final v = view();
    final r = v.selected;
    if (r == null || !v.canMeasure) return null;
    final result = _repo.saveMeasurement(residentId: r.id, value: state.value, by: _me, at: _now());
    state = state.copyWith(recorded: result);
    return result;
  }

  /// 시트를 닫는다 (잘못 쟀어요 뒤 등).
  void clearRecorded() => state = state.copyWith(clearRecorded: true);
}

final quickTempProvider = NotifierProvider<QuickTempController, QuickTempState>(QuickTempController.new);
