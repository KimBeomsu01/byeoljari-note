// PC 01 현황판: 별님 한 명의 지금 상태를 저장소 자료로 계산한다 (표 · 요약 카드 · 생활관 칩이 같이 쓴다).
// 판정은 저장된 측정 판정(judgment)과 열린 이상 건을 그대로 쓴다. 여기서 새로 판정하지 않는다.
import 'package:flutter/material.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_dashboard_ui.dart';

/// 표의 줄 색 · 상태 판정 꼬리표 종류.
enum RowTone { danger, abnormal, low, caution, school, normal, none }

class ResidentStatus {
  ResidentStatus({
    required this.resident,
    required this.cls,
    required this.homeroom,
    required this.latest,
    required this.baseline,
    required this.openCase,
    required this.openCall,
    required this.activity,
    required this.lastEntry,
    required this.openTask,
  });
  final Resident resident;
  final Class cls;
  final Staff homeroom;
  final Measurement? latest;
  final int baseline;
  final Case? openCase;
  final MedicalCall? openCall;
  final ScheduleItem? activity;
  final Entry? lastEntry;

  /// 열린 체온 할 일 (주의로 자동 생긴 재측정 등).
  final Entry? openTask;

  Stage? get stage => latest?.judgment.stage;

  /// 지금 학교 일과 중 (통학).
  bool get atSchool => activity?.kind == ScheduleKind.school;

  /// 열린 이상 건이 있으면 그 심각도, 없으면 최근 측정 판정.
  Stage? get alertStage => openCase?.severity ?? stage;

  RowTone get tone => switch (alertStage) {
    Stage.danger => RowTone.danger,
    Stage.abnormal => RowTone.abnormal,
    Stage.low => RowTone.low,
    Stage.caution => RowTone.caution,
    _ when atSchool => RowTone.school,
    Stage.normal => RowTone.normal,
    null => RowTone.none,
  };

  /// 이상 · 위험 · 저온 (빨강/파랑 줄).
  bool get isAlert => tone == RowTone.danger || tone == RowTone.abnormal || tone == RowTone.low;
  bool get isCaution => tone == RowTone.caution;

  /// 위로 올리는 순서 (클수록 위).
  int get rank => openCase != null ? 10 + openCase!.severity.rank : (stage?.rank ?? -1);
}

/// 모든 별님 상태. 이상 있는 별님이 위, 그다음 반 순서 · 별님 순서.
List<ResidentStatus> buildStatuses(InMemoryRepository repo, DateTime now) {
  final calls = repo.openCalls;
  final classOrder = {for (final c in repo.classes) c.id: c.order};
  final entries = repo.entries;
  final out = <ResidentStatus>[];
  for (final r in repo.residents) {
    final cls = repo.classOf(r.classId);
    final latest = repo.latestOf(r.id);
    final mine = entries.where((e) => e.residentId == r.id && e.scope == EntryScope.resident).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final tasks = repo.openTempTasksOf(r.id);
    out.add(
      ResidentStatus(
        resident: r,
        cls: cls,
        homeroom: repo.staff(cls.homeroomId),
        latest: latest,
        baseline: latest?.judgment.baseline ?? repo.baselineOf(r.id, now).value,
        openCase: repo.openCaseOf(r.id),
        openCall: calls.where((c) => c.residentId == r.id).firstOrNull,
        activity: repo.currentActivity(r.id, now),
        lastEntry: mine.firstOrNull,
        openTask: tasks.firstOrNull,
      ),
    );
  }
  out.sort((a, b) {
    final r = b.rank.compareTo(a.rank);
    if (r != 0) return r;
    final c = (classOrder[a.cls.id] ?? 0).compareTo(classOrder[b.cls.id] ?? 0);
    if (c != 0) return c;
    return a.resident.order.compareTo(b.resident.order);
  });
  return out;
}

/// 상태 판정 꼬리표 모양 (디자인 4가지 + 이상 · 저온 · 측정 전).
class ToneStyle {
  const ToneStyle(this.label, this.bg, this.fg, this.border, this.icon, {this.weight = FontWeight.w700, this.iconColor});
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final IconData icon;
  final FontWeight weight;
  final Color? iconColor;
}

ToneStyle toneStyle(RowTone t) => switch (t) {
  RowTone.danger => const ToneStyle('긴급 고온', Ds.red500, Colors.white, null, Icons.warning_amber_rounded),
  RowTone.abnormal => const ToneStyle('이상 고온', Ds.red500, Colors.white, null, Icons.warning_amber_rounded),
  RowTone.low => const ToneStyle('저온 주의', Ds.blue50, Ds.blue500, Ds.borderInfo, Icons.ac_unit_rounded),
  RowTone.caution => const ToneStyle('주의 관찰', Tw.amber100, Tw.amber800, Tw.amber200, Icons.error_outline_rounded),
  RowTone.school => const ToneStyle(
    '통학 중',
    Ds.gray100,
    Ds.gray700,
    Ds.gray200,
    Icons.directions_bus_rounded,
    weight: FontWeight.w600,
    iconColor: Ds.gray500,
  ),
  RowTone.normal => const ToneStyle('정상', Tw.emerald100, Tw.emerald800, Tw.emerald200, Icons.done_all_rounded),
  RowTone.none => const ToneStyle(
    '측정 전',
    Ds.gray100,
    Ds.gray600,
    Ds.gray200,
    Icons.schedule_rounded,
    weight: FontWeight.w600,
    iconColor: Ds.gray500,
  ),
};

