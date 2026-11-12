// 최신 기록의 기록 카드 (인수인계 명세 3.1 "기록 카드").
// 체온 박스의 값과 판정은 측정(Measurement)에서 읽는다 (통합 명세 6-3 3번).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'handover_common.dart';
import 'handover_view.dart';

class EntryCard extends ConsumerStatefulWidget {
  const EntryCard({super.key, required this.entry, required this.view, this.foldReadNotice = true, this.onCompleted});
  final Entry entry;
  final HandoverView view;

  /// 이미 확인한 전체 공지는 본문을 접는다. "전체 공지" 필터에서는 false.
  final bool foldReadNotice;

  /// 할 일을 완료했을 때 (넘어온 할 일을 화면에 남기기 위해).
  final VoidCallback? onCompleted;

  @override
  ConsumerState<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends ConsumerState<EntryCard> {
  bool _repliesOpen = false;
  bool _expanded = false;
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final fresh = ref.watch(sessionWrittenProvider).contains(widget.entry.id);
    final now = ref.read(clockProvider)();
    final e = repo.entry(widget.entry.id); // 늘 최신 상태로
    final v = widget.view;
    final author = repo.staff(e.authorId);
    final mine = e.authorId == me;
    final read = repo.isRead(e.id, me);
    final openTask = e.task != null && !e.task!.done;
    final replies = repo.repliesOf(e.id);
    final folded = widget.foldReadNotice && e.scope == EntryScope.facility && read && !_expanded;

    final (Color bg, Color line, bool dashed) = switch (e.scope) {
      EntryScope.facility => (hoNoticeBg, hoNoticeLine, false),
      EntryScope.classScope => (
          Color.alphaBlend(Color(repo.classOf(e.classId!).color).withValues(alpha: 0.10), Colors.white),
          Color(repo.classOf(e.classId!).color),
          true
        ),
      EntryScope.resident => (Colors.white, hoCardLine, false),
    };

    final topLabel = switch (e.scope) {
      EntryScope.facility => e.pinned ? '전체 공지 · 위에 고정' : '전체 공지',
      EntryScope.classScope => '${repo.classOf(e.classId!).name} 반 공지 · 반 전원 아카이브에 기록',
      EntryScope.resident => null,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: fresh ? brandDark : (v.countsAsUnread(e) ? hoUnreadBadge : line),
          width: fresh || dashed ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (topLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(topLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: e.scope == EntryScope.facility ? hoTaskInk : inkSub)),
          ),
        // 작성자 · 종류 · 시각
        Row(children: [
          NameAvatar(name: author.name, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: author.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' · ${_kindLabel(e)} · ${whenLabel(e.createdAt, now)}', style: const TextStyle(color: inkSub)),
                if (e.updatedAt != null) const TextSpan(text: ' · 고침', style: TextStyle(color: inkSub)),
              ]),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (fresh)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('방금 씀', style: TextStyle(fontSize: 11, color: brandDark, fontWeight: FontWeight.w700)),
            )
          else if (v.countsAsUnread(e))
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('● 새 기록', style: TextStyle(fontSize: 11, color: hoTaskInk, fontWeight: FontWeight.w700)),
            ),
          _MoreMenu(entry: e, mine: mine),
        ]),
        if (e.scope == EntryScope.resident && e.residentId != null) ...[
          const SizedBox(height: 6),
          _ResidentChip(residentId: e.residentId!),
        ],
        if (e.measurementId != null) ...[
          const SizedBox(height: 8),
          _TempBox(entry: e),
        ],
        if (e.title != null) ...[
          const SizedBox(height: 8),
          Text(e.title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
        if (e.body != null && e.body!.isNotEmpty)
          if (folded)
            InkWell(
              onTap: () => setState(() => _expanded = true),
              child: const SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('확인한 공지 · 눌러서 펼치기', style: TextStyle(fontSize: 13, color: inkSub)),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(e.body!, style: const TextStyle(fontSize: 15, height: 1.45)),
            ),
        if (e.photoCount > 0 && !folded) ...[
          const SizedBox(height: 8),
          _PhotoPlaceholder(count: e.photoCount),
        ],
        if (e.task != null) ...[
          const SizedBox(height: 8),
          _TaskBox(entry: e),
        ],
        const SizedBox(height: 6),
        _Footer(
          entry: e,
          view: v,
          mine: mine,
          read: read,
          openTask: openTask,
          replyCount: replies.length,
          repliesOpen: _repliesOpen,
          onToggleReplies: () => setState(() => _repliesOpen = !_repliesOpen),
          onCompleted: widget.onCompleted,
        ),
        if (_repliesOpen) ...[
          for (final r in replies)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NameAvatar(name: repo.staff(r.authorId).name, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${repo.staff(r.authorId).displayName} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: r.body),
                    TextSpan(text: '  ${whenLabel(r.createdAt, now)}', style: const TextStyle(color: inkSub, fontSize: 12)),
                  ])),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _reply,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendReply(),
                  decoration: const InputDecoration(
                    hintText: '답글 쓰기',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _sendReply,
                child: const Text('보내기'),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  void _sendReply() {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    ref.read(repoProvider).addReply(widget.entry.id, ref.read(currentUserProvider), text, ref.read(clockProvider)());
    _reply.clear();
    showToast(context, '답글을 남겼어요 · 이 기록도 확인으로 표시했어요');
  }

  /// 자동 체온 기록은 이상 건 종류·상태를 붙여 보여준다 (통합 명세 6-2 5번).
  String _kindLabel(Entry e) {
    final repo = ref.read(repoProvider);
    if (e.caseId != null) {
      final c = repo.caseById(e.caseId!);
      final tail = c.status == CaseStatus.closed
          ? ' · 종료${c.closeReason != null ? ' · ${c.closeReason}' : ''}'
          : (c.recoveredAt != null ? ' · 종료 대기' : '');
      return '${e.kindLabel} · ${c.kindLabel}$tail';
    }
    if (e.measurementId != null) {
      return '${e.kindLabel} · ${repo.measurement(e.measurementId!).judgment.stage.label}';
    }
    return e.kindLabel;
  }
}

