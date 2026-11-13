// SC-1 반별 일정 (일정 명세 3·4장, 통합 명세 6-5). 클로드 디자인 개선 시안 '4 반별 일정'.
// 질문 하나: "우리 반 별님들 지금 어디 있고, 체온은 다 쟀나?"
// 머리: 작은 '오늘 10월 28일 수요일 ▾'(누르면 달력) 위에 큰 '일정', 오른쪽 [● 은하수자리 ▾](누르면 반 고르기).
// ① 먼저 챙길 별님 N — 이상 대응·긴급(긴급 먼저) / 주의 + 재측정 할 일 / 지난 측정 미기록. 줄마다 [재기] → 퀵 체온.
// ② '별님 6명 · 지금 09:41' + 한 줄에 한 별님 (얼굴 · 이름 · 장소/다음 일정 · 오른쪽 체온 상태 칩). 줄 누르면 하루 일정(SC-2).
// 맨 아래 작은 '파일로 일정 올리기'(SC-U). 일정 탭은 앱 공통 머리가 없어 이 화면이 머리를 직접 그린다.
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

  Future<void> _pickClass(InMemoryRepository repo, String selected, String? home) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      builder: (_) => _ClassSheet(classes: repo.classes, selected: selected, homeClassId: home),
    );
    if (picked != null && mounted) setState(() => _classId = picked);
  }

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

    // 오른쪽 칩이 보여주는 측정 시점 이름 ('오전 체온')
    String? slotHeader;
    if (isToday) {
      for (final r in residents) {
        final s = currentSlot(repo.slotStatuses(r.id, date, now), now);
        if (s != null) {
          slotHeader = slotShortName(s.slot);
          break;
        }
      }
    }

    final priority = isToday ? _priorityOf(repo, residents, date, now) : const <_Priority>[];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 6, Gap.page, 72),
        children: [
          _Header(
            date: date,
            isToday: isToday,
            calendarOpen: _calendarOpen,
            cls: cls,
            mine: classId == home,
            onDate: () => setState(() {
              _calendarOpen = !_calendarOpen;
              _calendarMonth = DateTime(date.year, date.month);
            }),
            onClass: () => _pickClass(repo, classId, home),
          ),
          if (!isToday)
            Padding(
              padding: const EdgeInsets.only(top: Gap.m),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '다른 날 일정을 보고 있어요',
                      style: TextStyle(fontSize: T.caption, color: inkSub),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: sage,
                      foregroundColor: brandDark,
                      minimumSize: const Size(tapHeight, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => setState(() {
                      _date = null;
                      _calendarOpen = false;
                    }),
                    child: const Text('오늘로'),
                  ),
                ],
              ),
            ),
          if (_calendarOpen)
            _MonthCalendar(
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
            ),
          if (priority.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PriorityCard(items: priority, onMeasure: (r) => openQuickTempFor(context, ref, r)),
          ],
          // 구역 머리: '별님 6명 · 지금 09:41'  ·  오른쪽 '오전 체온'
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 18, 2, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    isToday ? '별님 ${residents.length}명 · 지금 ${hm(now)}' : '별님 ${residents.length}명',
                    style: const TextStyle(
                      fontFamily: fontBig,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: inkMain,
                    ),
                  ),
                ),
                if (slotHeader != null) ...[
                  const SizedBox(width: Gap.s),
                  Text(
                    slotHeader,
                    style: const TextStyle(fontSize: T.caption, color: inkSub),
                  ),
                ],
              ],
            ),
          ),
          if (residents.isEmpty)
            const EmptyNote('이 반에 등록된 별님이 없어요')
          else
            // 반·날짜를 바꾸면 목록 전체를 새로 만든다 (이전 반 별님이 남아 보이지 않게, 5-5).
            KeyedSubtree(
              key: ValueKey('list-$classId-${date.toIso8601String()}'),
              child: _ResidentList(
                children: [
                  for (final r in residents) _ResidentRow(repo: repo, resident: r, date: date, now: now, today: today),
                ],
              ),
            ),
          if (isWeekend(date))
            const Padding(
              padding: EdgeInsets.fromLTRB(2, Gap.m, 2, 0),
              child: Text(
                '주말에는 식사와 여가 활동만 있어요',
                style: TextStyle(fontSize: T.caption, color: inkSub),
              ),
            ),
          const SizedBox(height: Gap.l),
          // 눌러야 보이게: 일정은 사무국에서 바꾸고, 파일로 올리는 것은 맨 아래 작은 줄로.
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: brandDark,
                minimumSize: const Size(tapHeight, 48),
                textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: () => showUploadSheet(context),
              icon: const Icon(Icons.upload_outlined, size: 20),
              label: const Text('파일로 일정 올리기'),
            ),
          ),
          const Text(
            '일정은 사무국에서 바꿔요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: T.caption, color: inkSub),
          ),
        ],
      ),
    );
  }

  /// 먼저 챙길 별님: 이상 대응·긴급(긴급 먼저) → 주의 + 재측정 할 일 → 지난 측정 미기록.
  List<_Priority> _priorityOf(InMemoryRepository repo, List<Resident> residents, DateTime date, DateTime now) {
    final cases = <_Priority>[];
    final caution = <_Priority>[];
    final missed = <_Priority>[];
    for (final r in residents) {
      final c = repo.openCaseOf(r.id);
      if (c != null) {
        final again = c.remeasureAt != null ? ' · ${hm(c.remeasureAt!)} 다시 재기' : '';
        cases.add(_Priority(r, '${c.isUrgent ? '긴급' : '이상 대응 중'}$again', urgent: c.isUrgent));
        continue;
      }
      final latest = repo.latestOf(r.id);
      final tasks = repo.openTempTasksOf(r.id);
      if (latest != null &&
          latest.judgment.stage == Stage.caution &&
          tasks.isNotEmpty &&
          sameDay(latest.measuredAt, date)) {
        final due = tasks.first.task!.dueAt;
        caution.add(_Priority(r, due != null ? '${hm(due)} 다시 재기' : '${tasks.first.task!.label} 부탁'));
        continue;
      }
      final miss = repo.slotStatuses(r.id, date, now).where((s) => s.state == SlotState.missed).firstOrNull;
      if (miss != null) missed.add(_Priority(r, '${slotShortName(miss.slot)} 아직'));
    }
    cases.sort((a, b) => a.urgent == b.urgent ? 0 : (a.urgent ? -1 : 1));
    return [...cases, ...caution, ...missed];
  }
}

