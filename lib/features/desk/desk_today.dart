// DESK-1 오늘 현황 (첫 화면, 원본 2장 + 통합 6-7-4·5).
// 개선 시안 6 "오늘 전체에서 누가 걱정이고, 어디가 비었나?":
// 한 문장 요약 → 먼저 살펴볼 별님 카드 → 반별 오늘 체온 기록 타일, 오른쪽에 고른 별님 상세.
// 조회용: 여기서 열고 닫아도 확인·담당 상태는 바뀌지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../alert_case/case_ui.dart' show acksOf, caseBadge, caseColors, caseStatusLabel, circledStage, eventActor, eventText, staffName;
import 'desk_common.dart';

/// 시안의 옅은 글자색 (준비 중 메뉴, 지나지 않은 단계).
const Color deskMuted = Color(0xFF7A6458);

/// 진행 막대의 빈 부분.
const Color _track = Color(0xFFEAD9D2);

/// 시안의 선택·보조 초록 면.
const Color deskSelected = Color(0xFFEEF5EA);

const _stageShort = ['관찰', '조제', '처방', '병원'];

class DeskTodayView extends ConsumerStatefulWidget {
  const DeskTodayView({super.key, required this.onResident, required this.onCase, this.onClass});
  final ValueChanged<String> onResident;
  final ValueChanged<String> onCase;

  /// 반 타일을 누르면 그 반 별님 기록으로.
  final ValueChanged<String>? onClass;

  @override
  ConsumerState<DeskTodayView> createState() => _DeskTodayViewState();
}

class _DeskTodayViewState extends ConsumerState<DeskTodayView> {
  /// 고른 별님 (없으면 첫 번째 줄을 오른쪽에 보여 준다).
  String? selectedResident;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final stats = classStats(repo, now);
    final total = stats.fold<int>(0, (a, s) => a + s.members);
    final recorded = stats.fold<int>(0, (a, s) => a + s.recorded);
    final items = attentionItems(repo, now);
    final open = repo.openCases;
    final urgent = open.where((c) => c.isUrgent).length;
    final recheck = items.where((i) => i.caseItem == null).length;

    AttentionItem? shown;
    for (final it in items) {
      if (it.resident.id == selectedResident) shown = it;
    }
    shown ??= items.isEmpty ? null : items.first;

    final main = <Widget>[
      _Heading(now: now, urgent: urgent, abnormal: open.length - urgent, recheck: recheck, noRecord: total - recorded),
      const SizedBox(height: 24),
      _sectionTitle('먼저 살펴볼 별님 ${items.length}', key: const ValueKey('desk-attention-title')),
      const SizedBox(height: 10),
      if (items.isEmpty)
        const _EmptyBox('지금 먼저 살펴볼 별님이 없어요')
      else
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _AttentionCard(
            item: items[i],
            now: now,
            selected: selectedResident != null && items[i].resident.id == shown?.resident.id,
            onTap: () => setState(() => selectedResident = items[i].resident.id),
          ),
        ],
      const SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.end, children: [
        _sectionTitle('반별 오늘 체온 기록'),
        const Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Text('반을 누르면 그 반 별님 기록으로', style: TextStyle(fontSize: T.caption, color: inkSub)),
        ),
      ]),
      const SizedBox(height: 10),
      _ClassTiles(stats: stats, repo: repo, onClass: widget.onClass),
    ];

    final detail = shown == null
        ? null
        : _DetailCard(
            key: ValueKey('desk-detail-${shown.resident.id}'),
            item: shown,
            now: now,
            onResident: widget.onResident,
            onCase: widget.onCase,
          );

    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth >= 940 && detail != null;
      if (side) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ListView(
              key: const PageStorageKey('desk-today'),
              padding: const EdgeInsets.only(bottom: 32),
              children: main,
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 336,
            child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 32), child: detail),
          ),
        ]);
      }
      return ListView(
        key: const PageStorageKey('desk-today'),
        padding: const EdgeInsets.only(bottom: 32),
        children: [...main, if (detail != null) ...[const SizedBox(height: 24), detail]],
      );
    });
  }
}

Widget _sectionTitle(String text, {Key? key}) => Text(text,
    key: key, style: const TextStyle(fontFamily: fontBig, fontSize: 20, fontWeight: FontWeight.w700, color: inkMain, height: 1.35));

