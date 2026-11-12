// AR 별님 아카이브 (통합 명세 6-4, 아카이브 명세, 인수인계 3.3). 화면 이름: "기록 모아보기".
// 체온(측정 한 건 = 한 줄) + 이 별님 기록 + 소속 반 공지를 최신순으로 한 타임라인에 보여준다.
// 열기만 해서는 읽음 처리하지 않는다. [새 기록 확인]은 종류·검색 없이 "모두"를 볼 때만.
// 디자인: docs/design.md (40~60대 선생님, 한 줄에 한 가지, 글자 15 이상, 누르는 것 56 이상).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _search = TextEditingController();
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
    _search.dispose();
    super.dispose();
  }

  void _resetConditions() => setState(() {
        _filter = ArchiveFilter.all;
        _search.clear();
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
        appBar: AppBar(title: const Text('기록 모아보기')),
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
    final query = _search.text.trim();
    final searched = all.where((x) => matchesQuery(repo, x, query)).toList();
    final counts = {for (final f in ArchiveFilter.values) f: searched.where((x) => x.matches(f)).length};
    final visible = searched.where((x) => x.matches(_filter)).toList();
    final plain = _filter == ArchiveFilter.all && query.isEmpty;
    final unread = plain ? all.where((x) => isUnread(repo, x, me)).toList() : const <ArchiveRecord>[];
    final rows = buildRows(
      visible: visible,
      homeroomHistory: repo.homeroomHistoryOf(r.classId),
      now: now,
      showHomeroomDividers: _filter != ArchiveFilter.classNotice,
      expanded: _expanded,
    );
    const side = EdgeInsets.symmetric(horizontal: Gap.page);

    return Scaffold(
      appBar: AppBar(title: const Text('기록 모아보기')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _Header(repo: repo, resident: r, cls: cls)),
        if (unread.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.page, 0),
              child: InfoCard(
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.m, Gap.m),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      NewRecordMark(text: '새 기록 ${unread.length}건', size: T.body),
                      const Text('아직 확인 안 했어요', style: TextStyle(fontSize: T.caption, color: inkSub)),
                    ]),
                  ),
                  const SizedBox(width: Gap.s),
                  FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Gap.l)),
                    onPressed: () => _markAllRead(repo, unread, me),
                    child: const Text('새 기록 확인'),
                  ),
                ]),
              ),
            ),
          ),
        // 검색
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.l, Gap.page, 0),
            child: TextField(
              controller: _search,
              maxLength: 80,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: T.body, color: inkMain),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '기록 찾기 (예: 소리)',
                counterText: '',
                constraints: const BoxConstraints(minHeight: tapHeight),
                prefixIcon: const Icon(Icons.search, size: 26, color: inkSub),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '찾는 말 지우기',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.close, color: inkMain),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
        ),
        // 종류 고르기
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.page, 0),
            child: Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
              for (final f in ArchiveFilter.values)
                ChoiceChip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  label: Text('${f.label} ${counts[f]}'),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ]),
          ),
        ),
        if (!plain)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.page, 0),
              child: InfoCard(
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.s, Gap.s),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      query.isEmpty ? '${_filter.label} ${visible.length}건' : '찾은 기록 ${visible.length}건',
                      style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(tapHeight, tapHeight)),
                    onPressed: _resetConditions,
                    child: const Text('모든 기록 보기'),
                  ),
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
            padding: const EdgeInsets.only(top: Gap.s, bottom: 48),
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
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.page, Gap.m),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
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

class _Header extends StatelessWidget {
  const _Header({required this.repo, required this.resident, required this.cls});
  final InMemoryRepository repo;
  final Resident resident;
  final Class cls;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.s, Gap.page, 0),
      child: InfoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ExcludeSemantics(child: ResidentAvatar(name: resident.name, classColor: cls.color, size: 64)),
            const SizedBox(width: Gap.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(resident.name, style: const TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain)),
                Text('${cls.name} · 담임 ${repo.staff(cls.homeroomId).displayName}',
                    style: const TextStyle(fontSize: T.body, color: inkSub)),
              ]),
            ),
          ]),
          const SizedBox(height: Gap.m),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('별님카드 보기'),
            onPressed: () => openResidentCard(context, resident.id),
          ),
        ]),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.m),
        child: Row(children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(label, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
            ),
          ),
          const SizedBox(width: Gap.m),
          const Expanded(child: Divider(thickness: 1.5, height: 1.5)),
        ]),
      );
}