class _ResidentChip extends ConsumerWidget {
  const _ResidentChip({required this.residentId});
  final String residentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final r = repo.resident(residentId);
    final cls = repo.classOf(r.classId);
    return Semantics(
      button: true,
      label: '${r.name} 별님 아카이브 열기',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => openArchive(context, r.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            color: Color(cls.color).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            NameAvatar(name: r.name, size: 28, color: Color(cls.color).withValues(alpha: 0.45)),
            const SizedBox(width: 6),
            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(' · ${cls.name}', style: const TextStyle(fontSize: 13, color: inkSub)),
            const Icon(Icons.chevron_right, size: 18, color: inkSub),
          ]),
        ),
      ),
    );
  }
}

class _TempBox extends ConsumerWidget {
  const _TempBox({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = ref.read(clockProvider)();
    final m = repo.measurement(entry.measurementId!);
    final j = m.judgment;
    final col = stageColors[j.stage]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: col.soft, borderRadius: BorderRadius.circular(11), border: Border.all(color: col.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: formatTemp(m.value),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: col.ink,
                    decoration: m.isVoided ? TextDecoration.lineThrough : null,
                  )),
              TextSpan(text: '℃', style: TextStyle(fontSize: 13, color: col.ink)),
            ]),
          ),
          StageTag(stage: j.stage),
          if (m.isVoided) const Text('무효 처리됨', style: TextStyle(fontSize: 12, color: inkSub)),
        ]),
        Text('평소보다 ${formatDiff(j.diff)} · ${repo.staff(m.recordedBy).displayName} · ${whenLabel(m.measuredAt, now)}',
            style: const TextStyle(fontSize: 12.5, color: inkMain)),
        if (entry.caseId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
              onPressed: () => openCaseDetail(context, entry.caseId!),
              child: const Text('대응 이력 보기 ›'),
            ),
          ),
      ]),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '사진 $count장 (시연용 자리 표시)',
        excludeSemantics: true,
        child: Container(
          height: 88,
          width: 132,
          decoration: BoxDecoration(color: const Color(0xFFE6E8E3), borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.photo_outlined, color: inkSub),
            Text('사진 $count장', style: const TextStyle(fontSize: 12, color: inkSub)),
          ]),
        ),
      );
}

