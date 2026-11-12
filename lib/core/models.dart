// 통합 명세 8장 공통 데이터 모델.
// 체온은 정수 ×10 (365 = 36.5℃), 별님 ID는 residentId.

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
  bool get opensCase =>
      this == Stage.abnormal || this == Stage.danger || this == Stage.low;

  /// 심각도 순위. 위험 > 이상 = 저온 > 주의 > 평소.
  int get rank => switch (this) {
        Stage.danger => 3,
        Stage.abnormal || Stage.low => 2,
        Stage.caution => 1,
        Stage.normal => 0,
      };
}

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
  });
  final String id;
  final String classId;
  final String name;
  final int order;

  /// 간호사가 직접 정한 기저치 (×10). 있으면 항상 우선.
  final int? baselineManual;
}

class ClassHomeroomHistory {
  const ClassHomeroomHistory({required this.classId, required this.staffId, required this.from, this.to});
  final String classId;
  final String staffId;
  final DateTime from;
  final DateTime? to;
}

/// 측정 시점의 판정 스냅샷. 나중에 기저치가 바뀌어도 그대로 둔다.
class Judgment {
  const Judgment({required this.stage, required this.baseline, required this.diff});
  final Stage stage;
  final int baseline;
  final int diff;
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

  Measurement copyWith({String? caseId, DateTime? voidedAt, String? voidedBy, String? voidReason}) =>
      Measurement(
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
        remeasureAt: remeasureAt ?? this.remeasureAt,
        recoveredAt: clearRecovered ? null : (recoveredAt ?? this.recoveredAt),
        closedAt: closedAt ?? this.closedAt,
        closeReason: closeReason ?? this.closeReason,
      );
}

class CaseEvent {
  const CaseEvent({
    required this.id,
    required this.caseId,
    required this.type,
    required this.actorId,
    required this.at,
    this.data = const {},
  });
  final String id;
  final String caseId;
  final String type;
  final String actorId; // 'system' 가능
  final DateTime at;
  final Map<String, Object?> data;
}

enum TaskKind { temp, memo }

class Task {
  const Task({
    required this.id,
    required this.label,
    required this.kind,
    required this.dueAt,
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
        done: true,
        auto: auto,
        doneBy: by,
        doneAt: at,
        resultMeasurementId: measurementId,
      );
}

enum EntryScope { facility, classScope, resident }

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
    this.measurementId,
    this.caseId,
    this.task,
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
  final String? measurementId;
  final String? caseId;
  final Task? task;

  Entry withTask(Task t) => Entry(
        id: id,
        scope: scope,
        authorId: authorId,
        kindLabel: kindLabel,
        createdAt: createdAt,
        classId: classId,
        residentId: residentId,
        title: title,
        body: body,
        measurementId: measurementId,
        caseId: caseId,
        task: t,
      );
}

class MedicationGuideline {
  const MedicationGuideline({required this.residentId, required this.body, required this.writtenBy, required this.updatedAt});
  final String residentId;
  final String body;
  final String writtenBy;
  final DateTime updatedAt;
}
