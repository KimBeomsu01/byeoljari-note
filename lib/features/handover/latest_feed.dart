// HO-1 최신 기록 (인수인계 명세 3.1 + 통합 명세 6-3).
// 순서: 지금 챙길 일 → 보기 칩 → 긴급 · 이상 대응 → 고정 전체 공지 → 이전 근무에서 넘어온 할 일 → 최신 기록.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'entry_card.dart';
import 'handover_common.dart';
import 'handover_view.dart';
import 'response_card.dart';

class LatestFeed extends ConsumerStatefulWidget {
  const LatestFeed({super.key});

  @override
  ConsumerState<LatestFeed> createState() => _LatestFeedState();
}

class _LatestFeedState extends ConsumerState<LatestFeed> {
  FeedFilter _filter = FeedFilter.all;
  final _scroll = ScrollController();
  final _responseKey = GlobalKey();

  /// 이 화면에서 완료한 넘어온 할 일은 화면을 떠나기 전까지 남긴다 (4.4).
  final Set<String> _keep = {};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setFilter(FeedFilter f) {
    setState(() => _filter = f);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _goToResponse() {
    setState(() => _filter = FeedFilter.all);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _responseKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final now = ref.read(clockProvider)();
    final v = HandoverView(repo, me, now, keep: _keep);
    final missed = repo.missedTempResidents(now);

    Widget pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.page), child: w);

    final children = <Widget>[
      pad(_SummaryCard(view: v, missed: missed, onResponse: _goToResponse, onFilter: _setFilter)),
      const SizedBox(height: Gap.xl),
      pad(const Text('보기', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkSub))),
      const SizedBox(height: Gap.s),
      _ViewChips(view: v, selected: _filter, onSelect: _setFilter),
      if (v.activeCases.isNotEmpty) ...[
        pad(KeyedSubtree(key: _responseKey, child: SectionTitle('긴급 · 이상 대응', count: v.activeCases.length))),
        for (final c in v.activeCases)
          pad(Padding(padding: const EdgeInsets.only(bottom: Gap.m), child: ResponseCard(caseItem: c))),
      ],
      for (final w in _body(v)) pad(w),
    ];

    return ListView(
      controller: _scroll,
      // 아래 120: 떠 있는 '기록 남기기' 버튼이 마지막 카드를 가리지 않게.
      padding: const EdgeInsets.fromLTRB(0, Gap.s, 0, 120),
      children: children,
    );
  }

  List<Widget> _body(HandoverView v) {
    EntryCard card(Entry e, {bool fold = true}) => EntryCard(
          key: ValueKey('entry-${e.id}'),
          entry: e,
          view: v,
          foldReadNotice: fold,
          onCompleted: () => setState(() => _keep.add(e.id)),
        );

    if (_filter != FeedFilter.all) {
      final list = v.listFor(_filter);
      return [
        SectionTitle(_filter.label, count: list.length),
        if (list.isEmpty) EmptyNote(_filter.emptyText),
        for (final e in list) card(e, fold: _filter != FeedFilter.facility),
      ];
    }

    final pinned = v.pinnedNotices;
    final carried = v.carried;
    final rest = v.listFor(FeedFilter.all);
    final openCarried = carried.where(v.hasOpenTask).length;
    return [
      if (pinned.isNotEmpty) ...[
        const SectionTitle('전체 공지'),
        for (final e in pinned) card(e),
      ],
      if (carried.isNotEmpty) ...[
        SectionTitle('이전 근무에서 넘어온 할 일', count: openCarried),
        const Padding(
          padding: EdgeInsets.only(bottom: Gap.m),
          child: Text('완료할 때까지 여기에 남아요', style: TextStyle(fontSize: T.caption, color: inkSub)),
        ),
        for (final e in carried) card(e),
      ],
      SectionTitle('최신 기록', count: rest.length),
      if (rest.isEmpty) const EmptyNote('새로 들어온 기록이 없어요'),
      for (final e in rest) card(e),
      _RangeFooter(view: v),
    ];
  }
}

