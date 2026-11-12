// 최신 기록의 기록 카드 (인수인계 명세 3.1 "기록 카드").
// 체온 상자의 값과 판정은 측정(Measurement)에서 읽는다 (통합 명세 6-3 3번).
// 카드 순서: 무슨 기록·새 기록 표시 → 누구(별님) → 체온 → 제목·본문 → 할 일 → 확인·답글 → 버튼 → 작성자·시각(보조 글자).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'handover_common.dart';
import 'handover_view.dart';

class EntryCard extends ConsumerStatefulWidget {
  const EntryCard({super.key, required this.entry, required this.view, this.foldReadNotice = true, this.onCompleted});
  final Entry entry;
  final HandoverView view;

  /// 이미 확인한 전체 공지는 본문을 접는다. "전체 공지" 보기에서는 false.
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
    final unread = v.countsAsUnread(e);
    final openTask = e.task != null && !e.task!.done;
    final replies = repo.repliesOf(e.id);
    final folded = widget.foldReadNotice && e.scope == EntryScope.facility && read && !_expanded;

    // 바탕·띠: 전체 공지 = 옅은 남색 + 남색 띠, 반 공지 = 반 색 띠, 별님 기록 = 흰 카드.
    final (Color bg, Color? accent) = switch (e.scope) {
      EntryScope.facility => (hoNoticeBg, brandDark),
      EntryScope.classScope => (surface, Color(repo.classOf(e.classId!).color)),
      EntryScope.resident => (surface, null),
    };

    final String? topLabel = switch (e.scope) {
      EntryScope.facility => e.pinned ? '📌 전체 공지 · 맨 위 고정' : '전체 공지',
      EntryScope.classScope => '${repo.classOf(e.classId!).name} 반 공지',
      EntryScope.resident => null,
    };

    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 맨 위 줄: 무슨 기록인지 + 새 기록 표시 + ⋯
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: e.scope == EntryScope.resident && e.residentId != null
              ? Align(alignment: Alignment.centerLeft, child: _ResidentChip(residentId: e.residentId!))
              : Text(topLabel ?? '',
                  style: TextStyle(
                    fontSize: T.body,
                    fontWeight: FontWeight.w800,
                    color: e.scope == EntryScope.facility ? brandDark : inkMain,
                  )),
        ),
        _MoreMenu(entry: e, mine: mine),
      ]),
      if (fresh || unread)
        Padding(
          padding: const EdgeInsets.only(top: Gap.xs),
          child: fresh
              ? const Text('✎ 방금 쓴 기록', style: TextStyle(fontSize: T.caption, color: brandDark, fontWeight: FontWeight.w800))
              : const NewMark(),
        ),
      if (e.measurementId != null) ...[
        const SizedBox(height: Gap.m),
        _TempBox(entry: e),
      ],
      if (e.title != null) ...[
        const SizedBox(height: Gap.m),
        Text(e.title!, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
      ],
      if (e.body != null && e.body!.isNotEmpty)
        if (folded)
          InkWell(
            borderRadius: BorderRadius.circular(Radii.button),
            onTap: () => setState(() => _expanded = true),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: const Row(children: [
                Flexible(
                  child: Text('확인한 공지 · 눌러서 펼치기',
                      style: TextStyle(fontSize: T.body, color: brandDark, fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.expand_more, color: brandDark),
              ]),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: Gap.s),
            child: Text(e.body!, style: const TextStyle(fontSize: T.body, height: 1.5, color: inkMain)),
          ),
      if (e.photoCount > 0 && !folded) ...[
        const SizedBox(height: Gap.m),
        _PhotoPlaceholder(count: e.photoCount),
      ],
      if (e.task != null) ...[
        const SizedBox(height: Gap.m),
        _TaskBox(entry: e),
      ],
      const SizedBox(height: Gap.m),
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
        const SizedBox(height: Gap.s),
        const Divider(),
        for (final r in replies)
          Padding(
            padding: const EdgeInsets.only(top: Gap.m),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NameAvatar(name: repo.staff(r.authorId).name, size: 36),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.body, style: const TextStyle(fontSize: T.body, height: 1.5, color: inkMain)),
                  Text('${repo.staff(r.authorId).displayName} · ${whenLabel(r.createdAt, now)}',
                      style: const TextStyle(fontSize: T.caption, color: inkSub)),
                ]),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: Gap.m),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _reply,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                style: const TextStyle(fontSize: T.body, color: inkMain),
                onSubmitted: (_) => _sendReply(),
                decoration: const InputDecoration(hintText: '답글 쓰기'),
              ),
            ),
            const SizedBox(width: Gap.s),
            FilledButton(onPressed: _sendReply, child: const Text('보내기')),
          ]),
        ),
      ],
      const SizedBox(height: Gap.m),
      // 맨 아래: 누가 · 언제 (보조 글자)
      Text('${author.displayName} · ${whenLabel(e.createdAt, now)}${e.updatedAt != null ? ' (고침)' : ''}',
          style: const TextStyle(fontSize: T.caption, color: inkSub)),
      Text(_kindLabel(e), style: const TextStyle(fontSize: T.caption, color: inkSub)),
    ]);

    // 테두리: 방금 쓴 기록 = 남색 굵게, 공지 = 띠 색, 그 밖 = 기본 선. (그림자 없음)
    final borderColor = fresh ? brandDark : (accent ?? line);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: borderColor, width: fresh || accent != null ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(accent != null ? 8 + Gap.l : Gap.l, Gap.s, Gap.s, Gap.l),
            child: content,
          ),
          if (accent != null) Positioned(left: 0, top: 0, bottom: 0, width: 8, child: ColoredBox(color: accent)),
        ]),
      ),
    );
  }

  void _sendReply() {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    ref.read(repoProvider).addReply(widget.entry.id, ref.read(currentUserProvider), text, ref.read(clockProvider)());
    _reply.clear();
    showToast(context, '답글을 남겼어요 · 이 기록도 확인으로 표시했어요');
  }

  /// 무슨 기록인지. 자동 체온 기록은 이상 건 종류·상태를 붙여 보여준다 (통합 명세 6-2 5번).
  String _kindLabel(Entry e) {
    final repo = ref.read(repoProvider);
    if (e.caseId != null) {
      final c = repo.caseById(e.caseId!);
      final tail = c.status == CaseStatus.closed
          ? ' 끝남${c.closeReason != null ? ': ${c.closeReason}' : ''}'
          : (c.recoveredAt != null ? ' 끝내기 전' : '');
      return '${e.kindLabel} (${c.kindLabel}$tail)';
    }
    if (e.measurementId != null) {
      return '${e.kindLabel} (${repo.measurement(e.measurementId!).judgment.stage.label})';
    }
    return e.kindLabel;
  }
}

