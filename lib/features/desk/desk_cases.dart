// DESK-3 긴급·이상 대응 현황 (원본 4장 + 통합 6-7-3, 이상 대응 S8).
// 조회용: 확인·담당·종료 버튼이 없고, 열거나 닫아도 상태가 바뀌지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../alert_case/case_ui.dart';
import 'desk_common.dart';
import 'desk_today.dart' show DeskStageBar, deskEventText;

class DeskCasesView extends ConsumerStatefulWidget {
  const DeskCasesView({super.key, this.caseId, required this.onSelect, required this.onResident});
  final String? caseId;
  final ValueChanged<String> onSelect;
  final void Function(String residentId, {String? recordKey}) onResident;

  @override
  ConsumerState<DeskCasesView> createState() => _DeskCasesViewState();
}

class _DeskCasesViewState extends ConsumerState<DeskCasesView> {
  bool closedTab = false;
  String? classFilter;
  String nameQuery = '';

  @override
  void initState() {
    super.initState();
    final id = widget.caseId;
    if (id != null) {
      try {
        closedTab = !ref.read(repoProvider).caseById(id).isOpen;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final open = repo.openCases; // 긴급 → 이상 대응, 최근 순
    final closed = repo.allCases.where((c) => !c.isOpen).toList()
      ..sort((a, b) => (b.closedAt ?? b.createdAt).compareTo(a.closedAt ?? a.createdAt));
    final q = nameQuery.trim();
    final shown = (closedTab ? closed : open)
        .where((c) => classFilter == null || c.classId == classFilter)
        .where((c) => q.isEmpty || repo.resident(c.residentId).name.contains(q))
        .toList();
    Case? selected;
    if (widget.caseId != null) {
      try {
        selected = repo.caseById(widget.caseId!);
      } catch (_) {}
    }

    final table = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: Gap.m, runSpacing: Gap.m, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SegmentedButton<bool>(
          key: const ValueKey('desk-case-tab'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text('진행 중 ${open.length}')),
            ButtonSegment(value: true, label: Text('종료 ${closed.length}')),
          ],
          selected: {closedTab},
          onSelectionChanged: (s) => setState(() => closedTab = s.first),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String?>(
            initialValue: classFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '반'),
            items: [
              const DropdownMenuItem(value: null, child: Text('전체 반')),
              for (final c in repo.classes) DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => classFilter = v),
          ),
        ),
        SizedBox(
          width: 200,
          child: TextField(
            decoration: const InputDecoration(hintText: '별님 이름', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => nameQuery = v),
          ),
        ),
      ]),
      const SizedBox(height: Gap.m),
      DeskTable(
        empty: closedTab ? '조건에 맞는 종료 기록이 없어요' : '지금 진행 중인 대응이 없어요',
        cols: const [
          DeskCol('발생', flex: 2),
          DeskCol('별님 · 반', flex: 3),
          DeskCol('최초 측정', flex: 2),
          DeskCol('마지막 조치', flex: 4),
          DeskCol('담당자', flex: 2),
          DeskCol('단계', flex: 2),
          DeskCol('상태', flex: 3),
        ],
        rows: [for (final c in shown) _row(repo, c, now, c.id == selected?.id)],
      ),
    ]);

    final detail = selected == null
        ? const DeskCard(child: EmptyNote('표에서 한 건을 고르면 자세한 내용이 여기에 보여요'))
        : _CaseDetail(
            key: ValueKey('desk-case-detail-${selected.id}'),
            c: selected,
            onResident: widget.onResident,
          );

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 1100;
      final heading = DeskHeading('긴급·이상 대응 현황', sub: '조회용이에요 · 확인·담당·종료는 폰 앱에서 해요');
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [heading, table])),
          const SizedBox(width: Gap.l),
          SizedBox(width: 420, child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 32), child: detail)),
        ]);
      }
      return ListView(padding: const EdgeInsets.only(bottom: 32), children: [heading, table, const SizedBox(height: Gap.l), detail]);
    });
  }

  DeskRow _row(InMemoryRepository repo, Case c, DateTime now, bool selected) {
    final r = repo.resident(c.residentId);
    final last = lastActionOf(repo, c.id);
    final col = caseColors(c);
    return DeskRow(
      key: ValueKey('desk-case-${c.id}'),
      selected: selected,
      highlight: c.isUrgent && c.isOpen ? col.soft : null,
      onTap: () => widget.onSelect(c.id),
      cells: [
        Text(whenLabel(c.createdAt, now), style: const TextStyle(fontSize: T.body)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (c.isUrgent) StatusPill('⚠ 긴급', color: stageColors[Stage.danger]!.ink, filled: true),
          TwoLine(r.name, repo.classOf(c.classId).name),
        ]),
        Text('${formatTemp(c.firstTemp)}℃', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: col.ink)),
        last == null
            ? const Text('조치 기록 없음', style: TextStyle(fontSize: T.caption, color: inkSub))
            : TwoLine(deskEventText(repo, last), '${whenLabel(last.at, now)} · ${eventActor(repo, last)}',
                const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkMain)),
        Text(c.assigneeId == null ? '미지정' : staffName(repo, c.assigneeId!),
            style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: c.assigneeId == null ? inkSub : inkMain)),
        Text('${circledStage[(c.stage - 1).clamp(0, 3)]} ${InMemoryRepository.stageLabel(c.stage)}', style: const TextStyle(fontSize: T.caption, color: inkMain)),
        Text(_statusText(c), style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: c.isOpen ? col.ink : inkSub)),
      ],
    );
  }
}

