// PF 별님카드 — 명세 없음, 통합 명세 6-6 최소안.
// 누구 → 평소 체온(기저치) → [투약 지침 보기]·[기록 모아보기] → 최근 2주 그래프 → 대응 이력(S9).
// 디자인: docs/design.md v2 — 모바일 아카이브 시제품과 같은 모양(얼굴 그림, 흰 카드, 옅은 판정 상자).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/baseline.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../alert_case/alert_sheet.dart';
import '../archive/archive_screen.dart';
import '../archive/archive_widgets.dart';
import 'temp_chart.dart';

class ResidentCardScreen extends ConsumerWidget {
  const ResidentCardScreen({super.key, required this.residentId});
  final String residentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = ref.read(clockProvider)();

    final Resident r;
    try {
      r = repo.resident(residentId);
    } catch (_) {
      return Scaffold(
        appBar: prototypeAppBar('별님카드'),
        body: const Center(child: EmptyNote('별님 정보를 불러오지 못했어요')),
      );
    }
    final cls = repo.classOf(r.classId);
    final baseline = repo.baselineOf(r.id, now);
    final from = now.subtract(baselineWindow);
    final points = repo.measurementsOf(r.id).where((m) => !m.isVoided && m.measuredAt.isAfter(from)).toList().reversed.toList();
    final cases = repo.casesOf(r.id);

    final (explain, explain2) = switch (baseline.source) {
      BaselineSource.manual => ('간호사가 직접 정한 값이에요', '기록으로 계산한 값보다 먼저 써요'),
      BaselineSource.median => ('최근 2주 동안 잰 체온의 가운데 값이에요', '이상·위험·저온이었던 때는 빼고, ${baseline.count}번 잰 값으로 계산했어요'),
      BaselineSource.provisional => (
          '아직 기록이 적어서 36.5℃를 임시로 써요',
          '기록이 $baselineMinRecords번 모이면 바뀌어요 (지금 ${baseline.count}번)'
        ),
    };

    const caption = TextStyle(fontSize: T.caption, color: inkSub, height: 1.45);
    final normal = stageColors[Stage.normal]!;

    void openArchiveOnce() {
      // 아카이브에서 들어왔으면 새로 쌓지 않고 그 화면으로 돌아간다 (화면이 돌고 도는 것 방지).
      final open = ArchiveScreen.openRouteFor(r.id);
      if (open != null) {
        Navigator.of(context).popUntil((route) => route == open);
      } else {
        openArchive(context, r.id);
      }
    }

