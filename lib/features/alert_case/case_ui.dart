// 이상 대응 화면들이 같이 쓰는 것: 이름표·색·상태 문구·권한·타임라인 문구.
// 판정은 저장된 측정의 judgment만 읽는다. 여기서 다시 계산하지 않는다 (통합 명세 5-2).
import 'package:flutter/material.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/seed.dart' show nightDutyStaffId;
import '../../core/theme.dart';

const circledStage = ['①', '②', '③', '④'];

String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String agoText(DateTime now, DateTime t) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  final m = d.inMinutes % 60;
  return m == 0 ? '${d.inHours}시간 전' : '${d.inHours}시간 $m분 전';
}

/// 화면 이름: 위험이 나온 건 = "⚠ 긴급", 이상·저온만 = "▲ 이상 대응" / "▼ 이상 대응".
String caseBadge(Case c) => c.isUrgent ? '⚠ 긴급' : '${c.severity.symbol} 이상 대응';

StageColors caseColors(Case c) => stageColors[c.isUrgent ? Stage.danger : c.severity]!;

String caseStatusLabel(Case c) {
  if (!c.isOpen) return '종료';
  if (c.recoveredAt != null) return '종료 대기';
  return switch (c.status) {
    CaseStatus.unacked => '미확인',
    CaseStatus.acked => '확인됨',
    CaseStatus.active => '대응 중',
    CaseStatus.waitingRemeasure => '재측정 대기',
    CaseStatus.closed => '종료',
  };
}

String staffName(InMemoryRepository repo, String id) {
  if (id == 'system') return '자동';
  try {
    return repo.staff(id).displayName;
  } catch (_) {
    return id;
  }
}

/// 무효가 아닌 이 건의 마지막 측정.
Measurement? latestOfCase(InMemoryRepository repo, String caseId) {
  final list = repo.measurementsOfCase(caseId).where((m) => !m.isVoided).toList();
  return list.isEmpty ? null : list.last;
}

/// 확인한 사람 (취소 안 된 'acked' 기록, 사람마다 처음 것만).
List<CaseEvent> acksOf(InMemoryRepository repo, String caseId) {
  final seen = <String>{};
  return [
    for (final e in repo.eventsOf(caseId))
      if (e.type == 'acked' && e.voidedBy == null && seen.add(e.actorId)) e
  ];
}

const closeReasons = ['평소 체온으로 회복', '병원 진료 후 귀원', '입원', '잘못 잰 값 (오측정)', '기타'];
const misMeasureReason = '잘못 잰 값 (오측정)';

/// 사람이 적은 기록만 취소할 수 있다 (이상 대응 B-S3-13 보충).
const voidableTypes = {'note', 'medication', 'director_order', 'hospital_result'};

/// 이상 대응 명세 3장 권한표 + 팀장 결정(사무국은 앱에서 보기만).
class CasePerms {
  CasePerms(this.repo, this.me, this.c, this.now);
  final InMemoryRepository repo;
  final String me;
  final Case c;
  final DateTime now;

  Role get role => repo.staff(me).role;
  bool get isOffice => role == Role.office || role == Role.admin;
  bool get isNurse => role == Role.nurse;
  bool get isDirector => role == Role.director;
  bool get isMedical => isNurse || isDirector;

  /// 당직 = 야간 근무조에 배정된 선생님 (통합 명세 6-2-4). 시연 역할 '당직'도 포함.
  bool get isNightDuty => me == nightDutyStaffId || repo.shiftAt(now, staffId: me)?.type == ShiftType.night;
  bool get isAssignee => c.assigneeId == me;

  /// 버튼을 하나도 안 보이는 경우: 사무국, 종료된 건.
  bool get readOnly => isOffice || !c.isOpen;

  bool get hasAcked => repo.eventsOf(c.id).any((e) => e.type == 'acked' && e.actorId == me && e.voidedBy == null);

  String? get remeasureDenied => measurableClasses(me).contains(c.classId) ? null : '이 반 체온 입력 권한이 없어요';
  String? get medicationDenied => isMedical ? null : '간호사·원장님만 투약을 기록할 수 있어요';

  bool get canRaise => c.stage < 4 && (isAssignee || isMedical || isNightDuty);
  String? get raiseDenied => canRaise ? null : '담당자·간호사·원장님이 단계를 올려요';

  /// 단계별 기록 권한 (S5 표 + 3장).
  String? stageDenied(int stage) => switch (stage) {
        2 => isMedical ? null : '원내 조제는 간호사·원장님만 기록할 수 있어요',
        3 => isMedical ? null : '원장 처방 요청은 간호사·원장님만 할 수 있어요',
        _ => null,
      };

  String stageAction(int stage) => switch (stage) {
        2 => '② 원내 조제로',
        3 => isDirector ? '③ 원장 처방으로' : '③ 원장 처방 요청',
        _ => '④ 병원으로 이동',
      };

