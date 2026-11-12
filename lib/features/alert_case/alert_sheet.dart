// S1 이상 경고 시트 (이상 대응 명세 S1) · S4 투약 지침 보기.
// 생활관 선생님은 두 손이 바쁘다: 큰 버튼 3개 이하, 글은 두 줄 이내.
// 투약 지침은 의료진이 쓴 글을 그대로 보여주기만 한다. 용량 계산·추천은 하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import 'case_sheets.dart' show confirm;
import 'case_ui.dart';

Future<void> showAlertSheet(BuildContext context, WidgetRef ref, SaveResult result) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AlertSheet(result: result, hostContext: context),
  );
}

class _AlertSheet extends ConsumerWidget {
  const _AlertSheet({required this.result, required this.hostContext});
  final SaveResult result;

  /// 시트를 연 화면 (자세히 보기로 S3를 열 때 쓴다).
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final m = result.measurement;
    final c = repo.caseById(result.caseItem!.id);
    final r = repo.resident(m.residentId);
    final cls = repo.classOf(m.classId);
    final stage = m.judgment.stage;
    final col = caseColors(c);
    final now = ref.read(clockProvider);
    final me = ref.read(currentUserProvider);
    final baseNote = repo.baselineOf(r.id, m.measuredAt).note;
    final danger = stage == Stage.danger;
    final night = repo.shiftAt(m.measuredAt)?.type == ShiftType.night;

    // 이 건의 직전 값 (재측정으로 올라간 경우 "38.4 → 39.1℃")
    final ms = repo.measurementsOfCase(c.id).where((x) => !x.isVoided && x.id != m.id).toList();
    final prev = result.caseCreated || ms.isEmpty ? null : ms.last;

    // 다른 사람이 확인했는지 (실시간)
    final acks = acksOf(repo, c.id).where((e) => e.actorId != me).toList();
    final ackLine = acks.isEmpty
        ? '아직 아무도 확인 안 함'
        : '${withSubject(staffName(repo, acks.first.actorId))} 확인했어요 (${agoText(now(), acks.first.at)})'
            '${acks.length > 1 ? ' 외 ${acks.length - 1}명' : ''}';

    void call() {
      final nurse = repo.allStaff.where((s) => s.role == Role.nurse).firstOrNull;
      toast(context, '${nurse?.displayName ?? '간호사'}에게 전화 연결 (시연: 실제로 걸지 않아요)');
    }

