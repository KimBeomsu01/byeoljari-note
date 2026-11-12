// SC-2 별님 하루 일정 (일정 명세 5장, 통합 명세 4-3·6-5).
// 머리: 이름·날짜·일정 개수·오전/오후 체온 상태. 아래: 시간 순 목록 (지금 = 붉은 굵은 테두리, 지남 = 바탕색 + '지남').
// '체온 재기' 버튼을 누르면 그 별님이 선택된 채 퀵 체온이 열린다. 측정 권한이 없는 반이면 안내만.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'schedule_widgets.dart';

class DayScheduleScreen extends ConsumerStatefulWidget {
  const DayScheduleScreen({super.key, required this.residentId, required this.date});
  final String residentId;
  final DateTime date;

  @override
  ConsumerState<DayScheduleScreen> createState() => _DayScheduleScreenState();
}

class _DayScheduleScreenState extends ConsumerState<DayScheduleScreen> with MinuteTicker {
  void _openQuickTemp(Resident r) {
    final me = ref.read(currentUserProvider);
    if (!measurableClasses(me).contains(r.classId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 반은 체온 측정 권한이 없어요')));
      return;
    }
    // 퀵 체온은 앱 공통 틀 위의 레이어라, 먼저 첫 화면으로 돌아간 뒤 연다.
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(quickTempProvider.notifier).openFor(r.id);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = ref.read(clockProvider)();
    final today = dayOf(now);
    final date = dayOf(widget.date);
    final isToday = sameDay(date, today);
    final r = repo.resident(widget.residentId);
    final cls = repo.classOf(r.classId);
    final items = repo.scheduleOf(r.id, date)..sort((a, b) => a.startAt.compareTo(b.startAt));
    final slots = repo.slotStatuses(r.id, date, now);
    final (am, pm) = amPm(slots);

    return Scaffold(
      appBar: AppBar(title: const Text('하루 일정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, 48),
        children: [
          // 머리: ① 누구 ② 날짜 ③ 오전·오후 체온
          InfoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ExcludeSemantics(child: ResidentAvatar(name: r.name, classColor: cls.color, size: 56)),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
                    Text(cls.name, style: const TextStyle(fontSize: T.caption, color: inkSub)),
                  ]),
                ),
              ]),
              const SizedBox(height: Gap.l),
              Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(dateLabel(date),
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
                if (isToday) const StatusPill('오늘', color: brandDark),
              ]),
              Text('일정 ${items.length}개', style: const TextStyle(fontSize: T.caption, color: inkSub)),
              const SizedBox(height: Gap.m),
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: SlotCell(label: '오전', status: am)),
                  const SizedBox(width: Gap.s),
                  Expanded(child: SlotCell(label: '오후', status: pm)),
                ]),
              ),
            ]),
          ),
          if (isWeekend(date) || r.commutesToSchool)
            Padding(
              padding: const EdgeInsets.only(top: Gap.m),
              child: Text(
                isWeekend(date) ? '주말에는 식사와 여가 활동만 있어요' : '학교에 다니는 별님이라 일정 흐름이 달라요',
                style: const TextStyle(fontSize: T.caption, color: inkSub),
              ),
            ),
          const SizedBox(height: Gap.l),
          if (items.isEmpty)
            const EmptyNote('이 날은 일정이 없어요')
          else
            for (final it in items)
              _ItemTile(
                item: it,
                now: now,
                slot: it.tempSlot == null ? null : slots.where((s) => s.slot == it.tempSlot).firstOrNull,
                onTemp: isToday && it.tempSlot != null ? () => _openQuickTemp(r) : null,
              ),
        ],
      ),
    );
  }
}

/// '오후 체온 · 목욕 전' → '오후 체온 (목욕 전)'. 버튼 글자 안에 점이 두 번 나오지 않게.
String _slotName(TempSlot ts) {
  final parts = ts.label.split(' · ');
  return parts.length == 1 ? parts.first : '${parts.first} (${parts.sublist(1).join(' ')})';
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.now, required this.slot, required this.onTemp});
  final ScheduleItem item;
  final DateTime now;
  final SlotStatus? slot;

  /// null이면 누를 수 없음 (오늘이 아닌 날).
  final VoidCallback? onTemp;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final isNow = !now.isBefore(item.startAt) && now.isBefore(item.endAt);
    final isPast = !now.isBefore(item.endAt);
    final red = nowRed;

    final body = Container(
      margin: const EdgeInsets.only(bottom: Gap.m),
      decoration: BoxDecoration(
        color: isNow ? stageColors[Stage.danger]!.soft : (isPast ? paper : surface),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: isNow ? red : line, width: isNow ? 3 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(Gap.l),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 84,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hm(item.startAt),
                      style: const TextStyle(
                          fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain, fontFeatures: _tabular)),
                  Text('~ ${hm(item.endAt)}',
                      style: const TextStyle(fontSize: T.caption, color: inkSub, fontFeatures: _tabular)),
                ]),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    KindTag(item.kind),
                    if (isNow) StatusPill('지금', color: red, filled: true),
                    if (isPast) const StatusPill('지남', color: inkSub),
                  ]),
                  const SizedBox(height: Gap.xs),
                  Text(item.title,
                      style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
                  Text(item.place, style: const TextStyle(fontSize: T.caption, color: inkSub)),
                  if (item.staffName != null)
                    Text('담당 ${item.staffName}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
                ]),
              ),
            ]),
          ),
        ),
        if (item.tempSlot != null) _tempBlock(item.tempSlot!),
      ]),
    );

    return Semantics(
      container: true,
      label: '${hm(item.startAt)}부터 ${hm(item.endAt)}까지 ${item.kind.label}${isNow ? ', 지금' : isPast ? ', 지남' : ''}',
      child: body,
    );
  }

  /// 체온 재는 일정: 상태 한 줄 + '체온 재기 · 오전 체온' 버튼 (일정보다 눈에 띄게, 일정 명세 2장).
  Widget _tempBlock(TempSlot ts) {
    final s = slot;
    final m = s?.measurement;
    final name = _slotName(ts);
    final Widget status;
    if (s != null && s.state == SlotState.recorded && m != null) {
      status = Semantics(
        label: '$name ${formatTemp(m.value)}도 ${m.judgment.stage.label}',
        excludeSemantics: true,
        child: StageTag(m.judgment.stage, value: m.value),
      );
    } else if (s?.state == SlotState.missed) {
      status = const Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
        StatusPill('미기록', color: inkSub),
        Text('아직 안 쟀어요', style: TextStyle(fontSize: T.caption, color: inkSub)),
      ]);
    } else {
      status = Text(s == null ? '예정' : '${hm(s.at)}에 재요', style: const TextStyle(fontSize: T.caption, color: inkSub));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (onTemp == null) ...[
            const Icon(Icons.thermostat, size: 24, color: brandDark),
            Text(name, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
          ],
          status,
        ]),
        if (onTemp != null) ...[
          const SizedBox(height: Gap.s),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
            onPressed: onTemp,
            icon: const Icon(Icons.thermostat, size: 24),
            label: Text('체온 재기 · $name'),
          ),
        ],
      ]),
    );
  }
}
