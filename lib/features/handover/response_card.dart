// HO-1 "긴급 · 이상 대응" 칸의 카드 (통합 명세 6-3 1번, 시제품 .card.urgent).
// 데이터는 이상 건(Case) 하나. 위험이 나온 건 = 긴급(빨강), 나머지 = 이상 대응(이상 주황 ▲ / 저온 파랑 ▼).
// 카드 순서: 상태 알약 → 누구(얼굴·이름·측정한 선생님·시각) → 몇 도 → 진행 단계 상자 → [확인했어요] [체온 재기].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'handover_common.dart';

class ResponseCard extends ConsumerWidget {
  const ResponseCard({super.key, required this.caseItem});
  final Case caseItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final now = ref.read(clockProvider)();
    final c = caseItem;
    final r = repo.resident(c.residentId);
    final cls = repo.classOf(c.classId);
    final last = repo.latestOf(r.id) ?? repo.measurement(c.firstMeasurementId);
    final col = stageColors[c.isUrgent ? Stage.danger : c.severity]!;
    final stageSymbol = c.isUrgent ? Stage.danger.symbol : c.severity.symbol;

    final events = repo.eventsOf(c.id).where((e) => e.voidedBy == null).toList();
    final ackers = <String>{
      for (final e in events)
        if (e.type == 'acked') e.actorId,
    }.toList();
    final iAcked = ackers.contains(me);

    // 누가 확인·담당했는지: 한 줄에 한 가지.
    final String whoLine;
    String? whoSub;
    if (c.assigneeId != null) {
      whoLine = '${repo.staff(c.assigneeId!).displayName} 담당';
    } else if (ackers.isNotEmpty) {
      whoLine = '${repo.staff(ackers.first).displayName} 확인했어요${ackers.length > 1 ? ' (외 ${ackers.length - 1}명)' : ''}';
      whoSub = '아직 맡은 사람은 없어요';
    } else {
      whoLine = '아직 아무도 확인 안 했어요';
    }
    final nobody = c.assigneeId == null && ackers.isEmpty;
    final late = c.remeasureAt != null && c.remeasureAt!.isBefore(now);
    final danger = stageColors[Stage.danger]!;

