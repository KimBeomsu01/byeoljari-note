// AR 별님 아카이브 (통합 명세 6-4, 아카이브 명세, 인수인계 3.3). 화면 이름: "기록 모아보기".
// 체온(측정 한 건 = 한 줄) + 이 별님 기록 + 소속 반 공지를 최신순으로 한 타임라인에 보여준다.
// 열기만 해서는 읽음 처리하지 않는다. [새 기록 확인]은 종류·검색 없이 "모두"를 볼 때만.
// 디자인: docs/design.md v2 — 팀 시제품(모바일 아카이브)의 배치·모양 + 한 단계 큰 글자.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../handover/write_sheet.dart';
import 'archive_timeline.dart';
import 'archive_widgets.dart';
import 'record_detail_sheet.dart';
import 'search_sheet.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key, required this.residentId});
  final String residentId;

  static final Map<String, Route<dynamic>> _openRoutes = {};

  /// 지금 화면 묶음 안에 열려 있는 이 별님의 아카이브 화면.
  /// 별님카드의 [기록 모아보기]가 새로 쌓지 않고 여기로 돌아갈 때 쓴다.
  static Route<dynamic>? openRouteFor(String residentId) {
    final r = _openRoutes[residentId];
    return r != null && r.isActive ? r : null;
  }

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  ArchiveFilter _filter = ArchiveFilter.all;
  String _query = '';

  /// 기간: 0 = 전체 기간, 7·30 = 최근 며칠.
  int _days = 0;
  final Set<String> _expanded = {};
  Route<dynamic>? _route;
  bool _marking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      _route = route;
      ArchiveScreen._openRoutes[widget.residentId] = route;
    }
  }

  @override
  void dispose() {
    if (ArchiveScreen._openRoutes[widget.residentId] == _route) ArchiveScreen._openRoutes.remove(widget.residentId);
    super.dispose();
  }

  void _resetConditions() => setState(() {
        _filter = ArchiveFilter.all;
        _query = '';
        _days = 0;
      });

  void _markAllRead(InMemoryRepository repo, List<ArchiveRecord> unread, String me) {
    if (_marking) return; // 중복 탭은 한 번만 처리
    _marking = true;
    final now = ref.read(clockProvider)();
    for (final r in unread) {
      repo.markRead(r.readTarget!.id, me, now, source: 'archive');
    }
    _marking = false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('새 기록 ${unread.length}건을 확인했어요'), duration: const Duration(seconds: 3)));
  }

  Future<void> _openSearch() async {
    final result = await showSearchSheet(context, query: _query, days: _days);
    if (result == null || !mounted) return;
    setState(() {
      _query = result.query.trim();
      _days = result.days;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final now = ref.read(clockProvider)();

    final Resident r;
    final List<ArchiveRecord> all;
    try {
      r = repo.resident(widget.residentId);
      all = buildArchiveRecords(repo, r.id);
    } catch (_) {
      // 실패를 0건으로 보이지 않는다 (5-5).
      return Scaffold(
        appBar: prototypeAppBar('기록 모아보기'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: EmptyNote(
              '기록을 불러오지 못했어요',
              action: OutlinedButton(onPressed: () => setState(() {}), child: const Text('다시 불러오기')),
            ),
          ),
        ),
      );
    }

    final cls = repo.classOf(r.classId);
    final query = _query;
    final today = DateTime(now.year, now.month, now.day);
    bool inPeriod(ArchiveRecord x) =>
        _days == 0 || today.difference(DateTime(x.at.year, x.at.month, x.at.day)).inDays < _days;
    final searched = all.where((x) => inPeriod(x) && matchesQuery(repo, x, query)).toList();
    final counts = {for (final f in ArchiveFilter.values) f: searched.where((x) => x.matches(f)).length};
    final visible = searched.where((x) => x.matches(_filter)).toList();
    final searching = query.isNotEmpty || _days != 0;
    final plain = _filter == ArchiveFilter.all && !searching;
    final unread = plain ? all.where((x) => isUnread(repo, x, me)).toList() : const <ArchiveRecord>[];
    final rows = buildRows(
      visible: visible,
      homeroomHistory: repo.homeroomHistoryOf(r.classId),
      now: now,
      showHomeroomDividers: _filter != ArchiveFilter.classNotice,
      expanded: _expanded,
    );
    const side = EdgeInsets.symmetric(horizontal: Gap.page);
    final meta = '${query.isEmpty ? '전체 기록' : '‘$query’ 찾는 중'} · ${_days == 0 ? '전체 기간' : '최근 $_days일'}';

    return Scaffold(
      appBar: prototypeAppBar('기록 모아보기'),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page - 4, 0, Gap.page, 0),
            child: BackLink('${cls.name} 별님 목록'),
          ),
        ),
        SliverToBoxAdapter(
          child: _Header(repo: repo, resident: r, cls: cls, total: all.length, since: all.isEmpty ? null : all.last.at),
        ),
        // 이 별님의 기록 아카이브 + 종류 고르기 + 기록 찾기
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.l + 4, Gap.page, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(
                header: true,
                child: const Text('이 별님의 기록 아카이브',
                    style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
              ),
              const SizedBox(height: Gap.m),
              _FilterTrack(selected: _filter, counts: counts, onSelect: (f) => setState(() => _filter = f)),
              const SizedBox(height: Gap.xs),
              Row(children: [
                Expanded(child: Text(meta, style: const TextStyle(fontSize: T.caption, color: inkSub))),
                const SizedBox(width: Gap.s),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(tapHeight, tapHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: inkMain,
                  ),
                  icon: const Icon(Icons.search, size: 24),
                  label: const Text('기록 찾기'),
                  onPressed: _openSearch,
                ),
              ]),
            ]),
          ),
        ),
        if (unread.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, 0),
              child: _UnreadBar(count: unread.length, onConfirm: () => _markAllRead(repo, unread, me)),
            ),
          ),
        if (searching)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, 0),
              child: GreyBox(
                padding: const EdgeInsets.fromLTRB(Gap.l, 2, 2, 2),
                child: Row(children: [
                  Expanded(
                    child: Text('찾은 기록 ${visible.length}건',
                        style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
                  ),
                  TextButton(onPressed: _resetConditions, child: const Text('모든 기록 보기')),
                ]),
              ),
            ),
          ),
        if (all.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(padding: side, child: EmptyNote('아직 남긴 기록이 없어요')),
          )
        else if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: side,
              child: EmptyNote(
                '찾는 기록이 없어요',
                action: OutlinedButton(onPressed: _resetConditions, child: const Text('모든 기록 보기')),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 40),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => switch (rows[i]) {
                DayHeaderRow(:final label) => _DayHeader(label),
                HomeroomDividerRow row => _HomeroomDivider(repo: repo, row: row),
                NormalGroupRow row => _NormalGroup(row: row, onExpand: () => setState(() => _expanded.add(row.groupKey))),
                RecordRow(:final record) => _RecordTile(record: record, repo: repo, me: me, cls: cls),
              },
            ),
          ),
      ]),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(color: surface, border: Border(top: BorderSide(color: line))),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 10, Gap.page, 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.edit_note, size: 26),
              label: Text('${r.name} 별님 기록 남기기', overflow: TextOverflow.ellipsis),
              onPressed: () => showWriteSheet(context, ref, classId: r.classId, residentId: r.id),
            ),
          ),
        ),
      ),
    );
  }
}

