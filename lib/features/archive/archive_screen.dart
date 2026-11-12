// AR 별님 아카이브 (통합 명세 6-4, 아카이브 명세, 인수인계 3.3).
// 체온(측정 한 건 = 한 줄) + 이 별님 기록 + 소속 반 공지를 최신순으로 한 타임라인에 보여준다.
// 열기만 해서는 읽음 처리하지 않는다. [새 기록 확인]은 필터·검색 없는 "모두"에서만.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../handover/write_sheet.dart';
import 'archive_timeline.dart';
import 'archive_widgets.dart';
import 'record_detail_sheet.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key, required this.residentId});
  final String residentId;

  static final Map<String, Route<dynamic>> _openRoutes = {};

  /// 지금 화면 묶음 안에 열려 있는 이 별님의 아카이브 화면.
  /// 별님카드의 [이 별님의 기록 아카이브]가 새로 쌓지 않고 여기로 돌아갈 때 쓴다.
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
      ..showSnackBar(const SnackBar(content: Text('새 기록을 확인했어요 · 최신 기록에도 반영돼요'), duration: Duration(seconds: 3)));
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
        appBar: AppBar(title: const Text('별님 아카이브')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('기록을 불러오지 못했어요'),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(120, 48)),
              onPressed: () => setState(() {}),
              child: const Text('다시 시도'),
            ),
          ]),
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

    return Scaffold(
      appBar: AppBar(title: const Text('별님 아카이브')),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _Header(repo: repo, resident: r, cls: cls, all: all)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Wrap(spacing: 8, children: [
              for (final f in ArchiveFilter.values)
                ChoiceChip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  label: Text('${f.label} ${counts[f]}'),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _search,
              maxLength: 80,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '기록 찾기 (내용·기록자)',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색어 지우기',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        if (!plain)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: Text(query.isEmpty ? '${_filter.label} ${visible.length}건' : '검색 결과 ${visible.length}건',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: _resetConditions,
                  child: const Text('조건 초기화'),
                ),
              ]),
            ),
          ),
        if (unread.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(
                color: stageColors[Stage.caution]!.soft,
                border: Border.all(color: stageColors[Stage.caution]!.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: Text('새 기록 ${unread.length}건 · 아직 확인하지 않았어요',
                      style: TextStyle(color: stageColors[Stage.caution]!.ink, fontWeight: FontWeight.w700)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(44, 44), backgroundColor: brandDark),
                  onPressed: () => _markAllRead(repo, unread, me),
                  child: const Text('새 기록 확인'),
                ),
              ]),
            ),
          ),
        if (all.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('아직 기록이 없어요.', style: TextStyle(color: inkSub))),
          )
        else if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('조건에 맞는 기록이 없어요', style: TextStyle(color: inkSub)),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(120, 48)),
                  onPressed: _resetConditions,
                  child: const Text('전체 기록 보기'),
                ),
              ]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => switch (rows[i]) {
                DayHeaderRow(:final label) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Semantics(
                        header: true, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  ),
                HomeroomDividerRow row => _HomeroomDivider(repo: repo, row: row),
                NormalGroupRow row => _NormalGroup(row: row, onExpand: () => setState(() => _expanded.add(row.groupKey))),
                RecordRow(:final record) => _RecordTile(record: record, repo: repo, me: me, cls: cls),
              },
            ),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: brandDark),
            icon: const Icon(Icons.edit_note),
            label: Text('${r.name} 별님 기록 남기기', overflow: TextOverflow.ellipsis),
            onPressed: () => showWriteSheet(context, ref, classId: r.classId, residentId: r.id),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.repo, required this.resident, required this.cls, required this.all});
  final InMemoryRepository repo;
  final Resident resident;
  final Class cls;
  final List<ArchiveRecord> all;

  @override
  Widget build(BuildContext context) {
    final first = all.isEmpty ? null : all.last.at;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        InitialAvatar(name: resident.name, color: cls.color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(resident.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('${cls.name} · 담임 ${repo.staff(cls.homeroomId).displayName}', style: const TextStyle(color: inkSub)),
            Text(
              first == null ? '기록 0건' : '기록 ${all.length}건 · ${first.year}년 ${first.month}월부터 이어짐',
              style: const TextStyle(color: inkSub, fontSize: 13),
            ),
          ]),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
          onPressed: () => openResidentCard(context, resident.id),
          child: const Text('별님카드 ›'),
        ),
      ]),
    );
  }
}

