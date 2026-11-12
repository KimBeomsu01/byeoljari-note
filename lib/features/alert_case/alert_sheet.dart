// S1 이상 경고 시트 (최소안). 상세 버튼 구성은 이상 대응 명세 S1을 따라 다음 단계에서 채운다.
// 투약 지침은 보여주기만 한다. 용량 계산·추천은 하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';

Future<void> showAlertSheet(BuildContext context, WidgetRef ref, SaveResult result) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AlertSheet(result: result),
  );
}

class _AlertSheet extends ConsumerWidget {
  const _AlertSheet({required this.result});
  final SaveResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final m = result.measurement;
    final c = repo.caseById(result.caseItem!.id);
    final r = repo.resident(m.residentId);
    final cls = repo.classOf(m.classId);
    final stage = m.judgment.stage;
    final col = stageColors[c.isUrgent ? Stage.danger : stage]!;
    final now = ref.read(clockProvider);
    final me = ref.read(currentUserProvider);
    final baseNote = repo.baselineOf(r.id, m.measuredAt).note;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: col.soft, borderRadius: BorderRadius.circular(16), border: Border.all(color: col.line, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${c.isUrgent ? '⚠ 긴급' : '${stage.symbol} 이상 대응'}${result.escalated ? ' · 위험으로 올랐어요' : ''}',
                style: TextStyle(color: col.ink, fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text('${cls.name} ${r.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${formatTemp(m.value)}℃ · 평소보다 ${formatDiff(m.judgment.diff)}℃ · ${stage.label}',
                  style: TextStyle(fontSize: 17, color: col.ink, fontWeight: FontWeight.w600)),
              Text('평소 체온 ${formatTemp(m.judgment.baseline)}℃ ($baseNote)',
                  style: const TextStyle(fontSize: 12, color: inkSub)),
              const SizedBox(height: 8),
              Text(
                c.isUrgent
                    ? '원장님·간호사·근무 선생님께 중요 알림을 보냈어요'
                    : '근무 중인 선생님·간호사·사무국에 알림을 보냈어요',
                style: const TextStyle(fontSize: 13),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.medication_outlined),
            label: const Text('투약 지침 보기'),
            onPressed: () => showGuideline(context, ref, r.id),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: brandDark),
            onPressed: () {
              repo.scheduleRemeasure(c.id, me, now(), const Duration(minutes: 30));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('30분 뒤 다시 재도록 알려 드릴게요')));
            },
            child: const Text('30분 뒤 다시 재기'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              repo.voidMeasurement(m.id, by: me, at: now());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('잘못 잰 값으로 표시했어요. 다시 재 주세요')));
            },
            child: const Text('잘못 쟀어요'),
          ),
        ]),
      ),
    );
  }
}

/// S4 투약 지침: 의료진이 쓴 글을 그대로 보여준다.
Future<void> showGuideline(BuildContext context, WidgetRef ref, String residentId) {
  final repo = ref.read(repoProvider);
  final g = repo.guidelineOf(residentId);
  final now = ref.read(clockProvider)();
  final r = repo.resident(residentId);
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('${r.name} 투약 지침'),
      content: g == null
          ? const Text('등록된 투약 지침이 없어요.\n간호사에게 바로 연락해 주세요.')
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (now.difference(g.updatedAt).inDays > 180)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  color: stageColors[Stage.caution]!.soft,
                  child: Text('${now.difference(g.updatedAt).inDays}일 동안 고치지 않은 지침이에요. 간호사에게 확인해 주세요.',
                      style: TextStyle(color: stageColors[Stage.caution]!.ink, fontSize: 13)),
                ),
              Text(g.body),
              const SizedBox(height: 10),
              Text('${repo.staff(g.writtenBy).displayName} 작성 · ${g.updatedAt.year}.${g.updatedAt.month}.${g.updatedAt.day}',
                  style: const TextStyle(fontSize: 12, color: inkSub)),
            ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
    ),
  );
}
