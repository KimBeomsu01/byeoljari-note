// HO-1 "긴급 · 이상 대응" 칸의 카드 (통합 명세 6-3 1번).
// 데이터는 이상 건(Case) 하나. 위험이 나온 건 = 긴급(빨강 ⚠), 나머지 = 이상 대응(이상 주황 ▲ / 저온 파랑 ▼).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
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
    final symbol = c.isUrgent ? Stage.danger.symbol : c.severity.symbol;
    final label =
        '$symbol ${c.kindLabel} · ${last.judgment.stage.label} ${formatTemp(last.value)}℃ · 평소보다 ${formatDiff(last.judgment.diff)}';

    final events = repo.eventsOf(c.id).where((e) => e.voidedBy == null).toList();
    final ackers = <String>{
      for (final e in events)
        if (e.type == 'acked') e.actorId
    }.toList();
    final iAcked = ackers.contains(me);
    final String who;
    if (c.assigneeId != null) {
      who = '${repo.staff(c.assigneeId!).displayName} 담당';
    } else if (ackers.isNotEmpty) {
      who = '${repo.staff(ackers.first).displayName} 확인${ackers.length > 1 ? ' 외 ${ackers.length - 1}명' : ''} · 담당 없음';
    } else {
      who = '아직 아무도 확인 안 함';
    }

    return Semantics(
      container: true,
      label: '${c.kindLabel}, ${cls.name} ${r.name}, ${formatTemp(last.value)}도 ${last.judgment.stage.label}',
      child: Material(
        color: col.soft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: col.line, width: c.isUrgent ? 2 : 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => openCaseDetail(context, c.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: col.ink, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: [
                NameAvatar(name: r.name, size: 34, color: Color(cls.color).withValues(alpha: 0.35)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.name} 별님', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('${cls.name} · ${repo.staff(last.recordedBy).displayName} 측정 · ${whenLabel(last.measuredAt, now)}',
                        style: const TextStyle(fontSize: 12.5, color: inkSub)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: inkSub),
              ]),
              const SizedBox(height: 8),
              Text('대응 단계 ${_circled(c.stage)} ${InMemoryRepository.stageLabel(c.stage)} · $who',
                  style: const TextStyle(fontSize: 13, color: inkMain)),
              if (c.remeasureAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    c.remeasureAt!.isBefore(now)
                        ? '⏱ ${hm(c.remeasureAt!)} 재측정 예정 · 시간이 지났어요'
                        : '⏱ ${hm(c.remeasureAt!)} 재측정 예정',
                    style: TextStyle(fontSize: 13, color: c.remeasureAt!.isBefore(now) ? col.ink : inkSub),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (iAcked)
                  _AckedChip(color: col)
                else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 44), foregroundColor: col.ink, side: BorderSide(color: col.line)),
                    onPressed: () => repo.acknowledge(c.id, me, ref.read(clockProvider)()),
                    child: const Text('확인했어요'),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(44, 44), backgroundColor: col.ink),
                  onPressed: () => ref.read(quickTempProvider.notifier).openFor(r.id),
                  child: const Text('재측정 입력'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AckedChip extends StatelessWidget {
  const _AckedChip({required this.color});
  final StageColors color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: hoDoneBg, borderRadius: BorderRadius.circular(99), border: Border.all(color: hoDoneLine)),
        alignment: Alignment.center,
        child: const Text('✓ 확인함', style: TextStyle(color: hoDoneInk, fontWeight: FontWeight.w700)),
      );
}

String _circled(int n) => switch (n) { 1 => '①', 2 => '②', 3 => '③', _ => '④' };
