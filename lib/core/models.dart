// 통합 명세 8장 공통 데이터 모델.
// 체온은 정수 ×10 (365 = 36.5℃), 별님 ID는 residentId.
// toJson/fromJson은 기기 안 저장(storage.dart)에 쓴다.

enum Role { care, nurse, office, director, admin }

/// 판정 단계 (통합 명세 5-2).
enum Stage { normal, caution, abnormal, danger, low }

extension StageInfo on Stage {
  String get label => switch (this) {
        Stage.normal => '평소',
        Stage.caution => '주의',
        Stage.abnormal => '이상',
        Stage.danger => '위험',
        Stage.low => '저온',
      };

  String get symbol => switch (this) {
        Stage.normal => '✓',
        Stage.caution => '!',
        Stage.abnormal => '▲',
        Stage.danger => '⚠',
        Stage.low => '▼',
      };

  /// 이상 건(Case)을 만드는 판정인가.
  bool get opensCase => this == Stage.abnormal || this == Stage.danger || this == Stage.low;

  /// 심각도 순위. 위험 > 이상 = 저온 > 주의 > 평소.
  int get rank => switch (this) {
        Stage.danger => 3,
        Stage.abnormal || Stage.low => 2,
        Stage.caution => 1,
        Stage.normal => 0,
      };
}

DateTime? _dt(Object? v) => v == null ? null : DateTime.parse(v as String);
String? _iso(DateTime? d) => d?.toIso8601String();
T _enum<T extends Enum>(List<T> values, Object? name) => values.firstWhere((e) => e.name == name);

class Staff {
  const Staff({required this.id, required this.name, required this.role, this.title});
  final String id;
  final String name;
  final Role role;

  /// 화면에 붙이는 호칭. 예: '선생님', '간호사', '원장님'.
  final String? title;

  String get displayName => '$name ${title ?? _defaultTitle}';
  String get _defaultTitle => switch (role) {
        Role.nurse => '간호사',
        Role.director => '원장님',
        _ => '선생님',
      };
}

class Class {
  const Class({
    required this.id,
    required this.name,
    required this.color,
    required this.homeroomId,
    required this.order,
    required this.sex,
  });
  final String id;
  final String name; // 예: '은하수자리'
  final int color; // 0xFFRRGGBB
  final String homeroomId;
  final int order;
  final String sex; // '여' | '남'
}

class Resident {
  const Resident({
    required this.id,
    required this.classId,
    required this.name,
    required this.order,
    this.baselineManual,
    this.commutesToSchool = false,
  });
  final String id;
  final String classId;
  final String name;
  final int order;

  /// 간호사가 직접 정한 기저치 (×10). 있으면 항상 우선.
  final int? baselineManual;

  /// 학교에 다니는 별님 (일정 패턴이 다름, 일정 5장).
  final bool commutesToSchool;
}

class ClassHomeroomHistory {
  const ClassHomeroomHistory({required this.classId, required this.staffId, required this.from, this.to});
  final String classId;
  final String staffId;
  final DateTime from;
  final DateTime? to;
}

/// 근무조 (통합 명세 8장 Shift). 시간은 [확인 필요].
enum ShiftType { am, pm, night }

class Shift {
  const Shift({required this.id, required this.type, required this.startAt, required this.endAt, required this.staffIds});
  final String id;
  final ShiftType type;
  final DateTime startAt;
  final DateTime endAt;
  final List<String> staffIds;

  String get label => switch (type) { ShiftType.am => '오전', ShiftType.pm => '오후', ShiftType.night => '야간' };
}

/// 측정 시점의 판정 스냅샷. 나중에 기저치가 바뀌어도 그대로 둔다.
class Judgment {
  const Judgment({required this.stage, required this.baseline, required this.diff});
  final Stage stage;
  final int baseline;
  final int diff;

  Map<String, Object?> toJson() => {'stage': stage.name, 'baseline': baseline, 'diff': diff};
  factory Judgment.fromJson(Map<String, Object?> j) =>
      Judgment(stage: _enum(Stage.values, j['stage']), baseline: j['baseline'] as int, diff: j['diff'] as int);
}

