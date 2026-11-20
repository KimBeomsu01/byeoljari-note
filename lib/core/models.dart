// 통합 명세 8장 공통 데이터 모델.
// 체온은 정수 ×10 (365 = 36.5℃), 별님 ID는 residentId.
// toJson/fromJson은 기기 안 저장(storage.dart)에 쓴다.

enum Role { care, nurse, office, director, admin, doctor }

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
  const Staff({required this.id, required this.name, required this.role, this.title, this.team, this.example = false});
  final String id;
  final String name;
  final Role role;

  /// 화면에 붙이는 호칭. 예: '선생님', '간호사', '원장님'.
  final String? title;

  /// 소속 (PC 머리에 표시). 예: '혜진원 의료지원팀'.
  final String? team;

  /// 개발 DB의 예시 자료. 실제 자료가 하나라도 생기면 화면에서 숨긴다.
  final bool example;

  String get displayName => '$name ${title ?? _defaultTitle}';
  String get _defaultTitle => switch (role) {
        Role.nurse => '간호사',
        Role.director => '원장님',
        Role.doctor => '원장',
        _ => '선생님',
      };

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'role': role.name, 'title': title, 'team': team, if (example) 'example': true};
  factory Staff.fromJson(Map<String, Object?> j) => Staff(
        id: j['id'] as String,
        name: j['name'] as String,
        role: _enum(Role.values, j['role']),
        title: j['title'] as String?,
        team: j['team'] as String?,
        example: j['example'] as bool? ?? false,
      );
}

class Class {
  const Class({
    required this.id,
    required this.name,
    required this.color,
    required this.homeroomId,
    required this.order,
    required this.sex,
    this.room,
    this.example = false,
  });
  final String id;
  final String name; // 예: '은하수자리'
  final int color; // 0xFFRRGGBB
  final String homeroomId;
  final int order;
  final String sex; // '여' | '남'

  /// 생활실. 예: '203호'.
  final String? room;
  final bool example;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'homeroomId': homeroomId,
        'order': order,
        'sex': sex,
        'room': room,
        if (example) 'example': true,
      };
  factory Class.fromJson(Map<String, Object?> j) => Class(
        id: j['id'] as String,
        name: j['name'] as String,
        color: j['color'] as int,
        homeroomId: j['homeroomId'] as String,
        order: j['order'] as int,
        sex: j['sex'] as String,
        room: j['room'] as String?,
        example: j['example'] as bool? ?? false,
      );
}

class Resident {
  const Resident({
    required this.id,
    required this.classId,
    required this.name,
    required this.order,
    this.baselineManual,
    this.commutesToSchool = false,
    this.sex,
    this.age,
    this.code,
    this.diagnosis,
    this.cautions,
    this.regularMeds,
    this.prnNote,
    this.severe = false,
    this.example = false,
  });
  final String id;
  final String classId;
  final String name;
  final int order;

  /// 간호사가 직접 정한 기저치 (×10). 있으면 항상 우선.
  final int? baselineManual;

  /// 학교에 다니는 별님 (일정 패턴이 다름, 일정 5장).
  final bool commutesToSchool;

  final String? sex; // '남' | '여'
  final int? age;

  /// 기록 번호. 예: 'HJ-2021-088'.
  final String? code;

  /// 주진단 (의료진이 쓴 글 그대로).
  final String? diagnosis;

  /// 금기·주의 (의료진이 쓴 글 그대로).
  final String? cautions;

  /// 상시 복약 (의료진이 쓴 글 그대로).
  final String? regularMeds;

  /// 필요시 투약 지시 (의료진이 쓴 글 그대로). 앱은 계산하지 않는다.
  final String? prnNote;

  /// 중증 표시.
  final bool severe;
  final bool example;

  /// 다이얼·아바타에 쓰는 이름 두 글자 (성 뺌).
  String get shortName => name.length >= 3 ? name.substring(name.length - 2) : name;

