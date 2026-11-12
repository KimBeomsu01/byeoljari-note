// SC-1 반별 일정 (일정 명세 3·4장, 통합 명세 6-5). 팀 시제품 '반별 카드'·'달력 펼침' 화면 그대로, 글자만 한 단계 크게.
// 옆으로 미는 반 칩 · 날짜 막대(달력 ▾) · '○○ 별님 N명 / 지금 09:41 기준' · 별님 카드 2열 · 파일로 일정 올리기(SC-U).
// 일정 탭 안에 들어가는 본문이다. 상단 제목줄('별자리노트' + ✦ 반별 일정)은 앱 공통 틀(app.dart)이 그린다.
//
// 2열 카드: 360px 폭에서도 들어가도록 카드 안 여백을 줄이고, '지금'·'다음' 줄은 두 줄까지, 체온 알약은 넘치면 다음 줄로.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'schedule_widgets.dart';
import 'upload_sheet.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> with MinuteTicker {
  /// null = 내 반 (로그인한 선생님의 담당 반).
  String? _classId;

  /// null = 오늘.
  DateTime? _date;
  bool _calendarOpen = false;
  DateTime? _calendarMonth;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    // 역할을 바꾸면 그 사람의 담당 반으로 돌아간다.
    ref.listen(currentUserProvider, (_, _) => setState(() => _classId = null));

    final now = ref.read(clockProvider)();
    final today = dayOf(now);
    final date = _date ?? today;
    final isToday = sameDay(date, today);
    final home = repo.homeClassOf(me);
    final classId = _classId ?? home ?? repo.classes.first.id;
    final cls = repo.classOf(classId);
    final residents = repo.residentsOf(classId);

    Widget pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.page), child: w);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, Gap.xs, 0, 120),
      children: [
        _ClassChips(
          classes: repo.classes,
          selected: classId,
          homeClassId: home,
          onSelect: (id) => setState(() => _classId = id),
        ),
        const SizedBox(height: Gap.m),
        pad(_DateBar(
          date: date,
          isToday: isToday,
          open: _calendarOpen,
          onToggle: () => setState(() {
            _calendarOpen = !_calendarOpen;
            _calendarMonth = DateTime(date.year, date.month);
          }),
          onToday: () => setState(() {
            _date = null;
            _calendarOpen = false;
          }),
        )),
        if (_calendarOpen)
          pad(_MonthCalendar(
            month: _calendarMonth ?? DateTime(date.year, date.month),
            selected: date,
            today: today,
            classColor: cls.color,
            hasSchedule: (d) => residents.any((r) => repo.scheduleOf(r.id, d).isNotEmpty),
            onMonth: (m) => setState(() => _calendarMonth = m),
            onPick: (d) => setState(() {
              _date = sameDay(d, today) ? null : d;
              _calendarOpen = false;
            }),
          )),
        // 구역 머리: '은하수자리 별님 6명'  ·  오른쪽 '지금 09:41 기준'
        pad(Padding(
          padding: const EdgeInsets.fromLTRB(2, Gap.l, 2, Gap.s + 2),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: Gap.s,
            children: [
              Text('${cls.name} 별님 ${residents.length}명',
                  style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
              Text(isToday ? '지금 ${hm(now)} 기준' : '하루 전체 일정',
                  style: const TextStyle(fontSize: T.caption, color: inkSub)),
            ],
          ),
        )),
        if (residents.isEmpty)
          pad(const EmptyNote('이 반에 등록된 별님이 없어요'))
        else
          // 반·날짜를 바꾸면 카드 전체를 새로 만든다 (이전 반 별님이 남아 보이지 않게, 5-5).
          pad(KeyedSubtree(
            key: ValueKey('cards-$classId-${date.toIso8601String()}'),
            child: _CardGrid(children: [
              for (final r in residents) _ResidentCard(repo: repo, resident: r, date: date, now: now, today: today),
            ]),
          )),
        if (isWeekend(date))
          pad(const Padding(
            padding: EdgeInsets.fromLTRB(2, Gap.m, 2, 0),
            child: Text('주말에는 식사와 여가 활동만 있어요', style: TextStyle(fontSize: T.caption, color: inkSub)),
          )),
        const SizedBox(height: Gap.xl),
        pad(OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(tapHeight),
            side: const BorderSide(color: line),
            foregroundColor: inkMain,
          ),
          onPressed: () => showUploadSheet(context),
          icon: const Icon(Icons.upload_outlined, size: 22),
          label: const Text('파일로 일정 올리기'),
        )),
        const SizedBox(height: Gap.l),
        pad(const Text('일정은 사무국에서 바꿔요',
            textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: inkSub))),
        const SizedBox(height: Gap.xs),
        pad(const Text('흩어진 일과(작업치료·프로그램·근무표)를 반별로 모아 봅니다\n동선 자동 안내·비접촉 측정 연동은 다음 단계',
            textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: inkSub, height: 1.6))),
      ],
    );
  }
}

