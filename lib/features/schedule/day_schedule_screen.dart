// SC-2 별님 하루 일정 (일정 명세 5장, 통합 명세 4-3·6-5). 팀 시제품 '별님 하루' 화면 그대로, 글자만 한 단계 크게.
// 머리: '‹ 반 이름' 뒤로 · 큰 얼굴 + '○○ 별님의 하루' · 날짜·일정 개수 · 오전/오후 체온 알약.
// 아래: 왼쪽 시각(시작 굵게, 끝 아래) + 오른쪽 일정 카드 (종류 알약 · 지금 = 붉은 테두리 · 지남).
// 체온 재는 일정의 짙은 '체온 측정 · 오전 체온' 버튼을 누르면 그 별님이 선택된 채 퀵 체온이 열린다. 측정 권한이 없는 반이면 안내만.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: Gap.page - 10,
        toolbarHeight: 56,
        title: _BackToClass(name: cls.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 48),
        children: [
          // 머리: ① 누구 ② 날짜 · 일정 개수 ③ 오전·오후 체온
          Row(children: [
            FaceAvatar.resident(r.id, size: 64),
            const SizedBox(width: Gap.m + 2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.name} 별님의 하루',
                    style: const TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain, height: 1.25)),
                const SizedBox(height: 3),
                Text('${longDateLabel(date, today: isToday)} · 일정 ${items.length}개',
                    style: const TextStyle(fontSize: T.caption, color: inkSub)),
              ]),
            ),
          ]),
          const SizedBox(height: Gap.m),
          Wrap(spacing: 6, runSpacing: 6, children: [
            SlotPill(label: '오전 체온', status: am),
            SlotPill(label: '오후 체온', status: pm),
          ]),
          if (isWeekend(date) || r.commutesToSchool)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
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
          const SizedBox(height: Gap.s),
          const Text('보기 전용 · 일정 변경은 사무국 웹에서 해요',
              textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: inkSub)),
        ],
      ),
    );
  }
}

/// 시제품의 '‹ 양자리반' 뒤로 가기. 누르는 칸 48 이상.
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
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chevron_left, size: 30, color: inkMain),
                  Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
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
    final place = item.staffName == null ? item.place : '${item.place} · ${item.staffName}';

    final card = Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: isPast ? const Color(0xFFFBFBF8) : surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: isNow ? stageColors[Stage.danger]!.line : line, width: isNow ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          KindTag(item.kind),
          if (isNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(tagRadius)),
              child: const Text('지금',
                  style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: Colors.white, height: 1.35)),
            ),
          if (isPast) const Text('지남', style: TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
        const SizedBox(height: 6),
        Text(item.title, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w700, color: inkMain, height: 1.3)),
        const SizedBox(height: 2),
        Text(place, style: const TextStyle(fontSize: T.caption, color: inkSub)),
        if (item.tempSlot != null) _tempBlock(item.tempSlot!),
      ]),
    );

    return Semantics(
      container: true,
      label: '${hm(item.startAt)}부터 ${hm(item.endAt)}까지 ${item.kind.label}${isNow ? ', 지금' : isPast ? ', 지남' : ''}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: Gap.s + 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 시각 칸: 시작 굵게, 끝은 아래 작게 (오른쪽 정렬)
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(hm(item.startAt),
                    style: TextStyle(
                        fontSize: T.body,
                        fontWeight: FontWeight.w800,
                        color: isPast ? inkSub : inkMain,
                        fontFeatures: _tabular)),
                Text(hm(item.endAt), style: const TextStyle(fontSize: T.caption, color: inkSub, fontFeatures: _tabular)),
              ]),
            ),
          ),
          const SizedBox(width: Gap.s + 2),
          Expanded(child: card),
        ]),
      ),
    );
  }

  /// 체온 재는 일정: 짙은 '🌡 체온 측정 · 오전 체온' 버튼 (일정보다 눈에 띄게, 일정 명세 2장) + 기록 상태.
  Widget _tempBlock(TempSlot ts) {
    final s = slot;
    final m = s?.measurement;
    final name = _slotName(ts);
    Widget? status;
    if (s != null && (s.state == SlotState.missed || (s.state == SlotState.recorded && m != null))) {
      status = SlotPill(label: name, status: s);
    } else if (onTemp == null) {
      status = Text(s == null ? '예정' : '${hm(s.at)}에 재요', style: const TextStyle(fontSize: T.caption, color: inkSub));
    }
    return Padding(
      padding: const EdgeInsets.only(top: Gap.s + 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (onTemp == null)
          Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Icon(Icons.thermostat, size: 20, color: brandDark),
            if (status is! SlotPill)
              Text(name, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
            ?status,
          ])
        else ...[
          if (status != null) ...[status, const SizedBox(height: Gap.s)],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: brandDark,
              foregroundColor: Colors.white,
              minimumSize: const Size(tapHeight, tapHeight),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onTemp,
            icon: const Icon(Icons.thermostat, size: 20),
            label: Text.rich(TextSpan(children: [
              const TextSpan(text: '체온 측정', style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' · $name', style: const TextStyle(fontWeight: FontWeight.w500)),
            ])),
          ),
        ],
      ]),
    );
  }
}