  Map<String, Object?> toJson() => {
        'id': id,
        'classId': classId,
        'name': name,
        'order': order,
        'baselineManual': baselineManual,
        'commutesToSchool': commutesToSchool,
        'sex': sex,
        'age': age,
        'code': code,
        'diagnosis': diagnosis,
        'cautions': cautions,
        'regularMeds': regularMeds,
        'prnNote': prnNote,
        'severe': severe,
        if (example) 'example': true,
      };
  factory Resident.fromJson(Map<String, Object?> j) => Resident(
        id: j['id'] as String,
        classId: j['classId'] as String,
        name: j['name'] as String,
        order: j['order'] as int,
        baselineManual: j['baselineManual'] as int?,
        commutesToSchool: j['commutesToSchool'] as bool? ?? false,
        sex: j['sex'] as String?,
        age: j['age'] as int?,
        code: j['code'] as String?,
        diagnosis: j['diagnosis'] as String?,
        cautions: j['cautions'] as String?,
        regularMeds: j['regularMeds'] as String?,
        prnNote: j['prnNote'] as String?,
        severe: j['severe'] as bool? ?? false,
        example: j['example'] as bool? ?? false,
      );
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

  Map<String, Object?> toJson() =>
      {'residentId': residentId, 'body': body, 'writtenBy': writtenBy, 'updatedAt': _iso(updatedAt)};
  factory MedicationGuideline.fromJson(Map<String, Object?> j) => MedicationGuideline(
        residentId: j['residentId'] as String,
        body: j['body'] as String,
        writtenBy: j['writtenBy'] as String,
        updatedAt: _dt(j['updatedAt'])!,
      );
}

// ── PC 화면 자료 (Claude Design PC 01~04)

/// 시설 일정 구분 (PC 02 범례).
enum CalendarCategory { facility, education, therapy, care, medical }

extension CalendarCategoryInfo on CalendarCategory {
  String get label => switch (this) {
        CalendarCategory.facility => '시설 행사 & 정기 점검',
        CalendarCategory.education => '개별화 특수 교육 & 통학',
        CalendarCategory.therapy => '재활 & 물리·작업치료',
        CalendarCategory.care => '생활 & 온수 목욕 케어',
        CalendarCategory.medical => '촉탁의 비대면 진료 & 의료협진',
      };

  /// 일과표 태그 글자.
  String get tag => switch (this) {
        CalendarCategory.facility => '시설공지',
        CalendarCategory.education => '특수교육',
        CalendarCategory.therapy => '재활치료',
        CalendarCategory.care => '케어일정',
        CalendarCategory.medical => '의료협진',
      };
}

/// 시설 · 생활관 일정 한 건 (PC 02).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.date,
    required this.title,
    required this.category,
    required this.createdBy,
    required this.createdAt,
    this.time,
    this.classId,
    this.owner,
    this.detail,
    this.holiday = false,
  });
  final String id;

  /// 날짜만 (00:00).
  final DateTime date;

  /// 'HH:mm'. 없으면 종일.
  final String? time;
  final String title;
  final CalendarCategory category;

  /// 대상 생활관. 없으면 시설 전체.
  final String? classId;

  /// 담당 (글자 그대로). 예: '관리팀 박서연'.
  final String? owner;
  final String? detail;

  /// 공휴일 이름 표시 (예: '개천절').
  final bool holiday;
  final String createdBy;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'date': _iso(date),
        'time': time,
        'title': title,
        'category': category.name,
        'classId': classId,
        'owner': owner,
        'detail': detail,
        'holiday': holiday,
        'createdBy': createdBy,
        'createdAt': _iso(createdAt),
      };
  factory CalendarEvent.fromJson(Map<String, Object?> j) => CalendarEvent(
        id: j['id'] as String,
        date: _dt(j['date'])!,
        time: j['time'] as String?,
        title: j['title'] as String,
        category: _enum(CalendarCategory.values, j['category']),
        classId: j['classId'] as String?,
        owner: j['owner'] as String?,
        detail: j['detail'] as String?,
        holiday: j['holiday'] as bool? ?? false,
        createdBy: j['createdBy'] as String,
        createdAt: _dt(j['createdAt'])!,
      );
}

/// 의료 호출 단계 (PC 03 목록 태그).
enum CallLevel { urgent, observe, general }

extension CallLevelInfo on CallLevel {
  String get label => switch (this) {
        CallLevel.urgent => '긴급',
        CallLevel.observe => '관찰 중',
        CallLevel.general => '일반 의뢰',
      };
}

enum CallStatus { open, done }

/// 의료 호출 한 건 (간호사 ↔ 촉탁의). 앱의 "간호 선생님에게 알림"도 여기로 들어온다.
class MedicalCall {
  const MedicalCall({
    required this.id,
    required this.residentId,
    required this.level,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    required this.summary,
    this.temp,
    this.diff,
    this.caseId,
    this.videoAt,
    this.doneAt,
    this.doctorId,
    this.forwardedAt,
    this.forwardedBy,
  });
  final String id;
  final String residentId;
  final CallLevel level;
  final CallStatus status;
  final DateTime createdAt;
  final String createdBy;

