// DESK-2 별님 기록 (원본 3장 + 통합 6-7-1·2·6).
// 타임라인 데이터·규칙은 앱 아카이브와 같다 (archive_timeline.dart의 순수 함수 사용).
// 기록을 열어 보기만 한다: 확인(읽음)·업무 완료로 처리하지 않는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/baseline.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../alert_case/case_ui.dart' show CaseBadge, caseStatusLabel;
import '../archive/archive_timeline.dart';
import '../archive/archive_widgets.dart' show authorAsOf, ymdHm;
import 'desk_common.dart';

enum DeskKind { all, personal, classNotice }

extension DeskKindLabel on DeskKind {
  String get label => switch (this) {
        DeskKind.all => '모두',
        DeskKind.personal => '이 별님 기록',
        DeskKind.classNotice => '반 공지',
      };
}

enum DeskPeriod { all, week, month }

extension DeskPeriodLabel on DeskPeriod {
  String get label => switch (this) {
        DeskPeriod.all => '전체',
        DeskPeriod.week => '최근 7일',
        DeskPeriod.month => '최근 30일',
      };
  Duration? get span => switch (this) {
        DeskPeriod.all => null,
        DeskPeriod.week => const Duration(days: 7),
        DeskPeriod.month => const Duration(days: 30),
      };
}

bool kindMatches(DeskKind k, ArchiveRecord r) => switch (k) {
      DeskKind.all => true,
      DeskKind.personal => !(r is EntryRecord && r.isClassNotice),
      DeskKind.classNotice => r is EntryRecord && r.isClassNotice,
    };

/// 조건에 맞는 타임라인 기록 (최신순).
List<ArchiveRecord> deskTimeline(InMemoryRepository repo, String residentId,
    {DeskKind kind = DeskKind.all, DeskPeriod period = DeskPeriod.all, String query = '', required DateTime now}) {
  final from = period.span == null ? null : now.subtract(period.span!);
  return [
    for (final r in buildArchiveRecords(repo, residentId))
      if (kindMatches(kind, r) && (from == null || !r.at.isBefore(from)) && matchesQuery(repo, r, query)) r,
  ];
}

class DeskResidentView extends ConsumerStatefulWidget {
  const DeskResidentView({super.key, this.residentId, this.initialRecordKey, required this.onSelect, required this.onCase});
  final String? residentId;
  final String? initialRecordKey;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onCase;

  @override
  ConsumerState<DeskResidentView> createState() => _DeskResidentViewState();
}