class Measurement {
  const Measurement({
    required this.id,
    required this.residentId,
    required this.classId,
    required this.value,
    required this.measuredAt,
    required this.recordedBy,
    required this.judgment,
    this.source = 'quick',
    this.caseId,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    this.correctsId,
  });
  final String id;
  final String residentId;
  final String classId;
  final int value;
  final DateTime measuredAt;
  final String recordedBy;
  final Judgment judgment;
  final String source;
  final String? caseId;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;
  final String? correctsId;

  bool get isVoided => voidedAt != null;

  Measurement copyWith({String? caseId, DateTime? voidedAt, String? voidedBy, String? voidReason}) => Measurement(
        id: id,
        residentId: residentId,
        classId: classId,
        value: value,
        measuredAt: measuredAt,
        recordedBy: recordedBy,
        judgment: judgment,
        source: source,
        caseId: caseId ?? this.caseId,
        voidedAt: voidedAt ?? this.voidedAt,
        voidedBy: voidedBy ?? this.voidedBy,
        voidReason: voidReason ?? this.voidReason,
        correctsId: correctsId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'residentId': residentId,
        'classId': classId,
        'value': value,
        'measuredAt': _iso(measuredAt),
        'recordedBy': recordedBy,
        'judgment': judgment.toJson(),
        'source': source,
        'caseId': caseId,
        'voidedAt': _iso(voidedAt),
        'voidedBy': voidedBy,
        'voidReason': voidReason,
        'correctsId': correctsId,
      };
  factory Measurement.fromJson(Map<String, Object?> j) => Measurement(
        id: j['id'] as String,
        residentId: j['residentId'] as String,
        classId: j['classId'] as String,
        value: j['value'] as int,
        measuredAt: _dt(j['measuredAt'])!,
        recordedBy: j['recordedBy'] as String,
        judgment: Judgment.fromJson((j['judgment'] as Map).cast()),
        source: j['source'] as String? ?? 'quick',
        caseId: j['caseId'] as String?,
        voidedAt: _dt(j['voidedAt']),
        voidedBy: j['voidedBy'] as String?,
        voidReason: j['voidReason'] as String?,
        correctsId: j['correctsId'] as String?,
      );
}

enum CaseStatus { unacked, acked, active, waitingRemeasure, closed }

/// 이상 건. 화면에서는 위험이 나온 건 = "긴급", 나머지 = "이상 대응" (C2 v1.2).
class Case {
  const Case({
    required this.id,
    required this.residentId,
    required this.classId,
    required this.severity,
    required this.status,
    required this.stage,
    required this.firstMeasurementId,
    required this.firstTemp,
    required this.baseline,
    required this.createdAt,
    this.assigneeId,
    this.remeasureAt,
    this.recoveredAt,
    this.closedAt,
    this.closeReason,
  });
  final String id;
  final String residentId;
  final String classId;

  /// 지금까지 나온 판정 중 가장 심한 것.
  final Stage severity;
  final CaseStatus status;
  final int stage; // 대응 단계 1~4
  final String firstMeasurementId;
  final int firstTemp;
  final int baseline;
  final DateTime createdAt;
  final String? assigneeId;
  final DateTime? remeasureAt;
  final DateTime? recoveredAt;
  final DateTime? closedAt;
  final String? closeReason;

  bool get isUrgent => severity == Stage.danger;
  bool get isOpen => status != CaseStatus.closed;
  String get kindLabel => isUrgent ? '긴급' : '이상 대응';

