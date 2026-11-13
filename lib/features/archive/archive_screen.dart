// AR 별님 아카이브 (통합 명세 6-4, 아카이브 명세, 인수인계 3.3). 화면 이름: "기록 모아보기".
// 체온(측정 한 건 = 한 줄) + 이 별님 기록 + 소속 반 공지를 최신순으로 한 타임라인에 보여준다.
// 열기만 해서는 읽음 처리하지 않는다. [다 봤어요]는 종류·검색 없이 "모두"를 볼 때만.
// 디자인: 개선 시안 5 "이 별님한테 요즘 무슨 일이 있었지?" — 이름 밑 평소 체온, 새 기록 띠 한 줄,
// 탭 이름만, 위쪽 돋보기 하나, 기록마다 노란 점 하나 + 카드 전체를 눌러 상세.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/judgment.dart';
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

/// 시안 색 (이 화면에서만).
const _segTrack = Color(0xFFF7E6E1);
const _newBand = Color(0xFFFDF3DC);
const _softGreen = Color(0xFFEEF5EA);

/// 탭 이름 (개수 없이 짧게).
String archiveTabLabel(ArchiveFilter f) => switch (f) {
      ArchiveFilter.all => '모두',
      ArchiveFilter.temp => '체온',
      ArchiveFilter.observation => '관찰',
      ArchiveFilter.classNotice => '공지',
    };

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
      ..showSnackBar(SnackBar(content: Text('새 기록 ${unread.length}개를 다 봤어요'), duration: const Duration(seconds: 3)));
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
        body: SafeArea(
          child: Column(children: [
            const _TopRow(back: '돌아가기'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                  child: EmptyNote(
                    '기록을 불러오지 못했어요',
                    action: OutlinedButton(onPressed: () => setState(() {}), child: const Text('다시 불러오기')),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    final cls = repo.classOf(r.classId);
    final query = _query;
    final today = DateTime(now.year, now.month, now.day);
    bool inPeriod(ArchiveRecord x) =>
        _days == 0 || today.difference(DateTime(x.at.year, x.at.month, x.at.day)).inDays < _days;
    final searched = all.where((x) => inPeriod(x) && matchesQuery(repo, x, query)).toList();
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
    final baseline = repo.baselineOf(r.id, now);
    final homeroom = repo.staff(cls.homeroomId);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: _TopRow(back: '${cls.name} 별님', onSearch: _openSearch),
          ),
          // 얼굴 · 이름 · 평소 체온 · 담임 · [별님카드]
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.l, Gap.page, 0),
              child: Row(children: [
                FaceAvatar.resident(r.id, size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(
                      header: true,
                      child: Text('${r.name} 별님',
                          style: const TextStyle(
                              fontFamily: fontBig, fontSize: 26, fontWeight: FontWeight.w800, color: inkMain, height: 1.25)),
                    ),
                    const SizedBox(height: 2),
                    // 좁으면 "평소 체온 …℃ ·" / "담임 …"로 말 덩어리째 줄을 바꾼다.
                    Wrap(children: [
                      Text('평소 체온 ${formatTemp(baseline.value)}℃ · ',
                          style: const TextStyle(fontSize: T.caption, color: inkSub, letterSpacing: -0.3)),
                      Text('담임 ${homeroom.name}',
                          style: const TextStyle(fontSize: T.caption, color: inkSub, letterSpacing: -0.3)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 4),
                Semantics(
                  label: '${r.name} 별님카드 열기',
                  button: true,
                  excludeSemantics: true,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: _softGreen,
                      foregroundColor: brandDark,
                      textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 16, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
                    ),
                    onPressed: () => openResidentCard(context, r.id),
                    child: const Text('별님카드'),
                  ),
                ),
              ]),
            ),
          ),
          // 종류 탭 (개수 없이 이름만)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.l, Gap.page, 0),
              child: _FilterTrack(selected: _filter, onSelect: (f) => setState(() => _filter = f)),
            ),
          ),
          if (unread.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.page, Gap.l, Gap.page, 0),
                child: _UnreadBand(count: unread.length, onConfirm: () => _markAllRead(repo, unread, me)),
              ),
            ),
          if (searching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.page, Gap.l, Gap.page, 0),
                child: _SearchBand(
                  title: query.isEmpty ? '최근 $_days일 기록' : '‘$query’ 찾는 중 · ${_days == 0 ? '전체 기간' : '최근 $_days일'}',
                  count: visible.length,
                  onEdit: _openSearch,
                  onReset: _resetConditions,
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
              padding: const EdgeInsets.only(bottom: 32),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => switch (rows[i]) {
                  DayHeaderRow(:final label) => _DayHeader(label),
                  HomeroomDividerRow row => _HomeroomDivider(repo: repo, row: row),
                  NormalGroupRow row =>
                    _NormalGroup(row: row, onExpand: () => setState(() => _expanded.add(row.groupKey))),
                  RecordRow(:final record) => _RecordCard(record: record, repo: repo, me: me),
                },
              ),
            ),
        ]),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(color: surface, border: Border(top: BorderSide(color: Color(0xFFF1DFD9)))),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 14, Gap.page, 14),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              onPressed: () => showWriteSheet(context, ref, classId: r.classId, residentId: r.id),
              child: Text('${r.name} 별님 기록 남기기', overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

/// 맨 위 줄: "‹ 은하수자리 별님" (뒤로) + 둥근 돋보기 (기록 찾기).
class _TopRow extends StatelessWidget {
  const _TopRow({required this.back, this.onSearch});
  final String back;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page - 8, 4, Gap.page, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: tapHeight),
          child: Row(children: [
            Flexible(
              child: Semantics(
                label: '뒤로: $back',
                button: true,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.button),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: tapHeight, minWidth: tapHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('‹',
                            style: TextStyle(
                                fontFamily: fontBig, fontSize: 32, fontWeight: FontWeight.w700, color: inkMain, height: 1)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(back,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, color: inkSub)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (onSearch != null)
              Material(
                color: surface,
                shape: const CircleBorder(side: BorderSide(color: line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSearch,
                  child: Tooltip(
                    message: '기록 찾기',
                    child: Semantics(
                      label: '기록 찾기',
                      button: true,
                      excludeSemantics: true,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.search, size: 24, color: inkMain),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

/// 분홍 바탕 위 흰 칸이 고른 것. 글자가 커서 한 줄에 안 들어가면 두 줄로.
class _FilterTrack extends StatelessWidget {
  const _FilterTrack({required this.selected, required this.onSelect});
  final ArchiveFilter selected;
  final ValueChanged<ArchiveFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double need(ArchiveFilter f) {
      final tp = TextPainter(
        text: TextSpan(
            text: archiveTabLabel(f),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: fontSmall)),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width + 16;
    }

    Widget seg(ArchiveFilter f) => _Segment(text: archiveTabLabel(f), selected: f == selected, onTap: () => onSelect(f));
    const gap = SizedBox(width: 6, height: 6);

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: _segTrack, borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(builder: (context, c) {
        const fs = ArchiveFilter.values;
        final widest = fs.map(need).reduce((a, b) => a > b ? a : b);
        final oneRow = widest * fs.length + 6 * (fs.length - 1) <= c.maxWidth;
        if (oneRow) {
          return Row(children: [
            for (var i = 0; i < fs.length; i++) ...[if (i > 0) gap, Expanded(child: seg(fs[i]))],
          ]);
        }
        return Column(children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) gap,
            Row(children: [Expanded(child: seg(fs[row * 2])), gap, Expanded(child: seg(fs[row * 2 + 1]))]),
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
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Text(text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected ? inkMain : inkSub,
                      )),
                ),
              ),
            ),
          ),
        ),
      );
}

/// 새 기록 띠 한 줄: "● 새 기록 7개" + [다 봤어요]. 읽음 처리는 이 버튼으로만.
class _UnreadBand extends StatelessWidget {
  const _UnreadBand({required this.count, required this.onConfirm});
  final int count;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(color: _newBand, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
              width: 12, height: 12, decoration: const BoxDecoration(color: starYellow, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('새 기록 $count개',
                style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
          ),
          const SizedBox(width: Gap.s),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontFamily: fontSmall, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            onPressed: onConfirm,
            child: const Text('다 봤어요'),
          ),
        ]),
      );
}

/// 찾는 중일 때만 보이는 띠: 조건 · 찾은 수 · [조건 바꾸기] · [모든 기록 보기].
class _SearchBand extends StatelessWidget {
  const _SearchBand({required this.title, required this.count, required this.onEdit, required this.onReset});
  final String title;
  final int count;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: T.caption, color: inkSub)),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: Gap.xs, children: [
            Padding(
              padding: const EdgeInsets.only(right: Gap.s),
              child: Text('찾은 기록 $count건',
                  style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
            ),
            TextButton(onPressed: onEdit, child: const Text('조건 바꾸기')),
            TextButton(onPressed: onReset, child: const Text('모든 기록 보기')),
          ]),
        ]),
      );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page + 2, 18, Gap.page, 10),
        child: Semantics(
          header: true,
          child: Text(label,
              style: const TextStyle(fontFamily: fontBig, fontSize: 16, fontWeight: FontWeight.w700, color: inkSub)),
        ),
      );
}

