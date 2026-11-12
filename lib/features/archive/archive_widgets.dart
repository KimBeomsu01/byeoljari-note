// 아카이브·별님카드가 같이 쓰는 작은 표시 조각.
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';

String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String ymdHm(DateTime d) => '${d.year}.${d.month}.${d.day} ${hhmm(d)}';

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

/// 판정 표시: 기호 + 글자 + 색 (색만으로 구분하지 않음, 5-4·5-7).
class StageBadge extends StatelessWidget {
  const StageBadge(this.stage, {super.key, this.dense = false});
  final Stage stage;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = stageColors[stage]!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(color: c.soft, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(20)),
      child: Text('${stage.symbol} ${stage.label}',
          style: TextStyle(color: c.ink, fontWeight: FontWeight.w700, fontSize: dense ? 12 : 13)),
    );
  }
}

/// 이름 첫 글자 아바타 (실제 사진 대신).
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, required this.color, this.radius = 24});
  final String name;
  final int color;
  final double radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CircleAvatar(
          radius: radius,
          backgroundColor: Color(color),
          child: Text(name.characters.first,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
        ),
      );
}

/// 반 공지용 점선 테두리.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color;
}

/// 사진 자리 표시 (시연은 실제 사진 없음).
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFECEAE2), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_outlined, size: 18, color: inkSub),
          const SizedBox(width: 6),
          Text('사진 $count장', style: const TextStyle(fontSize: 13, color: inkSub)),
        ]),
      );
}
