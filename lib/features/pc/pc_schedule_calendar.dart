// PC 02 통합 일정: 월간 캘린더 · 주간 · 일간 시간표 · 목록형 (Claude Design PcSchedule.dc.html 왼쪽 span 8).
import 'package:flutter/material.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import 'pc_dashboard_ui.dart';

/// 일정 분류 색: (연한 바탕, 글자, 점 · 진한 바탕). 디자인 범례 5색.
(Color, Color, Color) categoryColors(CalendarCategory c) => switch (c) {
  CalendarCategory.facility => (Ds.blue50, Ds.blue500, Ds.blue500),
  CalendarCategory.education => (Tw.greenSoft, Tw.greenInk, Ds.green500),
  CalendarCategory.therapy => (Ds.cyan50, Tw.cyanInk, Ds.cyan500),
  CalendarCategory.care => (Ds.orange50, Ds.orange500, Ds.orange500),
  CalendarCategory.medical => (Ds.red50, Ds.red500, Ds.red500),
};

/// 공휴일 이름 (양력 고정 + 2026년 음력 공휴일).
String? holidayName(DateTime d) {
  const fixed = {
    (1, 1): '신정',
    (3, 1): '삼일절',
    (5, 5): '어린이날',
    (6, 6): '현충일',
    (8, 15): '광복절',
    (10, 3): '개천절',
    (10, 9): '한글날',
    (12, 25): '성탄절',
  };
  const lunar2026 = {(2, 16): '설날', (2, 17): '설날', (2, 18): '설날', (5, 24): '부처님오신날', (9, 24): '추석', (9, 25): '추석', (9, 26): '추석'};
  return fixed[(d.month, d.day)] ?? (d.year == 2026 ? lunar2026[(d.month, d.day)] : null);
}

/// 그날 공휴일 표시 (이름표 또는 holiday 일정).
String? holidayOf(DateTime d, List<CalendarEvent> events) => holidayName(d) ?? (events.any((e) => e.holiday) ? '공휴일' : null);

/// 날짜 숫자 색: 일요일 · 공휴일 빨강, 토요일 파랑.
Color dayNumberColor(DateTime d, String? holiday) {
  if (d.weekday == DateTime.saturday) return Ds.blue500;
  if (d.weekday == DateTime.sunday || holiday != null) return Ds.red500;
  return Ds.gray900;
}

String eventLabel(CalendarEvent e) => e.time == null ? e.title : '${e.time} ${e.title}';

/// 일정 알약 (10px, radius 6). [solid]는 오늘 칸 (진한 바탕 · 흰 글자).
class EventPill extends StatelessWidget {
  const EventPill(this.text, this.category, {super.key, this.solid = false, this.size = 10});
  final String text;
  final CalendarCategory category;
  final bool solid;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (soft, ink, strong) = categoryColors(category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: solid ? strong : soft, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: pcText(size, weight: FontWeight.w600, color: solid ? Colors.white : ink),
      ),
    );
  }
}

const _weekHeads = ['일 (SUN)', '월 (MON)', '화 (TUE)', '수 (WED)', '목 (THU)', '금 (FRI)', '토 (SAT)'];

/// 일요일 시작 주의 첫날.
DateTime weekStart(DateTime d) => dayOf(d).subtract(Duration(days: d.weekday % 7));

Widget _weekdayHeader() => Container(
  padding: const EdgeInsets.only(bottom: 8),
  decoration: const BoxDecoration(
    border: Border(bottom: BorderSide(color: Ds.gray100)),
  ),
  child: Row(
    children: [
      for (var i = 0; i < 7; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _weekHeads[i],
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pcText(
                pcBase,
                weight: i == 0 || i == 6 ? FontWeight.w700 : FontWeight.w600,
                color: i == 0 ? Ds.red500 : (i == 6 ? Ds.blue500 : Ds.gray700),
              ),
            ),
          ),
        ),
      ],
    ],
  ),
);

