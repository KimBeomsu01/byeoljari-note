// 아카이브·별님카드가 같이 쓰는 작은 표시 조각 (docs/design.md).
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

export '../../core/ui.dart' show hhmm, plainDiff;

/// "2026년 10월 28일 09:41"
String ymdHm(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일 ${hhmm(d)}';

/// 기록 당시 작성자 표시: "박지은 선생님 · 당시 담임".
String authorAsOf(InMemoryRepository repo, String staffId, String? classId, DateTime at) {
  if (staffId == 'system') return '자동 기록';
  final Staff s;
  try {
    s = repo.staff(staffId);
  } catch (_) {
    return staffId;
  }
  if (classId != null) {
    for (final h in repo.homeroomHistoryOf(classId)) {
      final inRange = !at.isBefore(h.from) && (h.to == null || at.isBefore(h.to!));
      if (inRange && h.staffId == staffId) return '${s.displayName} · 당시 담임';
    }
  }
  return s.displayName;
}

/// 판정 표시. 예전 이름을 남겨 두고 공통 [StageTag]를 쓴다.
class StageBadge extends StatelessWidget {
  const StageBadge(this.stage, {super.key, this.dense = false});
  final Stage stage;
  final bool dense;

  @override
  Widget build(BuildContext context) => StageTag(stage, large: !dense);
}

/// 이름 아바타. 예전 이름을 남겨 두고 공통 [ResidentAvatar]를 쓴다.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, required this.color, this.radius = 24});
  final String name;
  final int color;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: ResidentAvatar(name: name, classColor: color, size: radius * 2));
}

/// "새 기록" 표시: 노란 점 + 글자 (색만으로 알리지 않는다).
class NewRecordMark extends StatelessWidget {
  const NewRecordMark({super.key, this.text = '새 기록', this.size = T.caption});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: starYellow, shape: BoxShape.circle, border: Border.all(color: inkMain, width: 1.5)),
        ),
        const SizedBox(width: Gap.s),
        Flexible(child: Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: inkMain))),
      ]);
}

/// 사진 자리 표시 (시연은 실제 사진 없음).
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: Gap.s),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: paper,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_outlined, size: 22, color: inkSub),
          const SizedBox(width: Gap.s),
          Text('사진 $count장', style: const TextStyle(fontSize: T.caption, color: inkSub, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// 할 일 한 줄: "○ 할 일 남음: 재측정" / "✓ 할 일 끝: 재측정".
String taskLine(Task task) => task.done ? '✓ 할 일 끝: ${task.label}' : '○ 할 일 남음: ${task.label}';

/// 할 일 표시 (기호 + 글자 + 색).
class TaskLine extends StatelessWidget {
  const TaskLine(this.task, {super.key, this.extra});
  final Task task;

  /// 둘째 줄 보조 글자 (예: "김하늘 선생님이 09:50에 했어요").
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final c = (task.done ? stageColors[Stage.normal] : stageColors[Stage.caution])!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Gap.s),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.soft,
        border: Border.all(color: c.line, width: 1.5),
        borderRadius: BorderRadius.circular(Radii.button),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(taskLine(task), style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: c.ink)),
        if (extra != null) Text(extra!, style: TextStyle(fontSize: T.caption, color: c.ink)),
      ]),
    );
  }
}

/// "잘못 잰 값" 표시 (취소선 숫자 옆).
class VoidTag extends StatelessWidget {
  const VoidTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: inkSub, width: 1.5),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: const Text('잘못 잰 값', style: TextStyle(color: inkSub, fontWeight: FontWeight.w800, fontSize: T.caption)),
      );
}

/// 아카이브 목록·상세 공통 "잘못 잰 값" 표시.
const voidLabel = VoidTag();