  Case copyWith({
    Stage? severity,
    CaseStatus? status,
    int? stage,
    String? assigneeId,
    DateTime? remeasureAt,
    bool clearRemeasure = false,
    DateTime? recoveredAt,
    bool clearRecovered = false,
    DateTime? closedAt,
    String? closeReason,
  }) =>
      Case(
        id: id,
        residentId: residentId,
        classId: classId,
        severity: severity ?? this.severity,
        status: status ?? this.status,
        stage: stage ?? this.stage,
        firstMeasurementId: firstMeasurementId,
        firstTemp: firstTemp,
        baseline: baseline,
        createdAt: createdAt,
        assigneeId: assigneeId ?? this.assigneeId,
        remeasureAt: clearRemeasure ? null : (remeasureAt ?? this.remeasureAt),
        recoveredAt: clearRecovered ? null : (recoveredAt ?? this.recoveredAt),
        closedAt: closedAt ?? this.closedAt,
        closeReason: closeReason ?? this.closeReason,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'residentId': residentId,
        'classId': classId,
        'severity': severity.name,
        'status': status.name,
        'stage': stage,
        'firstMeasurementId': firstMeasurementId,
        'firstTemp': firstTemp,
        'baseline': baseline,
        'createdAt': _iso(createdAt),
        'assigneeId': assigneeId,
        'remeasureAt': _iso(remeasureAt),
        'recoveredAt': _iso(recoveredAt),
        'closedAt': _iso(closedAt),
        'closeReason': closeReason,
      };
  factory Case.fromJson(Map<String, Object?> j) => Case(
        id: j['id'] as String,
        residentId: j['residentId'] as String,
        classId: j['classId'] as String,
        severity: _enum(Stage.values, j['severity']),
        status: _enum(CaseStatus.values, j['status']),
        stage: j['stage'] as int,
        firstMeasurementId: j['firstMeasurementId'] as String,
        firstTemp: j['firstTemp'] as int,
        baseline: j['baseline'] as int,
        createdAt: _dt(j['createdAt'])!,
        assigneeId: j['assigneeId'] as String?,
        remeasureAt: _dt(j['remeasureAt']),
        recoveredAt: _dt(j['recoveredAt']),
        closedAt: _dt(j['closedAt']),
        closeReason: j['closeReason'] as String?,
      );
}

/// 이상 건 기록 한 줄. 지우지 않고 취소 표시(voidedBy)만 한다.
class CaseEvent {
  const CaseEvent({
    required this.id,
    required this.caseId,
    required this.type,
    required this.actorId,
    required this.at,
    this.data = const {},
    this.voidedBy,
  });
  final String id;
  final String caseId;

  /// created · remeasured · escalated · recovered · acked · assigned · stage ·
  /// remeasure_scheduled · note · medication · director_order · hospital_result · closed
  final String type;
  final String actorId; // 'system' 가능
  final DateTime at;
  final Map<String, Object?> data;
  final String? voidedBy;

  Map<String, Object?> toJson() =>
      {'id': id, 'caseId': caseId, 'type': type, 'actorId': actorId, 'at': _iso(at), 'data': data, 'voidedBy': voidedBy};
  factory CaseEvent.fromJson(Map<String, Object?> j) => CaseEvent(
        id: j['id'] as String,
        caseId: j['caseId'] as String,
        type: j['type'] as String,
        actorId: j['actorId'] as String,
        at: _dt(j['at'])!,
        data: (j['data'] as Map? ?? const {}).cast(),
        voidedBy: j['voidedBy'] as String?,
      );
}

enum TaskKind { temp, memo }

class Task {
  const Task({
    required this.id,
    required this.label,
    required this.kind,
    required this.dueAt,
    this.duePreset,
    this.done = false,
    this.auto = false,
    this.doneBy,
    this.doneAt,
    this.resultMeasurementId,
  });
  final String id;
  final String label;
  final TaskKind kind;
  final DateTime? dueAt;

  /// '점심 전' · '13:00 목욕 전' · '저녁 전' · '다음 근무조' 등 (인수인계 6장).
  final String? duePreset;
  final bool done;
  final bool auto;
  final String? doneBy;
  final DateTime? doneAt;
  final String? resultMeasurementId;

