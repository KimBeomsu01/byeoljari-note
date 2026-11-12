// SC-1 반별 일정 (일정 명세 3·4장, 통합 명세 6-5).
// 반 고르기 · 날짜(달력) · 별님 카드 한 줄에 하나 · 파일로 일정 올리기(SC-U) · 안내.
// 일정 탭 안에 들어가는 본문이다. 상단 제목줄은 앱 공통 틀(app.dart)이 그린다.
//
// 카드를 한 줄에 하나로 둔 이유: 390px 폭에서 두 열로 나누면 카드 폭이 165px 안팎이라
// 본문 글자(17)로 '지금 학교 (08:40~14:30)'가 들어가지 않고, 오전·오후 칸이 너무 좁아진다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.s, Gap.page, 120),
      children: [
        _ClassChips(
          classes: repo.classes,
          selected: classId,
          homeClassId: home,
          onSelect: (id) => setState(() => _classId = id),
        ),
        const SizedBox(height: Gap.xl),
        _DateBlock(
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
        ),
        if (_calendarOpen)
          _MonthCalendar(
            month: _calendarMonth ?? DateTime(date.year, date.month),
            selected: date,
            today: today,
            hasSchedule: (d) => residents.any((r) => repo.scheduleOf(r.id, d).isNotEmpty),
            onMonth: (m) => setState(() => _calendarMonth = m),
            onPick: (d) => setState(() {
              _date = sameDay(d, today) ? null : d;
              _calendarOpen = false;
            }),
          ),
        if (isWeekend(date))
          const Padding(
            padding: EdgeInsets.only(top: Gap.m),
            child: InfoCard(
              child: Row(children: [
                Icon(Icons.info_outline, size: 24, color: brandDark),
                SizedBox(width: Gap.m),
                Expanded(child: Text('주말에는 식사와 여가 활동만 있어요', style: TextStyle(fontSize: T.body, color: inkMain))),
              ]),
            ),
          ),
        SectionTitle('${cls.name} 별님', count: residents.length),
        if (residents.isEmpty)
          const EmptyNote('이 반에 등록된 별님이 없어요')
        else
          // 반·날짜를 바꾸면 카드 전체를 새로 만든다 (이전 반 별님이 남아 보이지 않게, 5-5).
          KeyedSubtree(
            key: ValueKey('cards-$classId-${date.toIso8601String()}'),
            child: Column(children: [
              for (final r in residents)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.m),
                  child: _ResidentCard(repo: repo, resident: r, date: date, now: now, today: today),
                ),
            ]),
          ),
        const SizedBox(height: Gap.l),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
          onPressed: () => showUploadSheet(context),
          icon: const Icon(Icons.upload_file, size: 24),
          label: const Text('파일로 일정 올리기'),
        ),
        const SizedBox(height: Gap.l),
        const Text('일정은 사무국에서 바꿔요',
            textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: inkSub)),
      ],
    );
  }
}

// ── 반 고르기: 여섯 반이 한눈에 보이게 줄을 바꿔 늘어놓는다 (옆으로 밀어야 보이는 칸이 없게).
class _ClassChips extends StatelessWidget {
  const _ClassChips({required this.classes, required this.selected, required this.homeClassId, required this.onSelect});
  final List<Class> classes;
  final String selected;
  final String? homeClassId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
        for (final c in classes)
          _ClassChip(cls: c, selected: c.id == selected, mine: c.id == homeClassId, onTap: () => onSelect(c.id)),
      ]);
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.cls, required this.selected, required this.mine, required this.onTap});
  final Class cls;
  final bool selected;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${cls.name}${mine ? ', 내 반' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? brandDark : surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? brandDark : line, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: tapHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.s),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(cls.color),
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? Colors.white : inkSub, width: 1.5),
                  ),
                ),
                const SizedBox(width: Gap.s),
                Flexible(
                  child: Text(cls.name,
                      style: TextStyle(
                          fontSize: T.body, fontWeight: FontWeight.w700, color: selected ? Colors.white : inkMain)),
                ),
                if (mine) ...[
                  const SizedBox(width: Gap.s),
                  const StatusPill('내 반', color: brandDark),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 날짜: 크게 보여주고, 바꾸기·오늘로는 폭을 나눈 큰 버튼으로.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.isToday, required this.open, required this.onToggle, required this.onToday});
  final DateTime date;
  final bool isToday;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(tapHeight),
      padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.m),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: Gap.m, runSpacing: Gap.s, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(dateLabel(date), style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
        if (isToday) const StatusPill('오늘', color: brandDark),
      ]),
      const SizedBox(height: Gap.m),
      Row(children: [
        Expanded(
          child: Semantics(
            label: open ? '달력 접기' : '날짜 바꾸기, 달력 펼치기',
            excludeSemantics: true,
            button: true,
            child: OutlinedButton.icon(
              style: buttonStyle,
              onPressed: onToggle,
              icon: Icon(open ? Icons.expand_less : Icons.calendar_month, size: 24),
              label: Text(open ? '달력 접기' : '날짜 바꾸기'),
            ),
          ),
        ),
        if (!isToday) ...[
          const SizedBox(width: Gap.s),
          Expanded(child: OutlinedButton(style: buttonStyle, onPressed: onToday, child: const Text('오늘로'))),
        ],
      ]),
    ]);
  }
}

