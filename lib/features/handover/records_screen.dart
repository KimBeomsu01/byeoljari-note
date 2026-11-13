// 인수인계 전체 기록 (첫 화면 "안 본 기록 n개 ›"에서 연다).
// 예전 인수인계 탭 그대로: [기록 남기기] (맨 위, 할 일 버튼과 겹치지 않게) → [최신 기록 | 별님별 기록] → 목록.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import 'handover_common.dart';
import 'handover_view.dart';
import 'latest_feed.dart';
import 'resident_board.dart';
import 'write_sheet.dart';

/// 전체 기록 화면을 연다. 안 본 기록이 있으면 '안 본 기록' 보기로 시작한다.
Future<void> openHandoverRecords(BuildContext context, {FeedFilter? filter}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HandoverRecordsScreen(initialFilter: filter)));

class HandoverRecordsScreen extends ConsumerStatefulWidget {
  const HandoverRecordsScreen({super.key, this.initialFilter});
  final FeedFilter? initialFilter;

  @override
  ConsumerState<HandoverRecordsScreen> createState() => _HandoverRecordsScreenState();
}

class _HandoverRecordsScreenState extends ConsumerState<HandoverRecordsScreen> {
  int _seg = 0;
  late final FeedFilter _start;

  @override
  void initState() {
    super.initState();
    final v = HandoverView(ref.read(repoProvider), ref.read(currentUserProvider), ref.read(clockProvider)());
    _start = widget.initialFilter ?? (v.unread.isNotEmpty ? FeedFilter.unread : FeedFilter.all);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final unread = HandoverView(repo, me, ref.read(clockProvider)()).unread.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('인수인계 기록', style: TextStyle(fontFamily: fontBig, fontSize: T.title, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, Gap.m),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, tapHeight)),
                  onPressed: () => showWriteSheet(context, ref, classId: _seg == 1 ? ref.read(handoverClassProvider) : null),
                  icon: const Icon(Icons.edit_outlined, size: 22),
                  label: const Text('기록 남기기'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.m),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: hoSegBg, borderRadius: BorderRadius.circular(Radii.card)),
                child: Row(
                  children: [
                    _Seg(label: '최신 기록', badge: unread, selected: _seg == 0, onTap: () => setState(() => _seg = 0)),
                    const SizedBox(width: 4),
                    _Seg(label: '별님별 기록', selected: _seg == 1, onTap: () => setState(() => _seg = 1)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(index: _seg, children: [LatestFeed(initialFilter: _start), const ResidentBoard()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.selected, required this.onTap, this.badge = 0});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, 안 본 기록 $badge' : label,
      excludeSemantics: true,
      child: Material(
        color: selected ? surface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button - 2),
          side: BorderSide(color: selected ? line : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.button - 2),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: tapHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: T.body,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? inkMain : inkSub,
                      ),
                    ),
                  ),
                  if (badge > 0) ...[const SizedBox(width: 8), CountBadge(badge)],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
