// 저장소. 앱 상태 전체를 JSON 한 덩어리로 서버 DB(계정별)에 저장한다 (server_app.dart).
// 명단(직원·반·별님)도 상태 안에 있다: 시연 DB = 가상 명단, 개발 DB = 예시 명단만.
// 기록은 지우지 않는다. 무효·취소 표시만 한다.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'baseline.dart';
import 'dev_seed.dart' as dev;
import 'judgment.dart';
import 'models.dart';
import 'seed.dart' as seed;
import 'storage.dart';

/// 받침에 따라 '이/가'를 붙인다. 예: '박소연 간호사가', '김하늘 선생님이'.
/// 끝의 닫는 괄호는 건너뛰고 본다: '강다혜 촉탁의 (원장)이'.
String withSubject(String word) {
  final base = word.replaceFirst(RegExp(r'[)\s]+$'), '');
  if (base.isEmpty) return '$word이(가)';
  final c = base.codeUnitAt(base.length - 1);
  if (c < 0xAC00 || c > 0xD7A3) return '$word이(가)';
  return (c - 0xAC00) % 28 == 0 ? '$word가' : '$word이';
}

/// 앱 안 알림 (배너 + 🔔 목록).
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
  const SaveResult({required this.measurement, this.caseItem, this.caseCreated = false, this.escalated = false, this.task, this.call});
  final Measurement measurement;
  final Case? caseItem;
  final bool caseCreated;

  /// 이상 대응 → 긴급으로 바뀜.
  final bool escalated;

  /// 주의로 자동 생긴 재측정 할 일.
  final Task? task;

  /// 간호 선생님에게 간 의료 호출 (이상 건이 새로 생기면).
  final MedicalCall? call;
}

/// 자료 묶음. 시연 DB(가상 자료) / 개발 DB(예시만).
enum Dataset { demo, dev }

class InMemoryRepository extends ChangeNotifier {
  /// [snapshot]이 있으면 그 상태로, 없으면 [dataset]의 처음 상태로 연다.
  InMemoryRepository({this.dataset = Dataset.demo, String? snapshot, this.store, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    if (snapshot != null && _restore(snapshot)) return;
    _seedFresh(now());
  }

  /// 시계. 앱은 실제 시각, 테스트는 고정 시각을 넘긴다.
  final DateTime Function() _clock;

  /// 저장소. 없으면 저장하지 않는다 (테스트).
  final SnapshotStore? store;
  Dataset dataset;

  // ── 명단
  final List<Staff> _staff = [];
  final List<Class> _classes = [];
  final List<Resident> _residents = [];
  final Map<String, String> _placement = {};
  final Map<String, Set<String>> _permissions = {};
  final Map<String, List<String>> _shiftTemplate = {};
  final Map<String, String> _users = {};

  /// 반의 이전 담임 (담임 변경 표시용). 반 id → 직원 id.
  final Map<String, String> _previousHomeroom = {};
  final List<MedicationGuideline> _guidelines = [];

  // ── 기록
  final List<Measurement> _measurements = [];
  final List<Case> _cases = [];
  final List<CaseEvent> _events = [];
  final List<Entry> _entries = [];
  final List<AppNotice> _notices = [];
  final List<Reply> _replies = [];
  final List<ReadReceipt> _receipts = [];
  final Map<String, DateTime> _noticesSeenAt = {};

  // ── PC
  final List<CalendarEvent> _calendar = [];
  final List<MedicalCall> _calls = [];
  final List<CareMessage> _messages = [];
  final List<Prescription> _prescriptions = [];
  final List<Approval> _approvals = [];
  final List<HandoverSign> _signs = [];
  final List<ResidentPhoto> _photos = [];

  /// 읽은 시각: '<직원>|<대상>' → 시각. 대상: 'call:<호출>' · 'doc:<의사>'(간호사 채팅방) · 'res:<별님>'(의사 채팅방).
  final Map<String, DateTime> _reads = {};
  int _seq = 0;

  /// 실제 시각. 시연 DB와 개발 DB가 똑같이 움직인다.
  DateTime now() => _clock();

  String _id(String p) => '$p-${++_seq}';

  /// 화면에서 예시 표시를 할지 (개발 DB이고 아직 실제 자료가 없는 곳).
  bool get isDev => dataset == Dataset.dev;

  void _clearAll() {
    for (final l in <List>[
      _staff, _classes, _residents, _guidelines, _measurements, _cases, _events, _entries, _notices, _replies,
      _receipts, _calendar, _calls, _messages, _prescriptions, _approvals, _signs, _photos,
    ]) {
      l.clear();
    }
    _placement.clear();
    _reads.clear();
    _permissions.clear();
    _shiftTemplate.clear();
    _users.clear();
    _previousHomeroom.clear();
    _noticesSeenAt.clear();
    _seq = 0;
  }

  void _seedFresh(DateTime at) {
    _clearAll();
    if (dataset == Dataset.dev) {
      _staff.addAll(dev.exampleStaff);
      _classes.addAll(dev.exampleClasses);
      _residents.addAll(dev.exampleResidents);
      _users.addAll(dev.exampleUsers);
      return;
    }
    _seedDemo(at);
  }

  /// 처음 상태로 다시 채운다. 시연 DB는 오늘 날짜 기준 가상 자료, 개발 DB는 예시만.
  Future<void> resetDataset() async {
    _seedFresh(now());
    notifyListeners();
    await flushSave();
  }

  // ── 저장
  bool _savePending = false;
  Future<void> _lastSave = Future.value();

  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    if (store == null || _savePending) return;
    _savePending = true;
    _lastSave = Future<void>.delayed(const Duration(milliseconds: 300), () async {
      _savePending = false;
      await store!.save(toSnapshot());
    });
  }

  /// 저장을 기다리는 중인가 (다른 화면의 변경을 받아올지 정할 때).
  bool get hasPendingSave => _savePending;

  /// 다른 화면(모바일 ↔ PC)에서 저장한 상태로 바꾼다. 다시 저장하지는 않는다.
  bool loadRemote(String json) {
    final before = toSnapshot();
    if (!_restore(json)) {
      _restore(before);
      return false;
    }
    super.notifyListeners();
    return true;
  }

  /// 기다리던 저장을 끝낸다 (로그아웃 전 등).
  Future<void> flushSave() async {
    await _lastSave;
    if (store != null && !_savePending) await store!.save(toSnapshot());
  }

  Map<String, Object?> toSnapshotMap() => {
        'v': 1,
        'schema': 2,
        'dataset': dataset.name,
        'seq': _seq,
        'savedAt': now().toIso8601String(),
        'roster': {
          'staff': [for (final s in _staff) s.toJson()],
          'classes': [for (final c in _classes) c.toJson()],
          'residents': [for (final r in _residents) r.toJson()],
          'placement': _placement,
          'permissions': {for (final e in _permissions.entries) e.key: e.value.toList()},
          'shiftTemplate': _shiftTemplate,
          'users': _users,
          'previousHomeroom': _previousHomeroom,
        },
        'guidelines': [for (final g in _guidelines) g.toJson()],
        'measurements': [for (final m in _measurements) m.toJson()],
        'cases': [for (final c in _cases) c.toJson()],
        'events': [for (final e in _events) e.toJson()],
        'entries': [for (final e in _entries) e.toJson()],
        'notices': [for (final n in _notices) n.toJson()],
        'replies': [for (final r in _replies) r.toJson()],
        'receipts': [for (final r in _receipts) r.toJson()],
        'noticesSeenAt': {for (final e in _noticesSeenAt.entries) e.key: e.value.toIso8601String()},
        'calendar': [for (final c in _calendar) c.toJson()],
        'calls': [for (final c in _calls) c.toJson()],
        'messages': [for (final m in _messages) m.toJson()],
        'prescriptions': [for (final p in _prescriptions) p.toJson()],
        'approvals': [for (final a in _approvals) a.toJson()],
        'signs': [for (final s in _signs) s.toJson()],
        'photos': [for (final p in _photos) p.toJson()],
        'reads': {for (final e in _reads.entries) e.key: e.value.toIso8601String()},
      };

