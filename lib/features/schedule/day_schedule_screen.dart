// SC-2 별님 하루 일정 (일정 명세 5장, 통합 명세 4-3·6-5). 개선 시안의 말투로: 질문 하나 "이 별님 오늘 하루는?"
// 머리: '‹ 반 이름' 뒤로 · 작은 날짜·일정 개수 위에 큰 '○○ 별님의 하루' · 얼굴.
// 체온 카드: '오전 체온' / '오후 체온' 줄마다 오른쪽 상태 칩 (반별 일정 목록과 같은 칩).
// 하루 일정: 흰 카드 한 장에 한 줄 = 한 일정 (왼쪽 시각 · 제목 · 장소, 지금 = 옅은 빨강 바탕 + '지금', 지남 = 흐리게).
// 체온 재는 일정의 초록 '오전 체온 재기' 버튼 → 그 별님이 선택된 퀵 체온. 측정 권한이 없는 반이면 안내만.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'schedule_widgets.dart';

class DayScheduleScreen extends ConsumerStatefulWidget {
  const DayScheduleScreen({super.key, required this.residentId, required this.date});
  final String residentId;
  final DateTime date;

  @override
  ConsumerState<DayScheduleScreen> createState() => _DayScheduleScreenState();
}

class _DayScheduleScreenState extends ConsumerState<DayScheduleScreen> with MinuteTicker {
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.page - 10,
        toolbarHeight: 56,
        title: _BackToClass(name: cls.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 48),
        children: [
          // 머리: 작은 날짜 줄 + 큰 이름
          Row(
            children: [
              FaceAvatar.resident(r.id, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${longDateLabel(date, today: isToday)} · 일정 ${items.length}개',
                      style: const TextStyle(fontSize: T.caption, color: inkSub),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.name} 별님의 하루',
                      style: const TextStyle(
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
            ],
          ),
          if (isWeekend(date) || r.commutesToSchool)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: Text(
                isWeekend(date) ? '주말에는 식사와 여가 활동만 있어요' : '학교에 다니는 별님이라 일정 흐름이 달라요',
                style: const TextStyle(fontSize: T.caption, color: inkSub),
              ),
            ),
          if (slots.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Card(
              children: [
                for (final s in slots)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.slot.label,
                            style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
                          ),
                        ),
                        const SizedBox(width: Gap.s),
                        TempChip(slot: s, slotName: slotShortName(s.slot)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 22, 2, 12),
            child: Text(
              '하루 일정',
              style: TextStyle(fontFamily: fontBig, fontSize: 18, fontWeight: FontWeight.w700, color: inkMain),
            ),
          ),
          if (items.isEmpty)
            const EmptyNote('이 날은 일정이 없어요')
          else
            _Card(
              children: [
                for (final it in items)
                  _ItemRow(
                    item: it,
                    now: now,
                    slot: it.tempSlot == null ? null : slots.where((s) => s.slot == it.tempSlot).firstOrNull,
                    onTemp: isToday && it.tempSlot != null
                        ? () => openQuickTempFor(context, ref, r, popToFirst: true)
                        : null,
                  ),
              ],
            ),
          const SizedBox(height: Gap.l),
          const Text(
            '보기 전용 · 일정 변경은 사무국 웹에서 해요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: T.caption, color: inkSub),
          ),
        ],
      ),
    );
  }
}

/// 흰 카드 한 장, 줄 사이 옅은 구분선.
class _Card extends StatelessWidget {
  const _Card({required this.children});
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: lineSoft),
          children[i],
        ],
      ],
    ),
  );
}

/// '‹ 은하수자리' 뒤로 가기. 누르는 칸 52 이상.
class _BackToClass extends StatelessWidget {
  const _BackToClass({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '뒤로',
    child: Semantics(
      button: true,
      label: '뒤로, $name',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.button),
        onTap: () => Navigator.of(context).maybePop(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: tapHeight, minWidth: tapHeight),
          child: Padding(
            padding: const EdgeInsets.only(right: Gap.m),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left, size: 30, color: inkMain),
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.now, required this.slot, required this.onTemp});
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
    final place = item.staffName == null ? item.place : '${item.place} · ${item.staffName}';
    final ink = isPast ? inkSub : inkMain;

    Widget? mark;
    if (isNow) {
      mark = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: nowRed, borderRadius: BorderRadius.circular(999)),
        child: const Text(
          '지금',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
    } else if (isPast) {
      mark = const Text(
        '지남',
        style: TextStyle(fontSize: T.caption, color: inkSub),
      );
    }

    return Semantics(
      container: true,
      label:
          '${hm(item.startAt)}부터 ${hm(item.endAt)}까지 ${item.kind.label}${isNow
              ? ', 지금'
              : isPast
              ? ', 지남'
              : ''}',
      child: Container(
        color: isNow ? alertSoft : null,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hm(item.startAt),
                    style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: ink, fontFeatures: _tabular),
                  ),
                  Text(
                    hm(item.endAt),
                    style: const TextStyle(fontSize: T.caption, color: inkSub, fontFeatures: _tabular),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: ink, height: 1.3),
                        ),
                      ),
                      if (mark != null) ...[const SizedBox(width: Gap.s), mark],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place,
                    style: const TextStyle(fontSize: T.caption, color: inkSub, height: 1.35),
                  ),
                  if (item.tempSlot != null) _tempBlock(item.tempSlot!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 체온 재는 일정: 기록 상태 칩 + (오늘이면) 초록 '오전 체온 재기' 버튼 (일정보다 눈에 띄게, 일정 명세 2장).
  Widget _tempBlock(TempSlot ts) {
    final s = slot;
    final name = slotShortName(ts);
    // 예정은 버튼만 (위 체온 카드에 시각이 있다). 다른 날·기록·미기록이면 상태 칩.
    final chip = s == null || (s.state == SlotState.upcoming && onTemp != null)
        ? null
        : TempChip(slot: s, slotName: name);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: Gap.s,
        runSpacing: Gap.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onTemp != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: brandDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(tapHeight, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: onTemp,
              icon: const Icon(Icons.thermostat, size: 20),
              label: Text('$name 재기'),
            ),
          ?chip,
        ],
      ),
    );
  }
}
