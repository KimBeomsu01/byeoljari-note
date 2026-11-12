// HO-1 "긴급 · 이상 대응" 칸의 카드 (통합 명세 6-3 1번).
// 데이터는 이상 건(Case) 하나. 위험이 나온 건 = 긴급(빨강 ⚠), 나머지 = 이상 대응(이상 주황 ▲ / 저온 파랑 ▼).
// 카드 순서: 누구 → 몇 도·무슨 상태 → 누가 확인했나 → [확인했어요] [체온 재기] → 마지막 측정 (보조 글자).
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

    final events = repo.eventsOf(c.id).where((e) => e.voidedBy == null).toList();
    final ackers = <String>{
      for (final e in events)
        if (e.type == 'acked') e.actorId
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

    return Semantics(
      container: true,
      label: '${c.kindLabel}, ${cls.name} ${r.name}, ${formatTemp(last.value)}도 ${last.judgment.stage.label}',
      child: InfoCard(
        accent: c.isUrgent ? col.ink : col.line,
        onTap: () => openCaseDetail(context, c.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ① 누구
          Row(children: [
            ResidentAvatar(name: r.name, classColor: cls.color, size: 52),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.name} 별님',
                    style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain, height: 1.3)),
                Text(cls.name, style: const TextStyle(fontSize: T.caption, color: inkSub)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: inkSub, size: 28, semanticLabel: '자세히 보기'),
          ]),
          const SizedBox(height: Gap.m),
          // ② 몇 도 · 무슨 상태
          Wrap(spacing: Gap.m, runSpacing: Gap.s, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${formatTemp(last.value)}℃',
                style: TextStyle(
                  fontSize: T.number,
                  fontWeight: FontWeight.w800,
                  color: col.ink,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            StageTag(last.judgment.stage, large: true),
            if (c.isUrgent) StatusPill('${Stage.danger.symbol} 긴급', color: col.ink, filled: true),
          ]),
          const SizedBox(height: Gap.xs),
          Text(plainDiff(last.judgment.diff),
              style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain)),
          Text('대응 단계 ${_circled(c.stage)} ${InMemoryRepository.stageLabel(c.stage)}',
              style: const TextStyle(fontSize: T.body, color: inkMain)),
          if (c.remeasureAt != null)
            Text(
              late ? '⏱ ${hm(c.remeasureAt!)}에 다시 잴 시간이 지났어요' : '⏱ ${hm(c.remeasureAt!)}에 다시 재요',
              style: TextStyle(
                  fontSize: T.body, fontWeight: late ? FontWeight.w800 : FontWeight.w400, color: late ? col.ink : inkMain),
            ),
          const SizedBox(height: Gap.s),
          // 누가 확인했나
          Text(whoLine,
              style: TextStyle(
                  fontSize: T.body,
                  fontWeight: FontWeight.w700,
                  color: nobody ? stageColors[Stage.danger]!.ink : hoDone.ink)),
          if (whoSub != null) Text(whoSub, style: const TextStyle(fontSize: T.caption, color: inkSub)),
          const SizedBox(height: Gap.m),
          // ③ 할 일: 같은 폭 버튼 두 개
          Row(children: [
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
                onPressed: () => ref.read(quickTempProvider.notifier).openFor(r.id),
                child: const Text('체온 재기', textAlign: TextAlign.center),
              ),
            ),
          ]),
          const SizedBox(height: Gap.m),
          // 마지막 측정: 보조 글자
          Text('${repo.staff(last.recordedBy).displayName} 측정 · ${whenLabel(last.measuredAt, now)}',
              style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
      ),
    );
  }
}

class _AckedBox extends StatelessWidget {
  const _AckedBox();

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: tapHeight),
        padding: const EdgeInsets.symmetric(horizontal: Gap.m),
        decoration: BoxDecoration(
          color: hoDone.soft,
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: hoDone.line, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text('✓ 확인함',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: T.body, color: hoDone.ink, fontWeight: FontWeight.w800)),
      );
}

String _circled(int n) => switch (n) { 1 => '①', 2 => '②', 3 => '③', _ => '④' };