/// 체온 글자 색 (측정 판정 기준).
Color tempColor(Stage? s) => switch (s) {
  Stage.danger || Stage.abnormal => Ds.red500,
  Stage.low => Ds.blue500,
  Stage.caution => Tw.amber700,
  Stage.normal => Tw.emerald700,
  null => Ds.gray900,
};

/// 체온 아래 한 줄 (기저치 대비).
String tempNote(ResidentStatus s) {
  final m = s.latest;
  if (m == null) return s.atSchool ? '측정 전 (외출)' : '측정 전';
  final diff = m.judgment.diff;
  return switch (m.judgment.stage) {
    Stage.danger || Stage.abnormal => '▲ ${formatDiff(diff)}℃ 기저치 대비',
    Stage.low => '▼ ${formatDiff(diff)}℃ 기저치 대비',
    Stage.caution => '▲ ${formatDiff(diff)}℃ 미열 상태',
    Stage.normal => diff == 0 ? '기저 ${degC(m.judgment.baseline)} 일치' : '기저 ${degC(m.judgment.baseline)} · ${formatDiff(diff)}℃',
  };
}

/// 기록 한 줄 글 (체온 기록은 본문이 없어 값으로 쓴다).
String entryText(InMemoryRepository repo, Entry e) {
  final body = (e.body ?? '').trim();
  if (body.isNotEmpty) return body;
  final title = (e.title ?? '').trim();
  if (title.isNotEmpty) return title;
  if (e.measurementId != null) {
    try {
      return '체온 ${degC(repo.measurement(e.measurementId!).value)} 기록';
    } catch (_) {}
  }
  return e.kindLabel;
}

/// 대응 현황 꼬리표.
class ResponseStyle {
  const ResponseStyle(this.label, this.bg, this.fg, this.border, {this.icon, this.iconColor, this.weight = FontWeight.w500});
  final String label;
  final Color bg;
  final Color fg;
  final Color border;
  final IconData? icon;
  final Color? iconColor;
  final FontWeight weight;
}

ResponseStyle responseStyle(ResidentStatus s) {
  final call = s.openCall;
  if (call != null) {
    return call.level == CallLevel.urgent
        ? const ResponseStyle('의료호출 연결됨', Ds.red50, Ds.red500, Tw.red200, icon: Icons.phone_in_talk_rounded, weight: FontWeight.w700)
        : ResponseStyle(
            '의료호출 ${call.level.label}',
            Ds.blue50,
            Ds.blue500,
            Ds.borderInfo,
            icon: Icons.phone_in_talk_rounded,
            weight: FontWeight.w600,
          );
  }
  final c = s.openCase;
  if (c != null) {
    if (c.status == CaseStatus.waitingRemeasure && c.remeasureAt != null) {
      return ResponseStyle(
        '${hm(c.remeasureAt!)} 재측정 대기',
        Ds.gray100,
        Ds.gray700,
        Ds.gray200,
        icon: Icons.schedule_rounded,
        iconColor: Ds.gray500,
      );
    }
    if (c.status == CaseStatus.unacked) {
      return const ResponseStyle('확인 대기', Tw.amber50, Tw.amber700, Tw.amber200, icon: Icons.hourglass_top_rounded, weight: FontWeight.w600);
    }
    return ResponseStyle(
      '${c.kindLabel} 진행 중',
      Ds.red50,
      Ds.red500,
      Tw.red200,
      icon: Icons.medical_services_outlined,
      weight: FontWeight.w600,
    );
  }
  final task = s.openTask?.task;
  if (task != null) {
    return ResponseStyle(
      task.dueAt == null ? '재측정 대기' : '${hm(task.dueAt!)} 재측정 대기',
      Ds.gray100,
      Ds.gray700,
      Ds.gray200,
      icon: Icons.schedule_rounded,
      iconColor: Ds.gray500,
    );
  }
  if (s.atSchool) {
    return const ResponseStyle('정상 통학', Tw.emerald50, Tw.emerald700, Tw.emerald200, icon: Icons.check_rounded, weight: FontWeight.w600);
  }
  if (s.latest == null) return const ResponseStyle('체온 미기록', Ds.gray100, Ds.gray600, Ds.gray200);
  return const ResponseStyle('안정', Ds.gray100, Ds.gray600, Ds.gray200);
}

/// 별님 소개 한 줄 '남 · 24세 (중증)'.
String residentMeta(Resident r) {
  final parts = [if (r.sex != null) r.sex!, if (r.age != null) '${r.age}세'];
  final base = parts.join(' · ');
  if (!r.severe) return base;
  return base.isEmpty ? '중증' : '$base (중증)';
}

/// 생활관 '고래자리 204호'.
String classRoom(Class c) => c.room == null ? c.name : '${c.name} ${c.room}';