/// 기록 카드 바탕 (시안: 흰 카드, 둥글기 18, 옅은 테두리).
class _CardBox extends StatelessWidget {
  const _CardBox({required this.child, this.onTap, this.background, this.border, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final Color? background;
  final Color? border;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 10),
        child: Material(
          color: background ?? surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: border ?? line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14), child: child),
          ),
        ),
      );
}

class _HomeroomDivider extends StatelessWidget {
  const _HomeroomDivider({required this.repo, required this.row});
  final InMemoryRepository repo;
  final HomeroomDividerRow row;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(Gap.page, Gap.s, Gap.page, 0),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: const Color(0xFFF1EFF7), borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('✦', style: TextStyle(fontSize: T.body, color: noticeInk, height: 1.5)),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${row.at.year}년 ${row.at.month}월부터 담임이 ${_ro(repo.staff(row.toStaffId).displayName)} 바뀌었어요',
                style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: noticeInk),
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
    return Semantics(
      button: true,
      child: _CardBox(
        background: c.soft,
        border: okLine,
        onTap: onExpand,
        padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(children: [
            Expanded(
              child: Text('${Stage.normal.symbol} 평소 체온 ${row.records.length}건 보기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
            ),
            Icon(Icons.expand_more, color: c.ink, size: 26),
          ]),
        ),
      ),
    );
  }
}