  Task complete({required String by, required DateTime at, String? measurementId}) => Task(
        id: id,
        label: label,
        kind: kind,
        dueAt: dueAt,
        duePreset: duePreset,
        done: true,
        auto: auto,
        doneBy: by,
        doneAt: at,
        resultMeasurementId: measurementId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'kind': kind.name,
        'dueAt': _iso(dueAt),
        'duePreset': duePreset,
        'done': done,
        'auto': auto,
        'doneBy': doneBy,
        'doneAt': _iso(doneAt),
        'resultMeasurementId': resultMeasurementId,
      };
  factory Task.fromJson(Map<String, Object?> j) => Task(
        id: j['id'] as String,
        label: j['label'] as String,
        kind: _enum(TaskKind.values, j['kind']),
        dueAt: _dt(j['dueAt']),
        duePreset: j['duePreset'] as String?,
        done: j['done'] as bool? ?? false,
        auto: j['auto'] as bool? ?? false,
        doneBy: j['doneBy'] as String?,
        doneAt: _dt(j['doneAt']),
        resultMeasurementId: j['resultMeasurementId'] as String?,
      );
}

enum EntryScope { facility, classScope, resident }

/// 이전 본문 (수정 이력, 인수인계 4.7).
class EntryRevision {
  const EntryRevision({required this.body, required this.editedBy, required this.editedAt});
  final String body;
  final String editedBy;
  final DateTime editedAt;

  Map<String, Object?> toJson() => {'body': body, 'editedBy': editedBy, 'editedAt': _iso(editedAt)};
  factory EntryRevision.fromJson(Map<String, Object?> j) =>
      EntryRevision(body: j['body'] as String, editedBy: j['editedBy'] as String, editedAt: _dt(j['editedAt'])!);
}

class Entry {
  const Entry({
    required this.id,
    required this.scope,
    required this.authorId,
    required this.kindLabel,
    required this.createdAt,
    this.classId,
    this.residentId,
    this.title,
    this.body,
    this.photoCount = 0,
    this.measurementId,
    this.caseId,
    this.task,
    this.pinned = false,
    this.updatedAt,
    this.revisions = const [],
  });
  final String id;
  final EntryScope scope;
  final String authorId;
  final String kindLabel;
  final DateTime createdAt;
  final String? classId;
  final String? residentId;
  final String? title;
  final String? body;

  /// 사진 수. 시연은 실제 사진 대신 자리 표시만 한다.
  final int photoCount;
  final String? measurementId;
  final String? caseId;
  final Task? task;

  /// 고정된 전체 공지.
  final bool pinned;
  final DateTime? updatedAt;
  final List<EntryRevision> revisions;

  Entry copyWith({Task? task, String? body, DateTime? updatedAt, List<EntryRevision>? revisions}) => Entry(
        id: id,
        scope: scope,
        authorId: authorId,
        kindLabel: kindLabel,
        createdAt: createdAt,
        classId: classId,
        residentId: residentId,
        title: title,
        body: body ?? this.body,
        photoCount: photoCount,
        measurementId: measurementId,
        caseId: caseId,
        task: task ?? this.task,
        pinned: pinned,
        updatedAt: updatedAt ?? this.updatedAt,
        revisions: revisions ?? this.revisions,
      );

  Entry withTask(Task t) => copyWith(task: t);

  Map<String, Object?> toJson() => {
        'id': id,
        'scope': scope.name,
        'authorId': authorId,
        'kindLabel': kindLabel,
        'createdAt': _iso(createdAt),
        'classId': classId,
        'residentId': residentId,
        'title': title,
        'body': body,
        'photoCount': photoCount,
        'measurementId': measurementId,
        'caseId': caseId,
        'task': task?.toJson(),
        'pinned': pinned,
        'updatedAt': _iso(updatedAt),
        'revisions': [for (final r in revisions) r.toJson()],
      };
  factory Entry.fromJson(Map<String, Object?> j) => Entry(
        id: j['id'] as String,
        scope: _enum(EntryScope.values, j['scope']),
        authorId: j['authorId'] as String,
        kindLabel: j['kindLabel'] as String,
        createdAt: _dt(j['createdAt'])!,
        classId: j['classId'] as String?,
        residentId: j['residentId'] as String?,
        title: j['title'] as String?,
        body: j['body'] as String?,
        photoCount: j['photoCount'] as int? ?? 0,
        measurementId: j['measurementId'] as String?,
        caseId: j['caseId'] as String?,
        task: j['task'] == null ? null : Task.fromJson((j['task'] as Map).cast()),
        pinned: j['pinned'] as bool? ?? false,
        updatedAt: _dt(j['updatedAt']),
        revisions: [for (final r in (j['revisions'] as List? ?? const [])) EntryRevision.fromJson((r as Map).cast())],
      );
}

