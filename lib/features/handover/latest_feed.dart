// HO-1 최신 기록 (인수인계 명세 3.1 + 통합 명세 6-3).
// 개선 시안 1에서 첫 화면 "안 본 기록 n개" 안으로 옮겼다 (HandoverRecordsScreen).
// 순서: 머리말(범위·체온 미기록 링크) → 보기 칩 → 고정 전체 공지 → 이전 근무에서 넘어온 할 일 → 최신 기록.
// 긴급 · 이상 대응 카드는 첫 화면에 있다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'entry_card.dart';
import 'handover_common.dart';
import 'handover_view.dart';
import 'task_actions.dart';

class LatestFeed extends ConsumerStatefulWidget {
  const LatestFeed({super.key, this.initialFilter = FeedFilter.all});

  /// 처음 고른 보기 (첫 화면 "안 본 기록 n개"에서 열면 '안 본 기록').
  final FeedFilter initialFilter;

  @override
  ConsumerState<LatestFeed> createState() => _LatestFeedState();
}

class _LatestFeedState extends ConsumerState<LatestFeed> {
  late FeedFilter _filter = widget.initialFilter;
  final _scroll = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final now = ref.read(clockProvider)();
    final v = HandoverView(repo, me, now, keep: _keep);
    final missed = repo.missedTempResidents(now);

    Widget pad(Widget w) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: w,
    );

    final children = <Widget>[
      pad(_ListHead(view: v, missed: missed)),
      const SizedBox(height: Gap.s),
      _ViewChips(view: v, selected: _filter, onSelect: _setFilter),
      for (final w in _body(v)) pad(w),
    ];

    return ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(0, 0, 0, Gap.l), children: children);
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
        _Sec('${_filter.label} ${list.length}건'),
        if (list.isEmpty) EmptyNote(_filter.emptyText),
        for (final e in list) card(e, fold: _filter != FeedFilter.facility),
      ];
    }

    final pinned = v.pinnedNotices;
    final carried = v.carried;
    final rest = v.listFor(FeedFilter.all);
    final openCarried = carried.where(v.hasOpenTask).length;
    return [
      if (pinned.isNotEmpty) ...[_Sec('고정된 전체 공지 ${pinned.length}'), for (final e in pinned) card(e)],
      if (carried.isNotEmpty) ...[
        _Sec('이전 근무에서 넘어온 할 일 $openCarried', color: hoTaskInk, sub: '완료할 때까지 여기에 남아요'),
        for (final e in carried) card(e),
      ],
      _Sec('최신 기록 ${rest.length}', sub: '반 공지와 별님 기록'),
      if (rest.isEmpty) const EmptyNote('새로 들어온 기록이 없어요'),
      for (final e in rest) card(e),
      _RangeFooter(view: v),
    ];
  }
}

/// 목록 머리말 (개선 시안 1: "어제 07:00 이후 기록이에요" → 안 본 기록 목록 머리말로).
/// 체온 미기록은 일정 탭 "먼저 챙길 별님"으로 옮겼고, 여기에는 작은 링크만 남긴다.
class _ListHead extends ConsumerWidget {
  const _ListHead({required this.view, required this.missed});
  final HandoverView view;
  final List<Resident> missed;

  /// "어제 07:00" · 오늘이면 "오늘 07:00".
  static String _sinceText(DateTime since, DateTime now) {
    final w = whenLabel(since, now);
    return w.contains(' ') ? w : '오늘 $w';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: Gap.s,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.s),
        child: Text(
          '${_sinceText(view.since, view.now)} 이후 기록이에요',
          style: const TextStyle(fontSize: T.caption, color: inkSub),
        ),
      ),
      if (missed.isNotEmpty)
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle: const TextStyle(fontFamily: fontSmall, fontSize: T.caption, fontWeight: FontWeight.w700),
          ),
          onPressed: () => _showMissed(context, ref, missed),
          child: Text('체온 미기록 ${missed.length}명 ›'),
        ),
    ],
  );

  Future<void> _showMissed(BuildContext context, WidgetRef ref, List<Resident> missed) async {
    final repo = ref.read(repoProvider);
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (s) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(s).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xs),
                child: Text(
                  '체온을 아직 안 잰 별님 ${missed.length}명',
                  style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.m),
                child: Text('누르면 바로 체온을 잴 수 있어요.', style: TextStyle(fontSize: T.body, color: inkSub)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: Gap.l),
                  children: [
                    for (final r in missed)
                      ListTile(
                        minTileHeight: 72,
                        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.page),
                        leading: ResidentAvatar(name: r.name, classColor: repo.classOf(r.classId).color, residentId: r.id),
                        title: Text(
                          '${r.name} 별님',
                          style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w700, color: inkMain),
                        ),
                        subtitle: Text(repo.classOf(r.classId).name),
                        trailing: const Text(
                          '체온 재기 ›',
                          style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: brandDark),
                        ),
                        onTap: () => Navigator.pop(s, r.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (id != null && context.mounted) openQuickTempFor(context, ref, id);
  }
}

/// 목록 구역 이름 (시제품 .sec): 작고 굵은 보조 글자.
class _Sec extends StatelessWidget {
  const _Sec(this.text, {this.color = inkSub, this.sub});
  final String text;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, Gap.l, 2, Gap.s),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: color),
        ),
        if (sub != null)
          Text(
            sub!,
            style: const TextStyle(fontSize: T.caption, color: inkSub),
          ),
      ],
    ),
  );
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
    child: Row(
      children: [
        for (final f in FeedFilter.values)
          Padding(
            padding: const EdgeInsets.only(right: Gap.s),
            child: HoChip(label: '${f.label} ${view.countFor(f)}', selected: selected == f, onTap: () => onSelect(f)),
          ),
      ],
    ),
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
      child: Column(
        children: [
          Text(
            '✦ 내 지난 근무(${d.month}월 ${d.day}일$name)부터 보여요',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: T.caption, color: inkSub),
          ),
          const Text(
            '그 전 기록은 별님 아카이브에서 볼 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: T.caption, color: inkSub),
          ),
        ],
      ),
    );
  }
}