/// 날짜 · 갱신 시각 + 제목 + 한 문장 요약 (큰 숫자 카드 3개 → 문장 하나).
class _Heading extends StatelessWidget {
  const _Heading({required this.now, required this.urgent, required this.abnormal, required this.recheck, required this.noRecord});
  final DateTime now;
  final int urgent;
  final int abnormal;
  final int recheck;
  final int noRecord;

  @override
  Widget build(BuildContext context) {
    final danger = stageColors[Stage.danger]!.ink;
    final parts = <List<InlineSpan>>[
      if (urgent > 0) [const TextSpan(text: '긴급 '), TextSpan(text: '$urgent건', style: TextStyle(color: danger))],
      if (abnormal > 0) [const TextSpan(text: '이상 대응 '), TextSpan(text: '$abnormal건', style: TextStyle(color: stageColors[Stage.abnormal]!.ink))],
      if (recheck > 0) [const TextSpan(text: '다시 잴 별님 '), TextSpan(text: '$recheck명', style: TextStyle(color: stageColors[Stage.caution]!.ink))],
      if (noRecord > 0) [const TextSpan(text: '오늘 체온 기록 없는 별님 '), TextSpan(text: '$noRecord명', style: const TextStyle(color: inkSub))],
    ];
    final spans = <InlineSpan>[
      if (urgent == 0) const TextSpan(text: '긴급은 없어요. '),
    ];
    if (parts.isEmpty) {
      spans.add(const TextSpan(text: '먼저 살펴볼 별님이 없고, 오늘 모든 별님 체온이 기록됐어요.'));
    } else {
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) spans.add(const TextSpan(text: ', '));
        spans.addAll(parts[i]);
      }
      spans.add(const TextSpan(text: '이에요.'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${mdLabel(now)} · ${hhmm(now)} 갱신', key: const ValueKey('desk-updated'), style: const TextStyle(fontSize: 16, color: inkSub)),
      const SizedBox(height: 6),
      const Text('오늘 현황', style: TextStyle(fontFamily: fontBig, fontSize: 32, fontWeight: FontWeight.w800, color: inkMain, height: 1.3)),
      const SizedBox(height: 6),
      Text.rich(TextSpan(children: spans),
          key: const ValueKey('desk-summary'),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: inkMain, height: 1.5)),
    ]);
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
        child: EmptyNote(text),
      );
}

/// 판정 기호·이름 · 평소와의 차이: "▲ 이상 · 평소 +1.4".
String _stageLine(Measurement m) => '${m.judgment.stage.symbol} ${m.judgment.stage.label} · 평소 ${formatDiff(m.judgment.diff)}';

/// 먼저 살펴볼 별님 한 장: 얼굴 | 이름·반 | 체온·판정 | 상태 두 줄.
class _AttentionCard extends ConsumerWidget {
  const _AttentionCard({required this.item, required this.now, required this.selected, required this.onTap});
  final AttentionItem item;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final r = item.resident;
    final m = item.measurement;
    final c = item.caseItem;
    final cls = repo.classOf(r.classId);
    final stage = m?.judgment.stage ?? Stage.normal;
    final ink = m == null ? inkMain : stageColors[stage]!.ink;
    final unacked = c != null && c.isOpen && acksOf(repo, c.id).isEmpty;

    // 테두리: 아직 아무도 확인 안 한 건은 판정 색 굵은 선 (글자 "아직 아무도 확인 안 함"과 함께).
    final border = unacked
        ? BorderSide(color: caseColors(c).line, width: 2)
        : selected
            ? const BorderSide(color: brandDark, width: 2)
            : const BorderSide(color: line);

    final String status1;
    final String status2;
    Color status1Color = inkMain;
    if (c != null) {
      if (unacked) {
        status1 = '● 아직 아무도 확인 안 함';
        status1Color = stageColors[Stage.danger]!.ink;
      } else {
        final who = c.assigneeId == null ? '담당 없음' : '담당 ${staffName(repo, c.assigneeId!)}';
        status1 = '${caseStatusLabel(c)} · $who';
      }
      status2 = '${circledStage[(c.stage - 1).clamp(0, 3)]} ${InMemoryRepository.stageLabel(c.stage)} · ${whenLabel(c.createdAt, now)}부터';
    } else {
      final due = item.task?.dueAt;
      status1 = due == null ? '다시 재기 예정' : '${hhmm(due)} 다시 재기 예정';
      status2 = m == null ? '' : '${whenLabel(m.measuredAt, now)} ${staffName(repo, m.recordedBy)} 측정';
    }

