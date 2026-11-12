// 퀵 체온 상태: 열림/접힘, 선택한 반·별님, 별님별 작성 중인 값과 기록 완료 여부.
// 접었다 펴도 유지된다 (퀵 체온 명세 2장).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/baseline.dart';
import '../../core/providers.dart';

enum QtMode { resident, classSelect }

class QuickTempState {
  const QuickTempState({
    required this.open,
    required this.classId,
    required this.residentId,
    required this.mode,
    required this.drafts,
    required this.saved,
  });
  final bool open;
  final String classId;
  final String residentId;
  final QtMode mode;

  /// 별님별 작성 중인 값 (×10). 처음엔 36.5.
  final Map<String, int> drafts;

  /// 기록 완료 상태인 별님 → 저장된 값.
  final Map<String, int> saved;

  int get value => drafts[residentId] ?? defaultBaseline;
  bool get isSaved => saved[residentId] == value;

  QuickTempState copyWith({
    bool? open,
    String? classId,
    String? residentId,
    QtMode? mode,
    Map<String, int>? drafts,
    Map<String, int>? saved,
  }) =>
      QuickTempState(
        open: open ?? this.open,
        classId: classId ?? this.classId,
        residentId: residentId ?? this.residentId,
        mode: mode ?? this.mode,
        drafts: drafts ?? this.drafts,
        saved: saved ?? this.saved,
      );
}

class QuickTempController extends Notifier<QuickTempState> {
  @override
  QuickTempState build() {
    final repo = ref.read(repoProvider);
    final me = ref.watch(currentUserProvider);
    final allowed = measurableClasses(me);
    final cls = repo.classes.firstWhere((c) => allowed.contains(c.id), orElse: () => repo.classes.first);
    return QuickTempState(
      open: false,
      classId: cls.id,
      residentId: repo.residentsOf(cls.id).first.id,
      mode: QtMode.resident,
      drafts: const {},
      saved: const {},
    );
  }

  bool canMeasure(String classId) => measurableClasses(ref.read(currentUserProvider)).contains(classId);

  void toggle() => state = state.copyWith(open: !state.open, mode: QtMode.resident);
  void close() => state = state.copyWith(open: false);

  /// 다른 화면에서 별님을 지정해 연다 (통합 명세 4-3, C4).
  void openFor(String residentId) {
    final r = ref.read(repoProvider).resident(residentId);
    state = state.copyWith(open: true, classId: r.classId, residentId: residentId, mode: QtMode.resident);
  }

  void setMode(QtMode m) => state = state.copyWith(mode: m);

  void selectResident(String id) => state = state.copyWith(residentId: id, mode: QtMode.resident);

  /// 반 바꾸기: 그 반의 첫 별님으로. 권한 없는 반은 무시.
  void selectClass(String classId, {bool keepMode = false}) {
    if (!canMeasure(classId)) return;
    final first = ref.read(repoProvider).residentsOf(classId).first.id;
    state = state.copyWith(classId: classId, residentId: first, mode: keepMode ? state.mode : QtMode.resident);
  }

  /// 좌우 쓸기: 양 끝에서 멈춘다.
  void step(int delta) {
    final repo = ref.read(repoProvider);
    if (state.mode == QtMode.resident) {
      final list = repo.residentsOf(state.classId);
      final i = list.indexWhere((r) => r.id == state.residentId) + delta;
      if (i >= 0 && i < list.length) state = state.copyWith(residentId: list[i].id);
    } else {
      final allowed = repo.classes.where((c) => canMeasure(c.id)).toList();
      final i = allowed.indexWhere((c) => c.id == state.classId) + delta;
      if (i >= 0 && i < allowed.length) selectClass(allowed[i].id, keepMode: true);
    }
  }

  void setValue(int v) {
    final clamped = v.clamp(340, 420);
    state = state.copyWith(drafts: {...state.drafts, state.residentId: clamped});
  }

  /// 지금 값에서 delta만큼 (± 버튼·다이얼). 항상 최신 상태를 기준으로 계산한다.
  void nudge(int delta) => setValue(state.value + delta);

  void markSaved(String residentId, int value) => state = state.copyWith(saved: {...state.saved, residentId: value});
}

final quickTempProvider = NotifierProvider<QuickTempController, QuickTempState>(QuickTempController.new);