  bool get fullClose => isAssignee || isMedical || isNightDuty;
  bool get recordedFirst {
    try {
      return repo.measurement(c.firstMeasurementId).recordedBy == me;
    } catch (_) {
      return false;
    }
  }

  String? get closeDenied => (fullClose || recordedFirst) ? null : '담당자·간호사·원장님이 종료할 수 있어요';
  List<String> get allowedCloseReasons => fullClose ? closeReasons : const [misMeasureReason];

  bool canVoid(CaseEvent e) =>
      !isOffice && e.voidedBy == null && voidableTypes.contains(e.type) && (e.actorId == me || isDirector);
}

/// 타임라인 한 줄 문구 (이상 대응 8장 표시 문구).
String eventText(InMemoryRepository repo, CaseEvent e) {
  final d = e.data;
  final who = staffName(repo, e.actorId);
  String text(String k) => (d[k] ?? '').toString();
  switch (e.type) {
    case 'created':
      try {
        final m = repo.measurement(d['measurementId'] as String);
        return '🌡 처음 잰 체온 ${formatTemp(m.value)}℃ · ${m.judgment.stage.symbol} ${m.judgment.stage.label}';
      } catch (_) {
        return '🌡 이상 건 시작';
      }
    case 'remeasured':
      final v = d['value'] as int?;
      final st = Stage.values.where((s) => s.name == d['stage']).firstOrNull;
      return '🌡 재측정 ${v == null ? '' : '${formatTemp(v)}℃'}${st == null ? '' : ' · ${st.symbol} ${st.label}'}';
    case 'escalated':
      return '⚠ 위험이 나와 긴급으로 바뀌었어요 · 원장님께 알림';
    case 'recovered':
      final v = d['value'] as int?;
      return '✓ ${v == null ? '' : '${formatTemp(v)}℃ · '}평소 체온으로 돌아왔어요';
    case 'acked':
      return '👀 ${withSubject(who)} 확인했어요';
    case 'assigned':
      return '🙋 ${withSubject(who)} 맡았어요';
    case 'stage':
      final s = d['stage'] as int? ?? 1;
      final note = d['note'] as String?;
      return '↗ 대응 단계 ${circledStage[(s - 1).clamp(0, 3)]} ${InMemoryRepository.stageLabel(s)}'
          '${note == null || note.isEmpty ? '' : ' · $note'}';
    case 'remeasure_scheduled':
      final min = d['minutes'] as int? ?? 30;
      return '⏱ ${hm(e.at.add(Duration(minutes: min)))}에 다시 재기로 했어요 ($min분 뒤)';
    case 'note':
      return '📝 ${text('text')}';
    case 'medication':
      return '💊 투약 기록 · ${text('text')}';
    case 'director_order':
      return '🩺 원장님 지시 · ${text('text')}';
    case 'hospital_result':
      return '🏥 병원 · ${text('text')}';
    case 'closed':
      return '✅ 대응 종료 · ${text('reason')}';
    case 'measurement_voided':
      return '↩ 잘못 잰 값으로 표시했어요';
    default:
      return e.type;
  }
}

/// 타임라인에서 "누가" 줄에 쓸 이름. 처음 입력은 '자동'이 아니라 잰 선생님.
String eventActor(InMemoryRepository repo, CaseEvent e) {
  if (e.type == 'created') {
    try {
      return staffName(repo, repo.measurement(e.data['measurementId'] as String).recordedBy);
    } catch (_) {}
  }
  return staffName(repo, e.actorId);
}

/// 색만으로 구분하지 않도록 글자·기호가 들어간 표 (5-7). 크기는 StatusPill과 같다.
class LabelChip extends StatelessWidget {
  const LabelChip(this.text, {super.key, required this.color, this.filled = false});
  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(text,
            style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: filled ? Colors.white : color)),
      );
}

/// 큰 "⚠ 긴급" / "▲ 이상 대응" 알약 (색 채움 + 흰 글자).
class CaseBadge extends StatelessWidget {
  const CaseBadge(this.c, {super.key});
  final Case c;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: caseColors(c).ink, borderRadius: BorderRadius.circular(Radii.pill)),
        child: Text(caseBadge(c),
            style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
      );
}

/// 아이콘 + 한 줄 (알린 사람, 확인한 사람 같은 안내).
class IconLine extends StatelessWidget {
  const IconLine({super.key, required this.icon, required this.text, this.strong = false, this.color});
  final IconData icon;
  final String text;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 22, color: color ?? inkSub)),
        const SizedBox(width: Gap.s),
        Expanded(
          child: Text(text,
              style: TextStyle(
                fontSize: strong ? T.body : T.caption,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: color ?? inkMain,
              )),
        ),
      ]);
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
}
