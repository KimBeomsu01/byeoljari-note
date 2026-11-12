// 일정 화면(SC-1·SC-2)이 함께 쓰는 작은 조각들.
// 일정은 판정하지 않는다. 측정에 저장된 판정(judgment)과 이상 건 진행 여부를 읽어서 보여주기만 한다 (통합 명세 6-5).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
bool isWeekend(DateTime d) => d.weekday >= DateTime.saturday;

/// '10월 28일 (수)'
String dateLabel(DateTime d) => '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';

/// 시제품 날짜 막대: '오늘 · 10월 28일 수요일' / '10월 31일 토요일'.
String longDateLabel(DateTime d, {bool today = false}) =>
    '${today ? '오늘 · ' : ''}${d.month}월 ${d.day}일 ${_weekdays[d.weekday - 1]}요일';

/// 시제품의 작은 표 알약 모서리 (둥근 네모).
const double tagRadius = 7;

/// 연한 반 색 (선택된 반 칩, 오늘 날짜): 흰 바탕 위에 반 색 [alpha].
Color classTint(int color, [double alpha = 0.2]) => Color.alphaBlend(Color(color).withValues(alpha: alpha), surface);

/// 시제품 카드의 체온 알약: '오전 ✓ 36.5° 평소' / '오후 예정' / '오전 미기록'.
/// 기호 + 글자 + 색을 함께 쓴다 (5-4). [label]은 '오전' · '오후' · '오전 체온' 등.
class SlotPill extends StatelessWidget {
  const SlotPill({super.key, required this.label, required this.status});
  final String label;
  final SlotStatus? status;

  static const _missed = (Color(0xFF6B5446), Color(0xFFFCEEEA), Color(0xFFB7C1CC));
  static const _later = (Color(0xFF6B5446), Color(0xFFFCEEEA), line);

  @override
  Widget build(BuildContext context) {
    final s = status;
    final m = s?.measurement;
    final String text;
    final String spoken;
    final (Color, Color, Color) c;
    if (s == null) {
      text = '$label 없음';
      spoken = '$label 재는 때 없음';
      c = _later;
    } else if (s.state == SlotState.recorded && m != null) {
      final st = m.judgment.stage;
      final sc = stageColors[st]!;
      text = '$label ${st.symbol} ${formatTemp(m.value)}° ${st.label}';
      spoken = '$label ${formatTemp(m.value)}도 ${st.label}';
      c = (sc.ink, sc.soft, sc.line);
    } else if (s.state == SlotState.missed) {
      text = '$label 미기록';
      spoken = '$label 미기록, 아직 안 쟀어요';
      c = _missed;
    } else {
      text = '$label 예정';
      spoken = '$label 예정 ${hm(s.at)}';
      c = _later;
    }
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.$2,
          borderRadius: BorderRadius.circular(tagRadius),
          border: Border.all(color: c.$3),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: T.caption, fontWeight: FontWeight.w700, color: c.$1, height: 1.3, fontFeatures: const [FontFeature.tabularFigures()])),
      ),
    );
  }
}

/// '09:05'
String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 판정 '빨강'(지금 일정, 긴급)에 쓰는 색.
Color get nowRed => stageColors[Stage.danger]!.ink;

/// 일정 종류 색 (판정 색과 겹치지 않게 차분한 색). 색만으로 구분하지 않도록 늘 글자와 함께 쓴다.
const kindColors = <ScheduleKind, (Color bg, Color fg)>{
  ScheduleKind.meal: (Color(0xFFFCEFE0), Color(0xFF6B5524)),
  ScheduleKind.school: (Color(0xFFE3E7F5), Color(0xFF3B4A80)),
  ScheduleKind.therapy: (Color(0xFFE6F2DE), Color(0xFF2F6259)),
  ScheduleKind.art: (Color(0xFFF2E6F0), Color(0xFF74416A)),
  ScheduleKind.bath: (Color(0xFFE2EEF6), Color(0xFF2E5C7A)),
  ScheduleKind.living: (Color(0xFFFAE6E1), Color(0xFF4F5650)),
};

class KindTag extends StatelessWidget {
  const KindTag(this.kind, {super.key});
  final ScheduleKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = kindColors[kind]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(tagRadius)),
      child: Text(kind.label, style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: fg, height: 1.35)),
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
/// 한 줄에 한 가지: ① 오전/오후 ② 체온(크게) 또는 상태 ③ 판정 표시 또는 설명.
class SlotCell extends StatelessWidget {
  const SlotCell({super.key, required this.label, required this.status});
  final String label; // '오전' | '오후'
  final SlotStatus? status;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final s = status;
    final m = s?.measurement;
    final missed = s?.state == SlotState.missed;
    late final Widget main;
    Widget? sub;
    Color bg = surface;
    Color border = line;
    late final String spoken;
    if (s == null) {
      main = const Text('없음', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkSub));
      sub = const Text('재는 때가 없어요', style: TextStyle(fontSize: T.caption, color: inkSub));
      bg = paper;
      spoken = '$label 체온 재는 때 없음';
    } else if (s.state == SlotState.recorded && m != null) {
      final st = m.judgment.stage;
      final c = stageColors[st]!;
      main = Text('${formatTemp(m.value)}℃',
          style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: c.ink, fontFeatures: _tabular));
      sub = StageTag(st);
      bg = c.soft;
      border = c.line;
      spoken = '$label 체온 ${formatTemp(m.value)}도 ${st.label}';
    } else if (missed) {
      main = const Text('미기록', style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain));
      sub = const Text('아직 안 쟀어요', style: TextStyle(fontSize: T.caption, color: inkSub));
      spoken = '$label 체온 미기록, 아직 안 쟀어요';
    } else {
      main = Text('예정 ${hm(s.at)}',
          style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain, fontFeatures: _tabular));
      spoken = '$label 체온 예정 ${hm(s.at)}';
    }
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: missed ? const DashedBorderPainter(color: inkSub, radius: Radii.button, width: 2) : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Radii.button),
            border: missed ? null : Border.all(color: border, width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
            const SizedBox(height: 2),
            main,
            if (sub != null) ...[const SizedBox(height: 4), sub],
          ]),
        ),
      ),
    );
  }
}

/// 점선 테두리 (미기록).
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
