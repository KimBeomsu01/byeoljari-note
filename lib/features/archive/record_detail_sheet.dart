// AR 기록 상세 (아카이브 3장 D). 하단 시트. 열기만 해서는 확인(읽음) 처리하지 않는다.
// 순서 (docs/design.md): 누구 → 무슨 상태 → 내용·할 일 → 할 수 있는 것 → 답글·확인 → 기록한 사람·시각.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'archive_timeline.dart';
import 'archive_widgets.dart';

Future<void> showRecordDetail(BuildContext context, ArchiveRecord record) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
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

    const caption = TextStyle(fontSize: T.caption, color: inkSub, height: 1.45);
    Widget gap(double h) => SizedBox(height: h);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
      children: [
        // ① 누구
        Text(isNotice ? '${repo.classOf(e!.classId!).name} 전원' : '${r.name} 별님',
            style: const TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain)),
        Text(kind, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkSub)),
        gap(Gap.l),
        // ② 상태
        if (m != null) ..._measurementPart(repo, m),
        // 내용
        if (e?.title != null)
          Text(e!.title!, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
        if (e?.body != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text(e!.body!, style: const TextStyle(fontSize: T.body, height: 1.6, color: inkMain)),
          ),
        if ((e?.photoCount ?? 0) > 0) PhotoPlaceholder(e!.photoCount),
        if (e?.task != null) TaskLine(e!.task!, extra: _taskExtra(repo, e.task!)),
        // ③ 할 수 있는 것
        if (caseId != null) ...[
          gap(Gap.l),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
            icon: const Icon(Icons.history),
            label: const Text('대응 이력 보기'),
            onPressed: () => openCaseDetail(context, caseId),
          ),
        ],
        if (e != null) ...[
          gap(Gap.xl),
          _ReadState(repo: repo, entry: e, me: me),
          gap(Gap.xl),
          Semantics(
            header: true,
            child: Text('답글 ${replies.length}',
                style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
          ),
          if (replies.isEmpty) const Padding(padding: EdgeInsets.only(top: Gap.xs), child: Text('아직 답글이 없어요', style: caption)),
          for (final rp in replies)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: InfoCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rp.body, style: const TextStyle(fontSize: T.body, height: 1.5, color: inkMain)),
                  gap(Gap.xs),
                  Text(authorAsOf(repo, rp.authorId, classId, rp.createdAt), style: caption),
                  Text(ymdHm(rp.createdAt), style: caption),
                ]),
              ),
            ),
        ],
        // ④ 기록한 사람·시각 (맨 아래 보조 글자)
        gap(Gap.xl),
        const Divider(),
        gap(Gap.m),
        Text('기록한 사람: ${authorAsOf(repo, authorId, classId, at)}', style: caption),
        Text('기록한 때: ${ymdHm(at)}', style: caption),
        Text(m != null ? '체온 재기에서 남긴 기록이에요' : '인수인계에서 남긴 기록이에요', style: caption),
        gap(Gap.xl),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
          onPressed: () => Navigator.pop(context),
          child: const Text('목록으로'),
        ),
      ],
    );
  }

  static String _anyResidentOf(InMemoryRepository repo, String classId) => repo.residentsOf(classId).first.id;

  static String? _taskExtra(InMemoryRepository repo, Task task) {
    if (task.done) {
      final who = task.doneBy == null ? null : withSubject(repo.staff(task.doneBy!).displayName);
      final when = task.doneAt == null ? null : '${hhmm(task.doneAt!)}에';
      if (who == null && when == null) return null;
      return '${[?who, ?when].join(' ')} 했어요';
    }
    final due = task.duePreset ?? (task.dueAt == null ? null : hhmm(task.dueAt!));
    return due == null ? null : '$due까지';
  }

  List<Widget> _measurementPart(InMemoryRepository repo, Measurement m) {
    final j = m.judgment;
    const caption = TextStyle(fontSize: T.caption, color: inkSub, height: 1.45);
    return [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: Gap.m, runSpacing: Gap.s, children: [
        if (m.isVoided) voidLabel else StageTag(j.stage, large: true),
        Text('${formatTemp(m.value)}℃',
            style: TextStyle(
              fontSize: T.number,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              decoration: m.isVoided ? TextDecoration.lineThrough : null,
              color: m.isVoided ? inkSub : inkMain,
            )),
      ]),
      const SizedBox(height: Gap.s),
      Text(plainDiff(j.diff), style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
      Text('그때 평소 체온은 ${formatTemp(j.baseline)}℃였어요', style: caption),
      if (m.isVoided)
        Text(
            m.voidedBy == null
                ? '${ymdHm(m.voidedAt!)}에 잘못 잰 값으로 표시했어요'
                : '${withSubject(repo.staff(m.voidedBy!).displayName)} ${ymdHm(m.voidedAt!)}에 잘못 잰 값으로 표시했어요',
            style: caption),
      if (m.correctsId != null) const Text('잘못 잰 값을 다시 잰 기록이에요', style: caption),
      const SizedBox(height: Gap.l),
    ];
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
    final mine = entry.authorId == me;
    final read = !mine && repo.isRead(entry.id, me);
    return InfoCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (mine)
          const Text('내가 남긴 기록이에요', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain))
        else if (read)
          Text('✓ 내가 확인한 기록이에요',
              style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: stageColors[Stage.normal]!.ink))
        else ...[
          const NewRecordMark(text: '아직 확인하지 않은 새 기록이에요', size: T.body),
          const SizedBox(height: Gap.xs),
          const Text('열어 보기만으로는 확인되지 않아요', style: TextStyle(fontSize: T.caption, color: inkSub)),
        ],
        const SizedBox(height: Gap.s),
        Text('확인한 사람 ${readers.length}명', style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
        if (readers.isNotEmpty)
          Text(readers.map((x) => repo.staff(x.staffId).name).join(', '),
              style: const TextStyle(fontSize: T.caption, color: inkSub)),
      ]),
    );
  }
}
