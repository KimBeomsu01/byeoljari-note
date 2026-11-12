// DESK-1 오늘 현황 (첫 화면, 원본 2장 + 통합 6-7-4·5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../alert_case/case_ui.dart' show CaseBadge, caseStatusLabel;
import 'desk_common.dart';

class DeskTodayView extends ConsumerStatefulWidget {
  const DeskTodayView({super.key, required this.onResident, required this.onCase});
  final ValueChanged<String> onResident;
  final ValueChanged<String> onCase;

  @override
  ConsumerState<DeskTodayView> createState() => _DeskTodayViewState();
}

class _DeskTodayViewState extends ConsumerState<DeskTodayView> {
  String? classFilter;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final stats = classStats(repo, now);
    final total = stats.fold<int>(0, (a, s) => a + s.members);
    final recorded = stats.fold<int>(0, (a, s) => a + s.recorded);
    final open = repo.openCases;
    final urgent = open.where((c) => c.isUrgent).length;
    final items = attentionItems(repo, now, classId: classFilter);

    return ListView(
      key: const PageStorageKey('desk-today'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        DeskHeading('오늘 현황', sub: '${mdLabel(now)} 기준 · 오늘 어느 별님을 먼저 살펴볼지 확인해요'),
        LayoutBuilder(builder: (context, c) {
          final tiles = [
            _SummaryTile(
              key: const ValueKey('desk-sum-recorded'),
              label: '오늘 체온 기록 있음',
              value: '$recorded명',
              note: '전체 $total명 중 · 여러 번 재도 한 명',
              color: brandDark,
            ),
            _SummaryTile(
              key: const ValueKey('desk-sum-none'),
              label: '오늘 체온 기록 없음',
              value: '${total - recorded}명',
              note: '오늘 측정값이 아직 없어요 (누락·이상 뜻 아님)',
              color: inkSub,
            ),
            _SummaryTile(
              key: const ValueKey('desk-sum-open'),
              label: '현재 대응 중',
              value: '${open.length}건',
              note: '⚠ 긴급 $urgent건 · 이상 대응 ${open.length - urgent}건',
              color: urgent > 0 ? stageColors[Stage.danger]!.ink : brandDark,
            ),
          ];
          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: Gap.m),
                Expanded(child: tiles[i]),
              ],
            ]),
          );
        }),
        const SizedBox(height: Gap.xl),
        Text('반별 오늘 측정 현황', style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: Gap.m),
          child: Text('반 이름을 누르면 아래 목록이 그 반으로 좁혀져요', style: TextStyle(fontSize: T.caption, color: inkSub)),
        ),
        DeskTable(
          rowHeight: 48,
          cols: const [
            DeskCol('반', flex: 3),
            DeskCol('인원', flex: 2),
            DeskCol('오늘 기록 인원', flex: 3),
            DeskCol('마지막 측정', flex: 3),
            DeskCol('진행 중 대응', flex: 3),
          ],
          rows: [
            for (final s in stats)
              DeskRow(
                key: ValueKey('desk-class-${s.c.id}'),
                selected: classFilter == s.c.id,
                onTap: () => setState(() => classFilter = classFilter == s.c.id ? null : s.c.id),
                cells: [
                  Row(children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(s.c.color), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Flexible(child: Text(s.c.name, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700))),
                  ]),
                  Text('${s.members}명', style: const TextStyle(fontSize: T.body)),
                  Text('${s.recorded} / ${s.members}명', style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700)),
                  Text(s.lastAt == null ? '오늘 기록 없음' : hhmm(s.lastAt!),
                      style: TextStyle(fontSize: T.body, color: s.lastAt == null ? inkSub : inkMain)),
                  Text(s.openCases == 0 ? '없음' : '${s.openCases}건',
                      style: TextStyle(
                          fontSize: T.body,
                          fontWeight: s.openCases == 0 ? FontWeight.w400 : FontWeight.w800,
                          color: s.openCases == 0 ? inkSub : stageColors[Stage.abnormal]!.ink)),
                ],
              ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        Row(children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: classFilter == null ? '먼저 살펴볼 별님' : '먼저 살펴볼 별님 · ${repo.classOf(classFilter!).name}'),
                TextSpan(text: '  ${items.length}', style: const TextStyle(color: inkSub)),
              ]),
              key: const ValueKey('desk-attention-title'),
              style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain),
            ),
          ),
          if (classFilter != null)
            OutlinedButton(onPressed: () => setState(() => classFilter = null), child: const Text('전체 반 보기')),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: Gap.m),
          child: Text('열린 긴급·이상 대응 건 + 오늘 주의가 나와 재측정을 기다리는 별님', style: TextStyle(fontSize: T.caption, color: inkSub)),
        ),
        DeskTable(
          empty: classFilter == null ? '지금 먼저 살펴볼 별님이 없어요' : '이 반에는 지금 먼저 살펴볼 별님이 없어요',
          cols: const [
            DeskCol('별님 · 반', flex: 4),
            DeskCol('최근 체온', flex: 3),
            DeskCol('평소 기준', flex: 3),
            DeskCol('판정', flex: 3),
            DeskCol('대응 상태', flex: 4),
          ],
          rows: [
            for (final it in items) _attentionRow(it, now),
          ],
        ),
      ],
    );
  }

  DeskRow _attentionRow(AttentionItem it, DateTime now) {
    final repo = ref.read(repoProvider);
    final r = it.resident;
    final m = it.measurement;
    final c = it.caseItem;
    final cls = repo.classOf(r.classId);
    return DeskRow(
      key: ValueKey('desk-att-${r.id}'),
      highlight: c != null && c.isUrgent ? stageColors[Stage.danger]!.soft : null,
      cells: [
        LinkCell(
          key: ValueKey('desk-att-name-${r.id}'),
          tooltip: '${r.name} 별님 기록 보기',
          onTap: () => widget.onResident(r.id),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            FaceAvatar.resident(r.id, size: 36),
            const SizedBox(width: 8),
            Flexible(
              child: TwoLine(r.name, cls.name,
                  const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: navy, decoration: TextDecoration.underline)),
            ),
          ]),
        ),
        TwoLine(tempText(m), m == null ? null : whenLabel(m.measuredAt, now)),
        Text(baselineText(repo.baselineOf(r.id, now)), style: const TextStyle(fontSize: T.caption, color: inkMain)),
        Align(alignment: Alignment.centerLeft, child: m == null ? const Text('기록 없음') : StageTag(m.judgment.stage)),
        if (c != null)
          LinkCell(
            key: ValueKey('desk-att-case-${c.id}'),
            tooltip: '대응 현황에서 보기',
            onTap: () => widget.onCase(c.id),
            child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              CaseBadge(c),
              Text(caseStatusLabel(c), style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: navy, decoration: TextDecoration.underline)),
            ]),
          )
        else
          TwoLine('! 재측정 할 일 열림', it.task?.dueAt == null ? null : '${hhmm(it.task!.dueAt!)}까지',
              TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: stageColors[Stage.caution]!.ink)),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({super.key, required this.label, required this.value, required this.note, required this.color});
  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: line)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 5, color: color),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(Gap.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: T.number + 4, fontWeight: FontWeight.w800, color: color)),
              Text(note, style: const TextStyle(fontSize: T.caption, color: inkSub)),
            ]),
          )),
        ]),
      );
}
