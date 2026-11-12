// HO-1 최신 기록 (인수인계 명세 3.1 + 통합 명세 6-3).
// 순서: 교대 요약 → 필터 → 긴급 · 이상 대응 → 고정 전체 공지 → 이전 근무에서 넘어온 할 일 → 최신 기록.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
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

    final children = <Widget>[
      _SummaryCard(view: v, missed: missed, onResponse: _goToResponse, onFilter: _setFilter),
      const SizedBox(height: 12),
      _FilterChips(view: v, selected: _filter, onSelect: _setFilter),
      const SizedBox(height: 12),
      if (v.activeCases.isNotEmpty) ...[
        Padding(
          key: _responseKey,
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '긴급 · 이상 대응  ${v.activeCases.length}건 · 어떤 필터에서도 맨 위',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        for (final c in v.activeCases)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: ResponseCard(caseItem: c)),
        const SizedBox(height: 8),
      ],
      ..._body(v),
    ];

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
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
      if (list.isEmpty) return [_Empty(text: _filter.emptyText)];
      return [for (final e in list) card(e, fold: _filter != FeedFilter.facility)];
    }

    final pinned = v.pinnedNotices;
    final carried = v.carried;
    final rest = v.listFor(FeedFilter.all);
    final openCarried = carried.where(v.hasOpenTask).length;
    return [
      for (final e in pinned) card(e),
      if (carried.isNotEmpty) ...[
        _SectionTitle('이전 근무에서 넘어온 할 일 $openCarried · 완료할 때까지 남아요'),
        for (final e in carried) card(e),
      ],
      if (pinned.isNotEmpty || carried.isNotEmpty) const _SectionTitle('최신 기록'),
      if (rest.isEmpty) const _Empty(text: '기록이 없어요.'),
      for (final e in rest) card(e),
      _RangeFooter(view: v),
    ];
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.view, required this.missed, required this.onResponse, required this.onFilter});
  final HandoverView view;
  final List<Resident> missed;
  final VoidCallback onResponse;
  final ValueChanged<FeedFilter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final v = view;
    final shiftName = v.shift?.label ?? '지금';
    final residentCount = [for (final c in repo.classes) ...repo.residentsOf(c.id)].length;
    final header =
        '$shiftName 인계 · ${whenLabel(v.since, v.now)} 기준 · ${repo.classes.length}개 반 $residentCount명';
    final tasks = v.openTasks.length;
    final unread = v.unread.length;
    final allClear = v.activeCases.isEmpty && tasks == 0 && unread == 0;

    final tiles = <Widget>[
      _Stat(
          label: '긴급',
          value: v.urgentCount,
          symbol: Stage.danger.symbol,
          alert: v.urgentCount > 0,
          onTap: onResponse),
      _Stat(
          label: '이상 대응',
          value: v.abnormalCount,
          symbol: Stage.abnormal.symbol,
          alert: v.abnormalCount > 0,
          onTap: onResponse),
      _Stat(label: '남은 할 일', value: tasks, symbol: '☐', onTap: () => onFilter(FeedFilter.task)),
      _Stat(label: '안 본 기록', value: unread, symbol: '●', onTap: () => onFilter(FeedFilter.unread)),
      _Stat(
          label: '체온 미기록',
          value: missed.length,
          symbol: '○',
          onTap: () => _showMissed(context, ref, missed)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: hoSummaryBg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(header, style: const TextStyle(color: Color(0xFFD6DED9), fontSize: 12.5)),
        const SizedBox(height: 4),
        Text(
          allClear ? '넘겨받을 일을 모두 확인했어요' : '교대 요약',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          // 넓으면 한 줄 5칸, 좁으면 3칸 + 2칸
          final perRow = c.maxWidth >= 380 ? 5 : 3;
          final w = (c.maxWidth - (perRow - 1) * 6) / perRow;
          return Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in tiles) SizedBox(width: w, child: t),
          ]);
        }),
      ]),
    );
  }

  Future<void> _showMissed(BuildContext context, WidgetRef ref, List<Resident> missed) async {
    final repo = ref.read(repoProvider);
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (s) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(s).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('체온 미기록 ${missed.length}명',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('측정 시점이 지났는데 체온이 없어요. 누르면 퀵 체온에서 바로 잴 수 있어요.',
                  style: TextStyle(fontSize: 13, color: inkSub)),
            ),
            if (missed.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('체온 미기록 별님이 없어요.', style: TextStyle(color: inkSub)),
              ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final r in missed)
                  ListTile(
                    minTileHeight: 52,
                    leading: NameAvatar(name: r.name, color: Color(repo.classOf(r.classId).color).withValues(alpha: 0.4)),
                    title: Text('${r.name} 별님'),
                    subtitle: Text(repo.classOf(r.classId).name),
                    trailing: const Text('재기 ›'),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.symbol, required this.onTap, this.alert = false});
  final String label;
  final int value;
  final String symbol;
  final VoidCallback onTap;
  final bool alert;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label $value',
        excludeSemantics: true,
        child: Material(
          color: alert ? const Color(0xFF5A3A36) : const Color(0xFF3B4842),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$value',
                      style: TextStyle(
                          color: alert ? const Color(0xFFFFC9C4) : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text('$symbol $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFD6DED9), fontSize: 11.5)),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.view, required this.selected, required this.onSelect});
  final HandoverView view;
  final FeedFilter selected;
  final ValueChanged<FeedFilter> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final f in FeedFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.padded,
                label: Text('${f.label} ${view.countFor(f)}'),
                selected: selected == f,
                showCheckmark: false,
                shape: const StadiumBorder(),
                selectedColor: hoSummaryBg,
                labelStyle: TextStyle(
                    color: selected == f ? Colors.white : inkMain, fontWeight: FontWeight.w700, fontSize: 13),
                onSelected: (_) => onSelect(f),
              ),
            ),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: inkMain)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: inkSub, fontSize: 15))),
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        '✦ 내 지난 근무(${d.month}월 ${d.day}일$name)부터 모아 보여요\n그 전 기록은 별님 아카이브에서 볼 수 있어요',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, color: inkSub, height: 1.5),
      ),
    );
  }
}
