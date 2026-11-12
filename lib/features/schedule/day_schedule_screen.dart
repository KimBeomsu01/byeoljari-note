// SC-2 별님 하루 일정 (일정 명세 5장, 통합 명세 4-3·6-5).
// 머리: 이름·날짜·일정 개수·오전/오후 체온 상태. 아래: 시간 순 목록 (지금 = 붉은 테두리, 지남 = 흐리게).
// '체온 측정' 줄을 누르면 그 별님이 선택된 채 퀵 체온이 열린다. 측정 권한이 없는 반이면 안내만.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
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
      appBar: AppBar(
        backgroundColor: paper,
        title: const Text('하루 일정', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // 머리
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E2DC)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(cls.color),
                    child: Text(r.name.length >= 2 ? r.name.substring(1, 2) : r.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(
                      '${cls.name} · ${dateLabel(date)}${isToday ? ' 오늘' : ''} · 일정 ${items.length}개',
                      style: const TextStyle(fontSize: 13, color: inkSub),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: SlotCell(label: '오전', status: am)),
                const SizedBox(width: 8),
                Expanded(child: SlotCell(label: '오후', status: pm)),
              ]),
            ]),
          ),
          if (isWeekend(date) || r.commutesToSchool)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                isWeekend(date) ? '주말에는 식사와 여가 활동만 있어요' : '학교에 다니는 별님이라 일정 흐름이 달라요',
                style: const TextStyle(fontSize: 12, color: inkSub),
              ),
            ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('이 날은 일정이 없어요', style: TextStyle(color: inkSub))),
            )
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

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.now, required this.slot, required this.onTemp});
  final ScheduleItem item;
  final DateTime now;
  final SlotStatus? slot;

  /// null이면 누를 수 없음 (오늘이 아닌 날).
  final VoidCallback? onTemp;

  @override
  Widget build(BuildContext context) {
    final isNow = !now.isBefore(item.startAt) && now.isBefore(item.endAt);
    final isPast = !now.isBefore(item.endAt);
    final red = nowRed;

    final body = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isNow ? red : const Color(0xFFE2E2DC), width: isNow ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Opacity(
          opacity: isPast ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 52,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hm(item.startAt), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(hm(item.endAt), style: const TextStyle(fontSize: 12, color: inkSub)),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    KindTag(item.kind),
                    if (isNow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(4)),
                        child: const Text('지금',
                            style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    if (isPast) const Text('지남', style: TextStyle(fontSize: 11, color: inkSub, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    [item.place, if (item.staffName != null) item.staffName!].join(' · '),
                    style: const TextStyle(fontSize: 13, color: inkSub),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        if (item.tempSlot != null) _tempLine(item.tempSlot!),
      ]),
    );

    return Semantics(
      container: true,
      label: '${hm(item.startAt)}부터 ${hm(item.endAt)}까지 ${item.kind.label}${isNow ? ', 지금' : isPast ? ', 지남' : ''}',
      child: body,
    );
  }

  /// '체온 측정 · 오전 체온' 줄. 일정보다 눈에 띄게 (일정 명세 2장).
  Widget _tempLine(TempSlot ts) {
    final s = slot;
    final m = s?.measurement;
    String status;
    Color fg = brandDark;
    if (s != null && s.state == SlotState.recorded && m != null) {
      final st = m.judgment.stage;
      status = '${st.symbol} ${formatTemp(m.value)}° ${st.label}';
      fg = stageColors[st]!.ink;
    } else if (s?.state == SlotState.missed) {
      status = '미기록';
      fg = const Color(0xFF55595A);
    } else {
      status = '예정';
    }
    return Material(
      color: const Color(0xFFEAF2EC),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
      child: InkWell(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
        onTap: onTemp,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              const Icon(Icons.thermostat, size: 18, color: brandDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text('체온 측정 · ${ts.label}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: brandDark)),
              ),
              Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
              if (onTemp != null) const Icon(Icons.chevron_right, size: 18, color: brandDark),
            ]),
          ),
        ),
      ),
    );
  }
}