/// 별님 카드 (시제품 .prof): 얼굴 · 이름 · 반과 담임 · 기록 수, 별님카드로 가는 작은 알약 버튼.
class _Header extends StatelessWidget {
  const _Header({required this.repo, required this.resident, required this.cls, required this.total, this.since});
  final InMemoryRepository repo;
  final Resident resident;
  final Class cls;
  final int total;
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, 0),
      child: InfoCard(
        padding: const EdgeInsets.fromLTRB(Gap.l, 14, Gap.l, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FaceAvatar.resident(resident.id, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${resident.name} 별님',
                  style: const TextStyle(fontSize: T.title + 2, fontWeight: FontWeight.w800, color: inkMain, height: 1.3)),
              const SizedBox(height: 2),
              Text('${cls.name} · 담임 ${repo.staff(cls.homeroomId).displayName}',
                  style: const TextStyle(fontSize: T.caption, color: inkSub)),
              if (since != null)
                Text('기록 $total건 · ${since!.year}년 ${since!.month}월부터 이어짐',
                    style: const TextStyle(fontSize: T.caption, color: inkSub)),
              const SizedBox(height: Gap.s),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(tapHeight, tapHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: const Color(0xFFF1F8EA),
                  foregroundColor: okInk,
                  side: const BorderSide(color: okLine),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => openResidentCard(context, resident.id),
                child: const Text('별님카드 보기'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 시제품 .aseg: 회색 바탕 위 흰 칸이 고른 것. 한 줄에 다 안 들어가면 두 줄로.
class _FilterTrack extends StatelessWidget {
  const _FilterTrack({required this.selected, required this.counts, required this.onSelect});
  final ArchiveFilter selected;
  final Map<ArchiveFilter, int> counts;
  final ValueChanged<ArchiveFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final scaler = MediaQuery.textScalerOf(context);
    String label(ArchiveFilter f) => '${f.label} ${counts[f]}';
    double need(ArchiveFilter f) {
      final tp = TextPainter(
        text: TextSpan(text: label(f), style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, fontFamily: family)),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width + 14;
    }

    Widget seg(ArchiveFilter f) => _Segment(text: label(f), selected: f == selected, onTap: () => onSelect(f));
    const gap = SizedBox(width: 4, height: 4);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: segTrack, borderRadius: BorderRadius.circular(Radii.button)),
      child: LayoutBuilder(builder: (context, c) {
        const fs = ArchiveFilter.values;
        final widths = [for (final f in fs) need(f)];
        final oneRow = widths.fold<double>(0, (a, b) => a + b) + 4 * (fs.length - 1) <= c.maxWidth;
        if (oneRow) {
          return Row(children: [
            for (var i = 0; i < fs.length; i++) ...[
              if (i > 0) gap,
              Expanded(flex: (widths[i] * 10).round(), child: seg(fs[i])),
            ],
          ]);
        }
        return Column(children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) gap,
            Row(children: [
              Expanded(child: seg(fs[row * 2])),
              gap,
              Expanded(child: seg(fs[row * 2 + 1])),
            ]),
          ],
        ]);
      }),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.text, required this.selected, required this.onTap});
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: tapHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Text(text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: T.body,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? inkMain : inkSub,
                      )),
                ),
              ),
            ),
          ),
        ),
      );
}