class _DeskResidentViewState extends ConsumerState<DeskResidentView> {
  String? classFilter;
  String nameQuery = '';
  DeskKind kind = DeskKind.all;
  DeskPeriod period = DeskPeriod.all;
  bool showTable = false;
  String? selectedKey;
  final keyword = TextEditingController();
  final scroll = ScrollController();
  final listScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedKey = widget.initialRecordKey;
    // 다른 메뉴에서 넘어오면 고른 별님이 목록에서 보이게 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.residentId;
      if (id == null || !listScroll.hasClients || !mounted) return;
      final repo = ref.read(repoProvider);
      final all = [for (final c in repo.classes) ...repo.residentsOf(c.id)];
      final i = all.indexWhere((r) => r.id == id);
      if (i > 2) listScroll.jumpTo(math.min((i - 2) * 56.0, listScroll.position.maxScrollExtent));
    });
    keyword.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant DeskResidentView old) {
    super.didUpdateWidget(old);
    if (old.residentId != widget.residentId) {
      // 다른 별님을 고르면 이전 별님 상세를 비운다 (원본 6장).
      selectedKey = null;
      if (scroll.hasClients) scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    keyword.dispose();
    scroll.dispose();
    listScroll.dispose();
    super.dispose();
  }

  void closeDetail() => setState(() => selectedKey = null);

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 250, child: _residentList(repo)),
      const SizedBox(width: Gap.l),
      Expanded(
        child: widget.residentId == null
            ? const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyNote('왼쪽 목록에서 별님을 골라 주세요'),
              )
            : CallbackShortcuts(
                bindings: {const SingleActivator(LogicalKeyboardKey.escape): closeDetail},
                child: LayoutBuilder(builder: (context, c) {
                  final rec = _selectedRecord(repo);
                  return Stack(children: [
                    Positioned.fill(child: _detailScroll(repo, widget.residentId!, now)),
                    if (rec != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 16,
                        width: math.min(420, c.maxWidth - 24),
                        child: _RecordPanel(
                          key: ValueKey('desk-panel-${rec.key}'),
                          record: rec,
                          residentId: widget.residentId!,
                          onClose: closeDetail,
                          onCase: widget.onCase,
                        ),
                      ),
                  ]);
                }),
              ),
      ),
    ]);
  }

  ArchiveRecord? _selectedRecord(InMemoryRepository repo) {
    if (selectedKey == null || widget.residentId == null) return null;
    for (final r in buildArchiveRecords(repo, widget.residentId!)) {
      if (r.key == selectedKey) return r;
    }
    return null;
  }

  // ── 왼쪽 별님 목록

  Widget _residentList(InMemoryRepository repo) {
    final q = nameQuery.trim();
    final list = [
      for (final c in repo.classes)
        if (classFilter == null || classFilter == c.id)
          for (final r in repo.residentsOf(c.id))
            if (q.isEmpty || r.name.contains(q)) r,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DropdownButtonFormField<String?>(
            key: const ValueKey('desk-res-class'),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            key: const ValueKey('desk-res-search'),
            decoration: const InputDecoration(hintText: '별님 이름 찾기', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => nameQuery = v),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? const EmptyNote('조건에 맞는 별님이 없어요')
              : ListView(controller: listScroll, itemExtent: 56, children: [
                  for (final r in list)
                    Material(
                      color: r.id == widget.residentId ? sage : surface,
                      child: InkWell(
                        key: ValueKey('desk-res-${r.id}'),
                        onTap: () => widget.onSelect(r.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: r.id == widget.residentId
                              ? const BoxDecoration(border: Border(left: BorderSide(color: brandDark, width: 4)))
                              : null,
                          child: Row(children: [
                            FaceAvatar.resident(r.id, size: 36),
                            const SizedBox(width: 10),
                            Expanded(child: TwoLine(r.name, repo.classOf(r.classId).name)),
                            if (repo.openCaseOf(r.id) case final c?)
                              Text(c.isUrgent ? '⚠ 긴급' : '${c.severity.symbol} 대응',
                                  style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: stageColors[c.isUrgent ? Stage.danger : c.severity]!.ink)),
                          ]),
                        ),
                      ),
                    ),
                ]),
        ),
      ]),
    );
  }

  // ── 오른쪽: 머리 · 추이 · 타임라인 (한 스크롤)

  Widget _detailScroll(InMemoryRepository repo, String rid, DateTime now) {
    final r = repo.resident(rid);
    final records = deskTimeline(repo, rid, kind: kind, period: period, query: keyword.text, now: now);
    final personalTotal = buildArchiveRecords(repo, rid).where((x) => !(x is EntryRecord && x.isClassNotice)).length;
    final rows = buildRows(
      visible: records,
      homeroomHistory: repo.homeroomHistoryOf(r.classId),
      now: now,
      showHomeroomDividers: kind != DeskKind.classNotice,
      collapseNormals: false,
    );

    return CustomScrollView(
      key: ValueKey('desk-resident-scroll-$rid'),
      controller: scroll,
      slivers: [
        SliverToBoxAdapter(child: _header(repo, r, now)),
        const SliverToBoxAdapter(child: SizedBox(height: Gap.m)),
        SliverToBoxAdapter(child: _trend(repo, r, now)),
        const SliverToBoxAdapter(child: SizedBox(height: Gap.m)),
        SliverToBoxAdapter(child: _filters(records.length, personalTotal)),
        const SliverToBoxAdapter(child: SizedBox(height: Gap.s)),
        if (rows.isEmpty)
          const SliverToBoxAdapter(child: EmptyNote('조건에 맞는 기록이 없어요'))
        else
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => _row(repo, rows[i], now),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _header(InMemoryRepository repo, Resident r, DateTime now) {
    final cls = repo.classOf(r.classId);
    String homeroom;
    try {
      homeroom = repo.staff(cls.homeroomId).displayName;
    } catch (_) {
      homeroom = '담임 미등록';
    }
    final m = repo.latestOf(r.id);
    final b = repo.baselineOf(r.id, now);
    final open = repo.openCaseOf(r.id);
    return DeskCard(
      child: Wrap(spacing: Gap.xl, runSpacing: Gap.m, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          FaceAvatar.resident(r.id, size: 64),
          const SizedBox(width: Gap.m),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${r.name} 별님', key: const ValueKey('desk-resident-header'),
                style: const TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain)),
            Text('${cls.name} · 담임 $homeroom', style: const TextStyle(fontSize: T.body, color: inkSub)),
          ]),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('마지막 체온', style: TextStyle(fontSize: T.caption, color: inkSub)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(tempText(m), key: const ValueKey('desk-resident-latest'),
                style: TextStyle(fontSize: m == null ? T.title : T.number, fontWeight: FontWeight.w800, color: inkMain)),
            if (m != null) ...[const SizedBox(width: 8), StageTag(m.judgment.stage)],
          ]),
          if (m != null) Text(ymdHm(m.measuredAt), style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('평소 기준', style: TextStyle(fontSize: T.caption, color: inkSub)),
          Text(baselineText(b), style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
          if (b.source != BaselineSource.provisional) Text(b.note, style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
        if (open != null)
          LinkCell(
            onTap: () => widget.onCase(open.id),
            tooltip: '대응 현황에서 보기',
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CaseBadge(open),
              const SizedBox(width: 6),
              Text('${caseStatusLabel(open)} · 대응 보기',
                  style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: navy, decoration: TextDecoration.underline)),
            ]),
          ),
      ]),
    );
  }

  Widget _trend(InMemoryRepository repo, Resident r, DateTime now) {
    final from = now.subtract(const Duration(days: 7));
    final ms = repo.measurementsOf(r.id).where((m) => !m.isVoided && m.measuredAt.isAfter(from) && !m.measuredAt.isAfter(now)).toList();
    final b = repo.baselineOf(r.id, now);
    return DeskCard(
      title: '체온 추이 · 최근 7일',
      trailing: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('그래프')),
          ButtonSegment(value: true, label: Text('표')),
        ],
        selected: {showTable},
        onSelectionChanged: (s) => setState(() => showTable = s.first),
      ),
      child: ms.isEmpty
          ? const EmptyNote('최근 7일 체온 기록 없음')
          : showTable
              ? _trendTable(ms, now)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    height: 220,
                    child: Semantics(
                      label: '최근 7일 체온 ${ms.length}건. 표 보기로 값을 읽을 수 있어요',
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _TrendPainter(
                          points: [for (final m in ms.reversed) (m.measuredAt, m.value, m.judgment.stage)],
                          from: from,
                          to: now,
                          baseline: b.source == BaselineSource.provisional ? null : b.value,
                          fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.s),
                  Wrap(spacing: 12, runSpacing: 4, children: [
                    for (final s in Stage.values)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: stageColors[s]!.ink, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('${s.symbol} ${s.label}', style: const TextStyle(fontSize: T.caption, color: inkMain)),
                      ]),
                    Text(b.source == BaselineSource.provisional ? b.note : '점선 = 평소 기준 ${formatTemp(b.value)}℃',
                        style: const TextStyle(fontSize: T.caption, color: inkSub)),
                    const Text('측정하지 않은 날은 비워 둬요', style: TextStyle(fontSize: T.caption, color: inkSub)),
                  ]),
                ]),
    );
  }

  Widget _trendTable(List<Measurement> ms, DateTime now) => DeskTable(
            cols: const [DeskCol('측정 시각', flex: 3), DeskCol('체온', flex: 2), DeskCol('판정', flex: 3), DeskCol('평소와 차이', flex: 3)],
            rows: [
              for (final m in ms)
                DeskRow(cells: [
                  Text('${m.measuredAt.month}/${m.measuredAt.day} ${hhmm(m.measuredAt)}', style: const TextStyle(fontSize: T.body)),
                  Text('${formatTemp(m.value)}℃', style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700)),
                  Align(alignment: Alignment.centerLeft, child: StageTag(m.judgment.stage)),
                  Text(formatDiff(m.judgment.diff), style: const TextStyle(fontSize: T.body)),
                ]),
            ],
          );

  Widget _filters(int shown, int personalTotal) => DeskCard(
        title: '기록 타임라인',
        trailing: Text('보이는 기록 $shown건 · 이 별님 누적 $personalTotal건',
            key: const ValueKey('desk-tl-count'), style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
        child: Wrap(spacing: Gap.m, runSpacing: Gap.m, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<DeskKind>(
            key: const ValueKey('desk-tl-kind'),
            showSelectedIcon: false,
            segments: [for (final k in DeskKind.values) ButtonSegment(value: k, label: Text(k.label))],
            selected: {kind},
            onSelectionChanged: (s) => setState(() => kind = s.first),
          ),
          SegmentedButton<DeskPeriod>(
            key: const ValueKey('desk-tl-period'),
            showSelectedIcon: false,
            segments: [for (final p in DeskPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {period},
            onSelectionChanged: (s) => setState(() => period = s.first),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              key: const ValueKey('desk-tl-search'),
              controller: keyword,
              decoration: InputDecoration(
                hintText: '본문·기록자 찾기',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: keyword.text.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('desk-tl-clear'),
                        tooltip: '검색어 지우기',
                        icon: const Icon(Icons.close),
                        onPressed: keyword.clear,
                      ),
              ),
            ),
          ),
        ]),
      );

  Widget _row(InMemoryRepository repo, ArchiveRow row, DateTime now) {
    switch (row) {
      case DayHeaderRow(:final label):
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, Gap.l, 4, Gap.s),
          child: Text(label, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkSub)),
        );
      case HomeroomDividerRow(:final at, :final fromStaffId, :final toStaffId):
        String n(String id) {
          try {
            return repo.staff(id).displayName;
          } catch (_) {
            return id;
          }
        }
        return Padding(
          key: ValueKey('desk-tl-divider-${at.toIso8601String()}'),
          padding: const EdgeInsets.symmetric(vertical: Gap.m),
          child: Row(children: [
            const Expanded(child: Divider(color: coral, thickness: 1.5)),
            Flexible(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '담임 변경 · ${at.year}년 ${at.month}월 ${at.day}일 · ${n(fromStaffId)} → ${n(toStaffId)}\n이 선 아래는 이전 담임 때 기록이에요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkMain),
                ),
              ),
            ),
            const Expanded(child: Divider(color: coral, thickness: 1.5)),
          ]),
        );
      case NormalGroupRow(:final records):
        return Column(children: [for (final r in records) _recordTile(repo, r, now)]);
      case RecordRow(:final record):
        return _recordTile(repo, record, now);
    }
  }

  Widget _recordTile(InMemoryRepository repo, ArchiveRecord rec, DateTime now) {
    final selected = rec.key == selectedKey;
    final Widget body;
    switch (rec) {
      case TempRecord(:final m, :final entry):
        final st = stageColors[m.judgment.stage]!;
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('🌡 체온', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: inkSub)),
            Text('${formatTemp(m.value)}℃',
                style: TextStyle(
                  fontSize: T.title,
                  fontWeight: FontWeight.w800,
                  color: m.isVoided ? inkSub : st.ink,
                  decoration: m.isVoided ? TextDecoration.lineThrough : null,
                  decorationThickness: 2,
                )),
            if (m.isVoided)
              const StatusPill('↩ 잘못 잰 값', color: inkSub)
            else
              StageTag(m.judgment.stage),
            if (m.correctsId != null) const StatusPill('다시 잰 값', color: navy),
            if (m.caseId != null)
              () {
                try {
                  final c = repo.caseById(m.caseId!);
                  return StatusPill(c.isUrgent ? '⚠ 긴급 연결' : '이상 대응 연결', color: stageColors[c.isUrgent ? Stage.danger : c.severity]!.ink);
                } catch (_) {
                  return const SizedBox.shrink();
                }
              }(),
          ]),
          if (entry?.task != null)
            Text('할 일 · ${entry!.task!.label} ${entry.task!.done ? '✓ 완료' : '열림'}',
                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkMain)),
          Text('기록 ${authorAsOf(repo, m.recordedBy, m.classId, m.measuredAt)}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]);
      case EntryRecord(:final e, :final isClassNotice):
        final cls = e.classId == null ? null : repo.classOf(e.classId!);
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            StatusPill(isClassNotice ? '📢 ${e.kindLabel}' : '📝 ${e.kindLabel}',
                color: isClassNotice && cls != null ? inkMain : brandDark,
                background: isClassNotice && cls != null ? Color(cls.color).withValues(alpha: 0.18) : null),
            if (isClassNotice && cls != null) Text('${cls.name} 전체', style: const TextStyle(fontSize: T.caption, color: inkSub)),
            if (e.photoCount > 0) Text('사진 ${e.photoCount}장', style: const TextStyle(fontSize: T.caption, color: inkSub)),
          ]),
          const SizedBox(height: 2),
          Text([if (e.title != null) e.title!, if (e.body != null) e.body!].join(' · '),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: T.body, color: inkMain, height: 1.45)),
          if (e.task != null)
            Text('할 일 · ${e.task!.label} ${e.task!.done ? '✓ 완료' : '열림'}',
                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkMain)),
          Text('기록 ${authorAsOf(repo, e.authorId, e.classId, e.createdAt)}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? sage : surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: selected ? brandDark : line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('desk-tl-${rec.key}'),
          onTap: () => setState(() => selectedKey = rec.key),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 56,
                child: Text(hhmm(rec.at), style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkSub)),
              ),
              Expanded(child: body),
              const Icon(Icons.chevron_right, color: inkSub),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 기록 한 건 상세 (오른쪽 겹친 패널). 보기만 한다.