class _TaskBox extends ConsumerWidget {
  const _TaskBox({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = ref.read(clockProvider)();
    final t = entry.task!;
    if (!t.done) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: hoTaskBg, borderRadius: BorderRadius.circular(11), border: Border.all(color: hoTaskLine)),
        child: Text(
          '☐ 할 일 · ${t.label} · ${dueLabel(t, now)}${t.kind == TaskKind.temp ? ' · 체온 재기' : ''}',
          style: const TextStyle(color: hoTaskInk, fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      );
    }
    var result = '';
    if (t.resultMeasurementId != null) {
      final m = repo.measurement(t.resultMeasurementId!);
      result = ' · ${formatTemp(m.value)}℃ ${m.judgment.stage.symbol} ${m.judgment.stage.label}';
    }
    final by = t.doneBy != null ? repo.staff(t.doneBy!).displayName : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: hoDoneBg, borderRadius: BorderRadius.circular(11), border: Border.all(color: hoDoneLine)),
      child: Text(
        '✓ ${t.label} · ${t.doneAt != null ? whenLabel(t.doneAt!, now) : ''} $by 완료$result',
        style: const TextStyle(color: hoDoneInk, fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({
    required this.entry,
    required this.view,
    required this.mine,
    required this.read,
    required this.openTask,
    required this.replyCount,
    required this.repliesOpen,
    required this.onToggleReplies,
    this.onCompleted,
  });
  final Entry entry;
  final HandoverView view;
  final bool mine;
  final bool read;
  final bool openTask;
  final int replyCount;
  final bool repliesOpen;
  final VoidCallback onToggleReplies;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final readers = view.shiftReaders(entry.id);
    final denom = view.shift?.staffIds.length;
    final maxAvatars = openTask ? 2 : 4;

    final buttons = <Widget>[
      if (!mine)
        read
            ? Semantics(
                label: '확인함',
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: hoDoneBg, borderRadius: BorderRadius.circular(99), border: Border.all(color: hoDoneLine)),
                  child: const Text('✓ 확인함', style: TextStyle(color: hoDoneInk, fontWeight: FontWeight.w700)),
                ),
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => repo.markRead(entry.id, me, ref.read(clockProvider)()),
                child: const Text('확인'),
              ),
      if (openTask)
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(44, 44), backgroundColor: hoSummaryBg),
          onPressed: () => _complete(context, ref),
          child: const Text('완료하기'),
        ),
      if (mine && !openTask)
        const SizedBox(
          height: 44,
          child: Center(child: Text('내가 남긴 기록', style: TextStyle(fontSize: 13, color: inkSub))),
        ),
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 4,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final id in readers.take(maxAvatars))
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: NameAvatar(name: repo.staff(id).name, size: 22, color: hoDoneBg),
            ),
          const SizedBox(width: 4),
          Text(denom == null ? '확인 ${readers.length}명' : '확인 ${readers.length}/$denom',
              style: const TextStyle(fontSize: 12.5, color: inkSub)),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: onToggleReplies,
            child: Text(repliesOpen ? '답글 닫기' : '답글 $replyCount'),
          ),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(width: 6), buttons[i]],
        ]),
      ],
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final t = entry.task!;
    if (t.kind == TaskKind.temp) {
      // 체온 할 일 → 퀵 체온, 그 별님 선택된 채로. 저장하면 할 일이 자동 완료된다 (C4).
      onCompleted?.call();
      ref.read(quickTempProvider.notifier).openFor(entry.residentId!);
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('완료할까요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('할 일 · ${t.label}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(44, 48)),
                  onPressed: () => Navigator.pop(s, false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(44, 48)),
                  onPressed: () => Navigator.pop(s, true),
                  child: const Text('완료했어요'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    onCompleted?.call();
    ref.read(repoProvider).completeTask(entry.id, ref.read(currentUserProvider), ref.read(clockProvider)());
    showToast(context, '${t.label} 완료');
  }
}

