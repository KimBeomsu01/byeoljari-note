// 인수인계 탭: [최신 기록 | 별님별 기록] 세그먼트 + "기록 남기기" 버튼 (인수인계 명세 3장).
// 이 화면은 메모리 저장소를 바로 읽으므로 "불러오는 중·실패" 상태가 생기지 않는다.
// 서버 저장소로 바꿀 때 5-5 상태를 붙인다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import 'handover_common.dart';
import 'handover_view.dart';
import 'latest_feed.dart';
import 'resident_board.dart';
import 'write_sheet.dart';

class HandoverScreen extends ConsumerStatefulWidget {
  const HandoverScreen({super.key});

  @override
  ConsumerState<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends ConsumerState<HandoverScreen> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final unread = HandoverView(repo, me, ref.read(clockProvider)()).unread.length;

    return Stack(children: [
      Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: const Color(0xFFE8EAE3), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              _Seg(label: '최신 기록', badge: unread, selected: _seg == 0, onTap: () => setState(() => _seg = 0)),
              _Seg(label: '별님별 기록', selected: _seg == 1, onTap: () => setState(() => _seg = 1)),
            ]),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _seg, children: const [LatestFeed(), ResidentBoard()]),
        ),
      ]),
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton.extended(
          heroTag: 'handover-write',
          backgroundColor: hoSummaryBg,
          foregroundColor: Colors.white,
          onPressed: () => showWriteSheet(context, ref, classId: _seg == 1 ? ref.read(handoverClassProvider) : null),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('기록 남기기', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
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
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onTap,
              child: SizedBox(
                height: 44,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? inkMain : inkSub)),
                  if (badge > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: hoUnreadBadge, borderRadius: BorderRadius.circular(99)),
                      child: Text('$badge',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
}