class _RecordPanel extends ConsumerWidget {
  const _RecordPanel({super.key, required this.record, required this.residentId, required this.onClose, required this.onCase});
  final ArchiveRecord record;
  final String residentId;
  final VoidCallback onClose;
  final ValueChanged<String> onCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final r = repo.resident(residentId);
    final cls = repo.classOf(r.classId);
    final items = <(String, Widget)>[];
    void add(String k, String v, {TextStyle? style}) => items.add((k, Text(v, style: style ?? const TextStyle(fontSize: T.body, color: inkMain, height: 1.5))));
    String? caseId;
    String title;

    switch (record) {
      case TempRecord(:final m, :final entry):
        title = '체온 기록';
        add('대상', '${r.name} 별님 · ${cls.name}');
        add('측정 일시', ymdHm(m.measuredAt));
        items.add((
          '체온',
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${formatTemp(m.value)}℃',
                style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, decoration: m.isVoided ? TextDecoration.lineThrough : null)),
            StageTag(m.judgment.stage),
          ])
        ));
        add('평소와 비교', '${plainDiff(m.judgment.diff)} (저장 당시 기준 ${formatTemp(m.judgment.baseline)}℃)');
        add('당시 기록자', authorAsOf(repo, m.recordedBy, m.classId, m.measuredAt));
        add('출처', sourceLabel(m.source));
        if (m.isVoided) {
          add('상태', '↩ ${m.voidReason ?? '잘못 잰 값'} · ${m.voidedBy == null ? '' : authorAsOf(repo, m.voidedBy!, null, m.voidedAt!)} ${ymdHm(m.voidedAt!)}');
        }
        if (m.correctsId != null) {
          try {
            add('다시 잰 값', '앞서 잰 ${formatTemp(repo.measurement(m.correctsId!).value)}℃를 잘못 잰 값으로 두고 다시 쟀어요');
          } catch (_) {}
        }
        if (entry?.task != null) add('할 일', '${entry!.task!.label} · ${entry.task!.done ? '✓ 완료' : '열림'}');
        caseId = m.caseId;
      case EntryRecord(:final e, :final isClassNotice):
        title = e.kindLabel;
        add('대상', isClassNotice ? '${e.classId == null ? '' : repo.classOf(e.classId!).name} 전체 (반 공지 원본 1건)' : '${r.name} 별님 · ${cls.name}');
        add('작성 일시', ymdHm(e.createdAt));
        add('당시 기록자', authorAsOf(repo, e.authorId, e.classId, e.createdAt));
        add('출처', '인수인계 기록');
        if (e.title != null) add('제목', e.title!);
        add('본문', e.body ?? '(본문 없음)');
        if (e.photoCount > 0) add('사진', '사진 ${e.photoCount}장 (시연은 자리 표시)');
        if (e.task != null) add('할 일', '${e.task!.label} · ${e.task!.done ? '✓ 완료' : '열림'}');
        if (e.revisions.isNotEmpty) add('수정 이력', '${e.revisions.length}번 고쳤어요 · 마지막 ${ymdHm(e.updatedAt ?? e.createdAt)}');
        final replies = repo.repliesOf(e.id);
        if (replies.isNotEmpty) {
          add('답글', [for (final x in replies) '${authorAsOf(repo, x.authorId, null, x.createdAt)} ${hhmm(x.createdAt)} · ${x.body}'].join('\n'));
        }
        caseId = e.caseId;
    }

    return Material(
      color: surface,
      elevation: 8,
      shadowColor: inkMain.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card), side: const BorderSide(color: brandDark, width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: Focus(
        autofocus: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: sage,
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            child: Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain))),
              IconButton(key: const ValueKey('desk-panel-close'), tooltip: '닫기 (Esc)', icon: const Icon(Icons.close), onPressed: onClose),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (final (k, v) in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
                    v,
                  ]),
                ),
              if (caseId != null)
                () {
                  try {
                    final c = repo.caseById(caseId!);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('연결된 대응 건', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
                        const SizedBox(height: 4),
                        Row(children: [
                          CaseBadge(c),
                          const SizedBox(width: 8),
                          Text(caseStatusLabel(c), style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        OutlinedButton(onPressed: () => onCase(c.id), child: const Text('대응 현황에서 보기')),
                      ]),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                }(),
              const Text('열어 보기만 해요. 확인·완료로 처리하지 않아요.', style: TextStyle(fontSize: T.caption, color: inkSub)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 최근 7일 꺾은선. 점 색 = 판정 색 (표 보기로 글자도 제공).
class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.points, required this.from, required this.to, this.baseline, this.fontFamily});
  final String? fontFamily;
  final List<(DateTime, int, Stage)> points; // 오래된 순
  final DateTime from;
  final DateTime to;
  final int? baseline;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0, right = 12.0, top = 10.0, bottom = 28.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;
    final values = [for (final p in points) p.$2, ?baseline];
    var lo = ((values.reduce(math.min) - 3) / 5).floor() * 5;
    var hi = ((values.reduce(math.max) + 3) / 5).ceil() * 5;
    lo = math.min(lo, 355);
    hi = math.max(hi, 380);
    double x(DateTime t) => left + w * (t.difference(from).inMinutes / to.difference(from).inMinutes).clamp(0.0, 1.0);
    double y(int v) => top + h * (1 - (v - lo) / (hi - lo));

    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    void label(String s, Offset at, {bool center = false}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: T.caption, color: inkSub, fontFamily: fontFamily)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(center ? tp.width / 2 : tp.width, tp.height / 2));
    }

    final step = (hi - lo) > 40 ? 10 : 5;
    for (var v = lo; v <= hi; v += step) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), grid);
      label(formatTemp(v), Offset(left - 6, y(v)));
    }
    for (var d = DateTime(from.year, from.month, from.day + 1); !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      canvas.drawLine(Offset(x(d), top), Offset(x(d), top + h), grid);
      label('${d.month}/${d.day}', Offset(x(d), top + h + 14), center: true);
    }
    if (baseline != null) {
      final p = Paint()
        ..color = brandDark
        ..strokeWidth = 1.5;
      for (var sx = left; sx < left + w; sx += 10) {
        canvas.drawLine(Offset(sx, y(baseline!)), Offset(math.min(sx + 5, left + w), y(baseline!)), p);
      }
    }
    final linePaint = Paint()
      ..color = inkSub
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < points.length; i++) {
      // 측정 간격이 30시간 넘게 비면 선을 잇지 않는다 (측정하지 않은 날은 비워 둠).
      if (points[i].$1.difference(points[i - 1].$1) > const Duration(hours: 30)) continue;
      canvas.drawLine(Offset(x(points[i - 1].$1), y(points[i - 1].$2)), Offset(x(points[i].$1), y(points[i].$2)), linePaint);
    }
    for (final p in points) {
      final c = Offset(x(p.$1), y(p.$2));
      canvas.drawCircle(c, 6, Paint()..color = Colors.white);
      canvas.drawCircle(c, 4.5, Paint()..color = stageColors[p.$3]!.ink);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points.length != points.length || old.to != to || old.baseline != baseline || old.points.lastOrNull != points.lastOrNull;
}
