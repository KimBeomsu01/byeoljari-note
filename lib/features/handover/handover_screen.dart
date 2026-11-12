// HO-1 최신 기록 (임시 최소안). 지금은 퀵 체온과의 연결 확인용으로 대응 칸과 할 일만 보여준다.
// 인수인계 담당자가 인수인계 명세 3.1대로 채운다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../quick_temp/quick_temp_controller.dart';

class HandoverScreen extends ConsumerWidget {
  const HandoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final cases = repo.openCases.where((c) => c.recoveredAt == null).toList();
    final tasks = repo.entries.where((e) => e.task != null && !e.task!.done).toList();
    final urgent = cases.where((c) => c.isUrgent).length;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
      Text('긴급 $urgent · 이상 대응 ${cases.length - urgent} · 남은 할 일 ${tasks.length}',
          style: const TextStyle(fontSize: 13, color: inkSub)),
      const SizedBox(height: 12),
      const Text('긴급 · 이상 대응', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (cases.isEmpty) const Text('진행 중인 건이 없어요', style: TextStyle(color: inkSub)),
      for (final c in cases) _CaseCard(c: c),
      const SizedBox(height: 20),
      const Text('남은 할 일', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final e in tasks)
        Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            title: Text('${repo.resident(e.residentId!).name} · ${e.task!.label}'),
            subtitle: Text(e.body ??
                (e.measurementId != null
                    ? '${formatTemp(repo.measurement(e.measurementId!).value)}℃ 주의 · ${repo.staff(e.authorId).displayName}'
                    : '')),
            trailing: FilledButton.tonal(
              onPressed: () {
                if (e.task!.kind == TaskKind.temp) {
                  ref.read(quickTempProvider.notifier).openFor(e.residentId!);
                } else {
                  repo.completeTask(e.id, ref.read(currentUserProvider), ref.read(clockProvider)());
                }
              },
              child: const Text('완료하기'),
            ),
          ),
        ),
    ]);
  }
}

class _CaseCard extends ConsumerWidget {
  const _CaseCard({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final r = repo.resident(c.residentId);
    final last = repo.latestOf(r.id)!;
    final col = stageColors[c.isUrgent ? Stage.danger : c.severity]!;
    final who = c.assigneeId != null ? '${repo.staff(c.assigneeId!).displayName} 담당' : (c.status == CaseStatus.unacked ? '아직 아무도 확인 안 함' : '확인됨 · 담당 없음');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: col.soft, borderRadius: BorderRadius.circular(14), border: Border.all(color: col.line, width: c.isUrgent ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${c.isUrgent ? '⚠ 긴급' : '${c.severity.symbol} 이상 대응'} · ${last.judgment.stage.label} ${formatTemp(last.value)}℃ · 평소보다 ${formatDiff(last.judgment.diff)}',
          style: TextStyle(color: col.ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('${repo.classOf(c.classId).name} ${r.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        Text('대응 단계 ${c.stage} · $who', style: const TextStyle(fontSize: 13, color: inkSub)),
        const SizedBox(height: 8),
        Row(children: [
          if (c.status == CaseStatus.unacked)
            OutlinedButton(
              onPressed: () => repo.acknowledge(c.id, ref.read(currentUserProvider), ref.read(clockProvider)()),
              child: const Text('확인했어요'),
            ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => ref.read(quickTempProvider.notifier).openFor(r.id),
            child: const Text('재측정 입력'),
          ),
        ]),
      ]),
    );
  }
}
