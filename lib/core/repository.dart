// 저장소. 서버가 정해지기 전까지는 기기 안 메모리 구현만 쓴다 (통합 명세 11-1).
// 기록은 지우지 않는다. 무효·취소 표시만 한다.
import 'package:flutter/foundation.dart';

import 'baseline.dart';
import 'judgment.dart';
import 'models.dart';
import 'seed.dart' as seed;

/// 받침에 따라 '이/가'를 붙인다. 예: '박소연 간호사가', '김하늘 선생님이'.
String withSubject(String word) {
  final c = word.codeUnitAt(word.length - 1);
  if (c < 0xAC00 || c > 0xD7A3) return '$word이(가)';
  return (c - 0xAC00) % 28 == 0 ? '$word가' : '$word이';
}

/// 앱 안 알림 (금요일 시연은 배너 + 🔔 목록으로 대신, 통합 명세 9장).
class AppNotice {
  const AppNotice({
    required this.id,
    required this.caseId,
    required this.title,
    required this.body,
    required this.at,
    required this.recipientIds,
    this.important = false,
  });
  final String id;
  final String caseId;
  final String title;
  final String body;
  final DateTime at;
  final Set<String> recipientIds;

  /// 방해 금지를 무시하는 중요 알림 (긴급).
  final bool important;
}

class SaveResult {
  const SaveResult({required this.measurement, this.caseItem, this.caseCreated = false, this.escalated = false, this.task});
  final Measurement measurement;
  final Case? caseItem;
  final bool caseCreated;

  /// 이상 대응 → 긴급으로 바뀜.
  final bool escalated;

  /// 주의로 자동 생긴 재측정 할 일.
  final Task? task;
}

class InMemoryRepository extends ChangeNotifier {
  InMemoryRepository({bool withDemoState = true}) {
    _measurements.addAll(seed.seedHistory());
    if (withDemoState) _applyDemoStart();
  }

  final List<Measurement> _measurements = [];
  final List<Case> _cases = [];
  final List<CaseEvent> _events = [];
  final List<Entry> _entries = [];
  final List<AppNotice> _notices = [];
  int _seq = 0;

  String _id(String p) => '$p-${++_seq}';

  // ── 읽기
  List<Class> get classes => seed.classes;
  List<Resident> residentsOf(String classId) =>
      seed.residents.where((r) => r.classId == classId).toList()..sort((a, b) => a.order.compareTo(b.order));
  Resident resident(String id) => seed.residents.firstWhere((r) => r.id == id);
  Class classOf(String id) => seed.classes.firstWhere((c) => c.id == id);
  Staff staff(String id) => seed.staff.firstWhere((s) => s.id == id);
  List<Staff> get allStaff => seed.staff;

  List<Measurement> measurementsOf(String residentId) =>
      _measurements.where((m) => m.residentId == residentId).toList()..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

  /// 무효가 아닌 가장 최근 측정.
  Measurement? latestOf(String residentId) {
    for (final m in measurementsOf(residentId)) {
      if (!m.isVoided) return m;
    }
    return null;
  }

  Measurement measurement(String id) => _measurements.firstWhere((m) => m.id == id);

  BaselineResult baselineOf(String residentId, DateTime now) =>
      computeBaseline(resident: resident(residentId), history: _measurements, now: now);