String _statusText(Case c) {
  final s = caseStatusLabel(c);
  return switch (s) {
    '미확인' => '● 미확인',
    '종료 대기' => '✓ 종료 대기',
    '종료' => '■ 종료',
    _ => '◐ $s',
  };
}

class _CaseDetail extends ConsumerWidget {
  const _CaseDetail({super.key, required this.c, required this.onResident});
  final Case c;
  final void Function(String residentId, {String? recordKey}) onResident;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final r = repo.resident(c.residentId);
    final cls = repo.classOf(c.classId);
    final ms = repo.measurementsOfCase(c.id);
    final valid = ms.where((m) => !m.isVoided).toList();
    final latest = valid.isEmpty ? null : valid.last;
    final acks = acksOf(repo, c.id);
    final events = repo.eventsOf(c.id);
    final col = caseColors(c);

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 96, child: Text(k, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: T.body, color: inkMain))),
          ]),
        );

    return DeskCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          CaseBadge(c),
          StatusPill(_statusText(c), color: c.isOpen ? col.ink : inkSub),
          Text('발생 ${whenLabel(c.createdAt, now)} · ${agoText(now, c.createdAt)}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
        const SizedBox(height: Gap.m),
        Row(children: [
          FaceAvatar.resident(r.id, size: 48),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Text('${cls.name} ${r.name} 별님',
                key: const ValueKey('desk-case-detail-title'),
                style: const TextStyle(fontFamily: fontBig, fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain)),
          ),
        ]),
        const SizedBox(height: Gap.m),
        Container(
          padding: const EdgeInsets.all(Gap.l),
          decoration: BoxDecoration(color: col.soft, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: col.line)),
          child: Wrap(spacing: Gap.l, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(latest == null ? '기록 없음' : '${formatTemp(latest.value)}℃',
                style: TextStyle(fontFamily: fontBig, fontSize: latest == null ? T.title : T.number, fontWeight: FontWeight.w800, color: col.ink)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (latest != null)
                Text('평소 ${formatTemp(latest.judgment.baseline)}℃보다 ${formatDiff(latest.judgment.diff)}',
                    style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: col.ink)),
              Text('처음 ${formatTemp(c.firstTemp)}℃ · 측정 ${valid.length}회', style: const TextStyle(fontSize: T.caption, color: inkSub)),
              if (latest != null) Text('마지막 측정 ${whenLabel(latest.measuredAt, now)}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
            ]),
          ]),
        ),
        const SizedBox(height: Gap.m),
        DeskStageBar(stage: c.stage),
        const SizedBox(height: Gap.m),
        kv('확인한 사람', acks.isEmpty ? '아직 아무도 확인 안 함' : acks.map((e) => '${staffName(repo, e.actorId)} ${hhmm(e.at)}').join(', ')),
        kv('담당자', c.assigneeId == null ? '미지정' : staffName(repo, c.assigneeId!)),
        if (c.remeasureAt != null) kv('재측정', '${hhmm(c.remeasureAt!)} 예정'),
        if (!c.isOpen) kv('종료', '${c.closeReason ?? ''} · ${c.closedAt == null ? '' : whenLabel(c.closedAt!, now)}'),
        const SizedBox(height: Gap.m),
        Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
          OutlinedButton.icon(
            key: const ValueKey('desk-case-first'),
            onPressed: () => onResident(c.residentId, recordKey: 'm:${c.firstMeasurementId}'),
            icon: const Icon(Icons.thermostat),
            label: const Text('최초 측정 보기'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('desk-case-resident'),
            onPressed: () => onResident(c.residentId),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('별님 기록 보기'),
          ),
        ]),
        const SizedBox(height: Gap.l),
        const Text('대응 기록 (시간순)', style: TextStyle(fontFamily: fontBig, fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
        const SizedBox(height: Gap.s),
        if (events.isEmpty) const Text('조치 기록 없음', style: TextStyle(fontSize: T.body, color: inkSub)),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 60, child: Text(hhmm(e.at), style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkSub))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(deskEventText(repo, e),
                      style: TextStyle(
                        fontSize: T.body,
                        color: e.voidedBy == null ? inkMain : inkSub,
                        decoration: e.voidedBy == null ? null : TextDecoration.lineThrough,
                      )),
                  Text('${eventActor(repo, e)}${e.voidedBy == null ? '' : ' · 취소됨'}',
                      style: const TextStyle(fontSize: T.caption, color: inkSub)),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: Gap.m),
        const Text('사무국 PC는 보기만 해요. 이 화면을 열어도 확인·담당·종료 상태는 바뀌지 않아요.',
            style: TextStyle(fontSize: T.caption, color: inkSub)),
      ]),
    );
  }
}
