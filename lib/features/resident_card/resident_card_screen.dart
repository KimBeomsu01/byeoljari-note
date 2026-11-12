// PF 별님카드 — 명세 없음, 통합 명세 6-6 최소안.
// 누구 → 평소 체온(기저치) → [투약 지침 보기]·[기록 모아보기] → 최근 2주 그래프 → 대응 이력(S9).
// 디자인: docs/design.md.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/baseline.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../alert_case/alert_sheet.dart';
import '../archive/archive_screen.dart';
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
        appBar: AppBar(title: const Text('별님카드')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('별님카드')),
      body: ListView(padding: const EdgeInsets.fromLTRB(Gap.page, Gap.s, Gap.page, 120), children: [
        // ① 누구
        InfoCard(
          child: Row(children: [
            ExcludeSemantics(child: ResidentAvatar(name: r.name, classColor: cls.color, size: 72)),
            const SizedBox(width: Gap.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: const TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain)),
                Text(cls.name, style: const TextStyle(fontSize: T.body, color: inkMain)),
                Text('담임 ${repo.staff(cls.homeroomId).displayName}', style: const TextStyle(fontSize: T.body, color: inkSub)),
              ]),
            ),
          ]),
        ),

        // ② 평소 체온
        const SectionTitle('평소 체온'),
        InfoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${formatTemp(baseline.value)}℃',
                style: const TextStyle(
                  fontSize: T.number,
                  fontWeight: FontWeight.w800,
                  color: inkMain,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
            const SizedBox(height: Gap.xs),
            Text(explain, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain)),
            Text(explain2, style: caption),
          ]),
        ),
        // ③ 할 수 있는 것
        const SizedBox(height: Gap.xl),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
          icon: const Icon(Icons.medication_outlined),
          label: const Text('투약 지침 보기'),
          onPressed: () => showGuideline(context, ref, r.id),
        ),
        const SizedBox(height: Gap.m),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('기록 모아보기'),
          onPressed: () {
            // 아카이브에서 들어왔으면 새로 쌓지 않고 그 화면으로 돌아간다 (화면이 돌고 도는 것 방지).
            final open = ArchiveScreen.openRouteFor(r.id);
            if (open != null) {
              Navigator.of(context).popUntil((route) => route == open);
            } else {
              openArchive(context, r.id);
            }
          },
        ),

        // 그래프
        const SectionTitle('최근 2주 체온'),
        InfoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TempChart(points: points, baseline: baseline.value, from: from, to: now),
            if (points.isNotEmpty) ...[
              const SizedBox(height: Gap.m),
              const Divider(),
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
          for (final c in cases) Padding(padding: const EdgeInsets.only(bottom: Gap.m), child: _CaseTile(c: c)),
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
    const style = TextStyle(fontSize: T.body, color: inkMain);
    return [
      Text('가장 높았던 때: ${formatTemp(hi.value)}℃ (${day(hi.measuredAt)})', style: style),
      Text('가장 낮았던 때: ${formatTemp(lo.value)}℃ (${day(lo.measuredAt)})', style: style),
      Text(off == 0 ? '2주 동안 모두 평소 체온이었어요' : '평소와 다른 체온: ${points.length}번 중 $off번',
          style: style.copyWith(fontWeight: FontWeight.w700)),
    ];
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
      accent: c.isOpen ? sc.line : null,
      onTap: () => openCaseDetail(context, c.id),
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.s, Gap.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusPill(c.kindLabel, color: sc.ink, background: sc.soft),
                Text('처음 ${formatTemp(c.firstTemp)}℃',
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
              ]),
              const SizedBox(height: Gap.xs),
              Text('${d.year}년 ${d.month}월 ${d.day}일 ${hhmm(d)}', style: const TextStyle(fontSize: T.body, color: inkMain)),
              Text(_status, style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: c.isOpen ? sc.ink : inkSub)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: inkSub, size: 28),
        ]),
      ),
    );
  }
}
