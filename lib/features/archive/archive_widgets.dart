// 아카이브·별님카드가 같이 쓰는 작은 표시 조각 (docs/design.md).
import 'dart:ui' show PathMetric;

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

// ── 시제품(모바일 아카이브) 모양 조각

/// 시제품 아카이브 색 (반 공지 글자·점, 기록 찾기 테두리 등).
const noticeInk = Color(0xFF5F4F80);
const noticeDot = Color(0xFFA89AC2);
const segTrack = Color(0xFFFBE7E2);
const softGrey = Color(0xFFFFF3F0);
const unreadLine = Color(0xFFE7C27A);
const okInk = Color(0xFF3F6C53);
const okSoft = Color(0xFFE9F3ED);
const okLine = Color(0xFFCFE3D6);
const obsDot = Color(0xFF87A98E);

/// 화면 위 제목: 작은 '별자리노트' + ✦ 큰 제목 (app.dart 머리글과 같은 모양).
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('별자리노트', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('✦ ', style: TextStyle(fontSize: T.title, color: stageColors[Stage.danger]!.line)),
            Semantics(header: true, child: Text(title)),
          ]),
        ]),
      );
}

/// 시제품 머리글 AppBar (뒤로 화살표 대신 아래 [BackLink]를 쓴다).
PreferredSizeWidget prototypeAppBar(String title) => AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: Gap.page,
      toolbarHeight: 72,
      title: ScreenTitle(title),
    );

/// "‹ 은하수자리 별님 목록" 같은 뒤로 가기 글자 버튼.
class BackLink extends StatelessWidget {
  const BackLink(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: '뒤로: $label',
          button: true,
          excludeSemantics: true,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(tapHeight, tapHeight),
              padding: const EdgeInsets.only(left: 2, right: 12),
              foregroundColor: inkMain,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('‹', style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w700, height: 1)),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      );
}

/// 시제품의 작은 종류 표시 ("체온", "관찰", "반 공지"): 모서리가 살짝 둥근 글자 상자.
class KindTag extends StatelessWidget {
  const KindTag(this.text, {super.key, required this.ink, required this.background, this.border});
  final String text;
  final Color ink;
  final Color background;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Text(text, style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: ink)),
      );
}

/// 점선 둥근 테두리 (반 공지 카드).
class DashedRRectPainter extends CustomPainter {
  const DashedRRectPainter({required this.color, this.radius = 12, this.width = 1.5, this.dash = 6, this.gap = 4});
  final Color color;
  final double radius, width, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    for (final PathMetric m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, (d + dash).clamp(0, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) => old.color != color || old.radius != radius || old.width != width;
}

/// 회색 둥근 상자 (기록 상세의 머리 상자, 출처 줄).
class GreyBox extends StatelessWidget {
  const GreyBox({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: softGrey, borderRadius: BorderRadius.circular(10)),
        child: child,
      );
}

/// 시트 제목 줄: 제목 + 회색 동그라미 [닫기] (시제품 .sh-top).
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: const TextStyle(fontSize: T.headline - 2, fontWeight: FontWeight.w800, color: inkMain)),
          ),
        ),
        IconButton(
          tooltip: '닫기',
          constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFFDF0EC), foregroundColor: inkSub),
          icon: const Icon(Icons.close, size: 24),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ]);
}