  List<Case> get openCases {
    final list = _cases.where((c) => c.isOpen).toList();
    // 긴급이 맨 위, 그다음 최근 순 (6-3).
    list.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Case? openCaseOf(String residentId) {
    for (final c in _cases) {
      if (c.residentId == residentId && c.isOpen) return c;
    }
    return null;
  }

  Case caseById(String id) => _cases.firstWhere((c) => c.id == id);
  List<CaseEvent> eventsOf(String caseId) => _events.where((e) => e.caseId == caseId).toList();
  List<Entry> get entries => List.unmodifiable(_entries.reversed);
  List<AppNotice> noticesFor(String staffId) =>
      _notices.where((n) => n.recipientIds.contains(staffId)).toList().reversed.toList();

  MedicationGuideline? guidelineOf(String residentId) {
    for (final g in seed.medicationGuidelines) {
      if (g.residentId == residentId) return g;
    }
    return null;
  }

  /// 열린 체온 할 일이 있는 별님인가.
  List<Entry> openTempTasksOf(String residentId) => _entries
      .where((e) => e.residentId == residentId && e.task != null && !e.task!.done && e.task!.kind == TaskKind.temp)
      .toList();

  // ── 체온 저장 (통합 명세 7-1). 체온 입력은 이 함수 하나뿐이다.
  SaveResult saveMeasurement({
    required String residentId,
    required int value,
    required String by,
    required DateTime at,
    String? correctsId,
  }) {
    if (!isValidTemp(value)) {
      throw ArgumentError('체온은 34.0~42.0℃ 사이여야 해요');
    }
    final r = resident(residentId);
    final base = baselineOf(residentId, at).value;
    final j = judge(value: value, baseline: base);
    var m = Measurement(
      id: _id('m'),
      residentId: residentId,
      classId: r.classId,
      value: value,
      measuredAt: at,
      recordedBy: by,
      judgment: j,
      correctsId: correctsId,
    );

    // 열린 체온 할 일 자동 완료 (C4)
    for (final e in openTempTasksOf(residentId)) {
      _replaceEntry(e.withTask(e.task!.complete(by: by, at: at, measurementId: m.id)));
    }

    Case? caseItem;
    var created = false;
    var escalated = false;
    Task? task;
    final open = openCaseOf(residentId);

    if (open != null) {
      // 진행 중인 이상 건에 재측정으로 붙임
      m = m.copyWith(caseId: open.id);
      _event(open.id, 'remeasured', by, at, {'measurementId': m.id, 'value': value, 'stage': j.stage.name});
      var c = open;
      if (j.stage.opensCase) {
        if (j.stage.rank > c.severity.rank) {
          c = c.copyWith(severity: j.stage);
          escalated = j.stage == Stage.danger;
          if (escalated) {
            _event(c.id, 'escalated', 'system', at, {'to': 'danger'});
            _notify(c, '긴급으로 바뀌었어요', '${r.name} ${formatTemp(value)}℃ · 위험', at, important: true, addDirector: true);
          }
        }
        c = c.copyWith(clearRecovered: true, status: c.status == CaseStatus.waitingRemeasure ? CaseStatus.active : null);
      } else if (c.recoveredAt == null) {
        c = c.copyWith(recoveredAt: at);
        _event(c.id, 'recovered', 'system', at, {'value': value});
      }
      _replaceCase(c);
      caseItem = c;
    } else if (j.stage.opensCase) {
      final c = Case(
        id: _id('case'),
        residentId: residentId,
        classId: r.classId,
        severity: j.stage,
        status: CaseStatus.unacked,
        stage: 1,
        firstMeasurementId: m.id,
        firstTemp: value,
        baseline: base,
        createdAt: at,
      );
      _cases.add(c);
      m = m.copyWith(caseId: c.id);
      _event(c.id, 'created', 'system', at, {'measurementId': m.id});
      _entries.add(Entry(
        id: _id('e'),
        scope: EntryScope.resident,
        authorId: by,
        kindLabel: '체온 기록',
        createdAt: at,
        classId: r.classId,
        residentId: residentId,
        measurementId: m.id,
        caseId: c.id,
      ));
      _notify(
        c,
        c.isUrgent ? '새 긴급' : '새 이상 대응',
        '${classOf(r.classId).name} ${r.name} ${formatTemp(value)}℃ · 평소보다 ${formatDiff(j.diff)} · ${j.stage.label}',
        at,
        important: c.isUrgent,
        addDirector: c.isUrgent,
      );
      caseItem = c;
      created = true;
    } else if (j.stage == Stage.caution) {
      task = Task(id: _id('t'), label: '재측정', kind: TaskKind.temp, dueAt: at.add(const Duration(minutes: 30)), auto: true);
      _entries.add(Entry(
        id: _id('e'),
        scope: EntryScope.resident,
        authorId: by,
        kindLabel: '체온 기록',
        createdAt: at,
        classId: r.classId,
        residentId: residentId,
        measurementId: m.id,
        task: task,
      ));
    }

    _measurements.add(m);
    notifyListeners();
    return SaveResult(measurement: m, caseItem: caseItem, caseCreated: created, escalated: escalated, task: task);
  }

  /// 잘못 잰 값: 지우지 않고 무효 표시 (C7).
  void voidMeasurement(String id, {required String by, required DateTime at, String reason = '잘못 잰 값'}) {
    final i = _measurements.indexWhere((m) => m.id == id);
    _measurements[i] = _measurements[i].copyWith(voidedAt: at, voidedBy: by, voidReason: reason);
    notifyListeners();
  }

  // ── 이상 건 조작 (이상 대응 S3~S7)
  void acknowledge(String caseId, String by, DateTime at) {
    final c = caseById(caseId);
    if (c.status == CaseStatus.unacked) _replaceCase(c.copyWith(status: CaseStatus.acked));
    _event(caseId, 'acked', by, at);
    _notify(c, '확인했어요', '${withSubject(staff(by).displayName)} 확인했어요', at);
    notifyListeners();
  }

  void assign(String caseId, String by, DateTime at) {
    final c = caseById(caseId);
    _replaceCase(c.copyWith(assigneeId: by, status: CaseStatus.active));
    _event(caseId, 'assigned', by, at);
    _notify(c, '담당이 정해졌어요', '${withSubject(staff(by).displayName)} 맡았어요', at);
    notifyListeners();
  }

  void setStage(String caseId, int stage, String by, DateTime at) {
    _replaceCase(caseById(caseId).copyWith(stage: stage));
    _event(caseId, 'stage', by, at, {'stage': stage});
    notifyListeners();
  }

  void scheduleRemeasure(String caseId, String by, DateTime at, Duration after) {
    _replaceCase(caseById(caseId).copyWith(remeasureAt: at.add(after), status: CaseStatus.waitingRemeasure));
    _event(caseId, 'remeasure_scheduled', by, at, {'minutes': after.inMinutes});
    notifyListeners();
  }

  void addNote(String caseId, String type, String by, DateTime at, String text) {
    _event(caseId, type, by, at, {'text': text});
    notifyListeners();
  }

  void close(String caseId, String by, DateTime at, String reason) {
    final c = caseById(caseId);
    _replaceCase(c.copyWith(status: CaseStatus.closed, closedAt: at, closeReason: reason));
    _event(caseId, 'closed', by, at, {'reason': reason});
    _notify(c, '${c.kindLabel} 종료', '${resident(c.residentId).name} · $reason', at);
    notifyListeners();
  }

  // ── 인수인계 기록
  Entry addEntry(Entry e) {
    _entries.add(e);
    notifyListeners();
    return e;
  }

  void completeTask(String entryId, String by, DateTime at) {
    final e = _entries.firstWhere((x) => x.id == entryId);
    _replaceEntry(e.withTask(e.task!.complete(by: by, at: at)));
    notifyListeners();
  }

  // ── 내부
  void _replaceCase(Case c) => _cases[_cases.indexWhere((x) => x.id == c.id)] = c;
  void _replaceEntry(Entry e) => _entries[_entries.indexWhere((x) => x.id == e.id)] = e;

  void _event(String caseId, String type, String actor, DateTime at, [Map<String, Object?> data = const {}]) =>
      _events.add(CaseEvent(id: _id('ev'), caseId: caseId, type: type, actorId: actor, at: at, data: data));

  /// 받는 사람: 근무 중인 생활관 선생님 + 간호사 + 사무국, 긴급이면 원장 (9장).
  void _notify(Case c, String title, String body, DateTime at, {bool important = false, bool addDirector = false}) {
    final ids = <String>{
      ...seed.amShiftStaff,
      for (final s in seed.staff)
        if (s.role == Role.nurse || s.role == Role.office) s.id,
      if (addDirector || c.isUrgent)
        for (final s in seed.staff)
          if (s.role == Role.director) s.id,
    };
    _notices.add(AppNotice(
        id: _id('n'), caseId: c.id, title: title, body: body, at: at, recipientIds: ids, important: important));
  }

  // ── 시연 시작 상태 (10-3)
  void _applyDemoStart() {
    DateTime t(int h, int m, {int day = 28}) => DateTime(2026, 10, day, h, m);
    String rid(String name) => seed.residentByName(name).id;

    _entries.add(Entry(
        id: _id('e'), scope: EntryScope.facility, authorId: 'park_seoyeon', kindLabel: '전체 공지',
        createdAt: t(17, 50, day: 27), title: '독감 예방접종', body: '11월 3일(월) 오전, 별님 전원 예방접종이 있어요.'));
    _entries.add(Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'oh_jimin', kindLabel: '관찰 기록',
        createdAt: t(15, 20, day: 27), classId: 'aries', residentId: rid('정현우'),
        body: '오후에 기운이 없어 보였어요. 내일 오전에 체온 한 번 더 봐 주세요.',
        task: Task(id: _id('t'), label: '재측정', kind: TaskKind.temp, dueAt: t(10, 0))));
    _entries.add(Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'choi_minho', kindLabel: '관찰 기록',
        createdAt: t(7, 50), classId: 'aquarius', residentId: rid('한나리'),
        body: '아침에 왼쪽 무릎이 조금 긁혀 있었어요. 소독했어요. (사진 1장)'));
    _entries.add(Entry(
        id: _id('e'), scope: EntryScope.classScope, authorId: 'park_jieun', kindLabel: '반 공지',
        createdAt: t(8, 10), classId: 'aquarius', body: '송지은·서소율 통학 차량이 10분 늦어요.'));
    _entries.add(Entry(
        id: _id('e'), scope: EntryScope.facility, authorId: 'park_seoyeon', kindLabel: '전체 공지',
        createdAt: t(8, 30), title: '목욕실 점검', body: '오늘 14시~15시 2층 목욕실 점검이 있어요.'));
    _entries.add(Entry(
        id: _id('e'), scope: EntryScope.classScope, authorId: 'park_jieun', kindLabel: '반 공지',
        createdAt: t(8, 40), classId: 'milkyway', body: '오늘 목욕 순서가 바뀌었어요. 최도윤 별님이 먼저예요.'));
    _entries.add(Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'park_jieun', kindLabel: '관찰 기록',
        createdAt: t(8, 50), classId: 'milkyway', residentId: rid('최도윤'),
        body: '아침을 절반만 먹었어요. 오전 체온 부탁해요.',
        task: Task(id: _id('t'), label: '오전 체온', kind: TaskKind.temp, dueAt: t(11, 0))));

    saveMeasurement(residentId: rid('이서준'), value: 376, by: 'lee_sujin', at: t(9, 15));
    final s = saveMeasurement(residentId: rid('박승민'), value: 382, by: 'park_jieun', at: t(9, 20));
    _event(s.caseItem!.id, 'note', 'lee_sujin', t(9, 24), {'text': '물 마시게 하고 겉옷 벗겼어요.'});
    saveMeasurement(residentId: rid('한지호'), value: 374, by: 'kim_haneul', at: t(9, 39));
    saveMeasurement(residentId: rid('한지호'), value: 368, by: 'kim_haneul', at: t(9, 41));
  }
}
