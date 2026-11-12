// SC-1 반별 일정 (일정 명세 3·4장, 통합 명세 6-5).
// 반 탭 · 날짜 줄(달력) · 별님 카드 2열 · 보기 전용 안내 · 파일로 일정 올리기(SC-U).
// 일정 탭 안에 들어가는 본문이다. 상단 제목줄은 앱 공통 틀(app.dart)이 그린다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
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
    final home = repo.homeClassOf(me);
    final classId = _classId ?? home ?? repo.classes.first.id;
    final residents = repo.residentsOf(classId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: () => showUploadSheet(context),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('파일로 일정 올리기'),
          ),
        ),
        const SizedBox(height: 8),
        _ClassTabs(
          classes: repo.classes,
          selected: classId,
          homeClassId: home,
          onSelect: (id) => setState(() => _classId = id),
        ),
        const SizedBox(height: 8),
        _DateRow(
          date: date,
          isToday: sameDay(date, today),
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
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF1EA), borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 18, color: inkSub),
              SizedBox(width: 8),
              Expanded(child: Text('주말에는 식사와 여가 활동만 있어요', style: TextStyle(color: inkMain))),
            ]),
          ),
        const SizedBox(height: 12),
        if (residents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('이 반에 등록된 별님이 없어요', style: TextStyle(color: inkSub))),
          )
        else
          // 반·날짜를 바꾸면 카드 전체를 새로 만든다 (이전 반 별님이 남아 보이지 않게, 5-5).
          KeyedSubtree(
            key: ValueKey('cards-$classId-${date.toIso8601String()}'),
            child: _CardGrid(children: [
              for (final r in residents) _ResidentCard(repo: repo, resident: r, date: date, now: now, today: today),
            ]),
          ),
        const SizedBox(height: 20),
        const Center(
          child: Text('보기 전용 · 일정 변경은 사무국 웹에서 해요',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: inkSub)),
        ),
      ],
    );
  }
}

// ── 반 탭
class _ClassTabs extends StatelessWidget {
  const _ClassTabs({required this.classes, required this.selected, required this.homeClassId, required this.onSelect});
  final List<Class> classes;
  final String selected;
  final String? homeClassId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final c in classes)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ClassTab(cls: c, selected: c.id == selected, mine: c.id == homeClassId, onTap: () => onSelect(c.id)),
            ),
        ]),
      );
}

class _ClassTab extends StatelessWidget {
  const _ClassTab({required this.cls, required this.selected, required this.mine, required this.onTap});
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
        color: selected ? brandDark : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? brandDark : const Color(0xFFD9DCD5))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(cls.name,
                    style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : inkMain)),
                if (mine) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : const Color(0xFFE6EFE9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('내 반', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: brandDark)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 날짜 줄
class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.isToday, required this.open, required this.onToggle, required this.onToday});
  final DateTime date;
  final bool isToday;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '${dateLabel(date)}${isToday ? ' 오늘' : ''}, 달력 ${open ? '접기' : '펼치기'}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: brandDark),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(dateLabel(date),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 6),
                    const Text('오늘', style: TextStyle(fontSize: 12, color: brandDark, fontWeight: FontWeight.w700)),
                  ],
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: inkSub),
                ]),
              ),
            ),
          ),
        ),
        if (!isToday)
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: onToday,
            child: const Text('오늘로'),
          ),
      ]);
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
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E2DC)),
      ),
      child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: '이전 달',
            onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text('${month.year}년 ${month.month}월',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: '다음 달',
            onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        Row(children: [
          for (final w in const ['월', '화', '수', '목', '금', '토', '일'])
            Expanded(
              child: Text(w, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: inkSub)),
            ),
        ]),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(children: [
            for (final d in cells.sublist(row * 7, row * 7 + 7))
              Expanded(child: d == null ? const SizedBox(height: 44) : _dayCell(d)),
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
        borderRadius: BorderRadius.circular(8),
        onTap: () => onPick(d),
        child: SizedBox(
          height: 44,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 30,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? brandDark : null,
                borderRadius: BorderRadius.circular(8),
                border: isToday && !isSel ? Border.all(color: brandDark) : null,
              ),
              child: Text('${d.day}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isSel ? Colors.white : inkMain)),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dot ? brandDark : Colors.transparent, shape: BoxShape.circle),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 카드 2열
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: children[i]),
                const SizedBox(width: 8),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
              ]),
            ),
          ),
      ]);
}

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

    // 카드 테두리: 그날 기록된 판정 중 가장 심한 것. 위험 빨강 > 이상 주황 / 저온 파랑. 없고 미기록이면 회색 점선.
    Stage? worst;
    for (final s in slots) {
      final st = s.measurement?.judgment.stage;
      if (s.state == SlotState.recorded && st != null && st.opensCase && (worst == null || st.rank > worst.rank)) {
        worst = st;
      }
    }
    final missed = slots.any((s) => s.state == SlotState.missed);
    final dashed = worst == null && missed;
    final side = worst != null
        ? BorderSide(color: stageColors[worst]!.line, width: 2.5)
        : dashed
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFE2E2DC));

    // 지금 · 다음
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
            ? _line('지금', '${hm(current.startAt)} ${current.title}', color: nowRed, bold: true)
            : _line('지금', '${cls.name} 생활실'),
        next != null ? _line('다음', '${hm(next.startAt)} ${next.title}') : _line('다음', '오늘 일정 끝'),
      ];
    } else {
      lines = [
        Text(date.isBefore(today) ? '하루 일정 끝' : '일정 보기',
            style: const TextStyle(fontSize: 13, color: inkSub, fontWeight: FontWeight.w600)),
      ];
    }

    final card = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openDaySchedule(context, r.id, date),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(cls.color),
                  child: Text(_initial(r.name),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              // 큰 글자에서는 배지 글자가 두 줄로 내려간다 (넘치지 않게).
              if (openCase != null)
                Flexible(
                  child: Padding(padding: const EdgeInsets.only(left: 6), child: _CaseBadge(caseItem: openCase)),
                ),
            ]),
            const SizedBox(height: 4),
            Text(r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            ...lines,
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: SlotCell(label: '오전', status: am)),
              const SizedBox(width: 6),
              Expanded(child: SlotCell(label: '오후', status: pm)),
            ]),
          ]),
        ),
      ),
    );

    return Semantics(
      container: true,
      hint: '하루 일정 보기',
      child: dashed
          ? CustomPaint(foregroundPainter: const DashedBorderPainter(color: Color(0xFF9A9E9B), width: 2), child: card)
          : card,
    );
  }

  /// 프로필 대신 이름(성 다음 글자) 한 글자. 실제 사진은 쓰지 않는다.
  static String _initial(String name) => name.length >= 2 ? name.substring(1, 2) : name;

  Widget _line(String head, String body, {Color? color, bool bold = false}) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$head ', style: TextStyle(fontWeight: FontWeight.w700, color: color ?? inkSub)),
          TextSpan(text: body, style: TextStyle(color: color ?? inkMain, fontWeight: bold ? FontWeight.w700 : null)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
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
        borderRadius: BorderRadius.circular(8),
        onTap: () => openCaseDetail(context, caseItem.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Align(
            alignment: Alignment.topRight,
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: urgent ? c.ink : c.soft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.line),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: urgent ? Colors.white : c.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