/// 맨 위 "지금 챙길 일": 밝은 카드, 한 줄에 한 가지, 누르면 그 목록으로.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.view, required this.missed, required this.onResponse, required this.onFilter});
  final HandoverView view;
  final List<Resident> missed;
  final VoidCallback onResponse;
  final ValueChanged<FeedFilter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = view;
    final tasks = v.openTasks.length;
    final unread = v.unread.length;
    final allClear = v.activeCases.isEmpty && tasks == 0 && unread == 0;

    final rows = <Widget>[
      _Stat(
          label: '긴급',
          value: v.urgentCount,
          symbol: Stage.danger.symbol,
          bar: stageColors[Stage.danger]!.ink,
          ink: stageColors[Stage.danger]!.ink,
          onTap: onResponse),
      _Stat(
          label: '이상 대응',
          value: v.abnormalCount,
          symbol: Stage.abnormal.symbol,
          bar: stageColors[Stage.abnormal]!.line,
          ink: stageColors[Stage.abnormal]!.ink,
          onTap: onResponse),
      _Stat(
          label: '남은 할 일',
          value: tasks,
          symbol: '☐',
          bar: hoTask.line,
          ink: hoTask.ink,
          onTap: () => onFilter(FeedFilter.task)),
      _Stat(
          label: '안 본 기록',
          value: unread,
          symbol: '●',
          bar: starYellow,
          ink: inkMain,
          onTap: () => onFilter(FeedFilter.unread)),
      _Stat(
          label: '체온 미기록',
          value: missed.length,
          symbol: '○',
          bar: brandDark,
          ink: brandDark,
          onTap: () => _showMissed(context, ref, missed)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('지금 챙길 일', style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
            Text('${_sinceText(v.since, v.now)} 이후 기록이에요', style: const TextStyle(fontSize: T.caption, color: inkSub)),
            if (allClear)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text('✓ 넘겨받을 일을 모두 확인했어요',
                    style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: hoDone.ink)),
              ),
          ]),
        ),
        // 첫 화면에서 아래 카드가 보이도록 숫자 칸 2줄로: 긴급·이상 대응 / 할 일·안 본 기록·미기록
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.m, Gap.xs, Gap.m, Gap.m),
          child: Column(children: [
            Row(children: [Expanded(child: rows[0]), const SizedBox(width: Gap.s), Expanded(child: rows[1])]),
            const SizedBox(height: Gap.s),
            Row(children: [
              Expanded(child: rows[2]),
              const SizedBox(width: Gap.s),
              Expanded(child: rows[3]),
              const SizedBox(width: Gap.s),
              Expanded(child: rows[4]),
            ]),
          ]),
        ),
      ]),
    );
  }

  /// "어제 07:00" · 오늘이면 "오늘 07:00".
  static String _sinceText(DateTime since, DateTime now) {
    final w = whenLabel(since, now);
    return w.contains(' ') ? w : '오늘 $w';
  }

  Future<void> _showMissed(BuildContext context, WidgetRef ref, List<Resident> missed) async {
    final repo = ref.read(repoProvider);
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (s) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(s).size.height * 0.75),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xs),
              child: Text('체온을 아직 안 잰 별님 ${missed.length}명',
                  style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.m),
              child: Text('누르면 바로 체온을 잴 수 있어요.', style: TextStyle(fontSize: T.body, color: inkSub)),
            ),
            if (missed.isEmpty) const EmptyNote('체온을 안 잰 별님이 없어요'),
            Flexible(
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: Gap.l), children: [
                for (final r in missed)
                  ListTile(
                    minTileHeight: 72,
                    contentPadding: const EdgeInsets.symmetric(horizontal: Gap.page),
                    leading: ResidentAvatar(name: r.name, classColor: repo.classOf(r.classId).color),
                    title: Text('${r.name} 별님',
                        style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w700, color: inkMain)),
                    subtitle: Text(repo.classOf(r.classId).name),
                    trailing: const Text('체온 재기 ›',
                        style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: brandDark)),
                    onTap: () => Navigator.pop(s, r.id),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (id != null) ref.read(quickTempProvider.notifier).openFor(id);
  }
}

/// 요약 숫자 칸: 큰 숫자 + 이름. 0이면 조용하게, 0이 아니면 색 테두리 + 색 바탕 + 진한 글자.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.symbol,
    required this.bar,
    required this.ink,
    required this.onTap,
  });
  final String label;
  final int value;
  final String symbol;
  final Color bar;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = value > 0;
    return Semantics(
      button: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Material(
        color: on ? Color.alphaBlend(bar.withValues(alpha: 0.12), surface) : surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
          side: BorderSide(color: on ? bar : line, width: on ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.s),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$value',
                    style: TextStyle(
                      fontSize: T.number,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: on ? ink : inkSub,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$symbol $label',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: T.caption,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: on ? ink : inkSub,
                      )),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보기 칩: 글자 크기에 맞춰 늘어나고, 옆으로 밀어서 더 본다.
class _ViewChips extends StatelessWidget {
  const _ViewChips({required this.view, required this.selected, required this.onSelect});
  final HandoverView view;
  final FeedFilter selected;
  final ValueChanged<FeedFilter> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.page),
        child: Row(children: [
          for (final f in FeedFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: Gap.s),
              child: HoChip(
                label: '${f.label} ${view.countFor(f)}',
                selected: selected == f,
                onTap: () => onSelect(f),
              ),
            ),
        ]),
      );
}

class _RangeFooter extends StatelessWidget {
  const _RangeFooter({required this.view});
  final HandoverView view;

  @override
  Widget build(BuildContext context) {
    final s = view.repo.shiftAt(view.since, staffId: view.me);
    final name = s != null ? ' ${s.label} 근무' : '';
    final d = view.since;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xl),
      child: Column(children: [
        Text('내 지난 근무(${d.month}월 ${d.day}일$name)부터 보여요',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: T.caption, color: inkSub)),
        const Text('그 전 기록은 별님 아카이브에 있어요',
            textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: inkSub)),
      ]),
    );
  }
}