class _HomeroomDivider extends StatelessWidget {
  const _HomeroomDivider({required this.repo, required this.row});
  final InMemoryRepository repo;
  final HomeroomDividerRow row;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: Gap.xl),
        padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: Gap.l),
        decoration: BoxDecoration(
          color: Color.alphaBlend(brandDark.withValues(alpha: 0.08), surface),
          border: const Border.symmetric(horizontal: BorderSide(color: brandDark, width: 1.5)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.swap_horiz, color: brandDark, size: 26),
          ),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${row.at.year}년 ${row.at.month}월부터 담임이 ${_ro(repo.staff(row.toStaffId).displayName)} 바뀌었어요',
                style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain),
              ),
              Text(
                '그 전 담임은 ${_ieyo(repo.staff(row.fromStaffId).displayName)}. 아래 기록도 그대로 이어져요.',
                style: const TextStyle(fontSize: T.caption, color: inkSub),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.m),
      child: Semantics(
        button: true,
        child: InfoCard(
          background: c.soft,
          onTap: onExpand,
          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${Stage.normal.symbol} 평소 체온 ${row.records.length}건 보기',
                      style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: c.ink)),
                  Text('모두 평소와 비슷했어요', style: TextStyle(fontSize: T.caption, color: c.ink)),
                ]),
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
    Color? accent;

    switch (record) {
      case TempRecord(:final m):
        caseId = m.caseId ?? entry?.caseId;
        author = authorAsOf(repo, m.recordedBy, m.classId, m.measuredAt);
        body = [
          Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (m.isVoided) voidLabel else StageTag(m.judgment.stage, large: true),
            Text('${(m.value / 10).toStringAsFixed(1)}℃',
                style: TextStyle(
                  fontSize: T.title,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  decoration: m.isVoided ? TextDecoration.lineThrough : null,
                  color: m.isVoided ? inkSub : inkMain,
                )),
          ]),
          if (!m.isVoided) ...[
            const SizedBox(height: Gap.xs),
            Text(plainDiff(m.judgment.diff), style: const TextStyle(fontSize: T.body, color: inkMain)),
          ],
          if (entry?.body != null) ...[
            const SizedBox(height: Gap.xs),
            Text(entry!.body!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: T.body, height: 1.5)),
          ],
        ];
      case EntryRecord(:final e, :final isClassNotice):
        caseId = e.caseId;
        author = authorAsOf(repo, e.authorId, e.classId, e.createdAt);
        if (isClassNotice) accent = Color(cls.color);
        body = [
          Text(isClassNotice ? '반 공지 · ${cls.name} 전원' : e.kindLabel,
              style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: inkSub)),
          if (e.title != null)
            Text(e.title!, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
          if (e.body != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(e.body!, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: T.body, height: 1.5)),
            ),
          if (e.photoCount > 0) PhotoPlaceholder(e.photoCount),
        ];
    }

    final task = entry?.task;
    final timeWidth = MediaQuery.textScalerOf(context).scale(58);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.m),
      child: InfoCard(
        accent: accent,
        onTap: () => showRecordDetail(context, record),
        padding: const EdgeInsets.fromLTRB(Gap.m, 14, Gap.l, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: timeWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(hhmm(record.at),
                  style: const TextStyle(
                    fontSize: T.body,
                    fontWeight: FontWeight.w800,
                    color: inkMain,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
            ),
          ),
          const SizedBox(width: Gap.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (unread) const Padding(padding: EdgeInsets.only(bottom: Gap.xs), child: NewRecordMark()),
              ...body,
              if (task != null) TaskLine(task),
              if (replies > 0)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.s),
                  child: Text('답글 $replies개', style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: brandDark)),
                ),
              if (caseId != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.m),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text('대응 이력 보기'),
                      onPressed: () => openCaseDetail(context, caseId!),
                    ),
                  ),
                ),
              const SizedBox(height: Gap.s),
              Text(author, style: const TextStyle(fontSize: T.caption, color: inkSub)),
            ]),
          ),
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