/// 기록 카드: "09:15 · 체온 · 이수진 선생님" 한 줄 + 내용. 안 본 기록은 오른쪽 위 노란 점.
/// 확인 상태·답글·대응 이력은 카드를 눌러 여는 상세에서.
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.repo, required this.me});
  final ArchiveRecord record;
  final InMemoryRepository repo;
  final String me;

  @override
  Widget build(BuildContext context) {
    final unread = isUnread(repo, record, me);
    final entry = record.readTarget;

    final List<Widget> body;
    final String author;
    final String kind;

    switch (record) {
      case TempRecord(:final m):
        author = authorAsOf(repo, m.recordedBy, m.classId, m.measuredAt);
        kind = '체온';
        final task = entry?.task;
        body = [
          Wrap(spacing: 10, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${formatTemp(m.value)}℃',
                style: TextStyle(
                  fontFamily: fontBig,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  decoration: m.isVoided ? TextDecoration.lineThrough : null,
                  color: m.isVoided ? inkSub : inkMain,
                )),
            if (m.isVoided) voidLabel else StageTag(m.judgment.stage),
          ]),
          if (!m.isVoided || task != null)
            Text.rich(
              TextSpan(children: [
                if (!m.isVoided) TextSpan(text: plainDiff(m.judgment.diff)),
                if (!m.isVoided && task != null) const TextSpan(text: ' · '),
                if (task != null)
                  TextSpan(text: _taskNote(task), style: TextStyle(fontWeight: FontWeight.w700, color: _taskInk(task))),
              ]),
              style: const TextStyle(fontSize: 16, color: inkMain, height: 1.45),
            ),
          if (entry?.body != null)
            Text(entry!.body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, height: 1.45, color: inkMain)),
        ];
      case EntryRecord(:final e, :final isClassNotice):
        author = authorAsOf(repo, e.authorId, e.classId, e.createdAt);
        kind = isClassNotice ? '반 공지' : e.kindLabel.replaceAll(' 기록', '');
        final task = e.task;
        body = [
          if (e.title != null)
            Text(e.title!,
                style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain, height: 1.4)),
          if (e.body != null)
            Text(e.body!,
                maxLines: e.title == null ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: e.title == null ? T.body : 16,
                  fontWeight: e.title == null ? FontWeight.w700 : FontWeight.w400,
                  height: 1.45,
                  color: inkMain,
                )),
          if (task != null)
            Text(_taskNote(task), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _taskInk(task))),
          if (e.photoCount > 0) PhotoPlaceholder(e.photoCount),
        ];
    }

    return Semantics(
      label: unread ? '새 기록' : null,
      child: _CardBox(
        onTap: () => showRecordDetail(context, record),
        child: Stack(clipBehavior: Clip.none, children: [
          Padding(
            padding: EdgeInsets.only(right: unread ? 18 : 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${hhmm(record.at)} · $kind · $author', style: const TextStyle(fontSize: T.caption, color: inkSub)),
              const SizedBox(height: 6),
              for (var i = 0; i < body.length; i++) ...[if (i > 0) const SizedBox(height: 6), body[i]],
            ]),
          ),
          if (unread)
            const Positioned(
              top: 2,
              right: 0,
              child: SizedBox(
                width: 10,
                height: 10,
                child: DecoratedBox(decoration: BoxDecoration(color: starYellow, shape: BoxShape.circle)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// 할 일 한 마디: "다시 재기 남음" / "✓ 다시 재기 끝".
String _taskNote(Task task) {
  final label = task.label == '재측정' ? '다시 재기' : task.label;
  return task.done ? '✓ $label 끝' : '$label 남음';
}

Color _taskInk(Task task) => (task.done ? stageColors[Stage.normal] : stageColors[Stage.caution])!.ink;

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
