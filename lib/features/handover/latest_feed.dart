// HO-1 최신 기록 (인수인계 명세 3.1 + 통합 명세 6-3).
// 순서: 교대 요약 → 보기 칩 → 긴급 · 이상 대응 → 고정 전체 공지 → 이전 근무에서 넘어온 할 일 → 최신 기록.
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

    Widget pad(Widget w) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: w,
    );

    final children = <Widget>[
      pad(_SummaryCard(view: v, missed: missed, onResponse: _goToResponse, onFilter: _setFilter)),
      const SizedBox(height: Gap.m),
      _ViewChips(view: v, selected: _filter, onSelect: _setFilter),
      if (v.activeCases.isNotEmpty) ...[
        pad(
          KeyedSubtree(
            key: _responseKey,
            child: _Sec(
              '긴급 · 이상 대응 ${v.activeCases.length}',
              color: stageColors[Stage.danger]!.ink,
              dot: stageColors[Stage.danger]!.line,
            ),
          ),
        ),
        for (final c in v.activeCases)
          pad(
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.m),
              child: ResponseCard(caseItem: c),
            ),
          ),
      ],
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

/// 맨 위 교대 요약 (시제품 .summary): 짙은 녹회색 카드 + 흰 숫자. 칸을 누르면 그 목록으로.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.view, required this.missed, required this.onResponse, required this.onFilter});
  final HandoverView view;
  final List<Resident> missed;
  final VoidCallback onResponse;
  final ValueChanged<FeedFilter> onFilter;

  // 시제품 .stat 숫자 색 (짙은 바탕 위)
  static const _red = Color(0xFFFFB4B2);
  static const _amber = Color(0xFFF3CF86);
  static const _zero = Color(0xFFA9B8AF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = view;
    final tasks = v.openTasks.length;
    final unread = v.unread.length;
    final allClear = v.activeCases.isEmpty && tasks == 0 && unread == 0;
    final shiftName = v.shift == null ? '지금 근무' : '${v.shift!.label} 근무';

    Widget stat(String label, int value, Color on, VoidCallback onTap) =>
        _Stat(label: label, value: value, color: value > 0 ? on : _zero, onTap: onTap);

    return Container(
      padding: const EdgeInsets.all(Gap.m),
      decoration: BoxDecoration(color: brandDark, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, Gap.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        '$shiftName 인계',
                        style: const TextStyle(
                          fontSize: T.title,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: Gap.s),
                      child: Text(
                        '${hm(v.now)} 기준',
                        style: const TextStyle(fontSize: T.caption, color: hoOnDarkSub),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_sinceText(v.since, v.now)} 이후 기록이에요',
                  style: const TextStyle(fontSize: T.caption, color: hoOnDarkSub),
                ),
                if (allClear)
                  const Padding(
                    padding: EdgeInsets.only(top: Gap.xs),
                    child: Text(
                      '✦ 넘겨받을 일을 모두 확인했어요',
                      style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          // 2줄: 긴급·이상 대응 / 남은 할 일·안 본 기록·체온 미기록
          Row(
            children: [
              Expanded(child: stat('긴급', v.urgentCount, _red, onResponse)),
              const SizedBox(width: 6),
              Expanded(child: stat('이상 대응', v.abnormalCount, _amber, onResponse)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: stat('남은 할 일', tasks, _amber, () => onFilter(FeedFilter.task))),
              const SizedBox(width: 6),
              Expanded(child: stat('안 본 기록', unread, Colors.white, () => onFilter(FeedFilter.unread))),
              const SizedBox(width: 6),
              Expanded(child: stat('체온 미기록', missed.length, Colors.white, () => _showMissed(context, ref, missed))),
            ],
          ),
        ],
      ),
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
                child: Text(
                  '누르면 바로 체온을 잴 수 있어요.',
                  style: TextStyle(fontSize: T.body, color: inkSub),
                ),
              ),
              if (missed.isEmpty) const EmptyNote('체온을 안 잰 별님이 없어요'),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: Gap.l),
                  children: [
                    for (final r in missed)
                      ListTile(
                        minTileHeight: 72,
                        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.page),
                        leading: ResidentAvatar(
                          name: r.name,
                          classColor: repo.classOf(r.classId).color,
                          residentId: r.id,
                        ),
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
    if (id != null) ref.read(quickTempProvider.notifier).openFor(id);
  }
}

/// 요약 숫자 칸 (시제품 .stat): 옅은 흰 면 위에 큰 숫자 + 이름. 0이면 숫자를 흐리게.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color, required this.onTap});
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = value > 0;
    return Semantics(
      button: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: on ? 0.13 : 0.07),
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: T.number,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: T.caption,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: hoOnDarkSub,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 목록 구역 이름 (시제품 .sec): 작고 굵은 보조 글자. [dot]이 있으면 앞에 색 점.
class _Sec extends StatelessWidget {
  const _Sec(this.text, {this.color = inkSub, this.dot, this.sub});
  final String text;
  final Color color;
  final Color? dot;
  final String? sub;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, Gap.l, 2, Gap.s),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (dot != null) ...[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
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
