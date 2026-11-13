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
import '../../core/seed.dart' show amShiftStaff;
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'case_sheets.dart' show confirm;
import 'case_ui.dart';

Future<void> showAlertSheet(BuildContext context, WidgetRef ref, SaveResult result) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false, // 시안 손잡이(44×5)를 직접 그린다
    backgroundColor: surface,
    builder: (_) => _AlertSheet(result: result, hostContext: context),
  );
}

/// 시안 03a: 무슨 일(알약) → 누구·몇 도 + 평소와 차이 → 누구에게 알렸나 → 확인 띠 → 지금 할 일 1개(초록)
/// → 지침·전화 → 잘못 쟀어요. 위험(긴급)이면 같은 배치에서 [간호사에게 전화]가 초록 대신 빨강 주 버튼.
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
    final stage = m.judgment.stage;
    final col = caseColors(c);
    final now = ref.read(clockProvider);
    final me = ref.read(currentUserProvider);
    final danger = stage == Stage.danger;
    final night = repo.shiftAt(m.measuredAt)?.type == ShiftType.night;

    // 이 건의 직전 값 (재측정으로 올라간 경우 "38.4 → 39.1℃")
    final ms = repo.measurementsOfCase(c.id).where((x) => !x.isVoided && x.id != m.id).toList();
    final prev = result.caseCreated || ms.isEmpty ? null : ms.last;

    // 맨 위 알약: 무슨 일이 시작됐나
    final headline = result.escalated
        ? '⚠ 긴급으로 바뀌었어요'
        : result.caseCreated
        ? (c.isUrgent ? '⚠ 긴급 대응을 시작했어요' : '${c.severity.symbol} 이상 대응을 시작했어요')
        : '${caseBadge(c)} 중이에요';

    // 누구에게 알렸나 (저장소 알림 받는 사람과 같은 기준: 근무 선생님 + 간호사 (+ 긴급이면 원장님))
    final shiftStaff = (repo.shiftAt(m.measuredAt)?.staffIds ?? amShiftStaff).length;
    final nurses = repo.allStaff.where((s) => s.role == Role.nurse).map((s) => s.displayName).toList();
    final told = [...nurses, '근무 선생님 $shiftStaff명', if (c.isUrgent) '원장님'].join(', ');

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

    final laterAt = now().add(const Duration(minutes: 30));
    void later() {
      final t = now();
      repo.scheduleRemeasure(c.id, me, t, const Duration(minutes: 30));
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(SnackBar(content: Text('${hm(t.add(const Duration(minutes: 30)))}에 다시 알려 드릴게요')));
    }

    final callText = night ? '당직 간호사에게 전화' : '간호사에게 전화';
    final laterText = '30분 뒤 다시 재기 (${hm(laterAt)})';

    // 시안: 지금 할 일 1개만 58 높이 채운 버튼 (평소엔 초록 [30분 뒤 다시 재기], 위험이면 빨강 [전화]).
    final primary = FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: danger ? stageColors[Stage.danger]!.ink : brandDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 19, fontWeight: FontWeight.w700),
      ),
      onPressed: danger ? call : later,
      child: Text(danger ? callText : laterText, textAlign: TextAlign.center),
    );
    Widget outlined(String text, VoidCallback onTap) => OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        foregroundColor: inkMain,
        backgroundColor: surface,
        side: const BorderSide(color: lineStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
        textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      onPressed: onTap,
      child: Text(text, textAlign: TextAlign.center),
    );

    final trend = prev == null
        ? null
        : '${m.value > prev.value ? '▲ 올라갔어요' : (m.value < prev.value ? '▼ 내려가고 있어요' : '변화가 없어요')} '
              '(${formatTemp(prev.value)} → ${formatTemp(m.value)}℃)';

    final linkStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: inkSub,
      textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 16, fontWeight: FontWeight.w400),
    );
    const link = TextStyle(decoration: TextDecoration.underline, decorationColor: inkSub);
    final unacked = acks.isEmpty;
    final ackCol = unacked ? stageColors[Stage.danger]! : stageColors[Stage.normal]!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 10, Gap.page, Gap.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 손잡이
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: const Color(0xFFE6D6CF), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: Gap.l),
            // ① 무슨 일 (채운 알약)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: col.ink, borderRadius: BorderRadius.circular(Radii.pill)),
                child: Text(
                  headline,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: Gap.l),
            // ② 누구 + 몇 도 → 평소와 차이 → 평소·알린 사람
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${r.name} 별님 '),
                  TextSpan(
                    text: '${formatTemp(m.value)}℃',
                    style: TextStyle(color: col.ink),
                  ),
                ],
              ),
              style: const TextStyle(
                fontFamily: fontBig,
                fontSize: T.headline,
                fontWeight: FontWeight.w800,
                height: 1.3,
                color: inkMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              plainDiff(m.judgment.diff),
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: col.ink),
            ),
            if (trend != null) ...[
              const SizedBox(height: 6),
              Text(
                trend,
                style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: col.ink),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '평소 ${formatTemp(m.judgment.baseline)}℃ · $told에게 알렸어요',
              style: const TextStyle(fontSize: 16, color: inkSub, height: 1.4),
            ),
            const SizedBox(height: Gap.l),
            // ③ 확인 띠
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: ackCol.soft, borderRadius: BorderRadius.circular(Radii.button)),
              child: Row(
                children: [
                  if (unacked)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: ackCol.ink, shape: BoxShape.circle),
                    )
                  else
                    Icon(Icons.check_circle, size: 18, color: ackCol.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ackLine,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ackCol.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.l),
            // ④ 지금 할 일 1개
            const Text(
              '지금 할 일',
              style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub),
            ),
            const SizedBox(height: 6),
            primary,
            const SizedBox(height: Gap.l),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: outlined('투약 지침 보기', () => showGuideline(context, ref, r.id))),
                  const SizedBox(width: 10),
                  Expanded(child: danger ? outlined(laterText, later) : outlined(callText, call)),
                ],
              ),
            ),
            const SizedBox(height: Gap.s),
            // ⑤ 작은 글자 링크: 자세히 보기 · 잘못 쟀어요
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gap.l,
              children: [
                TextButton(
                  style: linkStyle,
                  onPressed: () {
                    Navigator.pop(context);
                    if (hostContext.mounted) openCaseDetail(hostContext, c.id);
                  },
                  child: const Text('자세히 보기', style: link),
                ),
                TextButton(
                  style: linkStyle,
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