/// ⋯ 메뉴: 본문 고치기 (이력 남김, 4.7) · 할 일로 넘기기.
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.entry, required this.mine});
  final Entry entry;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = mine && entry.measurementId == null;
    final canTask = entry.task == null && entry.scope != EntryScope.facility;
    if (!canEdit && !canTask) return const SizedBox(width: 4);
    return PopupMenuButton<String>(
      tooltip: '더 보기',
      icon: const Icon(Icons.more_horiz, color: inkSub),
      onSelected: (v) => v == 'edit' ? _edit(context, ref) : _toTask(context, ref),
      itemBuilder: (_) => [
        if (canEdit) const PopupMenuItem(value: 'edit', child: Text('본문 고치기')),
        if (canTask) const PopupMenuItem(value: 'task', child: Text('할 일로 넘기기')),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: entry.body ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('본문 고치기'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: ctrl, maxLines: 5, minLines: 2, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 6),
          const Text('이전 내용은 지우지 않고 이력으로 남아요.', style: TextStyle(fontSize: 12, color: inkSub)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: const Text('고치기')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty || text == entry.body) return;
    ref.read(repoProvider).editEntryBody(entry.id, text, ref.read(currentUserProvider), ref.read(clockProvider)());
    if (context.mounted) showToast(context, '고쳤어요 · 이전 내용은 이력으로 남았어요');
  }

  Future<void> _toTask(BuildContext context, WidgetRef ref) async {
    final preset = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('할 일로 넘기기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('언제까지 할까요?', style: TextStyle(color: inkSub)),
            const SizedBox(height: 8),
            for (final p in taskPresets)
              ListTile(minTileHeight: 48, title: Text(p), onTap: () => Navigator.pop(s, p)),
          ]),
        ),
      ),
    );
    if (preset == null) return;
    final repo = ref.read(repoProvider);
    final now = ref.read(clockProvider)();
    final body = (entry.body ?? '').split('\n').first;
    repo.attachTask(entry.id,
        label: body.length > 14 ? '${body.substring(0, 14)}…' : (body.isEmpty ? '확인하기' : body),
        kind: TaskKind.memo,
        duePreset: preset,
        dueAt: presetDueAt(repo.shifts, preset, now));
    if (context.mounted) showToast(context, '할 일로 넘겼어요 · 완료할 때까지 교대 요약에 남아요');
  }
}

/// 할 일 기한 프리셋 (인수인계 3.4). 시각은 [가정]: 일정과 연결되면 별님 일정에서 가져온다.
const taskPresets = ['점심 전', '13:00 목욕 전', '저녁 전', '다음 근무조'];

DateTime? presetDueAt(List<Shift> shifts, String preset, DateTime now) {
  DateTime today(int h, int m) {
    final t = DateTime(now.year, now.month, now.day, h, m);
    return t.isBefore(now) ? t.add(const Duration(days: 1)) : t;
  }

  switch (preset) {
    case '점심 전':
      return today(11, 30);
    case '13:00 목욕 전':
      return today(13, 0);
    case '저녁 전':
      return today(17, 30);
    case '다음 근무조':
      final next = shifts.where((s) => s.startAt.isAfter(now)).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
      return next.isEmpty ? null : next.first.startAt;
  }
  return null;
}