class _Priority {
  const _Priority(this.resident, this.reason, {this.urgent = false});
  final Resident resident;
  final String reason;
  final bool urgent;
}

// ── 머리: 작은 날짜 줄(▾) + 큰 '일정'  ·  오른쪽 반 알약
class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.isToday,
    required this.calendarOpen,
    required this.cls,
    required this.mine,
    required this.onDate,
    required this.onClass,
  });
  final DateTime date;
  final bool isToday;
  final bool calendarOpen;
  final Class cls;
  final bool mine;
  final VoidCallback onDate;
  final VoidCallback onClass;

  @override
  Widget build(BuildContext context) {
    final dateText = longDateLabel(date, today: isToday);
    final left = Semantics(
      button: true,
      label: '$dateText, ${calendarOpen ? '달력 접기' : '날짜 바꾸기, 달력 펼치기'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.button),
        onTap: onDate,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: tapHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: dateText),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(calendarOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 22, color: inkSub),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: T.caption, color: inkSub),
              ),
              const SizedBox(height: 4),
              const Text(
                '일정',
                style: TextStyle(
                  fontFamily: fontBig,
                  fontSize: T.headline,
                  fontWeight: FontWeight.w800,
                  color: inkMain,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // 반 알약은 제 크기대로 (좁으면 줄 폭의 반까지), 남는 폭은 날짜 줄·제목.
    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: left),
          ),
          const SizedBox(width: Gap.s),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
            child: _ClassPill(cls: cls, mine: mine, onTap: onClass),
          ),
        ],
      ),
    );
  }
}

/// [● 은하수자리 ▾] — 누르면 반 고르기.
class _ClassPill extends StatelessWidget {
  const _ClassPill({required this.cls, required this.mine, required this.onTap});
  final Class cls;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '반 고르기, 지금 ${cls.name}${mine ? ', 내 반' : ''}',
    excludeSemantics: true,
    child: Material(
      color: surface,
      shape: const StadiumBorder(side: BorderSide(color: lineStrong, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: Color(cls.color), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    cls.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: inkMain),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 24, color: inkMain),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 반 고르기 시트: 한 줄에 한 반 (반 색 점 · 이름 · '내 반' · 고른 반 ✓).
class _ClassSheet extends StatelessWidget {
  const _ClassSheet({required this.classes, required this.selected, required this.homeClassId});
  final List<Class> classes;
  final String selected;
  final String? homeClassId;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.l, Gap.page, Gap.l),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '반 고르기',
                  style: TextStyle(fontFamily: fontBig, fontSize: T.title, fontWeight: FontWeight.w700, color: inkMain),
                ),
              ),
              IconButton(
                tooltip: '닫기',
                constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: inkSub),
              ),
            ],
          ),
          const SizedBox(height: Gap.s),
          for (final c in classes)
            Semantics(
              button: true,
              selected: c.id == selected,
              label: '${c.name}${c.id == homeClassId ? ', 내 반' : ''}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.button),
                onTap: () => Navigator.of(context).pop(c.id),
                child: Container(
                  constraints: const BoxConstraints(minHeight: tapHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.id == selected ? sage : null,
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: Color(c.color), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: T.body,
                            fontWeight: c.id == selected ? FontWeight.w700 : FontWeight.w400,
                            color: inkMain,
                          ),
                        ),
                      ),
                      if (c.id == homeClassId)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            '내 반',
                            style: TextStyle(fontSize: T.caption, color: inkSub),
                          ),
                        ),
                      if (c.id == selected)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check, size: 22, color: brandDark),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// ── 먼저 챙길 별님 N: 노란 테두리 카드, 줄마다 '이름 · 이유' + [재기]