// ── 반 고르기: 시제품처럼 옆으로 미는 한 줄. 선택된 반은 반 색 옅은 바탕 + 반 색 테두리.
class _ClassChips extends StatefulWidget {
  const _ClassChips({required this.classes, required this.selected, required this.homeClassId, required this.onSelect});
  final List<Class> classes;
  final String selected;
  final String? homeClassId;
  final ValueChanged<String> onSelect;

  @override
  State<_ClassChips> createState() => _ClassChipsState();
}

/// 고른 반 칩이 늘 보이도록 가운데쯤으로 옆으로 밀어 둔다 (처음 열 때 · 반이 바뀔 때).
class _ClassChipsState extends State<_ClassChips> {
  final _controller = ScrollController();
  final _rowKey = GlobalKey();
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(_ClassChips old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal({required bool animate}) {
    if (!mounted || !_controller.hasClients) return;
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final chip = _keys[widget.selected]?.currentContext?.findRenderObject() as RenderBox?;
    if (row == null || chip == null) return;
    final pos = _controller.position;
    final left = Gap.page + chip.localToGlobal(Offset.zero, ancestor: row).dx;
    final target = (left - (pos.viewportDimension - chip.size.width) / 2).clamp(0.0, pos.maxScrollExtent);
    if ((target - pos.pixels).abs() < 1) return;
    if (animate) {
      _controller.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: 2),
        child: Row(key: _rowKey, children: [
          for (final c in widget.classes) ...[
            _ClassChip(
              key: _keys.putIfAbsent(c.id, GlobalKey.new),
              cls: c,
              selected: c.id == widget.selected,
              mine: c.id == widget.homeClassId,
              onTap: () => widget.onSelect(c.id),
            ),
            if (c != widget.classes.last) const SizedBox(width: Gap.s - 2),
          ],
        ]),
      );
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({super.key, required this.cls, required this.selected, required this.mine, required this.onTap});
  final Class cls;
  final bool selected;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(cls.color);
    return Semantics(
      button: true,
      selected: selected,
      label: '${cls.name}${mine ? ', 내 반' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? classTint(cls.color) : surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? color : line, width: selected ? 1.5 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: tapHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(cls.name,
                    style: TextStyle(
                        fontSize: T.body, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: inkMain)),
                if (mine) ...[
                  const SizedBox(width: 5),
                  const Text('내 반', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 날짜 막대: 흰 카드 한 줄 '📅 오늘 · 10월 28일 수요일 ……… 달력 ▾' (▾는 아이콘). 다른 날이면 옆에 짙은 '오늘로'.
class _DateBar extends StatelessWidget {
  const _DateBar({required this.date, required this.isToday, required this.open, required this.onToggle, required this.onToday});
  final DateTime date;
  final bool isToday;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final bar = Semantics(
      label: '${longDateLabel(date, today: isToday)}, ${open ? '달력 접기' : '날짜 바꾸기, 달력 펼치기'}',
      excludeSemantics: true,
      button: true,
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button), side: const BorderSide(color: line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.button),
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Gap.s),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 20, color: inkMain),
                const SizedBox(width: Gap.s + 2),
                Expanded(
                  child: Text(longDateLabel(date, today: isToday),
                      style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
                ),
                const SizedBox(width: Gap.s),
                Text(open ? '접기' : '달력',
                    style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub)),
                Icon(open ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 22, color: inkSub),
              ]),
            ),
          ),
        ),
      ),
    );
    if (isToday) return bar;
    return Row(children: [
      Expanded(child: bar),
      const SizedBox(width: Gap.s),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: brandDark,
          minimumSize: const Size(tapHeight, 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: onToday,
        child: const Text('오늘로'),
      ),
    ]);
  }
}