    final callLabel = Text(night ? '당직 간호사에게 전화' : '간호사에게 전화');
    // 위험이면 맨 위, 빨간색 (S1 표 아래 주석)
    final Widget callBtn = danger
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52), backgroundColor: stageColors[Stage.danger]!.ink),
            icon: const Icon(Icons.call),
            label: callLabel,
            onPressed: call,
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.call),
            label: callLabel,
            onPressed: call,
          );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
            decoration: BoxDecoration(
                color: col.soft, borderRadius: BorderRadius.circular(16), border: Border.all(color: col.line, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '${caseBadge(c)}${result.escalated ? ' · 위험으로 올랐어요' : ''}',
                    style: TextStyle(color: col.ink, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(
                  tooltip: '시트 닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              Text('${cls.name} ${r.name} 별님', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${formatTemp(m.value)}℃ · 평소보다 ${formatDiff(m.judgment.diff)}℃ · ${stage.label}',
                  style: TextStyle(fontSize: 17, color: col.ink, fontWeight: FontWeight.w600)),
              if (prev != null)
                Text(
                  '${m.value > prev.value ? '올라갔어요' : (m.value < prev.value ? '내려가고 있어요' : '변화가 없어요')} '
                  '(${formatTemp(prev.value)} → ${formatTemp(m.value)}℃)',
                  style: TextStyle(fontSize: 14, color: col.ink, fontWeight: FontWeight.w700),
                ),
              Text('평소 체온 ${formatTemp(m.judgment.baseline)}℃ ($baseNote)', style: const TextStyle(fontSize: 12, color: inkSub)),
              const SizedBox(height: 8),
              Text(
                c.isUrgent ? '근무 선생님·간호사·사무국, 원장님께도 알렸어요' : '근무 선생님·간호사·사무국에 알렸어요',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Icon(acks.isEmpty ? Icons.hourglass_empty : Icons.check_circle, size: 16, color: inkSub),
                const SizedBox(width: 4),
                Expanded(child: Text(ackLine, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          if (danger) ...[callBtn, const SizedBox(height: 8)],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.medication_outlined),
            label: const Text('투약 지침 보기'),
            onPressed: () => showGuideline(context, ref, r.id),
          ),
          const SizedBox(height: 8),
          if (!danger) ...[callBtn, const SizedBox(height: 8)],
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: brandDark),
            onPressed: () {
              final t = now();
              repo.scheduleRemeasure(c.id, me, t, const Duration(minutes: 30));
              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.pop(context);
              messenger?.showSnackBar(
                  SnackBar(content: Text('${hm(t.add(const Duration(minutes: 30)))}에 다시 알려 드릴게요')));
            },
            child: const Text('30분 뒤 다시 재기'),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () {
                  Navigator.pop(context);
                  if (hostContext.mounted) openCaseDetail(hostContext, c.id);
                },
                child: const Text('자세히 보기'),
              ),
            ),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: inkSub),
                onPressed: () async {
                  final ok = await confirm(context, '잘못 잰 값으로 표시할까요?',
                      result.caseCreated ? '기록은 지워지지 않고 무효 표시돼요. 이 건도 오측정으로 종료되고 알림이 가요.' : '기록은 지워지지 않고 무효 표시돼요.', '무효 표시');
                  if (!ok || !context.mounted) return;
                  final t = now();
                  repo.voidMeasurement(m.id, by: me, at: t);
                  if (result.caseCreated) repo.close(c.id, me, t, misMeasureReason);
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  Navigator.pop(context);
                  messenger?.showSnackBar(const SnackBar(content: Text('잘못 잰 값으로 표시했어요. 다시 재 주세요')));
                },
                child: const Text('잘못 쟀어요'),
              ),
            ),
          ]),
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

  // 최근 투약 기록 (중복 투약을 막도록 보여만 준다)
  final meds = [
    for (final c in repo.casesOf(residentId))
      for (final e in repo.eventsOf(c.id))
        if (e.type == 'medication' && e.voidedBy == null) e
  ]..sort((a, b) => b.at.compareTo(a.at));

  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('${r.name} 투약 지침'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (g == null)
            const Text('등록된 투약 지침이 없어요.\n간호사·원장님께 먼저 연락하세요.',
                style: TextStyle(fontWeight: FontWeight.w700))
          else ...[
            Text('${repo.staff(g.writtenBy).displayName} 작성 · ${g.updatedAt.year}.${g.updatedAt.month}.${g.updatedAt.day} 수정',
                style: const TextStyle(fontSize: 12, color: inkSub)),
            const SizedBox(height: 8),
            if (now.difference(g.updatedAt).inDays > 180)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                color: stageColors[Stage.caution]!.soft,
                child: Text('! ${now.difference(g.updatedAt).inDays}일 동안 고치지 않은 지침이에요. 간호사에게 확인해 주세요.',
                    style: TextStyle(color: stageColors[Stage.caution]!.ink, fontSize: 13)),
              ),
            Text(g.body),
          ],
          if (meds.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('최근 투약 기록', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            for (final e in meds.take(3))
              Text('${e.at.month}/${e.at.day} ${hm(e.at)} ${e.data['text'] ?? ''} (${repo.staff(e.actorId).name})',
                  style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 12),
          const Text('이 지침은 의료진이 미리 작성한 것이에요. 판단이 어려우면 간호사·원장님께 먼저 연락하세요.',
              style: TextStyle(fontSize: 12, color: inkSub)),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
    ),
  );
}