class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.items, required this.onMeasure});
  final List<_Priority> items;
  final ValueChanged<Resident> onMeasure;

  @override
  Widget build(BuildContext context) {
    final caution = stageColors[Stage.caution]!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: caution.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '먼저 챙길 별님 ${items.length}',
            style: TextStyle(fontFamily: fontBig, fontSize: T.body, fontWeight: FontWeight.w700, color: caution.ink),
          ),
          for (final p in items) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: p.resident.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' · ${p.reason}'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 16, color: inkMain, height: 1.35),
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: '${p.resident.name} 체온 재기',
                  excludeSemantics: true,
                  child: Material(
                    color: actionSoft,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onMeasure(p.resident),
                      child: const SizedBox(
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '재기',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: actionInk),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 흰 카드 하나에 별님 줄들 (사이 옅은 구분선).
class _ResidentList extends StatelessWidget {
  const _ResidentList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: lineSoft),
          children[i],
        ],
      ],
    ),
  );
}

// ── 별님 한 줄: 얼굴 44 · 이름(17 굵게) / 장소·다음 일정 (15) · 오른쪽 체온 상태 칩. 누르면 하루 일정.
class _ResidentRow extends StatelessWidget {
  const _ResidentRow({
    required this.repo,
    required this.resident,
    required this.date,
    required this.now,
    required this.today,
  });
  final InMemoryRepository repo;
  final Resident resident;
  final DateTime date;
  final DateTime now;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final r = resident;
    final items = repo.scheduleOf(r.id, date)..sort((a, b) => a.startAt.compareTo(b.startAt));
    final isToday = sameDay(date, today);

    // 두 번째 줄: 지금 일정이 있으면 '장소 · 다음', 생활실에 있으면 다음 일정만.
    String sub;
    if (isToday) {
      ScheduleItem? current;
      ScheduleItem? next;
      for (final it in items) {
        if (!now.isBefore(it.startAt) && now.isBefore(it.endAt)) current ??= it;
        if (it.startAt.isAfter(now)) next ??= it;
      }
      final nextText = next == null ? '오늘 일정이 끝났어요' : '${hm(next.startAt)} ${next.title.split(' · ').first}';
      sub = current != null ? '${current.place} · $nextText' : nextText;
    } else {
      sub = date.isBefore(today) ? '하루 일정이 끝났어요' : '일정 ${items.length}개가 있어요';
    }

    Widget? trailing;
    if (isToday) {
      final openCase = repo.openCaseOf(r.id);
      final chip = TempChip(slot: currentSlot(repo.slotStatuses(r.id, date, now), now), openCase: openCase);
      // 이상 대응 중·긴급 칩은 따로 눌러 이상 건 상세(S3)로 간다.
      trailing = openCase == null
          ? chip
          : Semantics(
              button: true,
              hint: '이상 건 상세 보기',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => openCaseDetail(context, openCase.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: Center(widthFactor: 1, heightFactor: 1, child: chip),
                ),
              ),
            );
    }

    return Semantics(
      container: true,
      hint: '하루 일정 보기',
      child: InkWell(
        onTap: () => openDaySchedule(context, r.id, date),
        child: LayoutBuilder(
          builder: (context, box) {
            final maxChip = (box.maxWidth - 28) / 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  FaceAvatar.resident(r.id, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: T.body,
                            fontWeight: FontWeight.w700,
                            color: inkMain,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: const TextStyle(fontSize: T.caption, color: inkSub, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    // 아주 좁은 폭 + 큰 글자에서는 칩을 줄의 반 폭 안으로 줄여 넣는다.
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxChip),
                      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: trailing),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── 월 달력 (일요일부터, 일요일 붉은 글자, 선택 = 초록 네모, 오늘 = 반 색 옅은 바탕, 일정 있는 날 = 반 색 점)
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
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '이전 달',
                iconSize: 26,
                constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
                onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left, color: inkSub),
              ),
              Expanded(
                child: Text(
                  '${month.year}년 ${month.month}월',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: fontBig,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: inkMain,
                  ),
                ),
              ),
              IconButton(
                tooltip: '다음 달',
                iconSize: 26,
                constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
                onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right, color: inkSub),
              ),
            ],
          ),
          Row(
            children: [
              for (final (i, w) in const ['일', '월', '화', '수', '목', '금', '토'].indexed)
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: T.caption, color: i == 0 ? _sunday : inkSub),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          for (var row = 0; row < cells.length ~/ 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  for (final d in cells.sublist(row * 7, row * 7 + 7))
                    Expanded(child: d == null ? const SizedBox(height: 48) : _dayCell(d)),
                ],
              ),
            ),
          const SizedBox(height: Gap.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: Color(classColor), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text(
                '일정이 있는 날',
                style: TextStyle(fontSize: T.caption, color: inkSub),
              ),
            ],
          ),
        ],
      ),
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
              constraints: const BoxConstraints(minHeight: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: isToday || isSel ? FontWeight.w700 : FontWeight.w400,
                      color: isSel ? Colors.white : (sunday ? _sunday : inkMain),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: !dot ? Colors.transparent : (isSel ? Colors.white : Color(classColor)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