    final name = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(r.name, style: const TextStyle(fontFamily: fontBig, fontSize: 19, fontWeight: FontWeight.w700, color: inkMain)),
      Text(cls.name, style: const TextStyle(fontSize: T.caption, color: inkSub)),
    ]);
    final temp = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(tempText(m), style: TextStyle(fontFamily: fontBig, fontSize: m == null ? 19 : 26, fontWeight: FontWeight.w800, color: ink)),
      if (m != null) Text(_stageLine(m), style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: ink)),
    ]);
    final status = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(status1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: status1Color)),
      if (status2.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(status2, style: const TextStyle(fontSize: T.caption, color: inkSub)),
      ],
    ]);

    return Semantics(
      button: true,
      selected: selected,
      label: '${r.name} 별님 자세히 보기',
      child: Material(
        key: ValueKey('desk-att-${r.id}'),
        color: c != null && c.isUrgent ? stageColors[Stage.danger]!.soft : surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: border),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: LayoutBuilder(builder: (context, box) {
              // 넓으면 시안처럼 4칸, 좁으면 얼굴 옆에 이름·체온, 아래 상태.
              if (box.maxWidth >= 520) {
                return Row(children: [
                  FaceAvatar.resident(r.id, size: 52),
                  const SizedBox(width: 12),
                  Expanded(flex: 8, child: name),
                  const SizedBox(width: 12),
                  Expanded(flex: 10, child: temp),
                  const SizedBox(width: 12),
                  Expanded(flex: 16, child: status),
                ]);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  FaceAvatar.resident(r.id, size: 52),
                  const SizedBox(width: 12),
                  Expanded(child: name),
                  const SizedBox(width: 12),
                  Flexible(child: temp),
                ]),
                const SizedBox(height: 10),
                status,
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

/// 반 타일 6개 + 진행 막대. 기록이 다 안 된 반만 노란 테두리.
class _ClassTiles extends StatelessWidget {
  const _ClassTiles({required this.stats, required this.repo, this.onClass});
  final List<ClassStat> stats;
  final InMemoryRepository repo;
  final ValueChanged<String>? onClass;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 480 ? 3 : 2;
        final w = (box.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final s in stats) SizedBox(width: w, child: _tile(s)),
        ]);
      });

  Widget _tile(ClassStat s) {
    final full = s.members == 0 || s.recorded >= s.members;
    final caution = stageColors[Stage.caution]!;
    final cases = repo.openCases.where((c) => c.classId == s.c.id).toList();
    final anyUrgent = cases.any((c) => c.isUrgent);
    final last = s.lastAt == null ? '오늘 측정 없음' : '마지막 측정 ${hhmm(s.lastAt!)}';
    final ratio = s.members == 0 ? 0.0 : s.recorded / s.members;
    return Tooltip(
      message: last,
      child: Semantics(
        button: true,
        label: '${s.c.name} 오늘 체온 기록 ${s.members}명 중 ${s.recorded}명'
            '${cases.isEmpty ? '' : ', 진행 중 대응 ${cases.length}건'}, $last. 누르면 그 반 별님 기록',
        excludeSemantics: true,
        child: Material(
          key: ValueKey('desk-class-${s.c.id}'),
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: full ? const BorderSide(color: line) : BorderSide(color: caution.line, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onClass == null ? null : () => onClass!(s.c.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(s.c.color), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.c.name, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain))),
                  if (cases.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(anyUrgent ? '⚠ ${cases.length}' : '▲ ${cases.length}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: stageColors[anyUrgent ? Stage.danger : Stage.abnormal]!.ink)),
                  ],
                  const SizedBox(width: 6),
                  Text('${s.recorded}/${s.members}',
                      style: TextStyle(fontFamily: fontBig, fontSize: T.body, fontWeight: FontWeight.w700, color: full ? inkMain : caution.ink)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(children: [
                      if (ratio > 0) Expanded(flex: (ratio * 1000).round(), child: Container(color: brandDark)),
                      if (ratio < 1) Expanded(flex: ((1 - ratio) * 1000).round(), child: Container(color: _track)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 오른쪽 상세: 고른 별님(없으면 첫 줄)의 상태 · 단계 · 확인/담당/알린 사람 · 대응 기록.
class _DetailCard extends ConsumerWidget {
  const _DetailCard({super.key, required this.item, required this.now, required this.onResident, required this.onCase});
  final AttentionItem item;
  final DateTime now;
  final ValueChanged<String> onResident;
  final ValueChanged<String> onCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final r = item.resident;
    final c = item.caseItem;
    final cls = repo.classOf(r.classId);
    Measurement? m = item.measurement;
    if (c != null) m = latestOfCaseOrNull(repo, c.id) ?? m;
    final stage = m?.judgment.stage ?? Stage.caution;
    final col = c != null ? caseColors(c) : stageColors[stage]!;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: col.ink, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(c != null ? caseBadge(c) : '${Stage.caution.symbol} 다시 잴 별님',
          style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: Colors.white)),
    );

    Widget row(String k, String v, {bool last = false, Color? color, bool strong = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: lineSoft))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 84, child: Text(k, style: const TextStyle(fontSize: 16, color: inkSub))),
            Expanded(
              child: Text(v, style: TextStyle(fontSize: 16, color: color ?? inkMain, fontWeight: strong ? FontWeight.w700 : FontWeight.w400)),
            ),
          ]),
        );

    final rows = <Widget>[];
    final timeline = <(DateTime, String)>[];
    if (c != null) {
      final acks = acksOf(repo, c.id);
      rows
        ..add(acks.isEmpty
            ? row('확인', '아직 아무도 안 함', color: stageColors[Stage.danger]!.ink, strong: true)
            : row('확인', acks.map((e) => '${staffName(repo, e.actorId)} ${hhmm(e.at)}').join(', ')))
        ..add(row('담당', c.assigneeId == null ? '아직 없어요' : staffName(repo, c.assigneeId!)));
      if (c.remeasureAt != null) rows.add(row('재측정', '${hhmm(c.remeasureAt!)} 예정'));
      rows.add(row('알린 사람', _recipientsText(repo, c.id), last: true));

      for (final e in repo.eventsOf(c.id)) {
        if (e.voidedBy != null) continue;
        timeline.add((e.at, deskEventText(repo, e)));
      }
      for (final n in _noticesOf(repo, c.id)) {
        timeline.add((n.at, '알림 보냄'));
      }
      timeline.sort((a, b) => a.$1.compareTo(b.$1));
    } else {
      final due = item.task?.dueAt;
      rows
        ..add(row('다시 재기', due == null ? (item.task?.duePreset ?? '예정') : '${hhmm(due)} 예정', strong: true))
        ..add(row('잰 사람', m == null ? '기록 없음' : '${staffName(repo, m.recordedBy)} · ${whenLabel(m.measuredAt, now)}', last: true));
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
          pill,
          if (c != null)
            Text('${whenLabel(c.createdAt, now)} 시작', style: const TextStyle(fontSize: T.caption, color: inkSub))
          else if (m != null)
            Text('${whenLabel(m.measuredAt, now)} 측정', style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
        const SizedBox(height: 16),
        Text('${cls.name} ${r.name} 별님',
            key: const ValueKey('desk-detail-title'),
            style: const TextStyle(fontFamily: fontBig, fontSize: 24, fontWeight: FontWeight.w800, color: inkMain, height: 1.3)),
        const SizedBox(height: 2),
        Text(m == null ? '오늘 체온 기록 없음' : '${formatTemp(m.value)}℃ · ${plainDiff(m.judgment.diff)}',
            style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: m == null ? inkSub : stageColors[stage]!.ink)),
        if (c != null) ...[
          const SizedBox(height: 16),
          DeskStageBar(stage: c.stage),
        ],
        const SizedBox(height: 16),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: lineSoft))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
        if (timeline.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('대응 기록', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
          for (final t in timeline) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 48, child: Text(hhmm(t.$1), style: const TextStyle(fontSize: T.caption, color: inkSub))),
              const SizedBox(width: 6),
              Expanded(child: Text(t.$2, style: const TextStyle(fontSize: T.caption, color: inkMain))),
            ]),
          ],
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _SoftButton(
            key: const ValueKey('desk-detail-resident'),
            label: '별님 기록 보기',
            onTap: () => onResident(r.id),
          ),
          if (c != null)
            _SoftButton(
              key: const ValueKey('desk-detail-case'),
              label: '대응 현황에서 보기',
              onTap: () => onCase(c.id),
            ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFF7EFEC), borderRadius: BorderRadius.circular(12)),
          child: const Text('사무국 화면은 보기 전용이에요. 여기서 열고 닫아도 확인·담당 상태는 바뀌지 않아요.',
              style: TextStyle(fontSize: T.caption, color: inkSub, height: 1.5)),
        ),
      ]),
    );
  }
}

