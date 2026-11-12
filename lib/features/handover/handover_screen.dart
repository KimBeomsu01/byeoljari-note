// 인수인계 탭: [최신 기록 | 별님별 기록] 두 칸 고르기 + "기록 남기기" 버튼 (인수인계 명세 3장).
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

    return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, Gap.s),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(Radii.button + 4),
              border: Border.all(color: line, width: 1.5),
            ),
            child: Row(children: [
              _Seg(label: '최신 기록', badge: unread, selected: _seg == 0, onTap: () => setState(() => _seg = 0)),
              const SizedBox(width: 4),
              _Seg(label: '별님별 기록', selected: _seg == 1, onTap: () => setState(() => _seg = 1)),
            ]),
          ),
        ),
        // 떠 있는 버튼은 카드 내용을 가려서, 탭 바로 아래 고정 버튼으로 둔다.
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.s),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showWriteSheet(context, ref, classId: _seg == 1 ? ref.read(handoverClassProvider) : null),
              icon: const Icon(Icons.edit_outlined, size: 24),
              label: const Text('기록 남기기'),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _seg, children: const [LatestFeed(), ResidentBoard()]),
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
            color: selected ? brandDark : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.button),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.button),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: T.body,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected ? Colors.white : inkMain)),
                    ),
                    if (badge > 0) ...[const SizedBox(width: 8), CountBadge(badge)],
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
