// PC 02 통합 일정 관리 (Claude Design PcSchedule.dc.html, 라우트 schedule-calendar).
// 레일 · 머리는 pc_shell.dart가 그린다. 여기는 main 안쪽: 머리 카드(보기 탭 · 달 이동 · 생활관 필터)
// → 12칸 격자 (캘린더 8 · 선택 일과표 4). 일정은 저장소 calendarEvents · addCalendarEvent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_dashboard_ui.dart';
import 'pc_schedule_calendar.dart';
import 'pc_schedule_day.dart';
import 'pc_schedule_dialogs.dart';

/// 보기 탭.
enum ScheduleView { month, week, day, list }

extension on ScheduleView {
  String get label => switch (this) {
    ScheduleView.month => '월간 캘린더',
    ScheduleView.week => '주간 뷰',
    ScheduleView.day => '일간 시간표',
    ScheduleView.list => '목록형 전체보기',
  };
}

class PcSchedulePage extends ConsumerStatefulWidget {
  const PcSchedulePage({super.key});

  @override
  ConsumerState<PcSchedulePage> createState() => _PcSchedulePageState();
}

class _PcSchedulePageState extends ConsumerState<PcSchedulePage> {
  ScheduleView _view = ScheduleView.month;
  DateTime? _month;
  DateTime? _selected;

  /// 생활관 필터 (null = 전체). 디자인 상태 `pill`.
  String? _classFilter;

  DateTime get _today => dayOf(ref.read(repoProvider).now());

  bool _visible(CalendarEvent e) => _classFilter == null || e.classId == null || e.classId == _classFilter;

  List<CalendarEvent> _eventsOn(InMemoryRepository repo, DateTime d) => repo.calendarOn(d).where(_visible).toList();

  String? _className(InMemoryRepository repo, String? id) {
    if (id == null) return null;
    try {
      return repo.classOf(id).name;
    } catch (_) {
      return null;
    }
  }

  void _select(DateTime d) => setState(() {
    _selected = dayOf(d);
    _month = DateTime(d.year, d.month);
  });

  void _move(int dir) => setState(() {
    final sel = _selected ?? _today;
    final month = _month ?? DateTime(sel.year, sel.month);
    switch (_view) {
      case ScheduleView.month:
      case ScheduleView.list:
        _month = DateTime(month.year, month.month + dir);
      case ScheduleView.week:
        _selected = DateTime(sel.year, sel.month, sel.day + 7 * dir);
        _month = DateTime(_selected!.year, _selected!.month);
      case ScheduleView.day:
        _selected = DateTime(sel.year, sel.month, sel.day + dir);
        _month = DateTime(_selected!.year, _selected!.month);
    }
  });

  Future<void> _create() async {
    final e = await showCreateEvent(context, initialDate: _selected ?? _today, classId: _classFilter);
    if (e == null || !mounted) return;
    _select(e.date);
    showDsToast(context, '신규 일정이 성공적으로 등록되었으며 실시간 타임라인에 반영되었습니다.');
  }

  void _excel(InMemoryRepository repo) {
    final m = _month ?? DateTime(_today.year, _today.month);
    final n = repo.calendarEvents.where((e) => e.date.year == m.year && e.date.month == m.month).length;
    showDsToast(
      context,
      '엑셀 파일 가져오기 · 내보내기는 아직 연결되지 않았어요 (${m.year}년 ${m.month}월 일정 $n건)',
      icon: Icons.table_view_outlined,
      iconColor: Colors.white,
    );
  }

  void _openEvent(CalendarEvent e) => showEventDetail(context, e);

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final today = dayOf(now);
    final selected = _selected ?? today;
    final month = _month ?? DateTime(selected.year, selected.month);
    if (_classFilter != null && !repo.classes.any((c) => c.id == _classFilter)) _classFilter = null;
    final example = repo.isDev && repo.calendarEvents.isEmpty;

