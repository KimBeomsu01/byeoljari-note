// PF 별님카드 — 명세 없음, 통합 명세 6-6 최소안.
// 프로필 · 평소 체온(기저치)과 최근 14일 그래프 · [투약 지침 보기] · 대응 이력(S9) · [이 별님의 기록 아카이브].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/baseline.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
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
        appBar: AppBar(title: const Text('별님카드')),
        body: const Center(child: Text('별님 정보를 불러오지 못했어요')),
      );
    }
    final cls = repo.classOf(r.classId);
    final baseline = repo.baselineOf(r.id, now);
    final from = now.subtract(baselineWindow);
    final points = repo.measurementsOf(r.id).where((m) => !m.isVoided && m.measuredAt.isAfter(from)).toList().reversed.toList();
    final cases = repo.casesOf(r.id);

    Widget section(String title, List<Widget> children) => Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            const SizedBox(height: 8),
            ...children,
          ]),
        );

    final baselineExplain = switch (baseline.source) {
      BaselineSource.manual => '간호사가 직접 정한 값이에요. 기록으로 계산한 값보다 먼저 써요.',
      BaselineSource.median => '최근 14일 중앙값: 최근 14일 동안 이상·위험·저온이 아니었던 체온 ${baseline.count}건의 가운데 값이에요.',
      BaselineSource.provisional => '기록이 $baselineMinRecords건 모이기 전까지는 36.5℃를 임시로 써요.',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('별님카드')),
      body: ListView(padding: const EdgeInsets.only(top: 8, bottom: 24), children: [
        // 프로필
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            InitialAvatar(name: r.name, color: cls.color, radius: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text(cls.name, style: const TextStyle(color: inkSub)),
                Text('담임 ${repo.staff(cls.homeroomId).displayName}', style: const TextStyle(color: inkSub)),
              ]),
            ),
          ]),
        ),

        section('평소 체온', [
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
            Text('${formatTemp(baseline.value)}℃', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(baseline.note, style: const TextStyle(color: inkSub, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(baselineExplain, style: const TextStyle(color: inkSub, fontSize: 13)),
          const SizedBox(height: 12),
          const Text('최근 14일 체온', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          TempChart(points: points, baseline: baseline.value, from: from, to: now),
          const SizedBox(height: 4),
          Text(
            '점선 = 평소 체온 · 점 색과 기호 = 판정 (${[
              for (final s in Stage.values) '${s.symbol} ${s.label}',
            ].join(' / ')})',
            style: const TextStyle(color: inkSub, fontSize: 12),
          ),
        ]),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.white),
            icon: const Icon(Icons.medication_outlined),
            label: const Text('투약 지침 보기'),
            onPressed: () => showGuideline(context, ref, r.id),
          ),
        ),

        section('대응 이력', [
          if (cases.isEmpty)
            const Text('대응 이력이 없어요.', style: TextStyle(color: inkSub))
          else
            for (final c in cases) Padding(padding: const EdgeInsets.only(bottom: 8), child: _CaseTile(c: c)),
        ]),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: brandDark),
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('이 별님의 기록 아카이브'),
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
        ),
      ]),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.c});
  final Case c;

  String get _status => switch (c.status) {
        CaseStatus.closed => '종료${c.closeReason != null ? ' · ${c.closeReason}' : ''}',
        _ when c.recoveredAt != null => '종료 대기',
        CaseStatus.unacked => '진행 중 · 확인 전',
        CaseStatus.acked => '진행 중 · 확인됨',
        CaseStatus.active => '진행 중 · 대응 단계 ${c.stage}',
        CaseStatus.waitingRemeasure => '진행 중 · 재측정 대기',
      };

  @override
  Widget build(BuildContext context) {
    final sc = stageColors[c.severity]!;
    final d = c.createdAt;
    return Material(
      color: c.isOpen ? sc.soft : const Color(0xFFF1EFE8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openCaseDetail(context, c.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(c.kindLabel, style: TextStyle(fontWeight: FontWeight.w800, color: sc.ink)),
                    StageBadge(c.severity, dense: true),
                  ]),
                  const SizedBox(height: 2),
                  Text('${d.year}.${d.month}.${d.day} ${hhmm(d)} · 처음 ${formatTemp(c.firstTemp)}℃', style: const TextStyle(fontSize: 13)),
                  Text(_status, style: const TextStyle(fontSize: 13, color: inkSub)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: inkSub),
            ]),
          ),
        ),
      ),
    );
  }
}