    return Scaffold(
      appBar: prototypeAppBar('별님카드'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 120), children: [
        const Padding(padding: EdgeInsets.only(left: 0), child: BackLink('돌아가기')),
        // ① 누구 — 큰 얼굴 그림
        InfoCard(
          padding: const EdgeInsets.fromLTRB(Gap.l, 16, Gap.l, 16),
          child: Row(children: [
            FaceAvatar.resident(r.id, size: 76),
            const SizedBox(width: Gap.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.name} 별님',
                    style: const TextStyle(fontSize: T.headline - 1, fontWeight: FontWeight.w800, color: inkMain, height: 1.3)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: Color(cls.color), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: Text(cls.name, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain))),
                ]),
                Text('담임 ${repo.staff(cls.homeroomId).displayName}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
              ]),
            ),
          ]),
        ),

        // ② 평소 체온 — 시제품 .tempbox처럼 옅은 초록 상자, 큰 숫자는 오른쪽
        const SectionTitle('평소 체온'),
        InfoCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(color: normal.soft, borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                Expanded(
                  child: Text('지금 쓰는 평소 체온',
                      style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: normal.ink)),
                ),
                const SizedBox(width: Gap.s),
                Text('${formatTemp(baseline.value)}℃',
                    style: TextStyle(
                      fontSize: T.number,
                      fontWeight: FontWeight.w800,
                      color: normal.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ]),
            ),
            const SizedBox(height: Gap.m),
            Text(explain, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
            Text(explain2, style: caption),
          ]),
        ),

        // ③ 할 수 있는 것 — 넓으면 2열, 좁거나 글자가 크면 위아래
        const SizedBox(height: Gap.l),
        _TwoButtons(
          left: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => showGuideline(context, ref, r.id),
            child: const Text('투약 지침 보기', textAlign: TextAlign.center),
          ),
          right: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: openArchiveOnce,
            child: const Text('기록 모아보기', textAlign: TextAlign.center),
          ),
        ),

        // 그래프
        const SectionTitle('최근 2주 체온'),
        InfoCard(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TempChart(points: points, baseline: baseline.value, from: from, to: now),
            if (points.isNotEmpty) ...[
              const SizedBox(height: Gap.m),
              ..._summary(points),
              const SizedBox(height: Gap.s),
              const Text('점선은 평소 체온이에요', style: caption),
              const Text('평소가 아닌 점에는 ! ▲ ⚠ ▼ 표시가 있어요', style: caption),
            ],
          ]),
        ),

        // ④ 대응 이력
        SectionTitle('대응 이력', count: cases.length),
        if (cases.isEmpty)
          const InfoCard(child: Text('대응 이력이 없어요', style: TextStyle(fontSize: T.body, color: inkSub)))
        else
          for (final c in cases) Padding(padding: const EdgeInsets.only(bottom: 10), child: _CaseTile(c: c)),
      ]),
    );
  }

  static List<Widget> _summary(List<Measurement> points) {
    var hi = points.first, lo = points.first;
    for (final m in points) {
      if (m.value > hi.value) hi = m;
      if (m.value < lo.value) lo = m;
    }
    final off = points.where((m) => m.judgment.stage != Stage.normal).length;
    String day(DateTime d) => '${d.month}월 ${d.day}일';
    Widget tile(String label, Measurement m) => Expanded(
          child: GreyBox(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
              Text('${formatTemp(m.value)}℃',
                  style: const TextStyle(
                    fontSize: T.title + 1,
                    fontWeight: FontWeight.w800,
                    color: inkMain,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
              Text(day(m.measuredAt), style: const TextStyle(fontSize: T.caption, color: inkSub)),
            ]),
          ),
        );
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        tile('가장 높았던 때', hi),
        const SizedBox(width: Gap.s),
        tile('가장 낮았던 때', lo),
      ]),
      const SizedBox(height: Gap.s),
      Text(off == 0 ? '2주 동안 모두 평소 체온이었어요' : '평소와 다른 체온: ${points.length}번 중 $off번',
          style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
    ];
  }
}

/// 버튼 두 개: 한 줄에 들어가면 2열, 아니면 위아래.
class _TwoButtons extends StatelessWidget {
  const _TwoButtons({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final tp = TextPainter(
      text: TextSpan(text: '투약 지침 보기', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, fontFamily: family)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
    )..layout();
    return LayoutBuilder(builder: (context, c) {
      final half = (c.maxWidth - Gap.s) / 2;
      if (tp.width + 40 <= half) {
        return Row(children: [Expanded(child: left), const SizedBox(width: Gap.s), Expanded(child: right)]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: Gap.s), right]);
    });
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.c});
  final Case c;

  String get _status => switch (c.status) {
        CaseStatus.closed => '종료${c.closeReason != null ? ' · ${c.closeReason}' : ''}',
        _ when c.recoveredAt != null => '종료 기다리는 중',
        CaseStatus.unacked => '진행 중 · 아직 확인 전',
        CaseStatus.acked => '진행 중 · 확인했어요',
        CaseStatus.active => '진행 중 · 대응 ${c.stage}단계',
        CaseStatus.waitingRemeasure => '진행 중 · 다시 재기 기다리는 중',
      };

  @override
  Widget build(BuildContext context) {
    final sc = stageColors[c.severity]!;
    final d = c.createdAt;
    return InfoCard(
      background: c.isOpen ? const Color(0xFFFFF7F6) : null,
      accent: null,
      onTap: () => openCaseDetail(context, c.id),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusPill(c.kindLabel, color: sc.ink, background: sc.soft),
                Text('처음 ${formatTemp(c.firstTemp)}℃',
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
              ]),
              const SizedBox(height: 6),
              Text('${d.year}년 ${d.month}월 ${d.day}일 ${hhmm(d)}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
              Text(_status, style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: c.isOpen ? sc.ink : inkMain)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: inkSub, size: 28),
        ]),
      ),
    );
  }
}