// ── 월 달력 (시제품: 일요일부터, 일요일 붉은 글자, 선택 = 짙은 네모, 오늘 = 반 색 옅은 바탕, 일정 있는 날 = 반 색 점)
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.today,
    required this.classColor,
    required this.hasSchedule,
    required this.onMonth,
    required this.onPick,
  });
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final int classColor;
  final bool Function(DateTime) hasSchedule;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onPick;

  static Color get _sunday => stageColors[Stage.danger]!.ink;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // 일요일 시작
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Container(
      margin: const EdgeInsets.only(top: Gap.s + 2),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: line),
      ),
      child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: '이전 달',
            iconSize: 26,
            constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
            onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left, color: inkSub),
          ),
          Expanded(
            child: Text('${month.year}년 ${month.month}월',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
          ),
          IconButton(
            tooltip: '다음 달',
            iconSize: 26,
            constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
            onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right, color: inkSub),
          ),
        ]),
        Row(children: [
          for (final (i, w) in const ['일', '월', '화', '수', '목', '금', '토'].indexed)
            Expanded(
              child: Text(w,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: i == 0 ? _sunday : inkSub)),
            ),
        ]),
        const SizedBox(height: Gap.xs),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              for (final d in cells.sublist(row * 7, row * 7 + 7))
                Expanded(child: d == null ? const SizedBox(height: tapHeight) : _dayCell(d)),
            ]),
          ),
        const SizedBox(height: Gap.xs),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: Color(classColor), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('일정이 있는 날', style: TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
      ]),
    );
  }

  Widget _dayCell(DateTime d) {
    final isSel = sameDay(d, selected);
    final isToday = sameDay(d, today);
    final dot = hasSchedule(d);
    final sunday = d.weekday == DateTime.sunday;
    return Semantics(
      button: true,
      selected: isSel,
      label: '${dateLabel(d)}${isToday ? ' 오늘' : ''}${dot ? ', 일정 있음' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isSel ? brandDark : (isToday ? classTint(classColor) : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onPick(d),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: tapHeight),
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${d.day}',
                    style: TextStyle(
                        fontSize: T.body,
                        height: 1.2,
                        fontWeight: isToday || isSel ? FontWeight.w800 : FontWeight.w500,
                        color: isSel ? Colors.white : (sunday ? _sunday : inkMain))),
                const SizedBox(height: 2),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: !dot ? Colors.transparent : (isSel ? Colors.white : Color(classColor)),
                    shape: BoxShape.circle,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 두 열로 나란히. 한 줄의 두 카드는 높이를 맞춘다.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < children.length ? Gap.s + 2 : 0),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: children[i]),
                const SizedBox(width: Gap.s + 2),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
              ]),
            ),
          ),
      ]);
}