// ─────────────────────────── 월간 캘린더

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.eventsOn,
    required this.onPick,
    this.example = false,
  });
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final List<CalendarEvent> Function(DateTime) eventsOn;
  final ValueChanged<DateTime> onPick;

  /// 개발 DB에 일정이 하나도 없으면 오늘 칸에 예시 일정 한 건.
  final bool example;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((lead + days) / 7).ceil();
    final start = first.subtract(Duration(days: lead));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _weekdayHeader(),
        const SizedBox(height: 8),
        for (var w = 0; w < weeks; w++) ...[
          if (w > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _cell(DateTime(start.year, start.month, start.day + w * 7 + i))),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(DateTime d) {
    final inMonth = d.month == month.month;
    final evs = eventsOn(d);
    if (!inMonth) {
      return PcHover(
        onTap: () => onPick(d),
        semanticsLabel: '${d.month}월 ${d.day}일',
        builder: (_) => Opacity(
          opacity: 0.5,
          child: Container(
            height: 112,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Ds.gray50,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x66E5E8EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${d.day}',
                  textAlign: TextAlign.right,
                  style: pcText(pcBase, color: Ds.gray400),
                ),
                if (evs.isNotEmpty)
                  Text(
                    evs.first.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pcText(10, color: Ds.gray400),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final isToday = sameDay(d, today);
    final isSel = sameDay(d, selected);
    final hol = holidayOf(d, evs);
    final numColor = dayNumberColor(d, hol);

    final Widget top;
    if (isToday) {
      top = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Ds.blue500, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  'TODAY',
                  style: pcText(9, weight: FontWeight.w700, color: Colors.white, spacing: 0.45, height: 1.4),
                ),
              ),
            ),
          ),
          if (hol != null)
            Flexible(
              child: Text(
                hol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pcText(12, weight: FontWeight.w700, color: Ds.red500),
              ),
            ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Ds.blue500, shape: BoxShape.circle, boxShadow: Ds.shadowSm),
            child: Text(
              '${d.day}',
              style: pcText(12, weight: FontWeight.w700, color: Colors.white, height: 1),
            ),
          ),
        ],
      );
    } else if (hol != null) {
      top = Row(
        children: [
          Expanded(
            child: Text(
              hol,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pcText(pcBase, weight: FontWeight.w700, color: Ds.red500),
            ),
          ),
          Text(
            '${d.day}',
            style: pcText(pcBase, weight: FontWeight.w700, color: numColor),
          ),
        ],
      );
    } else {
      top = Text(
        '${d.day}',
        textAlign: TextAlign.right,
        style: pcText(pcBase, weight: FontWeight.w700, color: numColor),
      );
    }

    final shown = evs.take(2).toList();
    final more = evs.length - shown.length;
    final pills = <Widget>[
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const SizedBox(height: 4),
        EventPill(eventLabel(shown[i]), shown[i].category, solid: isToday),
      ],
      if (example && isToday && evs.isEmpty)
        const Opacity(opacity: 0.6, child: EventPill('10:00 예시 일정', CalendarCategory.facility, solid: true)),
      if (more > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '외 $more건 추가',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pcText(10, weight: FontWeight.w600, color: Ds.blue500),
                ),
              ),
              const Icon(Icons.more_horiz_rounded, size: 12, color: Ds.blue500),
            ],
          ),
        ),
    ];

    return PcHover(
      onTap: () => onPick(d),
      semanticsLabel: '${d.month}월 ${d.day}일',
      builder: (hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 112,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFF6FAFF) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: isSel ? null : Border.all(color: hover ? Ds.blue500 : const Color(0xB3E5E8EB)),
          boxShadow: isSel
              ? const [
                  BoxShadow(color: Ds.blue500, spreadRadius: 2),
                  BoxShadow(color: Color(0x2E3182F6), blurRadius: 16, offset: Offset(0, 4)),
                ]
              : (hover ? Ds.shadowSm : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            top,
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: pills),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── 주간

class WeekBoard extends StatelessWidget {
  const WeekBoard({
    super.key,
    required this.selected,
    required this.today,
    required this.eventsOn,
    required this.onPick,
    required this.onEvent,
  });
  final DateTime selected;
  final DateTime today;
  final List<CalendarEvent> Function(DateTime) eventsOn;
  final ValueChanged<DateTime> onPick;
  final ValueChanged<CalendarEvent> onEvent;

  @override
  Widget build(BuildContext context) {
    final start = weekStart(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _weekdayHeader(),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _column(DateTime(start.year, start.month, start.day + i))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _column(DateTime d) {
    final evs = eventsOn(d);
    final hol = holidayOf(d, evs);
    final isSel = sameDay(d, selected);
    final isToday = sameDay(d, today);
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSel ? const Color(0x66E8F3FF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSel ? Ds.blue500 : const Color(0xB3E5E8EB), width: isSel ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PcHover(
            onTap: () => onPick(d),
            semanticsLabel: '${d.month}월 ${d.day}일',
            builder: (hover) => Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                Text(
                  '${d.month}/${d.day}',
                  style: pcText(pcBase, weight: FontWeight.w700, color: hover ? Ds.blue500 : dayNumberColor(d, hol), mono: true),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Ds.blue500, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      'TODAY',
                      style: pcText(9, weight: FontWeight.w700, color: Colors.white, height: 1.4),
                    ),
                  ),
                if (hol != null)
                  Text(
                    hol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pcText(12, weight: FontWeight.w700, color: Ds.red500),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (evs.isEmpty) Text('일정 없음', style: pcText(11, color: Ds.gray400)),
          for (final e in evs) ...[
            PcHover(
              onTap: () => onEvent(e),
              semanticsLabel: e.title,
              builder: (hover) {
                final (soft, ink, strong) = categoryColors(e.category);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: hover ? strong : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.time ?? '종일',
                        style: pcText(10, weight: FontWeight.w700, color: ink, mono: true),
                      ),
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: pcText(12, weight: FontWeight.w600, color: Ds.gray900, height: 1.35),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── 일간 시간표

class DayBoard extends StatelessWidget {
  const DayBoard({super.key, required this.day, required this.events, required this.onEvent, required this.className});
  final DateTime day;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEvent;
  final String? Function(String?) className;

  int? _hour(CalendarEvent e) => e.time == null ? null : int.tryParse(e.time!.split(':').first);

  @override
  Widget build(BuildContext context) {
    final allDay = events.where((e) => _hour(e) == null).toList();
    final hours = events.map(_hour).whereType<int>().toList();
    final from = [7, ...hours].reduce((a, b) => a < b ? a : b);
    final to = [20, ...hours].reduce((a, b) => a > b ? a : b);
    final hol = holidayOf(day, events);

    Widget row(String label, List<CalendarEvent> list) => Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Ds.gray100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                label,
                style: pcText(13, weight: FontWeight.w700, color: Ds.gray500, mono: true),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in list)
                  PcHover(
                    onTap: () => onEvent(e),
                    semanticsLabel: e.title,
                    builder: (hover) {
                      final (soft, ink, strong) = categoryColors(e.category);
                      final who = [className(e.classId), e.owner].whereType<String>().join(' · ');
                      return Container(
                        constraints: const BoxConstraints(maxWidth: 360),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: soft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: hover ? strong : Colors.transparent),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${e.time ?? '종일'} · ${e.category.tag}',
                              style: pcText(11, weight: FontWeight.w700, color: ink),
                            ),
                            Text(e.title, style: pcText(14, weight: FontWeight.w700, height: 1.4)),
                            if (who.isNotEmpty) Text(who, style: pcText(12, color: Ds.gray600)),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                '${day.year}년 ${day.month}월 ${day.day}일 (${weekdayKo[day.weekday - 1]}) 일간 시간표',
                style: pcText(pcBase, weight: FontWeight.w700),
              ),
              if (hol != null) ...[
                const SizedBox(width: 8),
                Text(
                  hol,
                  style: pcText(14, weight: FontWeight.w700, color: Ds.red500),
                ),
              ],
              const Spacer(),
              Text(
                '${events.length}건',
                style: pcText(14, weight: FontWeight.w700, color: Ds.blue500, mono: true),
              ),
            ],
          ),
        ),
        if (allDay.isNotEmpty) row('종일', allDay),
        for (var h = from; h <= to; h++) row('${two(h)}:00', events.where((e) => _hour(e) == h).toList()),
      ],
    );
  }
}

// ─────────────────────────── 목록형 전체보기

class MonthList extends StatelessWidget {
  const MonthList({
    super.key,
    required this.month,
    required this.events,
    required this.onEvent,
    required this.className,
    this.example = false,
  });
  final DateTime month;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEvent;
  final String? Function(String?) className;
  final bool example;

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      byDay.putIfAbsent(dayOf(e.date), () => []).add(e);
    }
    final days = byDay.keys.toList()..sort();
    if (days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Text(
          example ? '일정을 등록하면 이 달 일정이 날짜순으로 보여요' : '${month.month}월에는 등록된 일정이 없어요',
          textAlign: TextAlign.center,
          style: pcText(14, color: Ds.gray500),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('${month.year}년 ${month.month}월 전체 일정 ${events.length}건', style: pcText(pcBase, weight: FontWeight.w700)),
        ),
        for (final d in days) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Text(
                  '${two(d.month)}.${two(d.day)} (${weekdayKo[d.weekday - 1]})',
                  style: pcText(14, weight: FontWeight.w700, color: dayNumberColor(d, holidayOf(d, byDay[d]!)), mono: true),
                ),
                if (holidayOf(d, byDay[d]!) != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    holidayOf(d, byDay[d]!)!,
                    style: pcText(12, weight: FontWeight.w700, color: Ds.red500),
                  ),
                ],
              ],
            ),
          ),
          for (final e in byDay[d]!)
            PcHover(
              onTap: () => onEvent(e),
              semanticsLabel: e.title,
              builder: (hover) {
                final (soft, ink, _) = categoryColors(e.category);
                final who = [className(e.classId), e.owner].whereType<String>().join(' · ');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: hover ? Ds.gray50 : Colors.white,
                    border: const Border(bottom: BorderSide(color: Ds.gray100)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(e.time ?? '종일', style: pcText(14, weight: FontWeight.w700, mono: true)),
                      ),
                      Container(
                        width: 76,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            e.category.tag,
                            style: pcText(12, weight: FontWeight.w700, color: ink),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pcText(14, weight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(
                          who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pcText(13, color: Ds.gray500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Text(
                          e.detail ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pcText(12, color: Ds.gray600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ],
    );
  }
}

/// 범례 (5색) + 오른쪽 안내 한 줄.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key, required this.note, this.example = false});
  final String note;
  final bool example;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
    decoration: BoxDecoration(
      color: Ds.gray50,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0x99E5E8EB)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final c in CalendarCategory.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PcDot(10, categoryColors(c).$3),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: pcText(pcBase, weight: FontWeight.w500, color: Ds.gray700),
                  ),
                ],
              ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (example) ...[
              const ExampleTag(),
              const SizedBox(width: 6),
              Text('오늘 칸의 예시 일정은 실제 일정을 등록하면 사라져요', style: pcText(12, color: Ds.gray500)),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.cloud_done_outlined, size: 16, color: Ds.blue500),
            const SizedBox(width: 4),
            Text(
              note,
              style: pcText(pcBase, weight: FontWeight.w500, color: Ds.gray500),
            ),
          ],
        ),
      ],
    ),
  );
}