/// 새 기록 알림 줄 (시제품 .readline 색): "● 새 기록 7건 · 아직 확인 안 했어요" + [새 기록 확인].
class _UnreadBar extends StatelessWidget {
  const _UnreadBar({required this.count, required this.onConfirm});
  final int count;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = stageColors[Stage.caution]!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: unreadLine),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            NewRecordMark(text: '새 기록 $count건', size: T.body),
            Text('아직 확인 안 했어요', style: TextStyle(fontSize: T.caption, color: c.ink)),
          ]),
        ),
        const SizedBox(width: Gap.s),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
          onPressed: onConfirm,
          child: const Text('새 기록 확인'),
        ),
      ]),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page + 2, 14, Gap.page, 4),
        child: Semantics(
          header: true,
          child: Text(label, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkSub)),
        ),
      );
}

/// 왼쪽 세로선 + 색 점 (시제품 .ent). 기록 상자를 시간 줄에 매단다.
class _Rail extends StatelessWidget {
  const _Rail({required this.dot, required this.child});
  final Color dot;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page + 6, 0, Gap.page, 0),
        child: Container(
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: line, width: 2))),
          padding: const EdgeInsets.fromLTRB(14, 5, 0, 5),
          child: Stack(clipBehavior: Clip.none, children: [
            child,
            Positioned(
              left: -22,
              top: 16,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: paper, width: 2.5)),
              ),
            ),
          ]),
        ),
      );
}

/// 기록 상자 (시제품 .ebox). 반 공지는 반 색 옅은 바탕 + 반 색 점선.
class _EntryBox extends StatelessWidget {
  const _EntryBox({required this.child, this.onTap, this.background, this.border, this.dashed, this.padding});
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? background;
  final Color? border;
  final Color? dashed;

  @override
  Widget build(BuildContext context) {
    final box = Material(
      color: background ?? surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.button),
        side: dashed != null ? BorderSide.none : BorderSide(color: border ?? line, width: border == null ? 1 : 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12), child: child),
      ),
    );
    if (dashed == null) return box;
    return CustomPaint(foregroundPainter: DashedRRectPainter(color: dashed!, radius: Radii.button), child: box);
  }
}

class _HomeroomDivider extends StatelessWidget {
  const _HomeroomDivider({required this.repo, required this.row});
  final InMemoryRepository repo;
  final HomeroomDividerRow row;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(Gap.page, Gap.l, Gap.page, 0),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: const Color(0xFFF1EFF7), borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('✦', style: TextStyle(fontSize: T.body, color: noticeInk, height: 1.5)),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${row.at.year}년 ${row.at.month}월부터 담임이 ${_ro(repo.staff(row.toStaffId).displayName)} 바뀌었어요',
                style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: noticeInk),
              ),
              Text(
                '그 전 담임은 ${_ieyo(repo.staff(row.fromStaffId).displayName)}. 아래 기록도 그대로 이어져요.',
                style: const TextStyle(fontSize: T.caption, color: noticeInk),
              ),
            ]),
          ),
        ]),
      );
}

