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
import '../../core/ui.dart';
import 'case_sheets.dart' show confirm;
import 'case_ui.dart';

Future<void> showAlertSheet(BuildContext context, WidgetRef ref, SaveResult result) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: paper, // 시제품 시트 바탕 (흰 버튼이 떠 보이게)
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
        ? '아직 아무도 확인 안 했어요'
        : '${withSubject(staffName(repo, acks.first.actorId))} 확인했어요 (${agoText(now(), acks.first.at)})'
              '${acks.length > 1 ? ' 외 ${acks.length - 1}명' : ''}';

    void call() {
      final nurse = repo.allStaff.where((s) => s.role == Role.nurse).firstOrNull;
      toast(context, '${nurse?.displayName ?? '간호사'}에게 전화 연결 (시연: 실제로 걸지 않아요)');
    }

    void later() {
      final t = now();
      repo.scheduleRemeasure(c.id, me, t, const Duration(minutes: 30));
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(SnackBar(content: Text('${hm(t.add(const Duration(minutes: 30)))}에 다시 알려 드릴게요')));
    }

    final danger0 = stageColors[Stage.danger]!;
    final callLabel = Text(night ? '당직 간호사에게 전화' : '간호사에게 전화');
    // 시제품: 흰 바탕 + 옅은 테두리의 폭 전체 버튼
    final plain = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      foregroundColor: inkMain,
      backgroundColor: surface,
      side: const BorderSide(color: line, width: 1.5),
    );
    final guideBtn = OutlinedButton.icon(
      style: plain,
      icon: const Icon(Icons.assignment_outlined, size: 22, color: Color(0xFF9A6A3A)),
      label: const Text('투약 지침 보기'),
      onPressed: () => showGuideline(context, ref, r.id),
    );
    final callBtn = OutlinedButton.icon(
      style: plain,
      icon: Icon(Icons.call, size: 22, color: danger0.ink),
      label: callLabel,
      onPressed: call,
    );
    // 시제품: 연초록 바탕의 [30분 뒤 다시 재기]
    final laterBtn = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: brandDark,
        backgroundColor: const Color(0xFFE3F0D8),
        side: const BorderSide(color: Color(0xFF86B56C), width: 1.5),
      ),
      icon: const Icon(Icons.timer_outlined, size: 24),
      label: const Text('30분 뒤 다시 재기', style: TextStyle(fontWeight: FontWeight.w800)),
      onPressed: later,
    );
    // 위험이면 전화가 맨 위, 빨간색 (S1 표 아래 주석). 아니면 시제품 순서: 지침 → 전화 → (띄우고) 30분 뒤.
    final List<Widget> buttons = danger
        ? [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: danger0.ink),
              icon: const Icon(Icons.call, size: 24),
              label: callLabel,
              onPressed: call,
            ),
            const SizedBox(height: Gap.s),
            guideBtn,
            const SizedBox(height: Gap.l),
            laterBtn,
          ]
        : [guideBtn, const SizedBox(height: Gap.s), callBtn, const SizedBox(height: Gap.l), laterBtn];

    final trend = prev == null
        ? null
        : '${m.value > prev.value ? '▲ 올라갔어요' : (m.value < prev.value ? '▼ 내려가고 있어요' : '변화가 없어요')} '
              '(${formatTemp(prev.value)} → ${formatTemp(m.value)}℃)';

    final linkStyle = TextButton.styleFrom(minimumSize: const Size(0, tapHeight));
    const link = TextStyle(fontWeight: FontWeight.w600, decoration: TextDecoration.underline);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 시제품: 시트 맨 위 판정 색 띠
            Container(
              height: 4,
              decoration: BoxDecoration(color: col.line, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: Gap.s),
            // ① 무슨 일 (긴급/이상 대응 알약) + 닫기
            Row(
              children: [
                CaseBadge(c),
                const Spacer(),
                IconButton(
                  tooltip: '시트 닫기',
                  iconSize: 24,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: line),
                    backgroundColor: surface,
                  ),
                  icon: const Icon(Icons.close, color: inkMain),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (result.escalated)
              Text(
                '위험으로 올랐어요',
                style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: col.ink),
              ),
            const SizedBox(height: Gap.xs),
            // ② 누구 + ③ 몇 도 (시제품: "이서준 별님 38.4℃" 한 줄)
            Wrap(
              spacing: Gap.s,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  '${r.name} 별님',
                  style: const TextStyle(
                    fontSize: T.headline,
                    fontWeight: FontWeight.w600,
                    color: inkMain,
                    height: 1.3,
                  ),
                ),
                Text(
                  '${formatTemp(m.value)}℃',
                  style: TextStyle(
                    fontSize: T.number + 2,
                    fontWeight: FontWeight.w800,
                    color: col.ink,
                    height: 1.15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  plainDiff(m.judgment.diff),
                  style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: col.ink),
                ),
                Text(
                  '(평소 ${formatTemp(m.judgment.baseline)}℃)',
                  style: const TextStyle(fontSize: T.caption, color: inkSub),
                ),
              ],
            ),
            if (trend != null)
              Text(
                trend,
                style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: col.ink),
              ),
            Text(
              '${cls.name} · 평소 체온은 $baseNote',
              style: const TextStyle(fontSize: T.caption, color: inkSub),
            ),
            const SizedBox(height: Gap.s),
            // ④ 누가 알고 있나
            Text(
              c.isUrgent ? '근무 선생님·간호사·사무국, 원장님께도 알렸어요' : '근무 선생님·간호사·사무국에 알렸어요',
              style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w500, color: inkMain),
            ),
            const SizedBox(height: Gap.m),
            // 시제품: 회색 띠 "아직 아무도 확인 안 함"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 10),
              decoration: BoxDecoration(
                color: acks.isEmpty ? const Color(0xFFFBECE7) : stageColors[Stage.normal]!.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconLine(
                icon: acks.isEmpty ? Icons.hourglass_empty : Icons.check_circle,
                text: ackLine,
                strong: true,
                color: acks.isEmpty ? null : stageColors[Stage.normal]!.ink,
              ),
            ),
            const SizedBox(height: Gap.l),
            ...buttons,
            const SizedBox(height: Gap.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: TextButton(
                    style: linkStyle,
                    onPressed: () {
                      Navigator.pop(context);
                      if (hostContext.mounted) openCaseDetail(hostContext, c.id);
                    },
                    child: const Text('자세히 보기', style: link),
                  ),
                ),
                const SizedBox(width: Gap.l),
                Flexible(
                  child: TextButton(
                    style: linkStyle.copyWith(foregroundColor: const WidgetStatePropertyAll(inkSub)),
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        '잘못 잰 값으로 표시할까요?',
                        result.caseCreated ? '기록은 지워지지 않고 무효 표시돼요.\n이 건도 오측정으로 끝나고 알림이 가요.' : '기록은 지워지지 않고 무효 표시돼요.',
                        '무효 표시',
                      );
                      if (!ok || !context.mounted) return;
                      final t = now();
                      repo.voidMeasurement(m.id, by: me, at: t);
                      if (result.caseCreated) repo.close(c.id, me, t, misMeasureReason);
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      Navigator.pop(context);
                      messenger?.showSnackBar(const SnackBar(content: Text('잘못 잰 값으로 표시했어요. 다시 재 주세요')));
                    },
                    child: const Text('잘못 쟀어요', style: link),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        if (e.type == 'medication' && e.voidedBy == null) e,
  ]..sort((a, b) => b.at.compareTo(a.at));
  final caution = stageColors[Stage.caution]!;

  return showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xl),
      title: Text('${r.name} 투약 지침'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (g == null)
              const Text(
                '등록된 투약 지침이 없어요.\n간호사·원장님께 먼저 연락하세요.',
                style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700),
              )
            else ...[
              Text(
                '${repo.staff(g.writtenBy).displayName} 작성',
                style: const TextStyle(fontSize: T.caption, color: inkSub),
              ),
              Text(
                '${g.updatedAt.year}년 ${g.updatedAt.month}월 ${g.updatedAt.day}일 고침',
                style: const TextStyle(fontSize: T.caption, color: inkSub),
              ),
              const SizedBox(height: Gap.m),
              if (now.difference(g.updatedAt).inDays > 180)
                Container(
                  margin: const EdgeInsets.only(bottom: Gap.m),
                  padding: const EdgeInsets.all(Gap.m),
                  decoration: BoxDecoration(
                    color: caution.soft,
                    borderRadius: BorderRadius.circular(Radii.button),
                    border: Border.all(color: caution.line, width: 1.5),
                  ),
                  child: Text(
                    '! ${now.difference(g.updatedAt).inDays}일 동안 고치지 않은 지침이에요.\n간호사에게 확인해 주세요.',
                    style: TextStyle(color: caution.ink, fontSize: T.body, fontWeight: FontWeight.w700),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(Gap.m),
                decoration: BoxDecoration(
                  color: paper,
                  borderRadius: BorderRadius.circular(Radii.button),
                  border: Border.all(color: line),
                ),
                child: Text(
                  g.body,
                  style: const TextStyle(fontSize: T.body, height: 1.6, color: inkMain),
                ),
              ),
            ],
            if (meds.isNotEmpty) ...[
              const SizedBox(height: Gap.l),
              const Text(
                '최근 투약 기록',
                style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800),
              ),
              for (final e in meds.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: Gap.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.data['text'] ?? ''}',
                        style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${e.at.month}/${e.at.day} ${hm(e.at)} · ${repo.staff(e.actorId).name}',
                        style: const TextStyle(fontSize: T.caption, color: inkSub),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: Gap.l),
            const Text(
              '이 지침은 의료진이 미리 쓴 글이에요.\n판단이 어려우면 간호사·원장님께 먼저 연락하세요.',
              style: TextStyle(fontSize: T.caption, color: inkSub),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(d), child: const Text('닫기')),
        ),
      ],
    ),
  );
}