/// 별님 이름 칩: 누르면 그 별님 아카이브로. 높이 56, 이름 크게.
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
        borderRadius: BorderRadius.circular(Radii.button),
        onTap: () => openArchive(context, r.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: tapHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.xs),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ResidentAvatar(name: r.name, classColor: cls.color, size: 44),
              const SizedBox(width: Gap.m),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(r.name, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain, height: 1.25)),
                  Text(cls.name, style: const TextStyle(fontSize: T.caption, color: inkSub)),
                ]),
              ),
              const Icon(Icons.chevron_right, size: 26, color: inkSub),
            ]),
          ),
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
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.m),
      decoration: BoxDecoration(
        color: col.soft,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: col.line, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: Gap.m, runSpacing: Gap.xs, children: [
          Text('${formatTemp(m.value)}℃',
              style: TextStyle(
                fontSize: T.number,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: col.ink,
                decoration: m.isVoided ? TextDecoration.lineThrough : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
          StageTag(j.stage, large: true),
        ]),
        if (m.isVoided)
          const Text('잘못 잰 값이라 무효로 했어요', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
        Text(plainDiff(j.diff), style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain)),
        Text('${repo.staff(m.recordedBy).displayName} 측정 · ${whenLabel(m.measuredAt, now)}',
            style: const TextStyle(fontSize: T.caption, color: inkSub)),
        if (entry.caseId != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: TextButton(
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 0)),
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
          height: 96,
          width: 148,
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(Radii.button),
            border: Border.all(color: line),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.photo_outlined, color: inkSub, size: 30),
            Text('사진 $count장', style: const TextStyle(fontSize: T.caption, color: inkSub)),
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
        padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
        decoration: BoxDecoration(
          color: hoTask.soft,
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: hoTask.line, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('☐ 할 일: ${t.label}', style: TextStyle(color: hoTask.ink, fontWeight: FontWeight.w800, fontSize: T.body)),
          Text('언제까지: ${dueLabel(t, now)}', style: const TextStyle(color: inkMain, fontSize: T.body)),
          if (t.kind == TaskKind.temp)
            const Text('체온을 재면 저절로 완료돼요', style: TextStyle(color: inkSub, fontSize: T.caption)),
        ]),
      );
    }
    final by = t.doneBy != null ? repo.staff(t.doneBy!).displayName : '';
    final m = t.resultMeasurementId != null ? repo.measurement(t.resultMeasurementId!) : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
      decoration: BoxDecoration(
        color: hoDone.soft,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: hoDone.line, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('✓ 완료: ${t.label}', style: TextStyle(color: hoDone.ink, fontWeight: FontWeight.w800, fontSize: T.body)),
        if (m != null)
          Text('잰 체온 ${formatTemp(m.value)}℃ ${m.judgment.stage.symbol} ${m.judgment.stage.label}',
              style: const TextStyle(color: inkMain, fontSize: T.body, fontWeight: FontWeight.w600)),
        Text('$by 완료${t.doneAt != null ? ' · ${whenLabel(t.doneAt!, now)}' : ''}',
            style: const TextStyle(color: inkSub, fontSize: T.caption)),
      ]),
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

    final buttons = <Widget>[
      if (!mine)
        read
            ? Semantics(
                label: '확인함',
                excludeSemantics: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: tapHeight),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hoDone.soft,
                    borderRadius: BorderRadius.circular(Radii.button),
                    border: Border.all(color: hoDone.line, width: 1.5),
                  ),
                  child: Text('✓ 확인함',
                      style: TextStyle(fontSize: T.body, color: hoDone.ink, fontWeight: FontWeight.w800)),
                ),
              )
            : OutlinedButton(
                onPressed: () => repo.markRead(entry.id, me, ref.read(clockProvider)()),
                child: const Text('확인'),
              ),
      if (openTask)
        FilledButton(
          onPressed: () => _complete(context, ref),
          child: const Text('완료하기'),
        ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 확인한 사람 + 답글 (한 줄에 들어가지 않으면 두 줄로)
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Gap.s,
        runSpacing: 0,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final id in readers.take(3))
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: NameAvatar(name: repo.staff(id).name, size: 30, color: hoDone.soft),
              ),
            if (readers.isNotEmpty) const SizedBox(width: Gap.xs),
            Text(denom == null ? '${readers.length}명 확인' : '$denom명 중 ${readers.length}명 확인',
                style: const TextStyle(fontSize: T.caption, color: inkSub, fontWeight: FontWeight.w600)),
          ]),
          TextButton.icon(
            onPressed: onToggleReplies,
            icon: Icon(repliesOpen ? Icons.expand_less : Icons.chat_bubble_outline, size: 22),
            label: Text(repliesOpen ? '답글 닫기' : '답글 $replyCount개'),
          ),
        ],
      ),
      if (buttons.isNotEmpty) ...[
        const SizedBox(height: Gap.s),
        Row(children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: Gap.s),
            Expanded(child: buttons[i]),
          ],
        ]),
      ] else if (mine)
        const Padding(
          padding: EdgeInsets.only(top: Gap.xs),
          child: Text('내가 남긴 기록이에요', style: TextStyle(fontSize: T.caption, color: inkSub)),
        ),
    ]);
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
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.l),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('완료할까요?', style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
            const SizedBox(height: Gap.s),
            Text('할 일: ${t.label}', style: const TextStyle(fontSize: T.body, color: inkMain)),
            const SizedBox(height: Gap.xl),
            Row(children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(s, false), child: const Text('취소')),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: FilledButton(onPressed: () => Navigator.pop(s, true), child: const Text('완료했어요')),
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
    if (!canEdit && !canTask) return const SizedBox(width: Gap.m, height: 48);
    return PopupMenuButton<String>(
      tooltip: '더 보기',
      iconSize: 28,
      padding: const EdgeInsets.all(10),
      icon: const Icon(Icons.more_horiz, color: inkSub),
      onSelected: (v) => v == 'edit' ? _edit(context, ref) : _toTask(context, ref),
      itemBuilder: (_) => [
        if (canEdit)
          const PopupMenuItem(
              value: 'edit', height: tapHeight, child: Text('본문 고치기', style: TextStyle(fontSize: T.body))),
        if (canTask)
          const PopupMenuItem(
              value: 'task', height: tapHeight, child: Text('할 일로 넘기기', style: TextStyle(fontSize: T.body))),
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
          TextField(controller: ctrl, maxLines: 6, minLines: 3, style: const TextStyle(fontSize: T.body)),
          const SizedBox(height: Gap.s),
          const Text('이전 내용은 지우지 않고 이력으로 남아요.', style: TextStyle(fontSize: T.caption, color: inkSub)),
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
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.l),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('할 일로 넘기기', style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
            const SizedBox(height: Gap.xs),
            const Text('언제까지 할까요?', style: TextStyle(fontSize: T.body, color: inkSub)),
            const SizedBox(height: Gap.s),
            for (final p in taskPresets)
              ListTile(
                minTileHeight: tapHeight,
                contentPadding: EdgeInsets.zero,
                title: Text(p, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: inkSub),
                onTap: () => Navigator.pop(s, p),
              ),
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
    if (context.mounted) showToast(context, '할 일로 넘겼어요 · 완료할 때까지 지금 챙길 일에 남아요');
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
