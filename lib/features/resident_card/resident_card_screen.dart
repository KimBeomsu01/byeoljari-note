// PF 별님카드 — 명세 없음, 통합 명세 6-6 최소안.
// 디자인: 개선 시안 5b — 누구(가운데 큰 얼굴) → 평소 체온 설명("37도면 열인가?"에 답하는 문장 + 14일 작은 그래프)
// → 목록 [투약 지침 ›] [대응 이력 N건 ›] [기록 모아보기 N건 ›].
// 큰 그래프·가장 높았던/낮았던 때는 작은 그래프를 누르면, 대응 이력 목록은 [대응 이력]을 누르면 시트로 열린다.
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
import '../archive/archive_timeline.dart';
import '../archive/archive_widgets.dart';
import 'temp_chart.dart';

/// 평소 체온을 쉬운 문장으로. 평소 범위는 판정 함수([judge])로 구한다 (화면에서 따로 계산하지 않는다).
String baselineSentence(BaselineResult b) {
  if (b.source == BaselineSource.provisional) {
    return '아직 기록이 적어서 ${formatTemp(b.value)}℃를 임시로 써요. '
        '기록이 $baselineMinRecords번 모이면 바뀌어요 (지금 ${b.count}번).';
  }
  var hi = b.value, lo = b.value;
  while (hi < maxTemp && judge(value: hi + 1, baseline: b.value).stage == Stage.normal) {
    hi++;
  }
  while (lo > minTemp && judge(value: lo - 1, baseline: b.value).stage == Stage.normal) {
    lo--;
  }
  final who = b.value >= 370
      ? '평소에 조금 높은 별님이에요.'
      : b.value <= 360
          ? '평소에 조금 낮은 별님이에요.'
          : '평소 체온이 보통인 별님이에요.';
  return '$who\n${formatTemp(lo)}~${formatTemp(hi)}℃는 평소 체온이에요.';
}