// ── 월 달력
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.today,
    required this.hasSchedule,
    required this.onMonth,
    required this.onPick,
  });
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime) hasSchedule;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // 월요일 시작
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Container(
      margin: const EdgeInsets.only(top: Gap.m),
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, Gap.xs, Gap.s),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: line),
      ),
      child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: '이전 달',
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
            onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left, color: brandDark),
          ),
          Expanded(
            child: Text('${month.year}년 ${month.month}월',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
          ),
          IconButton(
            tooltip: '다음 달',
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
            onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right, color: brandDark),
          ),
        ]),
        const SizedBox(height: Gap.xs),
        Row(children: [
          for (final w in const ['월', '화', '수', '목', '금', '토', '일'])
            Expanded(
              child: Text(w,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
            ),
        ]),
        const SizedBox(height: Gap.xs),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(children: [
            for (final d in cells.sublist(row * 7, row * 7 + 7))
              Expanded(child: d == null ? const SizedBox(height: tapHeight) : _dayCell(d)),
          ]),
      ]),
    );
  }

  Widget _dayCell(DateTime d) {
    final isSel = sameDay(d, selected);
    final isToday = sameDay(d, today);
    final dot = hasSchedule(d);
    return Semantics(
      button: true,
      selected: isSel,
      label: '${dateLabel(d)}${isToday ? ' 오늘' : ''}${dot ? ', 일정 있음' : ''}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.button),
        onTap: () => onPick(d),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: tapHeight),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Container(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? brandDark : null,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !isSel ? Border.all(color: brandDark, width: 2) : null,
              ),
              child: Text('${d.day}',
                  style: TextStyle(
                      fontSize: T.body,
                      fontWeight: isToday || isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? Colors.white : inkMain)),
            ),
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot ? brandDark : Colors.transparent, shape: BoxShape.circle),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 별님 카드: ① 누구 ② 지금·다음 ③ 오전·오후 체온 ④ 하루 일정 보기
class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.repo, required this.resident, required this.date, required this.now, required this.today});
  final InMemoryRepository repo;
  final Resident resident;
  final DateTime date;
  final DateTime now;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final r = resident;
    final cls = repo.classOf(r.classId);
    final items = repo.scheduleOf(r.id, date)..sort((a, b) => a.startAt.compareTo(b.startAt));
    final slots = repo.slotStatuses(r.id, date, now);
    final (am, pm) = amPm(slots);
    final openCase = repo.openCaseOf(r.id);

    // 카드 테두리: 그날 기록된 판정 중 가장 심한 것 (왼쪽 색 띠). 없고 미기록이면 점선.
    Stage? worst;
    for (final s in slots) {
      final st = s.measurement?.judgment.stage;
      if (s.state == SlotState.recorded && st != null && st.opensCase && (worst == null || st.rank > worst.rank)) {
        worst = st;
      }
    }
    final missed = slots.any((s) => s.state == SlotState.missed);
    final dashed = worst == null && missed;

    // 지금 · 다음 (한 줄에 한 가지)
    final List<Widget> lines;
    if (sameDay(date, today)) {
      ScheduleItem? current;
      ScheduleItem? next;
      for (final it in items) {
        if (!now.isBefore(it.startAt) && now.isBefore(it.endAt)) current ??= it;
        if (it.startAt.isAfter(now)) next ??= it;
      }
      lines = [
        current != null
            ? _line(StatusPill('지금', color: nowRed, filled: true),
                '${current.title} (${hm(current.startAt)}~${hm(current.endAt)})',
                strong: true)
            : _line(const StatusPill('지금', color: inkSub), '${cls.name} 생활실'),
        next != null
            ? _line(const StatusPill('다음', color: inkSub), '${hm(next.startAt)} ${next.title}')
            : _line(const StatusPill('다음', color: inkSub), '오늘 일정이 끝났어요'),
      ];
    } else {
      lines = [
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.s),
          child: Text(date.isBefore(today) ? '하루 일정이 끝났어요' : '일정 ${items.length}개가 있어요',
              style: const TextStyle(fontSize: T.body, color: inkMain)),
        ),
      ];
    }

    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ExcludeSemantics(child: ResidentAvatar(name: r.name, classColor: cls.color, size: 56)),
        const SizedBox(width: Gap.m),
        Expanded(
          // 큰 글자에서는 배지가 이름 아래 줄로 내려간다 (넘치지 않게).
          child: Wrap(spacing: Gap.s, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(r.name, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
            if (openCase != null) _CaseBadge(caseItem: openCase),
          ]),
        ),
      ]),
      const SizedBox(height: Gap.m),
      ...lines,
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: SlotCell(label: '오전', status: am)),
          const SizedBox(width: Gap.s),
          Expanded(child: SlotCell(label: '오후', status: pm)),
        ]),
      ),
      const SizedBox(height: Gap.xs),
      // 카드 전체가 눌린다는 것을 글자로 알려 준다.
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(
            child: Text('하루 일정 보기',
                style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: brandDark)),
          ),
          Icon(Icons.chevron_right, size: 26, color: brandDark),
        ]),
      ),
    ]);

    const pad = EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.xs);
    final Widget card;
    if (dashed) {
      card = CustomPaint(
        foregroundPainter: const DashedBorderPainter(color: inkSub, radius: Radii.card, width: 2),
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
      card = InfoCard(
        accent: worst == null ? null : stageColors[worst]!.line,
        padding: pad,
        onTap: () => openDaySchedule(context, r.id, date),
        child: content,
      );
    }

    return Semantics(container: true, hint: '하루 일정 보기', child: card);
  }

  Widget _line(Widget pill, String body, {bool strong = false}) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.s),
        child: Row(children: [
          pill,
          const SizedBox(width: Gap.m),
          Expanded(
            child: Text(body,
                style: TextStyle(
                    fontSize: T.body, color: inkMain, fontWeight: strong ? FontWeight.w700 : FontWeight.w400)),
          ),
        ]),
      );
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
        customBorder: const StadiumBorder(),
        onTap: () => openCaseDetail(context, caseItem.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: StatusPill(text, color: c.ink, background: c.soft, filled: urgent),
          ),
        ),
      ),
    );
  }
}