// ── 별님 카드 (시제품): 얼굴 + 이름 / 붉은 '지금 · …' / '다음 10:40 …' / 알약 '오전 ✓ 36.5° 평소' '오후 예정'.
// 이상·위험·저온이 기록되면 판정 색 굵은 테두리, 지난 측정을 안 쟀으면 점선 + '측정 전'.
class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.repo, required this.resident, required this.date, required this.now, required this.today});
  final InMemoryRepository repo;
  final Resident resident;
  final DateTime date;
  final DateTime now;
  final DateTime today;

  static const _missedLine = Color(0xFF8E9AA8);

  @override
  Widget build(BuildContext context) {
    final r = resident;
    final cls = repo.classOf(r.classId);
    final items = repo.scheduleOf(r.id, date)..sort((a, b) => a.startAt.compareTo(b.startAt));
    final slots = repo.slotStatuses(r.id, date, now);
    final (am, pm) = amPm(slots);
    final openCase = repo.openCaseOf(r.id);

    // 테두리: 그날 기록된 판정 중 이상 대응이 열리는 가장 심한 것. 없고 미기록이면 점선.
    Stage? worst;
    for (final s in slots) {
      final st = s.measurement?.judgment.stage;
      if (s.state == SlotState.recorded && st != null && st.opensCase && (worst == null || st.rank > worst.rank)) {
        worst = st;
      }
    }
    final missed = slots.any((s) => s.state == SlotState.missed);
    final dashed = worst == null && missed;

    // 지금 · 다음 (두 줄까지, 넘치면 …)
    final List<Widget> lines;
    if (sameDay(date, today)) {
      ScheduleItem? current;
      ScheduleItem? next;
      for (final it in items) {
        if (!now.isBefore(it.startAt) && now.isBefore(it.endAt)) current ??= it;
        if (it.startAt.isAfter(now)) next ??= it;
      }
      lines = [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '지금', style: TextStyle(color: current != null ? nowRed : inkSub, fontWeight: FontWeight.w800)),
            TextSpan(text: current != null ? ' · ${current.title} · ${current.place}' : ' · ${cls.name} 생활실'),
          ]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain, height: 1.35),
        ),
        const SizedBox(height: 3),
        Text(next != null ? '다음 ${hm(next.startAt)} ${next.title}' : '오늘 일정이 끝났어요',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: T.caption, color: inkSub, height: 1.35)),
      ];
    } else {
      lines = [
        Text(date.isBefore(today) ? '하루 일정이 끝났어요' : '일정 ${items.length}개가 있어요',
            style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain, height: 1.35)),
      ];
    }

    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        FaceAvatar.resident(r.id, size: 40),
        const SizedBox(width: Gap.s),
        Expanded(
          // 좁거나 큰 글자면 '측정 전'이 이름 아래 줄로 내려간다.
          child: Wrap(spacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(r.name, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
            if (dashed && openCase == null)
              const Text('측정 전', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
          ]),
        ),
      ]),
      if (openCase != null) _CaseBadge(caseItem: openCase) else const SizedBox(height: Gap.s + 2),
      ...lines,
      const SizedBox(height: Gap.s),
      Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
        SlotPill(label: '오전', status: am),
        SlotPill(label: '오후', status: pm),
      ]),
    ]);

    const pad = EdgeInsets.fromLTRB(11, 11, 10, 12);
    final Widget card;
    if (dashed) {
      card = CustomPaint(
        foregroundPainter: const DashedBorderPainter(color: _missedLine, radius: Radii.card, width: 2),
        child: Material(
          color: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openDaySchedule(context, r.id, date),
            child: Padding(padding: pad, child: content),
          ),
        ),
      );
    } else {
      card = Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: worst == null ? const BorderSide(color: line) : BorderSide(color: stageColors[worst]!.line, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openDaySchedule(context, r.id, date),
          child: Padding(padding: pad, child: content),
        ),
      );
    }

    return Semantics(container: true, hint: '하루 일정 보기', child: card);
  }
}

/// '긴급'(빨강) / '이상 대응 중'(주황). 종료 대기 포함 열린 이상 건이면 보인다. 누르면 이상 건 상세(S3).
class _CaseBadge extends StatelessWidget {
  const _CaseBadge({required this.caseItem});
  final Case caseItem;

  @override
  Widget build(BuildContext context) {
    final urgent = caseItem.isUrgent;
    final c = stageColors[urgent ? Stage.danger : Stage.abnormal]!;
    final text = urgent ? '긴급' : '이상 대응 중';
    return Semantics(
      button: true,
      label: '$text, 상세 보기',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(tagRadius),
        onTap: () => openCaseDetail(context, caseItem.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: urgent ? c.ink : c.soft,
                borderRadius: BorderRadius.circular(tagRadius),
                border: Border.all(color: urgent ? c.ink : c.line),
              ),
              child: Text(text,
                  style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: urgent ? Colors.white : c.ink)),
            ),
          ),
        ),
      ),
    );
  }
}
