// AR 기록 상세 (아카이브 3장 D). 하단 시트. 열기만 해서는 확인(읽음) 처리하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import 'archive_timeline.dart';
import 'archive_widgets.dart';

Future<void> showRecordDetail(BuildContext context, ArchiveRecord record) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: paper,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, controller) => _RecordDetail(record: record, controller: controller),
      ),
    );

class _RecordDetail extends ConsumerWidget {
  const _RecordDetail({required this.record, required this.controller});
  final ArchiveRecord record;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);

    // 저장소의 최신 상태로 다시 읽는다 (판정은 저장된 값 그대로).
    final Measurement? m;
    final Entry? e;
    switch (record) {
      case TempRecord(m: final mm, entry: final ee):
        m = repo.measurement(mm.id);
        e = ee == null ? null : repo.entry(ee.id);
      case EntryRecord(e: final ee):
        m = null;
        e = repo.entry(ee.id);
    }
    final r = repo.resident(m?.residentId ?? e!.residentId ?? _anyResidentOf(repo, e!.classId!));
    final isNotice = e?.scope == EntryScope.classScope;
    final kind = m != null ? '체온 기록' : (isNotice ? '반 공지' : e!.kindLabel);
    final at = m?.measuredAt ?? e!.createdAt;
    final authorId = m?.recordedBy ?? e!.authorId;
    final classId = m?.classId ?? e!.classId;
    final caseId = m?.caseId ?? e?.caseId;
    final replies = e == null ? const <Reply>[] : repo.repliesOf(e.id);

    Widget field(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 64, child: Text(label, style: const TextStyle(color: inkSub, fontSize: 13))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
          ]),
        );

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(kind, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        field('대상', isNotice ? '${repo.classOf(e!.classId!).name} 전원' : '${r.name} 별님'),
        field('날짜·시각', ymdHm(at)),
        field('기록자', authorAsOf(repo, authorId, classId, at)),
        field('출처', m != null ? '퀵 체온' : '인수인계'),
        const Divider(height: 24),
        if (m != null) ..._measurementPart(repo, m),
        if (e?.title != null) Text(e!.title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (e?.body != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e!.body!, style: const TextStyle(fontSize: 16, height: 1.5))),
        if ((e?.photoCount ?? 0) > 0) PhotoPlaceholder(e!.photoCount),
        if (e?.task != null) _TaskBox(task: e!.task!, repo: repo),
        if (caseId != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.history),
            label: const Text('대응 이력 보기'),
            onPressed: () => openCaseDetail(context, caseId),
          ),
        ],
        if (e != null) ...[
          const SizedBox(height: 16),
          _ReadState(repo: repo, entry: e, me: me),
          const SizedBox(height: 16),
          Text('답글 ${replies.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (replies.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('아직 답글이 없어요.', style: TextStyle(color: inkSub))),
          for (final rp in replies)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${authorAsOf(repo, rp.authorId, classId, rp.createdAt)} · ${ymdHm(rp.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: inkSub)),
                const SizedBox(height: 2),
                Text(rp.body),
              ]),
            ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: brandDark),
          onPressed: () => Navigator.pop(context),
          child: const Text('목록으로'),
        ),
      ],
    );
  }

  static String _anyResidentOf(InMemoryRepository repo, String classId) => repo.residentsOf(classId).first.id;

  List<Widget> _measurementPart(InMemoryRepository repo, Measurement m) {
    final j = m.judgment;
    return [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 6, children: [
        Text('${formatTemp(m.value)}℃',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              decoration: m.isVoided ? TextDecoration.lineThrough : null,
              color: m.isVoided ? inkSub : inkMain,
            )),
        if (m.isVoided) const _VoidLabel() else StageBadge(j.stage),
      ]),
      const SizedBox(height: 4),
      Text('평소보다 ${formatDiff(j.diff)} · 그때 평소 체온 ${formatTemp(j.baseline)}℃',
          style: const TextStyle(color: inkSub, fontSize: 13)),
      if (m.isVoided)
        Text(
            m.voidedBy == null
                ? '${ymdHm(m.voidedAt!)}에 무효로 표시했어요'
                : '${withSubject(repo.staff(m.voidedBy!).displayName)} ${ymdHm(m.voidedAt!)}에 무효로 표시했어요',
            style: const TextStyle(color: inkSub, fontSize: 13)),
      if (m.correctsId != null)
        const Text('잘못 잰 값을 다시 잰 기록이에요', style: TextStyle(color: inkSub, fontSize: 13)),
      const SizedBox(height: 10),
    ];
  }
}

class _VoidLabel extends StatelessWidget {
  const _VoidLabel();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: inkSub), borderRadius: BorderRadius.circular(20)),
        child: const Text('잘못 잰 값', style: TextStyle(color: inkSub, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

/// 아카이브 목록·상세 공통 "잘못 잰 값" 표시.
const voidLabel = _VoidLabel();

class _TaskBox extends StatelessWidget {
  const _TaskBox({required this.task, required this.repo});
  final Task task;
  final InMemoryRepository repo;

  @override
  Widget build(BuildContext context) {
    final done = task.done;
    final c = done ? stageColors[Stage.normal]! : stageColors[Stage.caution]!;
    final due = task.duePreset ?? (task.dueAt == null ? null : hhmm(task.dueAt!));
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.soft, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(10)),
      child: Text(
        done
            ? '✓ 할 일 완료 · ${task.label}${task.doneBy != null ? ' · ${repo.staff(task.doneBy!).displayName}' : ''}${task.doneAt != null ? ' ${hhmm(task.doneAt!)}' : ''}'
            : '○ 할 일 열림 · ${task.label}${due != null ? ' · $due' : ''}',
        style: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ReadState extends StatelessWidget {
  const _ReadState({required this.repo, required this.entry, required this.me});
  final InMemoryRepository repo;
  final Entry entry;
  final String me;

  @override
  Widget build(BuildContext context) {
    final readers = repo.readersOf(entry.id);
    final mine = entry.authorId == me
        ? '내가 남긴 기록이에요'
        : repo.isRead(entry.id, me)
            ? '✓ 내가 확인한 기록이에요'
            : '아직 확인하지 않은 새 기록이에요 · 열어 보기만으로는 확인되지 않아요';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(mine, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text('확인한 사람 ${readers.length}명${readers.isEmpty ? '' : ' · ${readers.map((x) => repo.staff(x.staffId).name).join(', ')}'}',
          style: const TextStyle(color: inkSub, fontSize: 13)),
    ]);
  }
}