class _NormalGroup extends StatelessWidget {
  const _NormalGroup({required this.row, required this.onExpand});
  final NormalGroupRow row;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final c = stageColors[Stage.normal]!;
    return _Rail(
      dot: c.line,
      child: Semantics(
        button: true,
        child: _EntryBox(
          background: c.soft,
          border: okLine,
          onTap: onExpand,
          padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(children: [
              Expanded(
                child: Text('${Stage.normal.symbol} 평소 체온 ${row.records.length}건 보기',
                    style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: c.ink)),
              ),
              Icon(Icons.expand_more, color: c.ink, size: 28),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.repo, required this.me, required this.cls});
  final ArchiveRecord record;
  final InMemoryRepository repo;
  final String me;
  final Class cls;

  @override
  Widget build(BuildContext context) {
    final unread = isUnread(repo, record, me);
    final entry = record.readTarget;
    final replies = entry == null ? 0 : repo.repliesOf(entry.id).length;

    final List<Widget> body;
    final String? caseId;
    final String author;
    final KindTag kind;
    final Color dot;
    var notice = false;

    switch (record) {
      case TempRecord(:final m):
        caseId = m.caseId ?? entry?.caseId;
        author = authorAsOf(repo, m.recordedBy, m.classId, m.measuredAt);
        final sc = stageColors[m.judgment.stage]!;
        kind = m.isVoided
            ? const KindTag('체온', ink: inkSub, background: softGrey)
            : KindTag('체온', ink: sc.ink, background: sc.soft);
        dot = m.isVoided ? inkSub : sc.line;
        body = [
          Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${(m.value / 10).toStringAsFixed(1)}℃',
                style: TextStyle(
                  fontSize: T.title + 1,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  decoration: m.isVoided ? TextDecoration.lineThrough : null,
                  color: m.isVoided ? inkSub : inkMain,
                )),
            if (m.isVoided) voidLabel else StageTag(m.judgment.stage),
          ]),
          if (!m.isVoided) Text(plainDiff(m.judgment.diff), style: const TextStyle(fontSize: T.body, color: inkMain)),
          if (entry?.body != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(entry!.body!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: T.body, height: 1.5, color: inkMain)),
            ),
        ];
      case EntryRecord(:final e, :final isClassNotice):
        caseId = e.caseId;
        author = authorAsOf(repo, e.authorId, e.classId, e.createdAt);
        notice = isClassNotice;
        kind = isClassNotice
            ? const KindTag('반 공지', ink: noticeInk, background: surface)
            : KindTag(e.kindLabel.replaceAll(' 기록', ''), ink: okInk, background: okSoft);
        dot = isClassNotice ? noticeDot : obsDot;
        body = [
          if (e.title != null)
            Text(e.title!, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
          if (e.body != null)
            Text(e.body!,
                maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: T.body, height: 1.55, color: inkMain)),
          if (e.photoCount > 0) PhotoPlaceholder(e.photoCount),
        ];
    }

    final task = entry?.task;
    final Widget? status = entry == null
        ? null
        : unread
            ? const NewRecordMark()
            : Text(entry.authorId == me ? '내가 남긴 기록' : '✓ 확인함',
                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub));
    final classColor = Color(cls.color);

    return _Rail(
      dot: dot,
      child: _EntryBox(
        onTap: () => showRecordDetail(context, record),
        background: notice ? Color.alphaBlend(classColor.withValues(alpha: 0.12), surface) : null,
        dashed: notice ? classColor : null,
        border: unread && !notice ? unreadLine : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 종류 · 시각 · 기록자
          Wrap(spacing: Gap.s, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
            kind,
            Text('${hhmm(record.at)} · $author',
                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub)),
          ]),
          if (notice)
            Text('${cls.name} 전원에게 기록',
                style: const TextStyle(fontSize: T.caption, color: noticeInk, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...body,
          if (task != null) TaskLine(task),
          if (replies > 0)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text('답글 $replies개', style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: brandDark)),
            ),
          if (caseId != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('대응 이력 보기'),
                  onPressed: () => openCaseDetail(context, caseId!),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Align(alignment: Alignment.centerLeft, child: status ?? const SizedBox.shrink())),
            const Text('상세 ›', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
          ]),
        ]),
      ),
    );
  }
}

// 받침에 따라 "으로/로", "이에요/예요".
int? _jong(String w) {
  if (w.isEmpty) return null;
  final c = w.codeUnitAt(w.length - 1);
  if (c < 0xAC00 || c > 0xD7A3) return null;
  return (c - 0xAC00) % 28;
}

String _ro(String w) {
  final j = _jong(w);
  return (j == null || j == 0 || j == 8) ? '$w로' : '$w으로'; // ㄹ 받침은 "로"
}

String _ieyo(String w) {
  final j = _jong(w);
  return (j == null || j == 0) ? '$w예요' : '$w이에요';
}