/// 연한 초록 보조 버튼 (높이 52).
class _SoftButton extends StatelessWidget {
  const _SoftButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: deskSelected,
        borderRadius: BorderRadius.circular(Radii.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.button),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: tapHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: brandDark)),
          ),
        ),
      );
}

/// 대응 단계 막대 4칸 + 이름. 지금 단계까지 초록으로 채우고, 지금 단계 이름은 굵게.
class DeskStageBar extends StatelessWidget {
  const DeskStageBar({required this.stage});
  final int stage;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '대응 단계 ${circledStage[(stage - 1).clamp(0, 3)]} ${InMemoryRepository.stageLabel(stage)}',
        excludeSemantics: true,
        child: Column(children: [
          Row(children: [
            for (var s = 1; s <= 4; s++) ...[
              if (s > 1) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: s <= stage ? brandDark : _track, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Row(children: [
            for (var s = 1; s <= 4; s++) ...[
              if (s > 1) const SizedBox(width: 4),
              Expanded(
                child: Text('${circledStage[s - 1]} ${_stageShort[s - 1]}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: s == stage ? FontWeight.w700 : FontWeight.w400,
                      color: s == stage ? brandDark : deskMuted,
                    )),
              ),
            ],
          ]),
        ]),
      );
}

Measurement? latestOfCaseOrNull(InMemoryRepository repo, String caseId) {
  final list = repo.measurementsOfCase(caseId).where((m) => !m.isVoided).toList();
  return list.isEmpty ? null : list.last;
}

/// 이 건으로 보낸 알림 (받는 사람별 목록을 모아 한 번씩).
List<AppNotice> _noticesOf(InMemoryRepository repo, String caseId) {
  final seen = <String>{};
  final out = <AppNotice>[];
  for (final s in repo.allStaff) {
    for (final n in repo.noticesFor(s.id)) {
      if (n.caseId == caseId && seen.add(n.id)) out.add(n);
    }
  }
  return out;
}

/// "간호사 1 · 근무 4 · 사무국 2" (처음 알림을 받은 사람 기준).
String _recipientsText(InMemoryRepository repo, String caseId) {
  final ns = _noticesOf(repo, caseId)..sort((a, b) => a.at.compareTo(b.at));
  if (ns.isEmpty) return '아직 없어요';
  final counts = <Role, int>{};
  for (final id in ns.first.recipientIds) {
    Role role;
    try {
      role = repo.staff(id).role;
    } catch (_) {
      continue;
    }
    counts[role] = (counts[role] ?? 0) + 1;
  }
  const order = [Role.nurse, Role.care, Role.office, Role.director, Role.admin];
  String label(Role r) => switch (r) {
        Role.nurse => '간호사',
        Role.care => '근무',
        Role.office => '사무국',
        Role.director => '원장',
        Role.admin => '관리자',
      };
  return [for (final r in order) if ((counts[r] ?? 0) > 0) '${label(r)} ${counts[r]}'].join(' · ');
}

/// 대응 기록 한 줄을 짧게 (그림 문자 없이, 카카오 글씨에 없는 기호가 네모로 보이지 않게).
String deskEventText(InMemoryRepository repo, CaseEvent e) {
  if (e.type == 'created') {
    try {
      final m = repo.measurement(e.data['measurementId'] as String);
      return '${withSubject(eventActor(repo, e))} ${formatTemp(m.value)}℃ 측정';
    } catch (_) {}
  }
  var t = eventText(repo, e);
  const emoji = ['🌡', '👀', '🙋', '⏱', '📝', '💊', '🩺', '🏥', '✅', '↗', '↩'];
  for (final x in emoji) {
    if (t.startsWith(x)) {
      t = t.substring(x.length).trimLeft();
      break;
    }
  }
  return t;
}
