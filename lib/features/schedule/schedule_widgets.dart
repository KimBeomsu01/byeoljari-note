// 일정 화면(SC-1·SC-2)이 함께 쓰는 작은 조각들.
// 일정은 판정하지 않는다. 측정에 저장된 판정(judgment)과 이상 건 진행 여부를 읽어서 보여주기만 한다 (통합 명세 6-5).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
bool isWeekend(DateTime d) => d.weekday >= DateTime.saturday;

/// '10월 28일 (수)'
String dateLabel(DateTime d) => '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';

/// '09:05'
String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 판정 '빨강'(지금 일정, 긴급)에 쓰는 색.
Color get nowRed => stageColors[Stage.danger]!.ink;

/// 일정 종류 색 (판정 색과 겹치지 않게 차분한 색). 색만으로 구분하지 않도록 늘 글자와 함께 쓴다.
const kindColors = <ScheduleKind, (Color bg, Color fg)>{
  ScheduleKind.meal: (Color(0xFFF1E9D8), Color(0xFF6B5524)),
  ScheduleKind.school: (Color(0xFFE3E7F5), Color(0xFF3B4A80)),
  ScheduleKind.therapy: (Color(0xFFE6F0EE), Color(0xFF2F6259)),
  ScheduleKind.art: (Color(0xFFF2E6F0), Color(0xFF74416A)),
  ScheduleKind.bath: (Color(0xFFE2EEF6), Color(0xFF2E5C7A)),
  ScheduleKind.living: (Color(0xFFECEDE8), Color(0xFF4F5650)),
};

class KindTag extends StatelessWidget {
  const KindTag(this.kind, {super.key});
  final ScheduleKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = kindColors[kind]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(kind.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// 그날 측정 시점 중 오전 / 오후 하나씩.
(SlotStatus?, SlotStatus?) amPm(List<SlotStatus> slots) {
  SlotStatus? am;
  SlotStatus? pm;
  for (final s in slots) {
    if (s.slot.isMorning) {
      am ??= s;
    } else {
      pm ??= s;
    }
  }
  return (am, pm);
}

/// 카드·하루 일정 머리의 '오전' / '오후' 칸. 기호 + 글자 + 색을 함께 쓴다 (5-4, 5-7).
class SlotCell extends StatelessWidget {
  const SlotCell({super.key, required this.label, required this.status});
  final String label; // '오전' | '오후'
  final SlotStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final m = s?.measurement;
    late final String main;
    late final String sub;
    late final Color bg;
    late final Color fg;
    late final String spoken;
    if (s == null) {
      main = '없음';
      sub = '측정 시점 없음';
      bg = const Color(0xFFF0F0EC);
      fg = inkSub;
      spoken = '$label 체온 측정 시점 없음';
    } else if (s.state == SlotState.recorded && m != null) {
      final st = m.judgment.stage;
      final c = stageColors[st]!;
      main = '${st.symbol} ${formatTemp(m.value)}°';
      sub = st.label;
      bg = c.soft;
      fg = c.ink;
      spoken = '$label 체온 ${formatTemp(m.value)}도 ${st.label}';
    } else if (s.state == SlotState.missed) {
      main = '미기록';
      sub = '측정 전';
      bg = const Color(0xFFEDEDEA);
      fg = const Color(0xFF55595A);
      spoken = '$label 체온 미기록, 측정 전';
    } else {
      main = '예정';
      sub = hm(s.at);
      bg = Colors.white;
      fg = inkSub;
      spoken = '$label 체온 예정 ${hm(s.at)}';
    }
    final missed = s?.state == SlotState.missed;
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: missed ? const DashedBorderPainter(color: Color(0xFF9A9E9B), radius: 8) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: missed ? null : Border.all(color: const Color(0xFFE2E2DC)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: inkSub)),
            Text(main,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// 회색 점선 테두리 (미기록).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.color, this.radius = 12, this.width = 1.5});
  final Color color;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final rect = Offset(width / 2, width / 2) & Size(size.width - width, size.height - width);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color || old.radius != radius || old.width != width;
}

/// 시연 시계가 흐르므로 1분마다 다시 그린다 ('지금' 일정, 미기록 바뀜).
mixin MinuteTicker<T extends StatefulWidget> on State<T> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