class _HomeroomDivider extends StatelessWidget {
  const _HomeroomDivider({required this.repo, required this.row});
  final InMemoryRepository repo;
  final HomeroomDividerRow row;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Column(children: [
          const Divider(height: 1, thickness: 1.5),
          const SizedBox(height: 6),
          Text(
            '${row.at.year}년 ${row.at.month}월 · 담임 ${repo.staff(row.fromStaffId).name} → '
            '${repo.staff(row.toStaffId).displayName}. 이전 기록도 그대로 이어져요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: inkSub, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1.5),
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
    final values = row.records.reversed.map((t) => '${hhmm(t.m.measuredAt)} ${formatTemp(t.m.value)}').join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onExpand,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Text('${Stage.normal.symbol} 평소 체온 기록 ${row.records.length}건 · $values℃',
                      style: TextStyle(color: c.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Text('펼치기', style: TextStyle(color: c.ink, fontSize: 12)),
                Icon(Icons.expand_more, color: c.ink, size: 20),
              ]),
            ),
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

    final Color dot;
    final bool hollowDot;
    final List<Widget> body;
    final String? caseId;
    var notice = false;

    switch (record) {
      case TempRecord(:final m):
        final c = stageColors[m.judgment.stage]!;
        dot = m.isVoided ? inkSub : c.line;
        hollowDot = false;
        caseId = m.caseId ?? entry?.caseId;
        body = [
          Text('체온 기록 · ${authorAsOf(repo, m.recordedBy, m.classId, m.measuredAt)}',
              style: const TextStyle(fontSize: 12, color: inkSub)),
          const SizedBox(height: 2),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${formatTemp(m.value)}℃',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  decoration: m.isVoided ? TextDecoration.lineThrough : null,
                  color: m.isVoided ? inkSub : inkMain,
                )),
            if (m.isVoided) voidLabel else StageBadge(m.judgment.stage, dense: true),
            if (!m.isVoided)
              Text('평소보다 ${formatDiff(m.judgment.diff)}', style: const TextStyle(fontSize: 12, color: inkSub)),
          ]),
        ];
      case EntryRecord(:final e, :final isClassNotice):
        notice = isClassNotice;
        dot = isClassNotice ? Color(cls.color) : stageColors[Stage.normal]!.line;
        hollowDot = isClassNotice;
        caseId = e.caseId;
        body = [
          Text(
            '${isClassNotice ? '반 공지 · ${cls.name} 전원' : e.kindLabel} · ${authorAsOf(repo, e.authorId, e.classId, e.createdAt)}',
            style: const TextStyle(fontSize: 12, color: inkSub),
          ),
          if (e.title != null) Text(e.title!, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (e.body != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(e.body!, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
          if (e.photoCount > 0) PhotoPlaceholder(e.photoCount),
        ];
    }

    final task = entry?.task;
    final card = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (unread)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('● 새 기록',
                style: TextStyle(color: stageColors[Stage.caution]!.ink, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ...body,
        if (task != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              task.done ? '✓ 할 일 완료 · ${task.label}' : '○ 할 일 열림 · ${task.label}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: (task.done ? stageColors[Stage.normal]! : stageColors[Stage.caution]!).ink),
            ),
          ),
        if (replies > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('답글 $replies', style: const TextStyle(fontSize: 12, color: inkSub)),
          ),
        if (caseId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 6)),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('대응 이력 보기'),
              onPressed: () => openCaseDetail(context, caseId!),
            ),
          ),
      ]),
    );

    final highlight = unread ? stageColors[Stage.caution]!.line : Colors.transparent;
    Widget tile = Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: notice ? BorderSide.none : BorderSide(color: highlight, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showRecordDetail(context, record),
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: card),
      ),
    );
    if (notice) {
      tile = CustomPaint(foregroundPainter: DashedBorderPainter(unread ? highlight : Color(cls.color)), child: tile);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 16, 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 44,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(hhmm(record.at), style: const TextStyle(fontSize: 12, color: inkSub)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 15, right: 8),
          child: ExcludeSemantics(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hollowDot ? Colors.white : dot,
                border: Border.all(color: dot, width: 2),
              ),
            ),
          ),
        ),
        Expanded(child: tile),
      ]),
    );
  }
}