  String toSnapshot() => jsonEncode(toSnapshotMap());

  bool _restore(String json) {
    try {
      final j = jsonDecode(json) as Map<String, Object?>;
      if (j['v'] != 1 || j['schema'] != 2) return false;
      List<Map<String, Object?>> list(Map<String, Object?> src, String k) =>
          [for (final x in (src[k] as List? ?? const [])) (x as Map).cast()];
      final roster = (j['roster'] as Map).cast<String, Object?>();
      _clearAll();
      dataset = Dataset.values.byName(j['dataset'] as String? ?? 'demo');
      _staff.addAll([for (final x in list(roster, 'staff')) Staff.fromJson(x)]);
      _classes.addAll([for (final x in list(roster, 'classes')) Class.fromJson(x)]);
      _residents.addAll([for (final x in list(roster, 'residents')) Resident.fromJson(x)]);
      _placement.addAll(((roster['placement'] as Map?) ?? const {}).cast<String, String>());
      _permissions.addAll({
        for (final e in ((roster['permissions'] as Map?) ?? const {}).entries)
          e.key as String: {...(e.value as List).cast<String>()}
      });
      _shiftTemplate.addAll({
        for (final e in ((roster['shiftTemplate'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as List).cast<String>()
      });
      _users.addAll(((roster['users'] as Map?) ?? const {}).cast<String, String>());
      _previousHomeroom.addAll(((roster['previousHomeroom'] as Map?) ?? const {}).cast<String, String>());
      _guidelines.addAll([for (final x in list(j, 'guidelines')) MedicationGuideline.fromJson(x)]);
      _measurements.addAll([for (final x in list(j, 'measurements')) Measurement.fromJson(x)]);
      _cases.addAll([for (final x in list(j, 'cases')) Case.fromJson(x)]);
      _events.addAll([for (final x in list(j, 'events')) CaseEvent.fromJson(x)]);
      _entries.addAll([for (final x in list(j, 'entries')) Entry.fromJson(x)]);
      _notices.addAll([for (final x in list(j, 'notices')) AppNotice.fromJson(x)]);
      _replies.addAll([for (final x in list(j, 'replies')) Reply.fromJson(x)]);
      _receipts.addAll([for (final x in list(j, 'receipts')) ReadReceipt.fromJson(x)]);
      _noticesSeenAt.addAll({
        for (final e in ((j['noticesSeenAt'] as Map?) ?? const {}).entries) e.key as String: DateTime.parse(e.value as String)
      });
      _calendar.addAll([for (final x in list(j, 'calendar')) CalendarEvent.fromJson(x)]);
      _calls.addAll([for (final x in list(j, 'calls')) MedicalCall.fromJson(x)]);
      _messages.addAll([for (final x in list(j, 'messages')) CareMessage.fromJson(x)]);
      _prescriptions.addAll([for (final x in list(j, 'prescriptions')) Prescription.fromJson(x)]);
      _approvals.addAll([for (final x in list(j, 'approvals')) Approval.fromJson(x)]);
      _signs.addAll([for (final x in list(j, 'signs')) HandoverSign.fromJson(x)]);
      _photos.addAll([for (final x in list(j, 'photos')) ResidentPhoto.fromJson(x)]);
      _reads.addAll({
        for (final e in ((j['reads'] as Map?) ?? const {}).entries) e.key as String: DateTime.parse(e.value as String)
      });
      _seq = j['seq'] as int? ?? 0;
      return true;
    } catch (e) {
      debugPrint('저장된 상태를 읽지 못해 처음 상태로 엽니다: $e');
      return false;
    }
  }

  // ── 명단. 개발 DB의 예시 명단은 실제 명단이 하나라도 생기면 숨긴다.
  List<T> _visible<T>(List<T> all, bool Function(T) isExample) {
    final real = all.where((x) => !isExample(x)).toList();
    return real.isNotEmpty ? real : all.where(isExample).toList();
  }

  List<Class> get classes => _visible(_classes, (c) => c.example)..sort((a, b) => a.order.compareTo(b.order));
  List<Resident> get residents => _visible(_residents, (r) => r.example);
  List<Staff> get allStaff => _visible(_staff, (s) => s.example);

  /// 실제 명단 없이 예시 명단만 보이는 중인가.
  bool get rosterIsExample => _residents.every((r) => r.example);

  List<Resident> residentsOf(String classId) =>
      residents.where((r) => r.classId == classId).toList()..sort((a, b) => a.order.compareTo(b.order));
  Resident resident(String id) => _residents.firstWhere((r) => r.id == id);
  Class classOf(String id) => _classes.firstWhere((c) => c.id == id);
  Staff staff(String id) =>
      _staff.firstWhere((s) => s.id == id, orElse: () => Staff(id: id, name: id == 'system' ? '자동' : '알 수 없음', role: Role.care));

  /// 화면별 기본 사용자: mobile · pc · doctor.
  String defaultUser(String screen) => _users[screen] ?? (allStaff.isEmpty ? 'system' : allStaff.first.id);

  /// 반 담임 이력 (이전 담임이 있으면 2024.03~2026.03, 지금 담임은 2026.03부터).
  List<ClassHomeroomHistory> homeroomHistoryOf(String classId) {
    final c = classOf(classId);
    final prev = _previousHomeroom[classId];
    return [
      if (prev != null) ClassHomeroomHistory(classId: classId, staffId: prev, from: DateTime(2024, 3, 1), to: DateTime(2026, 3, 1)),
      ClassHomeroomHistory(classId: classId, staffId: c.homeroomId, from: DateTime(2026, 3, 1)),
    ];
  }

  /// 담당(배치) 반. 담임이면 그 반.
  String? homeClassOf(String staffId) {
    for (final c in classes) {
      if (c.homeroomId == staffId) return c.id;
    }
    final p = _placement[staffId];
    return p != null && classes.any((c) => c.id == p) ? p : null;
  }

  /// 체온을 잴 수 있는 반. 간호·사무·원장·의사·야간 당직은 전체, 생활관 선생님은 권한 반 (없으면 담당 반, 그것도 없으면 전체).
  Set<String> measurableClasses(String staffId) {
    final all = {for (final c in classes) c.id};
    final s = _staff.where((x) => x.id == staffId).firstOrNull;
    if (s == null || s.role != Role.care) return all;
    if ((_shiftTemplate['night'] ?? const []).contains(staffId)) return all;
    final p = _permissions[staffId];
    if (p != null) return p.where(all.contains).toSet();
    final mine = {
      for (final c in classes)
        if (c.homeroomId == staffId) c.id,
      if (_placement[staffId] case final placed? when all.contains(placed)) placed,
    };
    return mine.isNotEmpty ? mine : all;
  }

  /// 모바일(체온 측정 · 인수인계 · 별님카드)에 보이는 "내 담당 반". 체온을 잴 수 있는 반과 같다.
  Set<String> myClasses(String staffId) => measurableClasses(staffId);

  /// 이 기록이 내 담당 반 것인지. 반이 없는 기록(시설 전체 공지 등)은 모두에게 보인다.
  bool isMyEntry(Entry e, Set<String> mine) {
    final cls = e.classId ?? (e.residentId == null ? null : _residents.where((r) => r.id == e.residentId).firstOrNull?.classId);
    return cls == null || mine.contains(cls);
  }

  /// 명단 추가 (PC "전체 거주인 명부"). 실제 반·별님이 생기면 예시 명단은 숨겨진다.
  Class addClass({required String name, required String sex, String? room, String? homeroomId}) {
    final c = Class(
      id: _id('class'),
      name: name,
      color: [0xFFA89AC2, 0xFF7FA8C4, 0xFFB59A7A, 0xFF87A98E, 0xFFD39B94, 0xFF7D9BB0][_classes.length % 6],
      homeroomId: homeroomId ?? defaultUser('mobile'),
      order: _classes.where((c) => !c.example).length,
      sex: sex,
      room: room,
    );
    _classes.add(c);
    notifyListeners();
    return c;
  }

  Resident addResident({required String classId, required String name, String? sex, int? age, bool commutes = false}) {
    final r = Resident(
      id: _id('res'),
      classId: classId,
      name: name,
      order: _residents.where((r) => r.classId == classId).length,
      sex: sex,
      age: age,
      commutesToSchool: commutes,
    );
    _residents.add(r);
    notifyListeners();
    return r;
  }

  Staff addStaff({required String name, required Role role, String? title}) {
    final s = Staff(id: _id('staff'), name: name, role: role, title: title);
    _staff.add(s);
    notifyListeners();
    return s;
  }

  // ── 근무조: 매일 같은 틀 (오전 07~15, 오후 14~22, 야간 22~07)
  List<Shift> shiftsAround(DateTime at) {
    final out = <Shift>[];
    for (var d = -1; d <= 1; d++) {
      final day = DateTime(at.year, at.month, at.day + d);
      String key(String t) => 'sh-${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}-$t';
      void add(ShiftType type, String t, int from, int to) {
        final ids = _shiftTemplate[t] ?? const [];
        if (ids.isEmpty) return;
        out.add(Shift(
          id: key(t),
          type: type,
          startAt: day.add(Duration(hours: from)),
          endAt: day.add(Duration(hours: to)),
          staffIds: ids,
        ));
      }

      add(ShiftType.am, 'am', 7, 15);
      add(ShiftType.pm, 'pm', 14, 22);
      add(ShiftType.night, 'night', 22, 31);
    }
    return out;
  }

  List<Shift> get shifts => shiftsAround(now());

  Shift? shiftAt(DateTime at, {String? staffId}) {
    for (final s in shiftsAround(at).reversed) {
      if (!at.isBefore(s.startAt) && at.isBefore(s.endAt) && (staffId == null || s.staffIds.contains(staffId))) return s;
    }
    return null;
  }

  /// 인수인계 "내 직전 근무 시작 이후" 기준 시각. 없으면 24시간 전.
  DateTime handoverSince(String staffId, DateTime at) {
    final mine = shiftsAround(at).where((s) => s.staffIds.contains(staffId) && s.startAt.isBefore(at)).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
    final current = shiftAt(at, staffId: staffId);
    final previous = mine.where((s) => s.id != current?.id).toList();
    if (previous.isNotEmpty) return previous.first.startAt;
    return at.subtract(const Duration(hours: 24));
  }

  // ── 체온
  List<Measurement> measurementsOf(String residentId) =>
      _measurements.where((m) => m.residentId == residentId).toList()..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

  /// 모든 측정 (최신순). PC 타임라인 등.
  List<Measurement> get allMeasurements => _measurements.toList()..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

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

  // ── 별님 하루 일정 · 측정 시점 상태
  List<ScheduleItem> scheduleOf(String residentId, DateTime date) {
    final r = resident(residentId);
    final cls = classOf(r.classId);
    return seed.scheduleFor(r, cls, staff(cls.homeroomId).displayName, date);
  }

  /// 지금 하고 있는 일과 (PC 현황판 "현재 위치 및 일과").
  ScheduleItem? currentActivity(String residentId, DateTime at) {
    for (final i in scheduleOf(residentId, at)) {
      if (!at.isBefore(i.startAt) && at.isBefore(i.endAt)) return i;
    }
    return null;
  }

  /// 그날 측정 시점마다 기록됨 / 미기록 / 예정.
  List<SlotStatus> slotStatuses(String residentId, DateTime date, DateTime at) {
    final items = scheduleOf(residentId, date).where((i) => i.tempSlot != null).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final ms = measurementsOf(residentId).where((m) => !m.isVoided).toList();
    final dayEnd = DateTime(date.year, date.month, date.day).add(const Duration(days: 1));
    final out = <SlotStatus>[];
    for (var i = 0; i < items.length; i++) {
      final from = items[i].startAt;
      final to = i + 1 < items.length ? items[i + 1].startAt : dayEnd;
      final inWindow = ms.where((m) => !m.measuredAt.isBefore(from.subtract(const Duration(minutes: 30))) && m.measuredAt.isBefore(to));
      final m = inWindow.isEmpty ? null : inWindow.first;
      final state = m != null ? SlotState.recorded : (at.isAfter(items[i].endAt) ? SlotState.missed : SlotState.upcoming);
      out.add(SlotStatus(slot: items[i].tempSlot!, at: from, state: state, measurement: m));
    }
    return out;
  }

  /// 오늘 측정 시점이 지났는데 기록이 없는 별님 (교대 요약 "체온 미기록").
  List<Resident> missedTempResidents(DateTime at, {String? classId}) => [
        for (final r in residents)
          if (classId == null || r.classId == classId)
            if (slotStatuses(r.id, at, at).any((s) => s.state == SlotState.missed)) r
      ];

  // ── 이상 건
  List<Case> get openCases {
    final list = _cases.where((c) => c.isOpen).toList();
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
    for (final g in _guidelines) {
      if (g.residentId == residentId) return g;
    }
    return null;
  }

  // ── 알림
  List<AppNotice> noticesFor(String staffId) =>
      _notices.where((n) => n.recipientIds.contains(staffId)).toList().reversed.toList();

  /// 모든 알림 (최신순). PC 타임라인.
  List<AppNotice> get allNotices => _notices.reversed.toList();

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

  /// 별님 기록 = 그 별님 기록 + 소속 반 공지. 최신순.
  List<Entry> archiveEntriesOf(String residentId) {
    final r = resident(residentId);
    return _entries
        .where((e) =>
            (e.scope == EntryScope.resident && e.residentId == residentId) ||
            (e.scope == EntryScope.classScope && e.classId == r.classId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

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

  void attachTask(String entryId, {required String label, required TaskKind kind, String? duePreset, DateTime? dueAt}) {
    final e = entry(entryId);
    _replaceEntry(e.withTask(Task(id: _id('t'), label: label, kind: kind, dueAt: dueAt, duePreset: duePreset)));
    notifyListeners();
  }

  // ── 답글 · 확인 · 좋아요
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
        if (r.entryId == entryId && r.source != 'like' && seen.add(r.staffId)) r
    ];
  }

  bool isRead(String entryId, String staffId) =>
      _receipts.any((r) => r.entryId == entryId && r.staffId == staffId && r.source != 'like');

  void markRead(String entryId, String staffId, DateTime at, {String source = 'feed'}) {
    if (_markRead(entryId, staffId, at, source)) notifyListeners();
  }

  bool _markRead(String entryId, String staffId, DateTime at, String source) {
    if (isRead(entryId, staffId)) return false;
    _receipts.add(ReadReceipt(entryId: entryId, staffId: staffId, readAt: at, source: source));
    return true;
  }

  /// 좋아요 누른 사람 (관찰 기록 👍).
  List<String> likesOf(String entryId) =>
      {for (final r in _receipts) if (r.entryId == entryId && r.source == 'like') r.staffId}.toList();

  /// 좋아요 누르기. 기록은 지우지 않으므로 한 번 누르면 그대로 남는다.
  void like(String entryId, String staffId, DateTime at) {
    if (likesOf(entryId).contains(staffId)) return;
    _receipts.add(ReadReceipt(entryId: entryId, staffId: staffId, readAt: at, source: 'like'));
    _markRead(entryId, staffId, at, 'feed');
    notifyListeners();
  }

  // ── 체온 저장. 체온 입력은 이 함수 하나뿐이다.
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

    // 열린 체온 할 일 자동 완료
    for (final e in openTempTasksOf(residentId)) {
      _replaceEntry(e.withTask(e.task!.complete(by: by, at: at, measurementId: m.id)));
      _markRead(e.id, by, at, 'remeasure');
    }

    Case? caseItem;
    var created = false;
    var escalated = false;
    Task? task;
    MedicalCall? call;
    final open = openCaseOf(residentId);

    if (open != null) {
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
            final existing = _calls.where((x) => x.caseId == c.id && x.isOpen).firstOrNull;
            if (existing != null) _replaceCall(existing.copyWith(level: CallLevel.urgent));
          }
        }
        c = c.copyWith(clearRecovered: true, status: c.status == CaseStatus.waitingRemeasure ? CaseStatus.active : null);
      } else if (c.recoveredAt == null) {
        c = c.copyWith(recoveredAt: at, status: c.status == CaseStatus.waitingRemeasure ? CaseStatus.active : null);
        _event(c.id, 'recovered', 'system', at, {'value': value});
      }
      _replaceCase(c);
      caseItem = c;
      // 열린 호출이 있으면 재측정 값을 대화에 자동 첨부
      final openCall = _calls.where((x) => x.caseId == c.id && x.isOpen).firstOrNull;
      if (openCall != null) _vitalMessage(openCall.id, m, by, at);
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
      // 간호 선생님에게 의료 호출 (PC 의료 호출함)
      call = _openCall(
        residentId: residentId,
        level: c.isUrgent ? CallLevel.urgent : CallLevel.observe,
        by: by,
        at: at,
        summary: c.isUrgent ? '고열 감지 · 간호 선생님 확인 요청' : '체온 이상 · 관찰 요청',
        caseId: c.id,
        measurement: m,
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
    return SaveResult(measurement: m, caseItem: caseItem, caseCreated: created, escalated: escalated, task: task, call: call);
  }

  /// 잘못 잰 값: 지우지 않고 무효 표시.
  void voidMeasurement(String id, {required String by, required DateTime at, String reason = '잘못 잰 값'}) {
    final i = _measurements.indexWhere((m) => m.id == id);
    _measurements[i] = _measurements[i].copyWith(voidedAt: at, voidedBy: by, voidReason: reason);
    final caseId = _measurements[i].caseId;
    if (caseId != null) _event(caseId, 'measurement_voided', by, at, {'measurementId': id});
    notifyListeners();
  }

  // ── 이상 건 조작
  void acknowledge(String caseId, String by, DateTime at) {
    final c = caseById(caseId);
    if (_events.any((e) => e.caseId == caseId && e.type == 'acked' && e.actorId == by && e.voidedBy == null)) return;
    if (c.status == CaseStatus.unacked) _replaceCase(c.copyWith(status: CaseStatus.acked));
    _event(caseId, 'acked', by, at);
    _notify(c, '확인했어요', '${withSubject(staff(by).displayName)} 확인했어요', at);
    notifyListeners();
  }

  bool isAcknowledged(String caseId, String staffId) =>
      _events.any((e) => e.caseId == caseId && e.type == 'acked' && e.actorId == staffId && e.voidedBy == null);

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
    _notify(c, '대응 단계 $stage', '${resident(c.residentId).name} · ${stageLabel(stage)}', at,
        important: stage >= 3, addDirector: stage >= 3);
    notifyListeners();
  }

  void scheduleRemeasure(String caseId, String by, DateTime at, Duration after) {
    _replaceCase(caseById(caseId).copyWith(remeasureAt: at.add(after), status: CaseStatus.waitingRemeasure));
    _event(caseId, 'remeasure_scheduled', by, at, {'minutes': after.inMinutes});
    notifyListeners();
  }

  /// [type]: note · medication · director_order · hospital_result
  void addNote(String caseId, String type, String by, DateTime at, String text) {
    _event(caseId, type, by, at, {'text': text});
    notifyListeners();
  }

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

  // ── PC 02 통합 일정
  List<CalendarEvent> get calendarEvents => _calendar.toList()
    ..sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : (a.time ?? '').compareTo(b.time ?? '');
    });

  List<CalendarEvent> calendarOn(DateTime day) => calendarEvents
      .where((e) => e.date.year == day.year && e.date.month == day.month && e.date.day == day.day)
      .toList();

  CalendarEvent addCalendarEvent({
    required DateTime date,
    required String title,
    required CalendarCategory category,
    required String by,
    String? time,
    String? classId,
    String? owner,
    String? detail,
  }) {
    final e = CalendarEvent(
      id: _id('cal'),
      date: DateTime(date.year, date.month, date.day),
      time: time,
      title: title,
      category: category,
      classId: classId,
      owner: owner,
      detail: detail,
      createdBy: by,
      createdAt: now(),
    );
    _calendar.add(e);
    notifyListeners();
    return e;
  }

  // ── PC 03·04 의료 호출 · 케어팀 대화 · 처방
  /// 최신순 (마지막 대화 · 호출 시각 기준).
  List<MedicalCall> get calls => _calls.toList()..sort((a, b) => lastActivity(b).compareTo(lastActivity(a)));

  /// 호출의 마지막 움직임 (대화가 있으면 마지막 대화 시각).
  DateTime lastActivity(MedicalCall c) {
    var t = c.createdAt;
    for (final m in _messages) {
      if (m.callId == c.id && m.at.isAfter(t)) t = m.at;
    }
    return t;
  }
  List<MedicalCall> get openCalls => calls.where((c) => c.isOpen).toList();
  MedicalCall callById(String id) => _calls.firstWhere((c) => c.id == id);
  List<CareMessage> messagesOf(String callId) =>
      _messages.where((m) => m.callId == callId).toList()..sort((a, b) => a.at.compareTo(b.at));

  /// 오늘 끝낸 호출 수 (PC "금일 누적 현황").
  int doneCallsOn(DateTime day) => _calls
      .where((c) => c.doneAt != null && c.doneAt!.year == day.year && c.doneAt!.month == day.month && c.doneAt!.day == day.day)
      .length;

  MedicalCall _openCall({
    required String residentId,
    required CallLevel level,
    required String by,
    required DateTime at,
    required String summary,
    String? caseId,
    Measurement? measurement,
  }) {
    final c = MedicalCall(
      id: _id('call'),
      residentId: residentId,
      level: level,
      status: CallStatus.open,
      createdAt: at,
      createdBy: by,
      summary: summary,
      temp: measurement?.value,
      diff: measurement?.judgment.diff,
      caseId: caseId,
    );
    _calls.add(c);
    if (measurement != null) _vitalMessage(c.id, measurement, by, at);
    return c;
  }

  void _vitalMessage(String callId, Measurement m, String by, DateTime at) {
    _messages.add(CareMessage(
      id: _id('msg'),
      callId: callId,
      authorId: 'system',
      body: '${formatTemp(m.value)}°C',
      at: at,
      kind: 'vital',
      data: {'value': m.value, 'baseline': m.judgment.baseline, 'diff': m.judgment.diff, 'stage': m.judgment.stage.name, 'by': by},
    ));
  }

  /// 앱·PC에서 의료 호출을 새로 보낸다 (예: "간호 선생님 바로 통화", 일반 의뢰).
  MedicalCall requestCall({required String residentId, required CallLevel level, required String by, required String summary}) {
    final at = now();
    final c = _openCall(
      residentId: residentId,
      level: level,
      by: by,
      at: at,
      summary: summary,
      caseId: openCaseOf(residentId)?.id,
      measurement: latestOf(residentId),
    );
    notifyListeners();
    return c;
  }

  CareMessage sendMessage(String callId, String by, String body, {String kind = 'text', Map<String, Object?> data = const {}}) {
    final m = CareMessage(id: _id('msg'), callId: callId, authorId: by, body: body, at: now(), kind: kind, data: data);
    _messages.add(m);
    notifyListeners();
    return m;
  }

  /// 비대면 화상 진료 예약 (알림 연동 전용, 실제 화상 연결 없음).
  void scheduleVideo(String callId, DateTime at, String by) {
    _replaceCall(callById(callId).copyWith(videoAt: at));
    _messages.add(CareMessage(
      id: _id('msg'),
      callId: callId,
      authorId: 'system',
      body: '${withSubject(staff(by).displayName)} 비대면 화상 진료를 ${_hhmm(at)}로 예약했어요',
      at: now(),
      kind: 'system',
    ));
    notifyListeners();
  }

  void completeCall(String callId, String by) {
    final at = now();
    _replaceCall(callById(callId).copyWith(status: CallStatus.done, doneAt: at));
    _messages.add(CareMessage(
      id: _id('msg'),
      callId: callId,
      authorId: 'system',
      body: '${withSubject(staff(by).displayName)} 호출을 완료했어요',
      at: at,
      kind: 'system',
    ));
    notifyListeners();
  }

  // ── 간호사 호출 → 의료진 협진 (앱 → 의료 호출함(간호사) → 의료진 협진 포털)

  /// 의료진 쪽에서 보이는 우리 기관 이름.
  static const facilityName = '혜진원';

  /// 앱 "간호쌤 호출": 의료 호출함(간호사)에 호출이 가고, 별님카드에 호출 기록이 남는다.
  MedicalCall callNurse({required String residentId, required String by, required String reason}) {
    final at = now();
    final r = resident(residentId);
    final open = openCaseOf(residentId);
    final c = _openCall(
      residentId: residentId,
      level: open == null ? CallLevel.general : (open.isUrgent ? CallLevel.urgent : CallLevel.observe),
      by: by,
      at: at,
      summary: reason,
      caseId: open?.id,
      measurement: latestOf(residentId),
    );
    addEntry(Entry(
      id: '',
      scope: EntryScope.resident,
      authorId: by,
      kindLabel: '간호사 호출',
      createdAt: at,
      classId: r.classId,
      residentId: residentId,
      body: '간호 선생님을 호출했어요. $reason',
    ));
    return c;
  }

  /// 의료진(의사 · 병원) 목록. 개발 DB의 예시 의사는 실제 의사가 생기면 숨긴다.
  List<Staff> get doctors => allStaff.where((s) => s.role == Role.doctor).toList();

  /// 간호사가 호출을 의료진 채팅으로 보낸다 → 의료진 협진 포털 호출함에 알림.
  void forwardCall(String callId, String doctorId, String by) {
    final at = now();
    final c = callById(callId);
    _replaceCall(c.copyWith(doctorId: doctorId, forwardedAt: at, forwardedBy: by));
    _messages.add(CareMessage(
      id: _id('msg'),
      callId: callId,
      authorId: 'system',
      body: '${withSubject(staff(by).displayName)} ${staff(doctorId).displayName}에게 ${resident(c.residentId).name} 별님 호출을 보냈어요',
      at: at,
      kind: 'system',
    ));
    _reads['$by|call:$callId'] = at;
    _reads['$by|doc:$doctorId'] = at;
    notifyListeners();
  }

  DateTime? lastRead(String staffId, String key) => _reads['$staffId|$key'];

  /// 봤음 표시 (호출 · 채팅방). 이미 그 뒤에 봤으면 그대로.
  void markSeen(String staffId, String key) {
    final at = now();
    final old = _reads['$staffId|$key'];
    if (old != null && !old.isBefore(at)) return;
    _reads['$staffId|$key'] = at;
    notifyListeners();
  }

  /// 간호사 호출함: 내가 아직 열어 보지 않은 열린 호출.
  bool isNewCall(MedicalCall c, String staffId) =>
      c.isOpen && c.createdBy != staffId && c.forwardedBy != staffId && lastRead(staffId, 'call:${c.id}') == null;
  int newCallCount(String staffId) => _calls.where((c) => isNewCall(c, staffId)).length;

  /// 간호사 채팅방 하나 = 의사 한 명. 그 의사에게 보낸 호출들의 대화.
  List<MedicalCall> callsWithDoctor(String doctorId) => calls.where((c) => c.doctorId == doctorId).toList();
  List<CareMessage> doctorRoomMessages(String doctorId) {
    final ids = {for (final c in _calls) if (c.doctorId == doctorId) c.id};
    return _messages.where((m) => ids.contains(m.callId)).toList()..sort((a, b) => a.at.compareTo(b.at));
  }

  /// 의사 채팅방 하나 = 별님 한 명 (나에게 온 그 별님 호출들의 대화).
  List<MedicalCall> callsForDoctor(String doctorId) => calls.where((c) => c.doctorId == doctorId).toList();
  List<String> patientsOf(String doctorId) {
    final out = <String>[];
    for (final c in callsForDoctor(doctorId)) {
      if (!out.contains(c.residentId)) out.add(c.residentId);
    }
    return out;
  }

  List<CareMessage> patientRoomMessages(String doctorId, String residentId) {
    final ids = {for (final c in _calls) if (c.doctorId == doctorId && c.residentId == residentId) c.id};
    return _messages.where((m) => ids.contains(m.callId)).toList()..sort((a, b) => a.at.compareTo(b.at));
  }

  /// 안 읽은 수: 채팅방을 마지막으로 연 뒤 다른 사람이 쓴 글 (+ 의사는 새로 받은 호출).
  int roomUnread(String staffId, String key) {
    final read = lastRead(staffId, key);
    bool after(DateTime t) => read == null || t.isAfter(read);
    if (key.startsWith('doc:')) {
      return doctorRoomMessages(key.substring(4)).where((m) => m.kind != 'system' && m.authorId != staffId && after(m.at)).length;
    }
    final rid = key.substring(4);
    final msgs = patientRoomMessages(staffId, rid).where((m) => m.kind != 'system' && m.authorId != staffId && after(m.at)).length;
    final calls = _calls.where((c) => c.doctorId == staffId && c.residentId == rid && c.forwardedAt != null && after(c.forwardedAt!)).length;
    return msgs + calls;
  }

  /// 의사 포털 알림 수 (별님 채팅방 안 읽은 합).
  int doctorUnread(String doctorId) => patientsOf(doctorId).fold(0, (n, rid) => n + roomUnread(doctorId, 'res:$rid'));

  /// 의료 호출함(간호사) 알림 수: 새 호출 + 의료진 채팅방 안 읽은 글.
  int nurseUnread(String staffId) =>
      newCallCount(staffId) + doctors.fold(0, (n, d) => n + roomUnread(staffId, 'doc:${d.id}'));

  /// 비대면 진단·처방 기록 전체 (최근 것 먼저).
  List<Prescription> get prescriptions =>
      _prescriptions.toList()..sort((a, b) => (b.issuedAt ?? b.updatedAt).compareTo(a.issuedAt ?? a.updatedAt));

  Prescription? prescriptionOf(String callId) {
    final list = _prescriptions.where((p) => p.callId == callId).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.firstOrNull;
  }

  List<Prescription> prescriptionsOf(String residentId) =>
      _prescriptions.where((p) => p.residentId == residentId).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// 진단서 · 처방전 임시 저장 (의사가 쓴 글 그대로).
  Prescription saveDraft({
    required String callId,
    required String doctorId,
    required String code,
    required String codeName,
    required String opinion,
    required List<RxItem> items,
  }) {
    final call = callById(callId);
    final old = prescriptionOf(callId);
    if (old != null && old.issued) return old;
    final p = Prescription(
      id: old?.id ?? _id('rx'),
      callId: callId,
      residentId: call.residentId,
      doctorId: doctorId,
      code: code,
      codeName: codeName,
      opinion: opinion,
      items: items,
      status: 'draft',
      updatedAt: now(),
    );
    if (old != null) {
      _prescriptions[_prescriptions.indexWhere((x) => x.id == old.id)] = p;
    } else {
      _prescriptions.add(p);
    }
    notifyListeners();
    return p;
  }

  /// 전자서명 · 발행. 발행하면 고칠 수 없다.
  Prescription issuePrescription(String callId, String doctorId) {
    final p = prescriptionOf(callId)!;
    final at = now();
    final issued = Prescription(
      id: p.id,
      callId: p.callId,
      residentId: p.residentId,
      doctorId: doctorId,
      code: p.code,
      codeName: p.codeName,
      opinion: p.opinion,
      items: p.items,
      status: 'issued',
      updatedAt: at,
      issuedAt: at,
      number: 'Rx#${88000 + _seq}',
    );
    _prescriptions[_prescriptions.indexWhere((x) => x.id == p.id)] = issued;
    _messages.add(CareMessage(
      id: _id('msg'),
      callId: callId,
      authorId: 'system',
      body: '${withSubject(staff(doctorId).displayName)} 전자처방전을 발행했어요 (${issued.number})',
      at: at,
      kind: 'system',
    ));
    final call = callById(callId);
    if (call.caseId != null && _cases.any((c) => c.id == call.caseId)) {
      _event(call.caseId!, 'director_order', doctorId, at, {'text': '${p.code} ${p.codeName} · 처방전 ${issued.number}'});
    }
    notifyListeners();
    return issued;
  }

  // ── PC 01 결재 · 인계 서명
  List<Approval> get approvals => _approvals.toList()..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
  List<Approval> get pendingApprovals => approvals.where((a) => !a.approved).toList();

  void approve(String id, String by) {
    final i = _approvals.indexWhere((a) => a.id == id);
    final a = _approvals[i];
    if (a.approved) return;
    _approvals[i] = Approval(id: a.id, title: a.title, requestedBy: a.requestedBy, requestedAt: a.requestedAt, approvedBy: by, approvedAt: now());
    notifyListeners();
  }

  void approveAll(String by) {
    for (final a in pendingApprovals) {
      final i = _approvals.indexWhere((x) => x.id == a.id);
      _approvals[i] = Approval(id: a.id, title: a.title, requestedBy: a.requestedBy, requestedAt: a.requestedAt, approvedBy: by, approvedAt: now());
    }
    notifyListeners();
  }

  Approval addApproval(String title, String by) {
    final a = Approval(id: _id('ap'), title: title, requestedBy: by, requestedAt: now());
    _approvals.add(a);
    notifyListeners();
    return a;
  }

  List<HandoverSign> signsOf(String shiftId) => _signs.where((s) => s.shiftId == shiftId).toList();
  bool hasSigned(String shiftId, String staffId) => _signs.any((s) => s.shiftId == shiftId && s.staffId == staffId);

  void signHandover(String shiftId, String staffId) {
    if (hasSigned(shiftId, staffId)) return;
    _signs.add(HandoverSign(shiftId: shiftId, staffId: staffId, signedAt: now()));
    notifyListeners();
  }

  // ── 별님 프로필 사진 (카카오톡 프로필 기록처럼 최신순)
  List<ResidentPhoto> photosOf(String residentId) =>
      _photos.where((p) => p.residentId == residentId).toList()..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

  ResidentPhoto? profilePhotoOf(String residentId) => photosOf(residentId).firstOrNull;

  /// 프로필 사진은 그 별님 반의 담당 선생님(담임 또는 그 반에 배치된 선생님)만 올린다.
  bool canUploadPhoto(String staffId, String residentId) {
    final r = _residents.where((x) => x.id == residentId).firstOrNull;
    return r != null && homeClassOf(staffId) == r.classId;
  }

  ResidentPhoto addPhoto(String residentId, String url, {required String by}) {
    if (!canUploadPhoto(by, residentId)) throw StateError('담당 선생님만 프로필 사진을 올릴 수 있어요.');
    final p = ResidentPhoto(id: _id('ph'), residentId: residentId, url: url, uploadedBy: by, uploadedAt: now());
    _photos.add(p);
    notifyListeners();
    return p;
  }

  // ── 내부
  void _replaceCase(Case c) => _cases[_cases.indexWhere((x) => x.id == c.id)] = c;
  void _replaceEntry(Entry e) => _entries[_entries.indexWhere((x) => x.id == e.id)] = e;
  void _replaceCall(MedicalCall c) => _calls[_calls.indexWhere((x) => x.id == c.id)] = c;
  static String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _event(String caseId, String type, String actor, DateTime at, [Map<String, Object?> data = const {}]) =>
      _events.add(CaseEvent(id: _id('ev'), caseId: caseId, type: type, actorId: actor, at: at, data: data));

  /// 받는 사람: 근무 중인 생활관 선생님 + 간호 + 사무국, 긴급이면 원장.
  void _notify(Case c, String title, String body, DateTime at, {bool important = false, bool addDirector = false}) {
    final shift = shiftAt(at);
    final ids = <String>{
      ...(shift?.staffIds ?? _shiftTemplate['am'] ?? const []),
      for (final s in _staff)
        if (s.role == Role.nurse || s.role == Role.office) s.id,
      if (addDirector || c.isUrgent)
        for (final s in _staff)
          if (s.role == Role.director) s.id,
      for (final u in _users.values) u,
    };
    _notices.add(AppNotice(id: _id('n'), caseId: c.id, title: title, body: body, at: at, recipientIds: ids, important: important));
  }

  // ── 시연 DB 처음 상태: Claude Design 화면 내용
  void _seedDemo(DateTime at) {
    // 오전 자료가 다 지난 시각을 기준 날짜로 쓴다 (11시 전이면 어제).
    final anchor = at.hour >= 11 ? DateTime(at.year, at.month, at.day) : DateTime(at.year, at.month, at.day - 1);
    DateTime t(int h, int m, {int dayOffset = 0}) => DateTime(anchor.year, anchor.month, anchor.day + dayOffset, h, m);
    String rid(String name) => seed.residentByName(name).id;

    _staff.addAll(seed.staff);
    _classes.addAll(seed.classes);
    _residents.addAll(seed.residents);
    _placement.addAll(seed.demoPlacement);
    _permissions.addAll({
      'kim_haneul': {'milkyway'},
      'choi_minho': {'whale'},
      'park_jieun': {'aquarius', 'milkyway'},
      'lee_sujin': {'milkyway'},
    });
    _shiftTemplate.addAll(seed.demoShiftTemplate);
    _users.addAll(seed.demoUsers);
    _previousHomeroom.addAll(seed.demoPreviousHomeroom);
    _guidelines.addAll(seed.medicationGuidelines(anchor));
    _measurements.addAll(seed.seedHistory(anchor));
    _entries.addAll(seed.seedPastEntries(anchor));
    _calendar.addAll(seed.seedCalendar(anchor));

    void add(Entry e) {
      _entries.add(e);
      _receipts.add(ReadReceipt(entryId: e.id, staffId: e.authorId, readAt: e.createdAt, source: 'feed'));
    }

    add(Entry(
        id: _id('e'), scope: EntryScope.facility, authorId: 'park_seoyeon', kindLabel: '전체 공지',
        createdAt: t(17, 50, dayOffset: -1), title: '독감 예방접종', body: '다음 주 월요일 오전, 별님 전원 예방접종이 있어요.', pinned: true));
    add(Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'oh_jimin', kindLabel: '관찰 기록',
        createdAt: t(15, 20, dayOffset: -1), classId: 'aries', residentId: rid('정현우'),
        body: '오후에 기운이 없어 보였어요. 재측정 필요 (37.5°C 주의)',
        task: Task(id: _id('t'), label: '재측정', kind: TaskKind.temp, dueAt: t(10, 0), duePreset: '다음 근무조')));
    final nari = Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'choi_minho', kindLabel: '관찰 기록',
        createdAt: t(7, 50), classId: 'aquarius', residentId: rid('한나리'),
        body: '아침 식사 반찬 남김없이 잘 드시고 기분 좋게 노래 흥얼거리심. 컨디션 매우 양호합니다.');
    add(nari);
    _receipts.add(ReadReceipt(entryId: nari.id, staffId: 'park_jieun', readAt: t(8, 2), source: 'like'));
    _receipts.add(ReadReceipt(entryId: nari.id, staffId: 'lee_sujin', readAt: t(8, 5), source: 'like'));
    add(Entry(
        id: _id('e'), scope: EntryScope.facility, authorId: 'park_seoyeon', kindLabel: '전체 공지',
        createdAt: t(8, 0), title: '오늘 10:00 목욕실 온수 보일러 점검 안내',
        body: '10:00~11:30 온수 사용 불가. 오전 목욕은 일정을 앞당겨 진행해주세요.'));
    add(Entry(
        id: _id('e'), scope: EntryScope.classScope, authorId: 'park_jieun', kindLabel: '반 공지',
        createdAt: t(8, 10), classId: 'aquarius', body: '송지은·서소율 통학 차량이 10분 늦어요.'));
    add(Entry(
        id: _id('e'), scope: EntryScope.classScope, authorId: 'park_jieun', kindLabel: '반 공지',
        createdAt: t(8, 40), classId: 'milkyway',
        body: '보일러 점검으로 인해 목욕 순서가 은하수자리 1순위로 변경되었습니다. (09:30 순차 진행)'));
    add(Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'lee_sujin', kindLabel: '감각 메모',
        createdAt: t(8, 50), classId: 'milkyway', residentId: rid('이서준'),
        body: '아침 식사 때 숟가락 소리에 귀를 막았어요. 조용한 자리로 옮기니 다 먹었어요.'));

    // 오늘 아침 다른 별님들의 오전 체온 (평소).
    const skip = {'이서준', '박승민', '한지호', '최도윤', '임유나'};
    for (final r in seed.residents) {
      if (skip.contains(r.name)) continue;
      // 양자리 몇 명은 아직 안 잼 → "체온 미기록"
      if (r.classId == 'aries' && r.order >= 4) continue;
      if (r.commutesToSchool) continue;
      final base = seed.seedBaselines[r.id]!;
      final mAt = t(9, 0).add(Duration(minutes: 5 + r.order * 3));
      final cls = seed.classes.firstWhere((c) => c.id == r.classId);
      _measurements.add(Measurement(
        id: _id('m'),
        residentId: r.id,
        classId: r.classId,
        value: base + (r.order % 3) - 1,
        measuredAt: mAt,
        recordedBy: cls.homeroomId,
        judgment: judge(value: base + (r.order % 3) - 1, baseline: base),
      ));
    }
    // 통학 별님은 등교 전에 잼
    for (final r in seed.residents.where((r) => r.commutesToSchool)) {
      final base = seed.seedBaselines[r.id]!;
      _measurements.add(Measurement(
        id: _id('m'), residentId: r.id, classId: r.classId, value: base, measuredAt: t(8, 15 + r.order),
        recordedBy: 'kim_haneul', judgment: judge(value: base, baseline: base)));
    }
    // 시연 자료를 만드는 지금까지 지난 오후 측정 시점(목욕 전·귀가 후)도 평소 값으로 채운다.
    // 이서준·박승민은 이상 건 진행 중(재측정 대기)이라 비워 둔다.
    for (final r in seed.residents) {
      if (r.name == '이서준' || r.name == '박승민') continue;
      final cls = seed.classes.firstWhere((c) => c.id == r.classId);
      for (final slot in seed.scheduleFor(r, cls, '', anchor).where((i) => i.tempSlot != null && i.tempSlot != TempSlot.am)) {
        final mAt = slot.startAt.add(Duration(minutes: 3 + r.order));
        if (!mAt.isBefore(at)) continue;
        final base = seed.seedBaselines[r.id]!;
        _measurements.add(Measurement(
          id: _id('m'), residentId: r.id, classId: r.classId, value: base + (r.order % 2), measuredAt: mAt,
          recordedBy: cls.homeroomId, judgment: judge(value: base + (r.order % 2), baseline: base)));
      }
    }

    // 화면 시나리오: 이서준 주의 → 고열, 박승민 고온, 한지호 오측정, 임유나 09:45 정상
    saveMeasurement(residentId: rid('이서준'), value: 376, by: 'lee_sujin', at: t(9, 15));
    final s = saveMeasurement(residentId: rid('박승민'), value: 382, by: 'kim_haneul', at: t(9, 20));
    _event(s.caseItem!.id, 'note', 'lee_sujin', t(9, 24), {'text': '물 마시게 하고 겉옷 벗겼어요.'});
    acknowledge(s.caseItem!.id, 'park_soyeon', t(9, 26));
    scheduleRemeasure(s.caseItem!.id, 'park_soyeon', t(9, 21), const Duration(minutes: 30));
    saveMeasurement(residentId: rid('한지호'), value: 374, by: 'kim_haneul', at: t(9, 39));
    saveMeasurement(residentId: rid('한지호'), value: 368, by: 'kim_haneul', at: t(9, 41));
    saveMeasurement(residentId: rid('임유나'), value: 364, by: 'park_jieun', at: t(9, 45));
    final seojun = saveMeasurement(residentId: rid('이서준'), value: 384, by: 'lee_sujin', at: t(10, 11));

    // 의료 호출: 자동으로 생긴 호출 문구를 화면과 맞추고, 대화·처방 초안을 붙인다.
    final seojunCall = seojun.call!;
    _replaceCall(seojunCall.copyWith(level: CallLevel.urgent, summary: '촉탁의 비대면 협진 요청'));
    final seungminCall = _calls.firstWhere((c) => c.residentId == rid('박승민'));
    _replaceCall(seungminCall.copyWith(summary: '해열 조치 후 2차 재측정 관찰 중.'));
    _calls.add(MedicalCall(
      id: _id('call'), residentId: rid('최도윤'), level: CallLevel.general, status: CallStatus.open,
      createdAt: t(9, 30), createdBy: 'lee_sujin', summary: '식욕 부진 및 활력징후 모니터링 의뢰.'));
    // 오늘 이미 끝낸 호출 (누적 현황)
    for (var i = 0; i < 14; i++) {
      final r = seed.residents[(i * 5) % seed.residents.length];
      _calls.add(MedicalCall(
        id: _id('call'), residentId: r.id, level: CallLevel.general, status: CallStatus.done,
        createdAt: t(7, 0 + i * 3), createdBy: 'park_soyeon', summary: '정기 활력징후 확인', doneAt: t(7, 20 + i * 3)));
    }
    void msg(String callId, String who, int h, int m, String body, {String kind = 'text'}) => _messages
        .add(CareMessage(id: _id('msg'), callId: callId, authorId: who, body: body, at: t(h, m), kind: kind));
    msg(seojunCall.id, 'park_soyeon', 10, 12,
        '이서준 별님 기상 후 체온 37.6°C 미열에서 방금 10:11 38.4°C로 급상승 확인되어 촉탁의 원장님께 긴급 호출 연계 드립니다. 현재 신체 떨림 및 오한 반응 경미하게 관찰됩니다.');
    msg(seojunCall.id, 'lee_sujin', 10, 13,
        '따뜻한 보리차 120ml 수분 섭취 완료했고, 안면 홍조가 뚜렷합니다. 이마에 쿨링 시트 부착해 두었습니다. 이동 시 부축 필요 상태입니다.');
    msg(seojunCall.id, 'kang_dahye', 10, 15,
        '혈압 및 산소포화도(SpO2) 추가 측정 부탁드립니다. 10시 20분 비대면 화상 진료 즉시 연결 후 전자처방전 발급하겠습니다. 아세트아미노펜 단일제 원내 비축분 준비해 주세요.');
    msg(seojunCall.id, 'system', 10, 16, '촉탁의 강다혜 님이 비대면 진단 대기실에 입장하셨습니다', kind: 'system');
    _replaceCall(callById(seojunCall.id).copyWith(videoAt: t(10, 20)));
    msg(seungminCall.id, 'park_soyeon', 9, 51, '해열 조치 후 2차 재측정 관찰 중입니다. 냉찜질 처치했어요.');

    _prescriptions.add(Prescription(
      id: _id('rx'),
      callId: seojunCall.id,
      residentId: rid('이서준'),
      doctorId: 'kang_dahye',
      code: 'J06.9',
      codeName: '상세불명의 급성 상기도 감염',
      opinion: '금일 오전 10시 11분 38.4°C 급상승 및 경미한 오한 증상. 뇌병변 질환자로 발열성 경련 예방을 위해 즉시 해열제 투약 필요. '
          '페니실린계 금기 준수하여 아세트아미노펜 단일 제제 투약 지시함. 수분 섭취 유지 및 1시간 후 재측정 요망.',
      items: const [
        RxItem(
            name: '어린이타이레놀현탁액 (아세트아미노펜 3.2g/100mL)',
            usage: '1회 20mL 경구투여 · 4~6시간 간격 필요시 투여 (1일 최대 5회 초과 금지)',
            amount: '1회 20ml'),
        RxItem(name: '코대원에스시럽 20mL/포', usage: '기침 및 호흡기 자극 완화 목적 · 1일 3회 식후 경구투여', amount: '3일분 (9포)'),
      ],
      status: 'draft',
      updatedAt: t(10, 18),
    ));

    // ── 간호사 → 의료진 협진: 이서준은 강다혜 촉탁의, 최도윤은 문재호 전문의에게 보냈다. 박승민은 간호사가 보는 중.
    void forward(String callId, String doctorId, DateTime at) {
      _replaceCall(callById(callId).copyWith(doctorId: doctorId, forwardedAt: at, forwardedBy: 'park_soyeon'));
      _messages.add(CareMessage(
          id: _id('msg'),
          callId: callId,
          authorId: 'system',
          body: '박소연 수석간호사가 ${staff(doctorId).displayName}에게 ${resident(callById(callId).residentId).name} 별님 호출을 보냈어요',
          at: at,
          kind: 'system'));
    }

    forward(seojunCall.id, 'kang_dahye', t(10, 11));
    msg(seojunCall.id, 'park_soyeon', 10, 19, '아세트아미노펜 원내 비축분 준비해 두었습니다. 화상 진료 대기하겠습니다.');
    final doyunCall = _calls.firstWhere((c) => c.residentId == rid('최도윤') && c.isOpen);
    forward(doyunCall.id, 'moon_jaeho', t(9, 35));
    msg(doyunCall.id, 'park_soyeon', 9, 36, '최근 일주일 식사량이 평소의 절반 정도이고, 밤에 자주 깨는 편입니다. 상담 가능할까요?');
    msg(doyunCall.id, 'moon_jaeho', 9, 52, '다음 주 화요일 오후 비대면 상담 잡겠습니다. 그때까지 끼니별 식사량과 수면 시간을 기록해 주세요.');

    // 지난 비대면 진료 (처방 발행 · 호출 완료)
    void pastVisit(String name, String doctorId, int daysAgo, String summary, String code, String codeName, String opinion, List<RxItem> items) {
      final at = t(14, 10, dayOffset: -daysAgo);
      final c = MedicalCall(
          id: _id('call'), residentId: rid(name), level: CallLevel.general, status: CallStatus.done, createdAt: at,
          createdBy: 'park_soyeon', summary: summary, doneAt: at.add(const Duration(hours: 2)),
          doctorId: doctorId, forwardedAt: at.add(const Duration(minutes: 3)), forwardedBy: 'park_soyeon');
      _calls.add(c);
      _messages.add(CareMessage(id: _id('msg'), callId: c.id, authorId: 'park_soyeon', body: summary, at: at.add(const Duration(minutes: 4))));
      final issuedAt = at.add(const Duration(minutes: 50));
      _prescriptions.add(Prescription(
          id: _id('rx'), callId: c.id, residentId: rid(name), doctorId: doctorId, code: code, codeName: codeName,
          opinion: opinion, items: items, status: 'issued', updatedAt: issuedAt, issuedAt: issuedAt, number: 'Rx#${87900 + _seq}'));
      _messages.add(CareMessage(
          id: _id('msg'), callId: c.id, authorId: 'system', at: issuedAt, kind: 'system',
          body: '${staff(doctorId).displayName} · 전자처방전 발행 (${_prescriptions.last.number})'));
      _reads['$doctorId|res:${rid(name)}'] = issuedAt; // 지난 진료는 의사가 다 읽었다
    }

    pastVisit('한지호', 'yoon_seojin', 4, '콧물과 마른기침이 사흘째 이어집니다. 열은 없습니다.', 'J00', '급성 비인두염(감기)',
        '발열 없는 상기도 증상. 수분 섭취 유지, 증상 악화 시 재진 요망.',
        const [RxItem(name: '코푸시럽 (어린이용)', usage: '1일 3회 식후 경구투여', amount: '3일분')]);
    pastVisit('박승민', 'kang_dahye', 12, '오른쪽 팔꿈치에 긁힌 상처가 붉게 부어 있습니다.', 'L08.9', '상세불명의 피부 및 피하조직의 국소감염',
        '찰과상 부위 경미한 발적. 소독 후 연고 도포, 3일 경과 관찰.',
        const [RxItem(name: '후시딘연고 10g', usage: '1일 2회 환부 도포', amount: '1개')]);

    // 앱에서 담임 선생님이 방금 보낸 간호사 호출 (간호사가 아직 열어 보지 않음)
    final siwoo = rid('강시우');
    _openCall(
        residentId: siwoo, level: CallLevel.general, by: 'kim_haneul', at: t(10, 35),
        summary: '기침을 자주 하고 콧물이 나요.', measurement: latestOf(siwoo));
    _entries.add(Entry(
        id: _id('e'), scope: EntryScope.resident, authorId: 'kim_haneul', kindLabel: '간호사 호출', createdAt: t(10, 35),
        classId: resident(siwoo).classId, residentId: siwoo, body: '간호 선생님을 호출했어요. 기침을 자주 하고 콧물이 나요.'));

    // 읽음: 간호사는 오전 호출을 다 열어 봤고, 문재호 전문의 답은 아직. 강다혜 촉탁의는 10:16까지 읽었다.
    for (final c in [seojunCall, seungminCall, doyunCall]) {
      _reads['park_soyeon|call:${c.id}'] = t(10, 12);
    }
    _reads['park_soyeon|doc:kang_dahye'] = t(10, 19);
    _reads['park_soyeon|doc:moon_jaeho'] = t(9, 36);
    _reads['kang_dahye|res:${rid('이서준')}'] = t(10, 16);
    _reads['moon_jaeho|res:${rid('최도윤')}'] = t(9, 52);

    _approvals.addAll([
      Approval(id: _id('ap'), title: '고래자리 박승민 비상 해열제 선투약 품의', requestedBy: 'kim_haneul', requestedAt: t(9, 30)),
      Approval(id: _id('ap'), title: '야간 당직 간호기록부 전자서명 결재', requestedBy: 'oh_jimin', requestedAt: t(7, 5)),
    ]);
    final amShift = 'sh-${anchor.year}${anchor.month.toString().padLeft(2, '0')}${anchor.day.toString().padLeft(2, '0')}-am';
    for (final (who, m) in [('kim_haneul', 7), ('park_jieun', 9), ('lee_sujin', 12)]) {
      _signs.add(HandoverSign(shiftId: amShift, staffId: who, signedAt: t(7, m)));
    }
    // 프로필 사진 기록 (가상 일러스트, 그 반 담당 선생님이 올린 것으로)
    for (final (name, by, photos) in [
      ('이서준', 'kim_haneul', [(0, 260), (1, 150), (2, 40)]),
      ('김민준', 'lee_sujin', [(3, 90), (1, 12)]),
      ('한나리', 'park_jieun', [(1, 200), (0, 21)]),
    ]) {
      final rid = seed.residentByName(name).id;
      for (final (art, daysAgo) in photos) {
        final at = anchor.subtract(Duration(days: daysAgo));
        _photos.add(ResidentPhoto(
            id: _id('ph'), residentId: rid, url: 'face:$rid:$art', uploadedBy: by, uploadedAt: DateTime(at.year, at.month, at.day, 15, 20)));
      }
    }
    // 시연 사용자들은 아침 알림을 이미 봤다고 둔다 (새 알림만 🔔에 숫자).
    _noticesSeenAt['kim_haneul'] = t(9, 30);
  }
}
