// PF 최근 14일 체온 그래프. 글자는 15 이상 (docs/design.md). 평소 체온(기저치) 선 + 판정 색 점, 평소가 아닌 점에는 기호를 같이 그린다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

class TempChart extends StatelessWidget {
  const TempChart({super.key, required this.points, required this.baseline, required this.from, required this.to});

  /// 무효가 아닌 측정 (오래된 순).
  final List<Measurement> points;
  final int baseline;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('최근 2주 동안 잰 체온이 없어요', style: TextStyle(fontSize: T.body, color: inkSub))),
      );
    }
    final values = points.map((m) => m.value);
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final off = points.where((m) => m.judgment.stage != Stage.normal).length;
    final label = '최근 14일 체온 그래프. 기록 ${points.length}건, 가장 낮은 ${formatTemp(lo)}도, '
        '가장 높은 ${formatTemp(hi)}도, 평소 체온 ${formatTemp(baseline)}도. 평소가 아닌 기록 $off건.';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: CustomPaint(painter: _TempChartPainter(points, baseline, from, to, Theme.of(context).textTheme.bodyMedium?.fontFamily)),
        ),
      ),
    );
  }
}

class _TempChartPainter extends CustomPainter {
  _TempChartPainter(this.points, this.baseline, this.from, this.to, this.fontFamily);
  final String? fontFamily;
  final List<Measurement> points;
  final int baseline;
  final DateTime from;
  final DateTime to;

  static const _left = 46.0;
  static const _top = 34.0;
  static const _bottom = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [...points.map((m) => m.value), baseline];
    var lo = values.reduce(math.min) - 3;
    var hi = values.reduce(math.max) + 3;
    if (hi - lo < 10) {
      final mid = (hi + lo) / 2;
      lo = (mid - 5).floor();
      hi = (mid + 5).ceil();
    }
    final w = size.width - _left - 6;
    final h = size.height - _top - _bottom;
    final span = to.difference(from).inMinutes.clamp(1, 1 << 31);
    double x(DateTime t) => _left + w * (t.difference(from).inMinutes / span).clamp(0.0, 1.0);
    double y(int v) => _top + h * (1 - (v - lo) / (hi - lo));

    void text(String s, Offset at, {Color color = inkSub, double size = T.caption, bool center = false, FontWeight? weight}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: weight, fontFamily: fontFamily)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
    }

    // 축
    final axis = Paint()
      ..color = line
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(_left, _top + h), Offset(_left + w, _top + h), axis);
    text(formatTemp(hi), const Offset(0, _top - 10));
    text(formatTemp(lo), Offset(0, _top + h - 10));
    text('${from.month}/${from.day}', Offset(_left, _top + h + 6));
    final toLabel = TextPainter(
      text: TextSpan(text: '${to.month}/${to.day}', style: TextStyle(fontSize: T.caption, fontFamily: fontFamily)),
      textDirection: TextDirection.ltr,
    )..layout();
    text('${to.month}/${to.day}', Offset(_left + w - toLabel.width, _top + h + 6));

    // 평소 체온 점선
    final base = Paint()
      ..color = stageColors[Stage.normal]!.ink
      ..strokeWidth = 2;
    final by = y(baseline);
    for (var d = _left; d < _left + w; d += 8) {
      canvas.drawLine(Offset(d, by), Offset(math.min(d + 4, _left + w), by), base);
    }
    // 범례: 오른쪽 위에 "┄ 평소 37.1" (점과 겹치지 않게)
    final legend = TextPainter(
      text: TextSpan(
          text: '평소 ${formatTemp(baseline)}',
          style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: stageColors[Stage.normal]!.ink, fontFamily: fontFamily)),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = size.width - 6 - legend.width;
    legend.paint(canvas, Offset(lx, 0));
    for (var d = lx - 26.0; d < lx - 6; d += 8) {
      canvas.drawLine(Offset(d, legend.height / 2), Offset(d + 4, legend.height / 2), base);
    }

    // 선
    final trend = Paint()
      ..color = const Color(0xFF87A98E) // 시제품 세이지 초록
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].measuredAt), y(points[i].value));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, trend);

    // 점 (판정 색) + 평소가 아니면 기호
    for (final m in points) {
      final c = stageColors[m.judgment.stage]!;
      final o = Offset(x(m.measuredAt), y(m.value));
      canvas.drawCircle(o, 6, Paint()..color = c.line);
      canvas.drawCircle(
          o,
          6,
          Paint()
            ..color = c.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      if (m.judgment.stage != Stage.normal) {
        text(m.judgment.stage.symbol, o - const Offset(0, 16), color: c.ink, size: T.caption, center: true, weight: FontWeight.w800);
      }
    }
  }

  @override
  bool shouldRepaint(_TempChartPainter old) =>
      old.points != points || old.baseline != baseline || old.from != from || old.to != to;
}
