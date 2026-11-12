// 인수인계 탭: [최신 기록 | 별님별 기록] 두 칸 고르기 + 떠 있는 "기록 남기기" 버튼 (인수인계 명세 3장, 시제품 FAB).
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

    // 시제품의 오른쪽 아래 '기록 남기기' 알약 버튼. 떠 있으면 카드 글자를 가려서, 목록 아래 고정 줄에 둔다.
    return Column(
      children: [
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
          child: IndexedStack(index: _seg, children: const [LatestFeed(), ResidentBoard()]),
        ),
        Container(
          width: double.infinity,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.fromLTRB(Gap.page, 6, 16, 6),
          color: paper,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, tapHeight),
              padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
              shape: const StadiumBorder(),
            ),
            onPressed: () => showWriteSheet(context, ref, classId: _seg == 1 ? ref.read(handoverClassProvider) : null),
            icon: const Icon(Icons.edit_outlined, size: 22),
            label: const Text('기록 남기기'),
          ),
        ),
      ],
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