    return Semantics(
      container: true,
      label: '${c.kindLabel}, ${cls.name} ${r.name}, ${formatTemp(last.value)}도 ${last.judgment.stage.label}',
      child: Material(
        // 시제품 긴급 카드: 아주 옅은 바탕 + 판정 색 테두리 1.5
        color: Color.alphaBlend(col.soft.withValues(alpha: 0.55), surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: col.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openCaseDetail(context, c.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.s, Gap.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상태 알약 + 자세히 보기
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: col.ink, borderRadius: BorderRadius.circular(Radii.pill)),
                        child: Text(
                          '$stageSymbol ${c.kindLabel}',
                          style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(
                      width: tapHeight,
                      height: 36,
                      child: Icon(Icons.chevron_right, color: inkSub, size: 28, semanticLabel: '자세히 보기'),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.s),
                // 누구: 얼굴 · 이름 · 반 / 측정한 선생님 · 시각
                Padding(
                  padding: const EdgeInsets.only(right: Gap.s),
                  child: Row(
                    children: [
                      ResidentAvatar(name: r.name, classColor: cls.color, size: 48, residentId: r.id),
                      const SizedBox(width: Gap.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 6,
                              children: [
                                Text(
                                  '${r.name} 별님',
                                  style: const TextStyle(
                                    fontSize: T.title,
                                    fontWeight: FontWeight.w800,
                                    color: inkMain,
                                    height: 1.3,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    cls.name,
                                    style: const TextStyle(fontSize: T.caption, color: inkSub),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${repo.staff(last.recordedBy).displayName} 측정',
                              style: const TextStyle(fontSize: T.caption, color: inkSub),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        whenLabel(last.measuredAt, now),
                        style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.m),
                // 몇 도 · 무슨 상태
                Padding(
                  padding: const EdgeInsets.only(right: Gap.s),
                  child: Wrap(
                    spacing: Gap.m,
                    runSpacing: Gap.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${formatTemp(last.value)}℃',
                        style: TextStyle(
                          fontSize: T.number,
                          fontWeight: FontWeight.w800,
                          color: col.ink,
                          height: 1.1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      StageTag(last.judgment.stage),
                      Text(
                        plainDiff(last.judgment.diff),
                        style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.m),
                // 진행 단계 상자 (시제품 .steps)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(right: Gap.s),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 10),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Color.alphaBlend(col.line.withValues(alpha: 0.45), surface)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Step(
                        icon: _circled(c.stage),
                        text: '대응 단계 · ${InMemoryRepository.stageLabel(c.stage)}',
                        ok: true,
                      ),
                      if (c.remeasureAt != null)
                        _Step(
                          icon: '',
                          iconData: Icons.schedule,
                          text: late ? '${hm(c.remeasureAt!)}에 다시 잴 시간이 지났어요' : '${hm(c.remeasureAt!)}에 다시 재요',
                          ink: late ? danger.ink : inkMain,
                          strong: late,
                        ),
                      _Step(
                        icon: nobody ? '!' : '✓',
                        text: whoLine,
                        ink: nobody ? danger.ink : hoDoneInk,
                        strong: true,
                        ok: !nobody,
                      ),
                      if (whoSub != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 30),
                          child: Text(
                            whoSub,
                            style: const TextStyle(fontSize: T.caption, color: inkSub),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.m),
                // 할 수 있는 일: 같은 폭 버튼 두 개
                Padding(
                  padding: const EdgeInsets.only(right: Gap.s),
                  child: Row(
                    children: [
                      Expanded(
                        child: iAcked
                            ? const _AckedBox()
                            : OutlinedButton(
                                onPressed: () => repo.acknowledge(c.id, me, ref.read(clockProvider)()),
                                child: const Text('확인했어요', textAlign: TextAlign.center),
                              ),
                      ),
                      const SizedBox(width: Gap.s),
                      Expanded(
                        child: FilledButton(
                          // 시제품: 긴급 카드의 버튼은 #a8403f
                          style: c.isUrgent ? FilledButton.styleFrom(backgroundColor: danger.ink) : null,
                          onPressed: () => ref.read(quickTempProvider.notifier).openFor(r.id),
                          child: const Text('체온 재기', textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 진행 단계 한 줄: 작은 동그라미 기호 + 글자.
class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.text,
    this.ink = inkMain,
    this.strong = false,
    this.ok = false,
    this.iconData,
  });
  final String icon;
  final IconData? iconData;
  final String text;
  final Color ink;
  final bool strong;
  final bool ok;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1, right: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? stageColors[Stage.normal]!.line : surface,
            border: ok ? null : Border.all(color: ink),
          ),
          child: iconData != null
              ? Icon(iconData, size: 15, color: ok ? Colors.white : ink)
              : Text(
                  icon,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: ok ? Colors.white : ink,
                  ),
                ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: T.body, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: ink),
          ),
        ),
      ],
    ),
  );
}

class _AckedBox extends StatelessWidget {
  const _AckedBox();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: tapHeight),
    padding: const EdgeInsets.symmetric(horizontal: Gap.m),
    decoration: BoxDecoration(
      color: hoDoneBg,
      borderRadius: BorderRadius.circular(Radii.button),
      border: Border.all(color: hoDoneLine, width: 1.5),
    ),
    alignment: Alignment.center,
    child: const Text(
      '✓ 확인함',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: T.body, color: hoDoneInk, fontWeight: FontWeight.w800),
    ),
  );
}

String _circled(int n) => switch (n) {
  1 => '1',
  2 => '2',
  3 => '3',
  _ => '4',
};