String _baselineSource(BaselineResult b) => switch (b.source) {
      BaselineSource.manual => '간호사가 정한 값',
      BaselineSource.median => '최근 14일 중간값',
      BaselineSource.provisional => '임시 값',
    };

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
      return const Scaffold(
        body: SafeArea(
          child: Column(children: [
            _BackRow(),
            Expanded(child: Center(child: EmptyNote('별님 정보를 불러오지 못했어요'))),
          ]),
        ),
      );
    }
    final cls = repo.classOf(r.classId);
    final baseline = repo.baselineOf(r.id, now);
    final from = now.subtract(baselineWindow);
    final points = repo.measurementsOf(r.id).where((m) => !m.isVoided && m.measuredAt.isAfter(from)).toList().reversed.toList();
    final cases = repo.casesOf(r.id);
    final guideline = repo.guidelineOf(r.id);
    String? guidelineAuthor;
    if (guideline != null) {
      try {
        guidelineAuthor = repo.staff(guideline.writtenBy).displayName;
      } catch (_) {
        guidelineAuthor = guideline.writtenBy;
      }
    }
    final recordCount = buildArchiveRecords(repo, r.id).length;

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
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, 40), children: [
          const _BackRow(),
          const SizedBox(height: 18),
          // ① 누구 — 가운데 큰 얼굴
          Column(children: [
            FaceAvatar.resident(r.id, size: 96),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text('${r.name} 별님',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: fontBig, fontSize: 28, fontWeight: FontWeight.w800, color: inkMain, height: 1.25)),
            ),
            const SizedBox(height: 8),
            Text('${cls.name} · 담임 ${repo.staff(cls.homeroomId).displayName}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: inkSub)),
          ]),
          const SizedBox(height: 18),

          // ② 평소 체온 — 숫자 + 쉬운 문장 + 14일 작은 그래프
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, children: [
                const Text('평소 체온', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: inkSub)),
                Text(_baselineSource(baseline), style: const TextStyle(fontSize: 14, color: Color(0xFF7A6458))),
              ]),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: formatTemp(baseline.value)),
                  const TextSpan(text: '℃', style: TextStyle(fontSize: 20)),
                ]),
                semanticsLabel: '${formatTemp(baseline.value)}℃',
                style: const TextStyle(
                  fontFamily: fontBig,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: inkMain,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              Text(baselineSentence(baseline), style: const TextStyle(fontSize: 16, height: 1.5, color: inkMain)),
              const SizedBox(height: 12),
              Semantics(
                button: points.isNotEmpty,
                label: _chartLabel(points, baseline.value),
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: points.isEmpty ? null : () => _showChartSheet(context, points, baseline.value, from, now),
                  child: TempSparkline(points: points, baseline: baseline.value, from: from, to: now),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),

          // ③ 더 보기 목록
          Material(
            color: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card), side: const BorderSide(color: line)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              _ListRow(
                label: '투약 지침',
                value: guidelineAuthor ?? '없음',
                onTap: () => showGuideline(context, ref, r.id),
              ),
              const Divider(height: 1, thickness: 1, color: lineSoft),
              _ListRow(
                label: '대응 이력',
                value: '${cases.length}건',
                onTap: () => _showCasesSheet(context, cases),
              ),
              const Divider(height: 1, thickness: 1, color: lineSoft),
              _ListRow(label: '기록 모아보기', value: '$recordCount건', onTap: openArchiveOnce),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _chartLabel(List<Measurement> points, int baseline) {
    if (points.isEmpty) return '최근 14일 체온 그래프. 최근 2주 동안 잰 체온이 없어요.';
    final values = points.map((m) => m.value);
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final off = points.where((m) => m.judgment.stage != Stage.normal).length;
    return '최근 14일 체온 그래프. 기록 ${points.length}건, 가장 낮은 ${formatTemp(lo)}도, '
        '가장 높은 ${formatTemp(hi)}도, 평소 체온 ${formatTemp(baseline)}도. 평소가 아닌 기록 $off건. 누르면 크게 봐요.';
  }

  static Future<void> _showChartSheet(BuildContext context, List<Measurement> points, int baseline, DateTime from, DateTime to) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const SheetTitle('최근 2주 체온'),
            const SizedBox(height: Gap.m),
            TempChart(points: points, baseline: baseline, from: from, to: to),
            const SizedBox(height: Gap.m),
            ..._summary(points),
            const SizedBox(height: Gap.s),
            const Text('점선은 평소 체온이에요', style: TextStyle(fontSize: T.caption, color: inkSub)),
            const Text('평소가 아닌 점에는 ! ▲ ⚠ ▼ 표시가 있어요', style: TextStyle(fontSize: T.caption, color: inkSub)),
          ]),
        ),
      );

  static Future<void> _showCasesSheet(BuildContext context, List<Case> cases) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
            children: [
              SheetTitle('대응 이력 ${cases.length}건'),
              const SizedBox(height: Gap.m),
              if (cases.isEmpty)
                const EmptyNote('대응 이력이 없어요')
              else
                for (final c in cases) Padding(padding: const EdgeInsets.only(bottom: 10), child: _CaseTile(c: c)),
            ],
          ),
        ),
      );

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
                    fontFamily: fontBig,
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

/// "‹ 별님카드" 뒤로 가기 줄.
class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: '뒤로: 별님카드 닫기',
          button: true,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.button),
            onTap: () => Navigator.of(context).maybePop(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: tapHeight, minWidth: tapHeight),
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('‹',
                      style: TextStyle(fontFamily: fontBig, fontSize: 32, fontWeight: FontWeight.w700, color: inkMain, height: 1)),
                  SizedBox(width: 10),
                  Text('별님카드',
                      style: TextStyle(fontFamily: fontBig, fontSize: 19, fontWeight: FontWeight.w700, color: inkMain)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// 목록 한 줄 (시안: 높이 58, 이름 굵게 · 오른쪽 회색 값 · ›).
class _ListRow extends StatelessWidget {
  const _ListRow({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label, $value',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text(label, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Text(value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: T.body, color: inkSub)),
                ),
                const SizedBox(width: 8),
                const Text('›', style: TextStyle(fontSize: T.body, color: inkSub)),
              ]),
            ),
          ),
        ),
      );
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
