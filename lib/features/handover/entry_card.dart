// 최신 기록의 기록 카드 (인수인계 명세 3.1 "기록 카드").
// 체온 상자의 값과 판정은 측정(Measurement)에서 읽는다 (통합 명세 6-3 3번).
// 카드 순서 (시제품 .card): 공지·새 기록 알약 → 작성자 얼굴·이름·종류·시각 → 별님 칩 → 체온 상자 → 제목·본문 → 할 일 → 확인·답글 → 버튼.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
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

    final classColor = e.classId != null ? Color(repo.classOf(e.classId!).color) : line;

    // 시제품 카드 모양: 전체 공지 = 옅은 노랑 + 금색 테두리, 반 공지 = 반 색 10% + 반 색 점선, 별님 기록 = 흰 카드.
    final (Color bg, Color border, double borderW, bool dashed) = switch (e.scope) {
      EntryScope.facility => (hoNoticeBg, hoNoticeLine, 1.5, false),
      EntryScope.classScope => (Color.alphaBlend(classColor.withValues(alpha: 0.10), surface), classColor, 1.5, true),
      EntryScope.resident => (surface, line, 1.0, false),
    };

    // 맨 위 알약: 무슨 공지인지 + 새 기록 표시
    final pills = <Widget>[
      if (e.scope == EntryScope.facility)
        _Pill(
          icon: Icons.campaign_outlined,
          text: e.pinned ? '전체 공지 · 위에 고정' : '전체 공지',
          bg: brandDark,
          fg: Colors.white,
        ),
      if (e.scope == EntryScope.classScope)
        _Pill(
          icon: Icons.campaign_outlined,
          text: '${repo.classOf(e.classId!).name} 반 공지',
          bg: Color.alphaBlend(classColor.withValues(alpha: 0.35), surface),
          fg: inkMain,
        ),
      if (fresh) const _Pill(text: '✎ 방금 쓴 기록', bg: hoDoneBg, fg: hoDoneInk) else if (unread) const NewMark(),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.s),
            child: Wrap(spacing: 6, runSpacing: 6, children: pills),
          ),
        // 누가 · 무슨 기록 · 언제 (시제품 .who)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FaceAvatar.staff(e.authorId, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author.displayName,
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain, height: 1.3),
                  ),
                  Text(
                    _kindLabel(e),
                    style: const TextStyle(fontSize: T.caption, color: inkSub, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.s),
            Text(
              '${whenLabel(e.createdAt, now)}${e.updatedAt != null ? '\n(고침)' : ''}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain, height: 1.3),
            ),
            _MoreMenu(entry: e, mine: mine),
          ],
        ),
        if (e.scope == EntryScope.resident && e.residentId != null) ...[
          const SizedBox(height: Gap.s),
          _ResidentChip(residentId: e.residentId!),
        ],
        if (e.measurementId != null) ...[const SizedBox(height: Gap.s), _TempBox(entry: e)],
        if (e.title != null) ...[
          const SizedBox(height: Gap.m),
          Text(
            e.title!,
            style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain),
          ),
        ],
        if (e.body != null && e.body!.isNotEmpty)
          if (folded)
            InkWell(
              borderRadius: BorderRadius.circular(Radii.button),
              onTap: () => setState(() => _expanded = true),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: tapHeight),
                child: const Row(
                  children: [
                    Flexible(
                      child: Text(
                        '확인한 공지 · 눌러서 펼치기',
                        style: TextStyle(fontSize: T.body, color: brandDark, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.expand_more, color: brandDark),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: Text(
                e.body!,
                style: const TextStyle(fontSize: T.body, height: 1.6, color: inkMain),
              ),
            ),
        if (e.photoCount > 0 && !folded) ...[const SizedBox(height: Gap.s), _PhotoPlaceholder(count: e.photoCount)],
        if (e.task != null) ...[const SizedBox(height: Gap.s), _TaskBox(entry: e)],
        const SizedBox(height: Gap.m),
        Divider(height: 1, color: e.scope == EntryScope.facility ? const Color(0xFFFBEEDF) : hoFootLine),
        const SizedBox(height: Gap.s),
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
        if (_repliesOpen)
          Container(
            margin: const EdgeInsets.only(top: Gap.s),
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(color: const Color(0xFFFFF3F0), borderRadius: BorderRadius.circular(11)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.m),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FaceAvatar.staff(r.authorId, size: 32),
                        const SizedBox(width: Gap.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${repo.staff(r.authorId).displayName} · ${whenLabel(r.createdAt, now)}',
                                style: const TextStyle(fontSize: T.caption, color: inkSub, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                r.body,
                                style: const TextStyle(fontSize: T.body, height: 1.5, color: inkMain),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(fontSize: T.body, color: inkMain),
                        onSubmitted: (_) => _sendReply(),
                        decoration: const InputDecoration(hintText: '답글 쓰기 · 예) 재측정했어요', hintMaxLines: 2),
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    FilledButton(onPressed: _sendReply, child: const Text('보내기')),
                  ],
                ),
              ],
            ),
          ),
      ],
    );

    // 방금 쓴 기록은 테두리를 초록으로 강조 (시제품 .card.fresh). 그림자 없음.
    final borderColor = fresh ? hoDoneInk.withValues(alpha: 0.55) : border;
    final shape = dashed && !fresh
        ? _DashedBorder(color: borderColor, width: borderW, radius: Radii.card)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
            side: BorderSide(color: borderColor, width: fresh ? 2 : borderW),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.xs, Gap.m),
          child: Padding(
            padding: const EdgeInsets.only(right: Gap.s),
            child: content,
          ),
        ),
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