  /// 목록에 보이는 한 줄. 예: '촉탁의 비대면 협진 요청'.
  final String summary;
  final int? temp;
  final int? diff;
  final String? caseId;

  /// 비대면 화상 진료 예약 시각.
  final DateTime? videoAt;
  final DateTime? doneAt;

  /// 간호사가 이 호출을 보낸 의료진 (의사 · 병원). 보내기 전에는 null (간호사 호출함에만 있다).
  final String? doctorId;
  final DateTime? forwardedAt;
  final String? forwardedBy;

  bool get isOpen => status == CallStatus.open;
  bool get forwarded => doctorId != null;

  MedicalCall copyWith({
    CallLevel? level,
    CallStatus? status,
    DateTime? videoAt,
    DateTime? doneAt,
    String? summary,
    String? doctorId,
    DateTime? forwardedAt,
    String? forwardedBy,
  }) =>
      MedicalCall(
        doctorId: doctorId ?? this.doctorId,
        forwardedAt: forwardedAt ?? this.forwardedAt,
        forwardedBy: forwardedBy ?? this.forwardedBy,
        id: id,
        residentId: residentId,
        level: level ?? this.level,
        status: status ?? this.status,
        createdAt: createdAt,
        createdBy: createdBy,
        summary: summary ?? this.summary,
        temp: temp,
        diff: diff,
        caseId: caseId,
        videoAt: videoAt ?? this.videoAt,
        doneAt: doneAt ?? this.doneAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'residentId': residentId,
        'level': level.name,
        'status': status.name,
        'createdAt': _iso(createdAt),
        'createdBy': createdBy,
        'summary': summary,
        'temp': temp,
        'diff': diff,
        'caseId': caseId,
        'videoAt': _iso(videoAt),
        'doneAt': _iso(doneAt),
        'doctorId': doctorId,
        'forwardedAt': _iso(forwardedAt),
        'forwardedBy': forwardedBy,
      };
  factory MedicalCall.fromJson(Map<String, Object?> j) => MedicalCall(
        doctorId: j['doctorId'] as String?,
        forwardedAt: _dt(j['forwardedAt']),
        forwardedBy: j['forwardedBy'] as String?,
        id: j['id'] as String,
        residentId: j['residentId'] as String,
        level: _enum(CallLevel.values, j['level']),
        status: _enum(CallStatus.values, j['status']),
        createdAt: _dt(j['createdAt'])!,
        createdBy: j['createdBy'] as String,
        summary: j['summary'] as String,
        temp: j['temp'] as int?,
        diff: j['diff'] as int?,
        caseId: j['caseId'] as String?,
        videoAt: _dt(j['videoAt']),
        doneAt: _dt(j['doneAt']),
      );
}

/// 케어팀 대화 한 줄 (PC 03·04). kind: text · vital(체온 자동 첨부) · system(입장 안내 등).
class CareMessage {
  const CareMessage({
    required this.id,
    required this.callId,
    required this.authorId,
    required this.body,
    required this.at,
    this.kind = 'text',
    this.data = const {},
  });
  final String id;
  final String callId;
  final String authorId;
  final String body;
  final DateTime at;
  final String kind;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() =>
      {'id': id, 'callId': callId, 'authorId': authorId, 'body': body, 'at': _iso(at), 'kind': kind, 'data': data};
  factory CareMessage.fromJson(Map<String, Object?> j) => CareMessage(
        id: j['id'] as String,
        callId: j['callId'] as String,
        authorId: j['authorId'] as String,
        body: j['body'] as String,
        at: _dt(j['at'])!,
        kind: j['kind'] as String? ?? 'text',
        data: (j['data'] as Map? ?? const {}).cast(),
      );
}

/// 처방 약 한 줄. 의사가 쓴 글 그대로 저장하고 보여주기만 한다 (앱은 용량을 계산하지 않는다).
class RxItem {
  const RxItem({required this.name, required this.usage, required this.amount});
  final String name;
  final String usage;
  final String amount;

  Map<String, Object?> toJson() => {'name': name, 'usage': usage, 'amount': amount};
  factory RxItem.fromJson(Map<String, Object?> j) =>
      RxItem(name: j['name'] as String, usage: j['usage'] as String, amount: j['amount'] as String);
}