class Reply {
  const Reply({required this.id, required this.entryId, required this.authorId, required this.body, required this.createdAt});
  final String id;
  final String entryId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  Map<String, Object?> toJson() =>
      {'id': id, 'entryId': entryId, 'authorId': authorId, 'body': body, 'createdAt': _iso(createdAt)};
  factory Reply.fromJson(Map<String, Object?> j) => Reply(
        id: j['id'] as String,
        entryId: j['entryId'] as String,
        authorId: j['authorId'] as String,
        body: j['body'] as String,
        createdAt: _dt(j['createdAt'])!,
      );
}

/// 확인(읽음) 기록 (인수인계 4.3). source: feed · archive · reply · complete · remeasure
class ReadReceipt {
  const ReadReceipt({required this.entryId, required this.staffId, required this.readAt, required this.source});
  final String entryId;
  final String staffId;
  final DateTime readAt;
  final String source;

  Map<String, Object?> toJson() => {'entryId': entryId, 'staffId': staffId, 'readAt': _iso(readAt), 'source': source};
  factory ReadReceipt.fromJson(Map<String, Object?> j) => ReadReceipt(
        entryId: j['entryId'] as String,
        staffId: j['staffId'] as String,
        readAt: _dt(j['readAt'])!,
        source: j['source'] as String,
      );
}

class MedicationGuideline {
  const MedicationGuideline({required this.residentId, required this.body, required this.writtenBy, required this.updatedAt});
  final String residentId;
  final String body;
  final String writtenBy;
  final DateTime updatedAt;
}

// ── 일정 (일정 명세 9장)

enum ScheduleKind { meal, school, therapy, art, bath, living }

extension ScheduleKindInfo on ScheduleKind {
  String get label => switch (this) {
        ScheduleKind.meal => '식사',
        ScheduleKind.school => '학교',
        ScheduleKind.therapy => '치료·교육',
        ScheduleKind.art => '예체능',
        ScheduleKind.bath => '목욕',
        ScheduleKind.living => '생활',
      };
}

/// 체온 측정 시점 (통합 명세 7-3).
enum TempSlot { am, pmBath, pmReturn }

extension TempSlotInfo on TempSlot {
  String get label => switch (this) {
        TempSlot.am => '오전 체온',
        TempSlot.pmBath => '오후 체온 · 목욕 전',
        TempSlot.pmReturn => '오후 체온 · 귀가 후',
      };

  /// 카드의 '오전' / '오후' 칸.
  bool get isMorning => this == TempSlot.am;
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.residentId,
    required this.classId,
    required this.date,
    required this.startAt,
    required this.endAt,
    required this.title,
    required this.place,
    required this.kind,
    this.staffName,
    this.tempSlot,
  });
  final String id;
  final String residentId;
  final String classId;
  final DateTime date; // 날짜만 (00:00)
  final DateTime startAt;
  final DateTime endAt;
  final String title;
  final String place;
  final ScheduleKind kind;
  final String? staffName;
  final TempSlot? tempSlot;
}

/// 측정 시점 하나의 상태 (통합 명세 7-3).
enum SlotState { recorded, missed, upcoming }

class SlotStatus {
  const SlotStatus({required this.slot, required this.at, required this.state, this.measurement});
  final TempSlot slot;
  final DateTime at;
  final SlotState state;
  final Measurement? measurement;
}