/// 별님 이름 칩 (시제품 .starbtn): 얼굴 · 이름 · 반 · ›. 누르면 그 별님 아카이브로. 높이 48.
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
      child: Material(
        color: const Color(0xFFFFFAF8),
        shape: const StadiumBorder(side: BorderSide(color: line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openArchive(context, r.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: tapHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ResidentAvatar(name: r.name, classColor: cls.color, size: 34, residentId: r.id),
                  const SizedBox(width: Gap.s),
                  Text(
                    r.name,
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain),
                  ),
                  const Text(
                    ' 별님',
                    style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain),
                  ),
                  const SizedBox(width: Gap.s),
                  Flexible(
                    child: Text(
                      cls.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: T.caption, color: inkSub),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 22, color: inkSub),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 맨 위 작은 알약 (시제품 .pill).
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg, this.icon});
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 3, 12, 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 17, color: fg), const SizedBox(width: 5)],
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: fg, height: 1.3),
          ),
        ),
      ],
    ),
  );
}

/// 반 공지 카드의 점선 테두리 (시제품 .card.cls: 반 색 1.5px 점선).
class _DashedBorder extends ShapeBorder {
  const _DashedBorder({required this.color, required this.width, required this.radius});
  final Color color;
  final double width;
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  RRect _rrect(Rect rect) => RRect.fromRectAndRadius(rect.deflate(width / 2), Radius.circular(radius));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_rrect(rect).deflate(width / 2));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()..addRRect(_rrect(rect));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  ShapeBorder scale(double t) => _DashedBorder(color: color, width: width * t, radius: radius * t);
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
      padding: const EdgeInsets.fromLTRB(Gap.m, 10, Gap.m, 10),
      decoration: BoxDecoration(color: col.soft, borderRadius: BorderRadius.circular(11)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.isVoided)
                      const Text(
                        '잘못 잰 값이라 무효로 했어요',
                        style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
                      ),
                    Text(
                      plainDiff(j.diff),
                      style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain),
                    ),
                    Text(
                      '${repo.staff(m.recordedBy).displayName} 측정 · ${whenLabel(m.measuredAt, now)}',
                      style: const TextStyle(fontSize: T.caption, color: inkSub),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatTemp(m.value)}℃',
                    style: TextStyle(
                      fontSize: T.number,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: col.ink,
                      decoration: m.isVoided ? TextDecoration.lineThrough : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${j.stage.symbol} ${j.stage.label}',
                    style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: col.ink),
                  ),
                ],
              ),
            ],
          ),
          if (entry.caseId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openCaseDetail(context, entry.caseId!),
                child: const Text('대응 이력 보기 ›'),
              ),
            ),
        ],
      ),
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
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_outlined, color: inkSub, size: 30),
          Text(
            '사진 $count장',
            style: const TextStyle(fontSize: T.caption, color: inkSub),
          ),
        ],
      ),
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
    Widget box({
      required Color bg,
      required Color border,
      required Color dot,
      required String mark,
      required List<Widget> lines,
    }) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 9, 12, 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1, right: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            child: Text(
              mark,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 12, height: 1, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
          ),
        ],
      ),
    );

    if (!t.done) {
      return box(
        bg: hoTaskBg,
        border: hoTaskLine,
        dot: starYellow,
        mark: '!',
        lines: [
          Text(
            '할 일 · ${t.label}',
            style: const TextStyle(color: hoTaskInk, fontWeight: FontWeight.w800, fontSize: T.body),
          ),
          Text(
            '${dueLabel(t, now)}${t.duePreset != null ? '까지' : ''}',
            style: const TextStyle(color: hoTaskInk, fontSize: T.body, fontWeight: FontWeight.w600),
          ),
          if (t.kind == TaskKind.temp)
            const Text(
              '체온을 재면 저절로 완료돼요',
              style: TextStyle(color: inkSub, fontSize: T.caption),
            ),
        ],
      );
    }
    final by = t.doneBy != null ? repo.staff(t.doneBy!).displayName : '';
    final m = t.resultMeasurementId != null ? repo.measurement(t.resultMeasurementId!) : null;
    return box(
      bg: hoDoneBg,
      border: hoDoneLine,
      dot: stageColors[Stage.normal]!.line,
      mark: '✓',
      lines: [
        Text(
          '완료 · ${t.label}',
          style: const TextStyle(color: hoDoneInk, fontWeight: FontWeight.w800, fontSize: T.body),
        ),
        if (m != null)
          Text(
            '잰 체온 ${formatTemp(m.value)}℃ ${m.judgment.stage.symbol} ${m.judgment.stage.label}',
            style: const TextStyle(color: inkMain, fontSize: T.body, fontWeight: FontWeight.w600),
          ),
        Text(
          '$by 완료${t.doneAt != null ? ' · ${whenLabel(t.doneAt!, now)}' : ''}',
          style: const TextStyle(color: inkSub, fontSize: T.caption),
        ),
      ],
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
                    color: hoDoneBg,
                    borderRadius: BorderRadius.circular(Radii.button),
                    border: Border.all(color: hoDoneLine),
                  ),
                  child: const Text(
                    '✓ 확인함',
                    style: TextStyle(fontSize: T.body, color: hoDoneInk, fontWeight: FontWeight.w800),
                  ),
                ),
              )
            : OutlinedButton(
                // 시제품: 할 일이 없으면 [확인]이 주 버튼(짙은 색), 할 일이 있으면 [완료하기]가 주 버튼.
                style: openTask
                    ? null
                    : OutlinedButton.styleFrom(
                        backgroundColor: brandDark,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: brandDark),
                      ),
                onPressed: () => repo.markRead(entry.id, me, ref.read(clockProvider)()),
                child: const Text('확인'),
              ),
      if (openTask) FilledButton(onPressed: () => _complete(context, ref), child: const Text('완료하기')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 확인한 사람 얼굴 + "확인 n/4" · 답글 (시제품 .foot)
        Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (readers.isNotEmpty)
                    SizedBox(
                      width: 26.0 + (readers.take(openTask ? 2 : 4).length - 1) * 19,
                      height: 28,
                      child: Stack(
                        children: [
                          for (final (i, id) in readers.take(openTask ? 2 : 4).indexed)
                            Positioned(
                              left: i * 19.0,
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: surface),
                                padding: const EdgeInsets.all(1.5),
                                child: FaceAvatar.staff(id, size: 25),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '확인 '),
                        TextSpan(
                          text: denom == null ? '${readers.length}' : '${readers.length}/$denom',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: inkMain),
                        ),
                      ],
                    ),
                    semanticsLabel: denom == null ? '${readers.length}명 확인' : '$denom명 중 ${readers.length}명 확인',
                    style: const TextStyle(fontSize: T.caption, color: inkSub, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Material(
              color: repliesOpen ? hoSegBg : surface,
              shape: const StadiumBorder(side: BorderSide(color: line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onToggleReplies,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: tapHeight - 4, minWidth: tapHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(repliesOpen ? Icons.expand_less : Icons.chat_bubble_outline, size: 18, color: inkSub),
                        const SizedBox(width: 5),
                        Text(
                          repliesOpen ? '답글 닫기' : '답글 $replyCount개',
                          style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: Gap.s),
          // 시제품처럼 버튼은 오른쪽에. 누르기 쉽게 한 개당 폭 120 이상.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: Gap.s),
                Flexible(
                  child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 120), child: buttons[i]),
                ),
              ],
            ],
          ),
        ] else if (mine)
          const Padding(
            padding: EdgeInsets.only(top: Gap.xs),
            child: Text(
              '내가 남긴 기록이에요',
              style: TextStyle(fontSize: T.caption, color: inkSub),
            ),
          ),
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
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '완료할까요?',
                style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain),
              ),
              const SizedBox(height: Gap.s),
              Text(
                '할 일: ${t.label}',
                style: const TextStyle(fontSize: T.body, color: inkMain),
              ),
              const SizedBox(height: Gap.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => Navigator.pop(s, false), child: const Text('취소')),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: FilledButton(onPressed: () => Navigator.pop(s, true), child: const Text('완료했어요')),
                  ),
                ],
              ),
            ],
          ),
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
    if (!canEdit && !canTask) return const SizedBox(width: Gap.s, height: tapHeight);
    return PopupMenuButton<String>(
      tooltip: '더 보기',
      iconSize: 28,
      padding: const EdgeInsets.all(10),
      icon: const Icon(Icons.more_vert, color: inkSub),
      onSelected: (v) => v == 'edit' ? _edit(context, ref) : _toTask(context, ref),
      itemBuilder: (_) => [
        if (canEdit)
          const PopupMenuItem(
            value: 'edit',
            height: tapHeight,
            child: Text('본문 고치기', style: TextStyle(fontSize: T.body)),
          ),
        if (canTask)
          const PopupMenuItem(
            value: 'task',
            height: tapHeight,
            child: Text('할 일로 넘기기', style: TextStyle(fontSize: T.body)),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: entry.body ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('본문 고치기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              maxLines: 6,
              minLines: 3,
              style: const TextStyle(fontSize: T.body),
            ),
            const SizedBox(height: Gap.s),
            const Text(
              '이전 내용은 지우지 않고 이력으로 남아요.',
              style: TextStyle(fontSize: T.caption, color: inkSub),
            ),
          ],
        ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '할 일로 넘기기',
                style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain),
              ),
              const SizedBox(height: Gap.xs),
              const Text(
                '언제까지 할까요?',
                style: TextStyle(fontSize: T.body, color: inkSub),
              ),
              const SizedBox(height: Gap.s),
              for (final p in taskPresets)
                ListTile(
                  minTileHeight: tapHeight,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p,
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: inkSub),
                  onTap: () => Navigator.pop(s, p),
                ),
            ],
          ),
        ),
      ),
    );
    if (preset == null) return;
    final repo = ref.read(repoProvider);
    final now = ref.read(clockProvider)();
    final body = (entry.body ?? '').split('\n').first;
    repo.attachTask(
      entry.id,
      label: body.length > 14 ? '${body.substring(0, 14)}…' : (body.isEmpty ? '확인하기' : body),
      kind: TaskKind.memo,
      duePreset: preset,
      dueAt: presetDueAt(repo.shifts, preset, now),
    );
    if (context.mounted) showToast(context, '할 일로 넘겼어요 · 완료할 때까지 남은 할 일에 보여요');
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