/// 비대면 진단서 · 전자처방전 (PC 04). status: draft · issued
class Prescription {
  const Prescription({
    required this.id,
    required this.callId,
    required this.residentId,
    required this.doctorId,
    required this.code,
    required this.codeName,
    required this.opinion,
    required this.items,
    required this.status,
    required this.updatedAt,
    this.issuedAt,
    this.number,
  });
  final String id;
  final String callId;
  final String residentId;
  final String doctorId;

  /// 질병코드 (KCD-8). 예: 'J06.9'.
  final String code;
  final String codeName;
  final String opinion;
  final List<RxItem> items;
  final String status;
  final DateTime updatedAt;
  final DateTime? issuedAt;

  /// 처방전 번호. 예: 'Rx#88392'.
  final String? number;

  bool get issued => status == 'issued';

  Map<String, Object?> toJson() => {
        'id': id,
        'callId': callId,
        'residentId': residentId,
        'doctorId': doctorId,
        'code': code,
        'codeName': codeName,
        'opinion': opinion,
        'items': [for (final i in items) i.toJson()],
        'status': status,
        'updatedAt': _iso(updatedAt),
        'issuedAt': _iso(issuedAt),
        'number': number,
      };
  factory Prescription.fromJson(Map<String, Object?> j) => Prescription(
        id: j['id'] as String,
        callId: j['callId'] as String,
        residentId: j['residentId'] as String,
        doctorId: j['doctorId'] as String,
        code: j['code'] as String,
        codeName: j['codeName'] as String,
        opinion: j['opinion'] as String,
        items: [for (final i in (j['items'] as List? ?? const [])) RxItem.fromJson((i as Map).cast())],
        status: j['status'] as String,
        updatedAt: _dt(j['updatedAt'])!,
        issuedAt: _dt(j['issuedAt']),
        number: j['number'] as String?,
      );
}

/// 결재 대기 업무 (PC 01 "수석간호사 결재 대기 업무").
class Approval {
  const Approval({
    required this.id,
    required this.title,
    required this.requestedBy,
    required this.requestedAt,
    this.approvedBy,
    this.approvedAt,
  });
  final String id;
  final String title;
  final String requestedBy;
  final DateTime requestedAt;
  final String? approvedBy;
  final DateTime? approvedAt;

  bool get approved => approvedAt != null;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'requestedBy': requestedBy,
        'requestedAt': _iso(requestedAt),
        'approvedBy': approvedBy,
        'approvedAt': _iso(approvedAt),
      };
  factory Approval.fromJson(Map<String, Object?> j) => Approval(
        id: j['id'] as String,
        title: j['title'] as String,
        requestedBy: j['requestedBy'] as String,
        requestedAt: _dt(j['requestedAt'])!,
        approvedBy: j['approvedBy'] as String?,
        approvedAt: _dt(j['approvedAt']),
      );
}

/// 근무조 인계 서명 (PC 01 "인계 서명 상태").
class HandoverSign {
  const HandoverSign({required this.shiftId, required this.staffId, required this.signedAt});
  final String shiftId;
  final String staffId;
  final DateTime signedAt;

  Map<String, Object?> toJson() => {'shiftId': shiftId, 'staffId': staffId, 'signedAt': _iso(signedAt)};
  factory HandoverSign.fromJson(Map<String, Object?> j) =>
      HandoverSign(shiftId: j['shiftId'] as String, staffId: j['staffId'] as String, signedAt: _dt(j['signedAt'])!);
}

/// 별님 프로필 사진 한 장 (카카오톡 프로필처럼 쌓인다. 가장 최근 것이 지금 프로필).
/// [url]: 서버에 올린 사진은 `/api/photo/<id>`, 서버 없이 쓰면 `data:` 주소,
/// 시연 자료는 `face:<별님 id>:<그림 번호>` (가상 일러스트).
class ResidentPhoto {
  const ResidentPhoto({
    required this.id,
    required this.residentId,
    required this.url,
    required this.uploadedBy,
    required this.uploadedAt,
  });
  final String id;
  final String residentId;
  final String url;
  final String uploadedBy;
  final DateTime uploadedAt;

  Map<String, Object?> toJson() =>
      {'id': id, 'residentId': residentId, 'url': url, 'uploadedBy': uploadedBy, 'uploadedAt': _iso(uploadedAt)};
  factory ResidentPhoto.fromJson(Map<String, Object?> j) => ResidentPhoto(
        id: j['id'] as String,
        residentId: j['residentId'] as String,
        url: j['url'] as String,
        uploadedBy: j['uploadedBy'] as String,
        uploadedAt: _dt(j['uploadedAt'])!,
      );
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
