// 저장소. 서버가 정해지기 전까지는 기기 안 구현만 쓴다 (통합 명세 11-1).
// 상태가 바뀔 때마다 기기 안에 저장하고(storage.dart), 다시 켜면 이어서 보여준다.
// 기록은 지우지 않는다. 무효·취소 표시만 한다.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'baseline.dart';
import 'judgment.dart';
import 'models.dart';
import 'seed.dart' as seed;
import 'storage.dart';

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

  Map<String, Object?> toJson() => {
        'id': id,
        'caseId': caseId,
        'title': title,
        'body': body,
        'at': at.toIso8601String(),
        'recipientIds': recipientIds.toList(),
        'important': important,
      };
  factory AppNotice.fromJson(Map<String, Object?> j) => AppNotice(
        id: j['id'] as String,
        caseId: j['caseId'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        at: DateTime.parse(j['at'] as String),
        recipientIds: {...(j['recipientIds'] as List).cast<String>()},
        important: j['important'] as bool? ?? false,
      );
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
  /// [snapshot]이 있으면 지난번 상태를 이어서, 없으면 시연 시작 상태로 연다.
  InMemoryRepository({bool withDemoState = true, String? snapshot, this.store}) {
    if (snapshot != null && _restore(snapshot)) return;
    _seedFresh(withDemoState);
  }

  /// 기기 안 저장소. 없으면 저장하지 않는다 (테스트).
  final SnapshotStore? store;

  final List<Measurement> _measurements = [];
  final List<Case> _cases = [];
  final List<CaseEvent> _events = [];
  final List<Entry> _entries = [];
  final List<AppNotice> _notices = [];
  final List<Reply> _replies = [];
  final List<ReadReceipt> _receipts = [];
  final Map<String, DateTime> _noticesSeenAt = {};
  int _seq = 0;

  // ── 시연 시계: 10/28 09:41에서 시작해 실제 시간만큼 흐른다. 껐다 켜면 멈춘 시각부터 이어간다.
  DateTime _clockBase = seed.demoStart;
  DateTime _clockStartedAt = DateTime.now();
  DateTime now() => _clockBase.add(DateTime.now().difference(_clockStartedAt));

  /// 시연 중 시간 건너뛰기 (예: 30분 뒤 재측정 보여주기).
  void advanceClock(Duration d) {
    _clockBase = _clockBase.add(d);
    notifyListeners();
  }

  String _id(String p) => '$p-${++_seq}';

  void _seedFresh(bool withDemoState) {
    _measurements
      ..clear()
      ..addAll(seed.seedHistory());
    _cases.clear();
    _events.clear();
    _entries
      ..clear()
      ..addAll(seed.seedPastEntries());
    _notices.clear();
    _replies.clear();
    _receipts.clear();
    _noticesSeenAt.clear();
    _seq = 0;
    _clockBase = seed.demoStart;
    _clockStartedAt = DateTime.now();
    if (withDemoState) _applyDemoStart();
  }

  /// 시연 초기화: 저장된 기록을 지우고 10/28 09:41 시작 상태로 되돌린다.
  Future<void> resetDemo() async {
    await store?.clear();
    _seedFresh(true);
    notifyListeners();
  }

  // ── 저장
  bool _savePending = false;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    if (store == null || _savePending) return;
    _savePending = true;
    Future<void>.delayed(const Duration(milliseconds: 300), () async {
      _savePending = false;
      await store!.save(toSnapshot());
    });
  }

  /// 지금 상태 전체를 JSON으로. 시드 측정(지난 14일)은 다시 만들 수 있으므로 무효 처리된 것만 남긴다.
  String toSnapshot() => jsonEncode({
        'v': 1,
        'clock': now().toIso8601String(),
        'seq': _seq,
        'measurements': [
          for (final m in _measurements)
            if (!m.id.startsWith('seed-') || m.isVoided) m.toJson()
        ],
        'cases': [for (final c in _cases) c.toJson()],
        'events': [for (final e in _events) e.toJson()],
        'entries': [for (final e in _entries) e.toJson()],
        'notices': [for (final n in _notices) n.toJson()],
        'replies': [for (final r in _replies) r.toJson()],
        'receipts': [for (final r in _receipts) r.toJson()],
        'noticesSeenAt': {for (final e in _noticesSeenAt.entries) e.key: e.value.toIso8601String()},
      });

  bool _restore(String json) {
    try {
      final j = jsonDecode(json) as Map<String, Object?>;
      if (j['v'] != 1) return false;
      List<Map<String, Object?>> list(String k) => [for (final x in (j[k] as List? ?? const [])) (x as Map).cast()];
      final saved = [for (final x in list('measurements')) Measurement.fromJson(x)];
      final savedIds = {for (final m in saved) m.id};
      _measurements
        ..clear()
        ..addAll(seed.seedHistory().where((m) => !savedIds.contains(m.id)))
        ..addAll(saved);
      _cases
        ..clear()
        ..addAll([for (final x in list('cases')) Case.fromJson(x)]);
      _events
        ..clear()
        ..addAll([for (final x in list('events')) CaseEvent.fromJson(x)]);
      _entries
        ..clear()
        ..addAll([for (final x in list('entries')) Entry.fromJson(x)]);
      _notices
        ..clear()
        ..addAll([for (final x in list('notices')) AppNotice.fromJson(x)]);
      _replies
        ..clear()
        ..addAll([for (final x in list('replies')) Reply.fromJson(x)]);
      _receipts
        ..clear()
        ..addAll([for (final x in list('receipts')) ReadReceipt.fromJson(x)]);
      _noticesSeenAt
        ..clear()
        ..addAll({
          for (final e in ((j['noticesSeenAt'] as Map?) ?? const {}).entries) e.key as String: DateTime.parse(e.value as String)
        });
      _seq = j['seq'] as int? ?? 0;
      _clockBase = DateTime.parse(j['clock'] as String);
      _clockStartedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('저장된 상태를 읽지 못해 시연 시작 상태로 엽니다: $e');
      return false;
    }
  }

  // ── 사람·반
  List<Class> get classes => seed.classes;
  List<Resident> residentsOf(String classId) =>
      seed.residents.where((r) => r.classId == classId).toList()..sort((a, b) => a.order.compareTo(b.order));
  Resident resident(String id) => seed.residents.firstWhere((r) => r.id == id);
  Class classOf(String id) => seed.classes.firstWhere((c) => c.id == id);
  Staff staff(String id) => seed.staff.firstWhere((s) => s.id == id);
  List<Staff> get allStaff => seed.staff;
  List<ClassHomeroomHistory> homeroomHistoryOf(String classId) =>
      seed.homeroomHistory.where((h) => h.classId == classId).toList()..sort((a, b) => a.from.compareTo(b.from));

  /// 시연 사용자의 담당(배치) 반. 담임이면 그 반.
  String? homeClassOf(String staffId) {
    for (final c in seed.classes) {
      if (c.homeroomId == staffId) return c.id;
    }
    return seed.staffPlacement[staffId];
  }

  // ── 근무조
  List<Shift> get shifts => seed.seedShifts();

  Shift? shiftAt(DateTime at, {String? staffId}) {
    for (final s in shifts.reversed) {
      if (!at.isBefore(s.startAt) && at.isBefore(s.endAt) && (staffId == null || s.staffIds.contains(staffId))) return s;
    }
    return null;
  }

  /// 인수인계 "내 직전 근무 시작 이후" 기준 시각 (인수인계 3.1 방식 C).
  /// 나를 포함한 근무 중 지금 근무 바로 전 것의 시작. 없으면 24시간 전.
  DateTime handoverSince(String staffId, DateTime at) {
    final mine = shifts.where((s) => s.staffIds.contains(staffId) && s.startAt.isBefore(at)).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    final current = shiftAt(at, staffId: staffId);
    final previous = mine.where((s) => s != current && s.id != current?.id).toList();
    if (previous.isNotEmpty) return previous.first.startAt;
    return at.subtract(const Duration(hours: 24));
  }

  // ── 체온
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

  BaselineResult baselineOf(String residentId, DateTime at) =>
      computeBaseline(resident: resident(residentId), history: _measurements, now: at);

  // ── 일정 (일정 명세) · 측정 시점 상태 (통합 명세 7-3)
  List<ScheduleItem> scheduleOf(String residentId, DateTime date) => seed.scheduleFor(resident(residentId), date);

  /// 그날 측정 시점마다 기록됨 / 미기록 / 예정. 인수인계 "체온 미기록"과 일정 카드가 같이 쓴다.
  List<SlotStatus> slotStatuses(String residentId, DateTime date, DateTime at) {
    final items = scheduleOf(residentId, date).where((i) => i.tempSlot != null).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final ms = measurementsOf(residentId).where((m) => !m.isVoided).toList();
    final dayEnd = DateTime(date.year, date.month, date.day).add(const Duration(days: 1));
    final out = <SlotStatus>[];
    for (var i = 0; i < items.length; i++) {
      final from = items[i].startAt;
      final to = i + 1 < items.length ? items[i + 1].startAt : dayEnd;
      // 시점 30분 전부터 다음 시점 전까지 잰 것을 인정한다.
      final inWindow = ms.where((m) => !m.measuredAt.isBefore(from.subtract(const Duration(minutes: 30))) && m.measuredAt.isBefore(to));
      final m = inWindow.isEmpty ? null : inWindow.first; // 최신
      final state = m != null
          ? SlotState.recorded
          : (at.isAfter(items[i].endAt) ? SlotState.missed : SlotState.upcoming);
      out.add(SlotStatus(slot: items[i].tempSlot!, at: from, state: state, measurement: m));
    }
    return out;
  }

  /// 오늘 측정 시점이 지났는데 기록이 없는 별님 (교대 요약 "체온 미기록").
  List<Resident> missedTempResidents(DateTime at, {String? classId}) => [
        for (final r in seed.residents)
          if (classId == null || r.classId == classId)
            if (slotStatuses(r.id, at, at).any((s) => s.state == SlotState.missed)) r
      ];

  // ── 이상 건
  List<Case> get openCases {
    final list = _cases.where((c) => c.isOpen).toList();
    // 긴급이 맨 위, 그다음 최근 순 (6-3).
    list.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<Case> get allCases => List.unmodifiable(_cases);
  List<Case> casesOf(String residentId) =>
      _cases.where((c) => c.residentId == residentId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Case? openCaseOf(String residentId) {
    for (final c in _cases) {
      if (c.residentId == residentId && c.isOpen) return c;
    }
    return null;
  }

  Case caseById(String id) => _cases.firstWhere((c) => c.id == id);
  List<CaseEvent> eventsOf(String caseId) =>
      _events.where((e) => e.caseId == caseId).toList()..sort((a, b) => a.at.compareTo(b.at));
  List<Measurement> measurementsOfCase(String caseId) =>
      _measurements.where((m) => m.caseId == caseId).toList()..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

  MedicationGuideline? guidelineOf(String residentId) {
    for (final g in seed.medicationGuidelines) {
      if (g.residentId == residentId) return g;
    }
    return null;
  }

  // ── 알림
  List<AppNotice> noticesFor(String staffId) =>
      _notices.where((n) => n.recipientIds.contains(staffId)).toList().reversed.toList();

  int unseenNoticeCount(String staffId) {
    final seen = _noticesSeenAt[staffId];
    return noticesFor(staffId).where((n) => seen == null || n.at.isAfter(seen)).length;
  }

  void markNoticesSeen(String staffId, DateTime at) {
    _noticesSeenAt[staffId] = at;
    notifyListeners();
  }

  // ── 인수인계 기록
  List<Entry> get entries => List.unmodifiable(_entries.reversed);
  Entry entry(String id) => _entries.firstWhere((e) => e.id == id);

  /// 별님 아카이브 = 그 별님 기록 + 소속 반 공지 (통합 명세 8장). 최신순.
  List<Entry> archiveEntriesOf(String residentId) {
    final r = resident(residentId);
    return _entries
        .where((e) =>
            (e.scope == EntryScope.resident && e.residentId == residentId) ||
            (e.scope == EntryScope.classScope && e.classId == r.classId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 열린 체온 할 일이 있는 별님인가.
  List<Entry> openTempTasksOf(String residentId) => _entries
      .where((e) => e.residentId == residentId && e.task != null && !e.task!.done && e.task!.kind == TaskKind.temp)
      .toList();

  Entry addEntry(Entry e) {
    final withId = e.id.isEmpty
        ? Entry(
            id: _id('e'),
            scope: e.scope,
            authorId: e.authorId,
            kindLabel: e.kindLabel,
            createdAt: e.createdAt,
            classId: e.classId,
            residentId: e.residentId,
            title: e.title,
            body: e.body,
            photoCount: e.photoCount,
            task: e.task == null
                ? null
                : Task(id: _id('t'), label: e.task!.label, kind: e.task!.kind, dueAt: e.task!.dueAt, duePreset: e.task!.duePreset),
            pinned: e.pinned,
          )
        : e;
    _entries.add(withId);
    _receipts.add(ReadReceipt(entryId: withId.id, staffId: withId.authorId, readAt: withId.createdAt, source: 'feed'));
    notifyListeners();
    return withId;
  }

  /// 본문 수정: 지우지 않고 이전 본문을 이력으로 남긴다 (인수인계 4.7).
  void editEntryBody(String entryId, String body, String by, DateTime at) {
    final e = entry(entryId);
    _replaceEntry(e.copyWith(
      body: body,
      updatedAt: at,
      revisions: [...e.revisions, EntryRevision(body: e.body ?? '', editedBy: by, editedAt: at)],
    ));
    notifyListeners();
  }

  void completeTask(String entryId, String by, DateTime at) {
    final e = entry(entryId);
    _replaceEntry(e.withTask(e.task!.complete(by: by, at: at)));
    _markRead(entryId, by, at, 'complete');
    notifyListeners();
  }

  /// 기존 기록을 할 일로 넘기기 (인수인계 "할 일로 넘기기").
  void attachTask(String entryId, {required String label, required TaskKind kind, String? duePreset, DateTime? dueAt}) {
    final e = entry(entryId);
    _replaceEntry(e.withTask(Task(id: _id('t'), label: label, kind: kind, dueAt: dueAt, duePreset: duePreset)));
    notifyListeners();
  }

  // ── 답글 · 확인
  List<Reply> repliesOf(String entryId) =>
      _replies.where((r) => r.entryId == entryId).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Reply addReply(String entryId, String by, String body, DateTime at) {
    final r = Reply(id: _id('r'), entryId: entryId, authorId: by, body: body, createdAt: at);
    _replies.add(r);
    _markRead(entryId, by, at, 'reply');
    notifyListeners();
    return r;
  }

  List<ReadReceipt> readersOf(String entryId) {
    final seen = <String>{};
    return [
      for (final r in _receipts)
        if (r.entryId == entryId && seen.add(r.staffId)) r
    ];
  }

  bool isRead(String entryId, String staffId) => _receipts.any((r) => r.entryId == entryId && r.staffId == staffId);

  /// [source]: feed · archive · reply · complete · remeasure
  void markRead(String entryId, String staffId, DateTime at, {String source = 'feed'}) {
    if (_markRead(entryId, staffId, at, source)) notifyListeners();
  }

  bool _markRead(String entryId, String staffId, DateTime at, String source) {
    if (isRead(entryId, staffId)) return false;
    _receipts.add(ReadReceipt(entryId: entryId, staffId: staffId, readAt: at, source: source));
    return true;
  }

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
      _markRead(e.id, by, at, 'remeasure');
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
            _notify(c, '긴급으로 바뀌었어요', '${classOf(r.classId).name} ${r.name} ${formatTemp(value)}℃ · 위험', at,
                important: true, addDirector: true);
          }
        }
        c = c.copyWith(clearRecovered: true, status: c.status == CaseStatus.waitingRemeasure ? CaseStatus.active : null);
      } else if (c.recoveredAt == null) {
        c = c.copyWith(recoveredAt: at, status: c.status == CaseStatus.waitingRemeasure ? CaseStatus.active : null);
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
      final e = Entry(
        id: _id('e'),
        scope: EntryScope.resident,
        authorId: by,
        kindLabel: '체온 기록',
        createdAt: at,
        classId: r.classId,
        residentId: residentId,
        measurementId: m.id,
        caseId: c.id,
      );
      _entries.add(e);
      _markRead(e.id, by, at, 'feed');
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
      final e = Entry(
        id: _id('e'),
        scope: EntryScope.resident,
        authorId: by,
        kindLabel: '체온 기록',
        createdAt: at,
        classId: r.classId,
        residentId: residentId,
        measurementId: m.id,
        task: task,
      );
      _entries.add(e);
      _markRead(e.id, by, at, 'feed');
    }

    _measurements.add(m);
    notifyListeners();
    return SaveResult(measurement: m, caseItem: caseItem, caseCreated: created, escalated: escalated, task: task);
  }

  /// 잘못 잰 값: 지우지 않고 무효 표시 (C7).
  void voidMeasurement(String id, {required String by, required DateTime at, String reason = '잘못 잰 값'}) {
    final i = _measurements.indexWhere((m) => m.id == id);
    _measurements[i] = _measurements[i].copyWith(voidedAt: at, voidedBy: by, voidReason: reason);
    final caseId = _measurements[i].caseId;
    if (caseId != null) _event(caseId, 'measurement_voided', by, at, {'measurementId': id});
    notifyListeners();
  }

  // ── 이상 건 조작 (이상 대응 S3~S7)
  void acknowledge(String caseId, String by, DateTime at) {
    final c = caseById(caseId);
    // 같은 사람이 두 번 눌러도 기록은 한 번만
    if (_events.any((e) => e.caseId == caseId && e.type == 'acked' && e.actorId == by && e.voidedBy == null)) return;
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

  /// 대응 단계 ①관찰·재측정 ②원내 조제 ③원장 처방 ④인근 병원.
  void setStage(String caseId, int stage, String by, DateTime at, {String? note}) {
    final c = caseById(caseId);
    _replaceCase(c.copyWith(stage: stage));
    _event(caseId, 'stage', by, at, {'stage': stage, 'note': note});
    // ③ 원장 처방 요청부터는 원장님께도 (이상 대응 S5)
    _notify(c, '대응 단계 $stage', '${resident(c.residentId).name} · ${stageLabel(stage)}', at,
        important: stage >= 3, addDirector: stage >= 3);
    notifyListeners();
  }

  void scheduleRemeasure(String caseId, String by, DateTime at, Duration after) {
    _replaceCase(caseById(caseId).copyWith(remeasureAt: at.add(after), status: CaseStatus.waitingRemeasure));
    _event(caseId, 'remeasure_scheduled', by, at, {'minutes': after.inMinutes});
    notifyListeners();
  }

  /// 메모·투약 기록·원장 지시·병원 결과 등 글 한 줄. [type]: note · medication · director_order · hospital_result
  void addNote(String caseId, String type, String by, DateTime at, String text) {
    _event(caseId, type, by, at, {'text': text});
    notifyListeners();
  }

  /// 기록 취소: 지우지 않고 취소 표시 (이상 대응 원칙).
  void voidEvent(String eventId, String by) {
    final i = _events.indexWhere((e) => e.id == eventId);
    final e = _events[i];
    _events[i] = CaseEvent(id: e.id, caseId: e.caseId, type: e.type, actorId: e.actorId, at: e.at, data: e.data, voidedBy: by);
    notifyListeners();
  }

  void close(String caseId, String by, DateTime at, String reason) {
    final c = caseById(caseId);
    _replaceCase(c.copyWith(status: CaseStatus.closed, closedAt: at, closeReason: reason, clearRemeasure: true));
    _event(caseId, 'closed', by, at, {'reason': reason});
    _notify(c, '${c.kindLabel} 종료', '${resident(c.residentId).name} · $reason', at);
    notifyListeners();
  }

  static String stageLabel(int stage) => switch (stage) {
        1 => '관찰·재측정',
        2 => '원내 조제',
        3 => '원장 처방',
        _ => '인근 병원',
      };

  // ── 내부
  void _replaceCase(Case c) => _cases[_cases.indexWhere((x) => x.id == c.id)] = c;
  void _replaceEntry(Entry e) => _entries[_entries.indexWhere((x) => x.id == e.id)] = e;

  void _event(String caseId, String type, String actor, DateTime at, [Map<String, Object?> data = const {}]) =>
      _events.add(CaseEvent(id: _id('ev'), caseId: caseId, type: type, actorId: actor, at: at, data: data));

  /// 받는 사람: 근무 중인 생활관 선생님 + 간호사 + 사무국, 긴급이면 원장 (9장).
  void _notify(Case c, String title, String body, DateTime at, {bool important = false, bool addDirector = false}) {
    final shift = shiftAt(at);
    final ids = <String>{
      ...(shift?.staffIds ?? seed.amShiftStaff),
      for (final s in seed.staff)
        if (s.role == Role.nurse || s.role == Role.office) s.id,
      if (addDirector || c.isUrgent)
        for (final s in seed.staff)
          if (s.role == Role.director) s.id,
    };
    _notices.add(AppNotice(id: _id('n'), caseId: c.id, title: title, body: body, at: at, recipientIds: ids, important: important));
  }

  // ── 시연 시작 상태 (10-3)
  void _applyDemoStart() {
    DateTime t(int h, int m, {int day = 28}) => DateTime(2026, 10, day, h, m);
    String rid(String name) => seed.residentByName(name).id;
    void add(Entry e) {
      _entries.add(e);
      _receipts.add(ReadReceipt(entryId: e.id, staffId: e.authorId, readAt: e.createdAt, source: 'feed'));
    }

    add(Entry(
        id: _id('e'), scope: EntryScope.facility, authorId: 'park_seoyeon', kindLabel: '전체 공지',
        createdAt: t(17, 50, day: 27), title: '독감 예방접종', body: '11월 3일(월) 오전, 별님 전원 예방접종이 있어요.', pinned: true));
    add(Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'oh_jimin', kindLabel: '관찰 기록',
        createdAt: t(15, 20, day: 27), classId: 'aries', residentId: rid('정현우'),
        body: '오후에 기운이 없어 보였어요. 내일 오전에 체온 한 번 더 봐 주세요.',
        task: Task(id: _id('t'), label: '재측정', kind: TaskKind.temp, dueAt: t(10, 0), duePreset: '다음 근무조')));
    final nari = Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'choi_minho', kindLabel: '관찰 기록',
        createdAt: t(7, 50), classId: 'aquarius', residentId: rid('한나리'),
        body: '아침에 왼쪽 무릎이 조금 긁혀 있었어요. 소독했어요.', photoCount: 1);
    add(nari);
    _replies.add(Reply(id: _id('r'), entryId: nari.id, authorId: 'lee_sujin', body: '확인했어요. 점심 후에 한 번 더 볼게요.', createdAt: t(8, 5)));
    add(Entry(
        id: _id('e'), scope: EntryScope.classScope, authorId: 'park_jieun', kindLabel: '반 공지',
        createdAt: t(8, 10), classId: 'aquarius', body: '송지은·서소율 통학 차량이 10분 늦어요.'));
    add(Entry(
        id: _id('e'), scope: EntryScope.facility, authorId: 'park_seoyeon', kindLabel: '전체 공지',
        createdAt: t(8, 30), title: '목욕실 점검', body: '오늘 14시~15시 2층 목욕실 점검이 있어요.'));
    add(Entry(
        id: _id('e'), scope: EntryScope.classScope, authorId: 'park_jieun', kindLabel: '반 공지',
        createdAt: t(8, 40), classId: 'milkyway', body: '오늘 목욕 순서가 바뀌었어요. 최도윤 별님이 먼저예요.'));
    add(Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'park_jieun', kindLabel: '관찰 기록',
        createdAt: t(8, 50), classId: 'milkyway', residentId: rid('최도윤'),
        body: '아침을 절반만 먹었어요. 오전 체온 부탁해요.',
        task: Task(id: _id('t'), label: '오전 체온', kind: TaskKind.temp, dueAt: t(11, 0), duePreset: '점심 전')));

    // 오늘 아침 다른 별님들의 오전 체온 (평소). 이서준·박승민·한지호·최도윤은 아래에서 따로.
    final skip = {'이서준', '박승민', '한지호', '최도윤'};
    for (final r in seed.residents) {
      if (skip.contains(r.name)) continue;
      final slot = seed.scheduleFor(r, t(0, 0)).firstWhere((i) => i.tempSlot == TempSlot.am);
      if (slot.startAt.isAfter(t(9, 41))) continue;
      // 양자리·고래자리 몇 명은 아직 안 잼 → "체온 미기록" 시연
      if (r.classId == 'aries' && r.order >= 3) continue;
      final base = seed.seedBaselines[r.id]!;
      final at = slot.startAt.add(Duration(minutes: 5 + r.order * 3));
      final cls = seed.classes.firstWhere((c) => c.id == r.classId);
      _measurements.add(Measurement(
        id: _id('m'),
        residentId: r.id,
        classId: r.classId,
        value: base + (r.order % 3) - 1,
        measuredAt: at,
        recordedBy: cls.homeroomId,
        judgment: judge(value: base + (r.order % 3) - 1, baseline: base),
      ));
    }

    saveMeasurement(residentId: rid('이서준'), value: 376, by: 'lee_sujin', at: t(9, 15));
    final s = saveMeasurement(residentId: rid('박승민'), value: 382, by: 'park_jieun', at: t(9, 20));
    _event(s.caseItem!.id, 'note', 'lee_sujin', t(9, 24), {'text': '물 마시게 하고 겉옷 벗겼어요.'});
    saveMeasurement(residentId: rid('한지호'), value: 374, by: 'kim_haneul', at: t(9, 39));
    saveMeasurement(residentId: rid('한지호'), value: 368, by: 'kim_haneul', at: t(9, 41));
  }
}
