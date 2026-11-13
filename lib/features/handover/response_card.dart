// 인수인계 첫 화면의 이상 대응 카드 (개선 시안 1: "근무 시작 30초 안에 꼭 눌러야 하는 [확인했어요]를 카드 안 첫 번째 버튼으로").
// 데이터는 이상 건(Case) 하나. 위험이 나온 건 = 긴급(빨강 ⚠), 나머지 = 이상 대응(이상 주황 ▲ / 저온 파랑 ▼).
// 카드 순서: 상태 알약 · 시각 › → 누구(얼굴·이름·반) + 큰 체온 → 평소와 차이 → 확인 상태 띠 → [확인했어요] [재측정 입력].
// 대응 단계·측정한 사람은 카드를 눌러 상세(S3)에서 본다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'handover_common.dart';
import 'task_actions.dart';

class ResponseCard extends ConsumerWidget {
  const ResponseCard({super.key, required this.caseItem});
  final Case caseItem;

  /// "21분 전" · "2시간 전" · "1일 전".
  static String ago(DateTime t, DateTime now) {
    final m = now.difference(t).inMinutes;
    if (m < 1) return '방금';
    if (m < 60) return '$m분 전';
    if (m < 24 * 60) return '${m ~/ 60}시간 전';
    return '${m ~/ (24 * 60)}일 전';
  }

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
    final danger = stageColors[Stage.danger]!;

    final ackers = <String>{
      for (final e in repo.eventsOf(c.id))
        if (e.voidedBy == null && e.type == 'acked') e.actorId,
    }.toList();
    final iAcked = ackers.contains(me);
    final nobody = c.assigneeId == null && ackers.isEmpty;
    final String who;
    if (c.assigneeId != null) {
      who = '${repo.staff(c.assigneeId!).displayName} 담당';
    } else if (ackers.isNotEmpty) {
      who = '${repo.staff(ackers.first).displayName} 확인했어요${ackers.length > 1 ? ' (외 ${ackers.length - 1}명)' : ''}';
    } else {
      who = '아직 아무도 확인 안 했어요';
    }
    final late = c.remeasureAt != null && c.remeasureAt!.isBefore(now);
    final temp = formatTemp(last.value);

    return Semantics(
      container: true,
      label: '${c.kindLabel}, ${cls.name} ${r.name} 별님, $temp도 ${last.judgment.stage.label}',
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: col.line, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openCaseDetail(context, c.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상태 알약 · 언제 ›
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: col.ink, borderRadius: BorderRadius.circular(Radii.pill)),
                      child: Text(
                        '$symbol ${c.kindLabel}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: Text(
                        '${whenLabel(last.measuredAt, now)} · ${ago(last.measuredAt, now)} ›',
                        textAlign: TextAlign.right,
                        semanticsLabel: '${whenLabel(last.measuredAt, now)} 측정, 자세히 보기',
                        style: const TextStyle(fontSize: T.caption, color: inkSub),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 누구 + 몇 도
                Row(
                  children: [
                    FaceAvatar.resident(r.id, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.name} 별님',
                            style: const TextStyle(
                              fontFamily: fontBig,
                              fontSize: T.title,
                              fontWeight: FontWeight.w700,
                              color: inkMain,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(cls.name, style: const TextStyle(fontSize: T.caption, color: inkSub)),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: temp),
                          const TextSpan(text: '℃', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                      semanticsLabel: '$temp도',
                      style: TextStyle(
                        fontFamily: fontBig,
                        fontSize: T.number,
                        fontWeight: FontWeight.w800,
                        color: col.ink,
                        height: 1.15,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plainDiff(last.judgment.diff),
                  style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: col.ink),
                ),
                const SizedBox(height: 10),
                // 누가 확인했는지 (한 줄)
                _Band(
                  text: who,
                  ink: nobody ? danger.ink : hoDoneInk,
                  bg: nobody ? alertSoft : hoDoneBg,
                  mark: nobody ? null : '✓',
                ),
                if (late) ...[
                  const SizedBox(height: Gap.s),
                  _Band(text: '${hm(c.remeasureAt!)}에 다시 잴 시간이 지났어요', ink: danger.ink, bg: alertSoft, mark: '!'),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 13,
                      child: iAcked
                          ? const _AckedBox()
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 54),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              onPressed: () => repo.acknowledge(c.id, me, ref.read(clockProvider)()),
                              child: const Text('확인했어요', textAlign: TextAlign.center),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 10,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 54),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: inkMain,
                          side: const BorderSide(color: lineStrong, width: 1.5),
                          textStyle: const TextStyle(fontFamily: fontSmall, fontSize: T.body, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => openQuickTempFor(context, ref, r.id),
                        child: const Text('재측정 입력', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 확인 상태 띠: 점(또는 기호) + 굵은 한 줄. 색만으로 뜻을 전하지 않도록 글자로 말한다.
class _Band extends StatelessWidget {
  const _Band({required this.text, required this.ink, required this.bg, this.mark});
  final String text;
  final Color ink;
  final Color bg;
  final String? mark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        if (mark == null)
          Container(width: 10, height: 10, decoration: BoxDecoration(color: ink, shape: BoxShape.circle))
        else
          Text(mark!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink, height: 1.2)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink, height: 1.3)),
        ),
      ],
    ),
  );
}

class _AckedBox extends StatelessWidget {
  const _AckedBox();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 54),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: sage,
      borderRadius: BorderRadius.circular(Radii.button),
      border: Border.all(color: hoDoneLine, width: 1.5),
    ),
    alignment: Alignment.center,
    child: const Text(
      '✓ 확인함',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: T.body, color: brandDark, fontWeight: FontWeight.w700),
    ),
  );
}
