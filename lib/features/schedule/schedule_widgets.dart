// 일정 화면(SC-1·SC-2)이 함께 쓰는 작은 조각들.
// 일정은 판정하지 않는다. 측정에 저장된 판정(judgment)과 이상 건 진행 여부를 읽어서 보여주기만 한다 (통합 명세 6-5).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../quick_temp/quick_temp_controller.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
bool isWeekend(DateTime d) => d.weekday >= DateTime.saturday;

/// '10월 28일 (수)'
String dateLabel(DateTime d) => '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';

/// '오늘 10월 28일 수요일' / '10월 31일 토요일'.
String longDateLabel(DateTime d, {bool today = false}) =>
    '${today ? '오늘 ' : ''}${d.month}월 ${d.day}일 ${_weekdays[d.weekday - 1]}요일';

/// 연한 반 색 (오늘 날짜): 흰 바탕 위에 반 색 [alpha].
Color classTint(int color, [double alpha = 0.2]) => Color.alphaBlend(Color(color).withValues(alpha: alpha), surface);

/// '09:05'
String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 지금 일정·긴급에 쓰는 빨강.
Color get nowRed => stageColors[Stage.danger]!.ink;

/// '오후 체온 · 목욕 전' → '오후 체온'.
String slotShortName(TempSlot s) => s.label.split(' · ').first;

/// 목록 오른쪽 칩이 보여줄 측정 시점: 이미 시작된 것 중 가장 늦은 것, 없으면 첫 것.
SlotStatus? currentSlot(List<SlotStatus> slots, DateTime now) {
  if (slots.isEmpty) return null;
  SlotStatus? pick;
  for (final s in slots) {
    if (!s.at.isAfter(now)) pick = s;
  }
  return pick ?? slots.first;
}

/// 체온 재기: 측정 권한이 있는 반이면 그 별님이 선택된 퀵 체온을 연다. 없으면 안내만.
/// [popToFirst] 하루 일정처럼 위에 쌓인 화면에서 열 때는 먼저 첫 화면으로 돌아간다 (퀵 체온은 앱 공통 틀 위의 레이어).
void openQuickTempFor(BuildContext context, WidgetRef ref, Resident r, {bool popToFirst = false}) {
  final me = ref.read(currentUserProvider);
  if (!measurableClasses(me).contains(r.classId)) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 반은 체온 측정 권한이 없어요')));
    return;
  }
  if (popToFirst) Navigator.of(context).popUntil((route) => route.isFirst);
  ref.read(quickTempProvider.notifier).openFor(r.id);
}

/// 시안의 오른쪽 상태 칩: '✓ 36.4' / '! 37.6 주의' / 점선 '아직 안 잼' / '▲ 이상 대응 중' / '⚠ 긴급' / '13:00 예정'.
/// 기호 + 글자 + 색을 함께 쓴다 (5-4). [openCase]가 있으면 체온보다 먼저 보여준다.
class TempChip extends StatelessWidget {
  const TempChip({super.key, required this.slot, this.openCase, this.slotName});
  final SlotStatus? slot;
  final Case? openCase;

  /// 읽어 주는 말 앞머리 ('오전 체온'). 없으면 시점 이름.
  final String? slotName;

  static const _dashed = Color(0xFFB39A8F);

  @override
  Widget build(BuildContext context) {
    final s = slot;
    final m = s?.measurement;
    final name = slotName ?? (s == null ? '체온' : slotShortName(s.slot));
    String text;
    String spoken;
    Color fg = inkSub;
    Color? bg;
    Color? border;
    var dashed = false;
    final c = openCase;
    if (c != null) {
      final sc = stageColors[c.isUrgent ? Stage.danger : Stage.abnormal]!;
      text = c.isUrgent ? '⚠ 긴급' : '▲ 이상 대응 중';
      spoken = c.isUrgent ? '긴급' : '이상 대응 중';
      fg = sc.ink;
      bg = sc.soft;
    } else if (s == null) {
      return const SizedBox.shrink();
    } else if (s.state == SlotState.recorded && m != null) {
      final st = m.judgment.stage;
      final sc = stageColors[st]!;
      text = st == Stage.normal
          ? '${st.symbol} ${formatTemp(m.value)}'
          : '${st.symbol} ${formatTemp(m.value)} ${st.label}';
      spoken = '$name ${formatTemp(m.value)}도 ${st.label}';
      fg = sc.ink;
      bg = sc.soft;
    } else if (s.state == SlotState.missed) {
      text = '아직 안 잼';
      spoken = '$name 아직 안 쟀어요';
      dashed = true;
    } else {
      text = '${hm(s.at)} 예정';
      spoken = '$name ${hm(s.at)} 예정';
      border = lineStrong;
    }
    final label = Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: fg,
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final chip = dashed
        ? CustomPaint(
            foregroundPainter: const DashedBorderPainter(color: _dashed, radius: 999, width: 1.5),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: label),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: border == null ? null : Border.all(color: border, width: 1.5),
            ),
            child: label,
          );
    return Semantics(label: spoken, excludeSemantics: true, child: chip);
  }
}

/// 점선 테두리 (아직 안 잼).
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
    final r = radius.clamp(0.0, rect.shortestSide / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 7;
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