    final Widget board = switch (_view) {
      ScheduleView.month => MonthGrid(
        month: month,
        selected: selected,
        today: today,
        eventsOn: (d) => _eventsOn(repo, d),
        onPick: _select,
        example: example,
      ),
      ScheduleView.week => WeekBoard(
        selected: selected,
        today: today,
        eventsOn: (d) => _eventsOn(repo, d),
        onPick: _select,
        onEvent: _openEvent,
      ),
      ScheduleView.day => DayBoard(
        day: selected,
        events: _eventsOn(repo, selected),
        onEvent: _openEvent,
        className: (id) => _className(repo, id),
      ),
      ScheduleView.list => MonthList(
        month: month,
        events: repo.calendarEvents.where((e) => e.date.year == month.year && e.date.month == month.month).where(_visible).toList(),
        onEvent: _openEvent,
        className: (id) => _className(repo, id),
        example: example,
      ),
    };

    final latest = repo.calendarEvents.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final legendNote = latest.isEmpty ? '아직 등록한 일정이 없어요' : '최근 일정 등록 ${relTime(latest.first.createdAt, now)}';

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(repo, now, month, selected),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    // 12칸 격자 (gap 16): 캘린더 8칸 · 선택 일과표 4칸 (xl).
                    final track = (c.maxWidth - 11 * 16) / 12;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: track * 8 + 7 * 16,
                          child: PcCard(
                            border: const Color(0xCCE5E8EB),
                            shadow: pcSoftShadow,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                board,
                                const SizedBox(height: 8),
                                CalendarLegend(note: legendNote, example: example),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: track * 4 + 3 * 16,
                          child: DayAgendaPanel(
                            key: ValueKey('agenda-${selected.toIso8601String()}'),
                            day: selected,
                            events: _eventsOn(repo, selected),
                            onEvent: _openEvent,
                            className: (id) => _className(repo, id),
                            example: example,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(InMemoryRepository repo, DateTime now, DateTime month, DateTime selected) {
    final classes = repo.classes;
    final shift = repo.shiftAt(now);
    final today = dayOf(now);

    Widget tab(ScheduleView v) {
      final on = _view == v;
      return PcHover(
        onTap: () => setState(() => _view = v),
        semanticsLabel: v.label,
        builder: (hover) => Semantics(
          selected: on,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: on ? Ds.shadowSm : null,
            ),
            child: Text(
              v.label,
              style: pcText(pcBase, weight: on ? FontWeight.w700 : FontWeight.w400, color: on || hover ? Ds.gray900 : Ds.gray600),
            ),
          ),
        ),
      );
    }

    Widget roundIcon(IconData icon, String tip, VoidCallback onTap) => Tooltip(
      message: tip,
      child: PcHover(
        onTap: onTap,
        semanticsLabel: tip,
        builder: (hover) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: hover ? Colors.white : Colors.transparent, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: hover ? Ds.gray900 : Ds.gray600),
        ),
      ),
    );

    Widget filterPill(String label, String? id) {
      final on = _classFilter == id;
      return Semantics(
        selected: on,
        child: PcButton(
          label: label,
          onTap: () => setState(() => _classFilter = id),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          bg: on ? Ds.blue500 : Colors.white,
          fg: on ? Colors.white : Ds.gray700,
          border: on ? null : Ds.gray200,
          hoverBg: on ? Ds.blue500 : Ds.gray50,
          hoverFg: on ? Colors.white : Ds.gray900,
          weight: on ? FontWeight.w700 : FontWeight.w400,
          shadow: on ? Ds.shadowSm : null,
        ),
      );
    }

    final months = [for (var i = -6; i <= 6; i++) DateTime(month.year, month.month + i)];

    return PcCard(
      border: const Color(0xCCE5E8EB),
      shadow: pcSoftShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1줄: 제목 + 엑셀 · 일정 등록
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Ds.blue50, borderRadius: BorderRadius.circular(16), boxShadow: Ds.shadowSm),
                    child: const Icon(Icons.calendar_month_outlined, size: 24, color: Ds.blue500),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('혜진원 장애인거주시설', style: pcText(pcBase, color: Ds.gray500)),
                          const SizedBox(width: 4),
                          Text('•', style: pcText(pcBase, color: Ds.gray500)),
                          const SizedBox(width: 4),
                          Text(
                            '실시간 스케줄 허브',
                            style: pcText(pcBase, weight: FontWeight.w600, color: Ds.blue500),
                          ),
                        ],
                      ),
                      Text(
                        '혜진원 시설 & 생활관 통합 일정 관리',
                        style: pcText(20, weight: FontWeight.w700, height: 28 / 20, spacing: -0.5),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PcButton(
                    label: '엑셀(XLSX) 가져오기 / 내보내기',
                    icon: Icons.table_view_outlined,
                    iconColor: Ds.gray600,
                    gap: 4,
                    onTap: () => _excel(repo),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    bg: Ds.gray100,
                    fg: Ds.gray800,
                    border: Ds.gray200,
                    hoverBg: Ds.gray200,
                  ),
                  const SizedBox(width: 8),
                  PcButton(
                    key: const ValueKey('schedule-create'),
                    label: '+ 일정 등록',
                    icon: Icons.add_rounded,
                    iconSize: 20,
                    gap: 4,
                    onTap: _create,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    bg: Ds.blue500,
                    fg: Colors.white,
                    hoverBg: Ds.blue600,
                    weight: FontWeight.w700,
                    shadow: const [BoxShadow(color: Color(0x593182F6), blurRadius: 14, offset: Offset(0, 4))],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 2줄: 보기 탭 + 달 이동 · 달 고르기 · 저장 상태
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Ds.gray100,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x99E5E8EB)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [for (final v in ScheduleView.values) tab(v)]),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Ds.gray100,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x99E5E8EB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          roundIcon(
                            Icons.chevron_left_rounded,
                            _view == ScheduleView.week ? '이전 주' : (_view == ScheduleView.day ? '이전 날' : '이전 달'),
                            () => _move(-1),
                          ),
                          PcHover(
                            onTap: () => _select(today),
                            semanticsLabel: '오늘로 이동',
                            builder: (hover) => AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: hover ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '오늘 (${today.year}. ${today.month}. ${today.day} ${weekdayKo[today.weekday - 1]})',
                                style: pcText(pcBase, weight: FontWeight.w700, color: Ds.blue500),
                              ),
                            ),
                          ),
                          roundIcon(
                            Icons.chevron_right_rounded,
                            _view == ScheduleView.week ? '다음 주' : (_view == ScheduleView.day ? '다음 날' : '다음 달'),
                            () => _move(1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<DateTime>(
                      tooltip: '달 고르기',
                      onSelected: (m) => setState(() => _month = m),
                      itemBuilder: (_) => [
                        for (final m in months)
                          PopupMenuItem<DateTime>(
                            value: m,
                            child: Text(
                              '${m.year}년 ${m.month}월',
                              style: pcText(
                                14,
                                weight: m == month ? FontWeight.w700 : FontWeight.w400,
                                color: m == month ? Ds.blue500 : Ds.gray900,
                              ),
                            ),
                          ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Ds.gray100,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x99E5E8EB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${month.year}년 ${month.month}월', style: pcText(pcBase, weight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Ds.gray500),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Ds.gray200),
                        boxShadow: Ds.shadowSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PcDot(8, Ds.green500),
                          const SizedBox(width: 4),
                          Text(repo.store != null ? '서버 실시간 저장 연동됨' : '이 기기에 저장 중', style: pcText(pcBase, color: Ds.gray600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 3줄: 생활관 필터 + 지금 근무조
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '생활관 필터:',
                          style: pcText(pcBase, weight: FontWeight.w500, color: Ds.gray500),
                        ),
                      ),
                      filterPill('전체 생활관 (${classes.length}개 반)', null),
                      for (final c in classes)
                        () {
                          final severe = repo.residentsOf(c.id).where((r) => r.severe).length;
                          return filterPill(severe > 0 ? '${c.name} (중증 $severe명)' : c.name, c.id);
                        }(),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.visibility_outlined, size: 16, color: Ds.gray500),
                const SizedBox(width: 4),
                Text(
                  shift == null ? '교대 근무조: 없음' : '교대 근무조: ${shift.label}(${hm(shift.startAt)}~${hm(shift.endAt)})',
                  style: pcText(pcBase, color: Ds.gray500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
