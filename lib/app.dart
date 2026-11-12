// 공통 틀 (통합 명세 4-1): 상단 제목 + 🔔, 하단 메뉴 3개, 가운데 퀵 체온 레이어.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/alert_case/notice_center.dart';
import 'features/handover/handover_screen.dart';
import 'features/quick_temp/quick_temp_controller.dart';
import 'features/quick_temp/quick_temp_screen.dart';
import 'features/schedule/schedule_screen.dart';

class ByeoljariApp extends StatelessWidget {
  const ByeoljariApp({super.key, this.fontFamilyForScreenshots});

  /// 스크린샷 테스트에서 한글 글꼴을 지정할 때만 쓴다.
  final String? fontFamilyForScreenshots;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '별자리노트',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(fontFamily: fontFamilyForScreenshots),
        // 폰 화면 폭으로 보여준다 (PC 브라우저에서도).
        builder: (context, child) => ColoredBox(
          color: const Color(0xFFD5DDE8),
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: child),
          ),
        ),
        home: const NoticeBannerHost(child: AppShell()),
      );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final qtOpen = ref.watch(quickTempProvider.select((s) => s.open));
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final unseen = repo.unseenNoticeCount(me);

    return Scaffold(
      appBar: qtOpen
          ? null
          : AppBar(
              titleSpacing: Gap.page,
              title: Text(_tab == 0 ? '인수인계' : '일정'),
              actions: [
                _RoleSwitch(),
                IconButton(
                  tooltip: '알림',
                  iconSize: 30,
                  constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                  onPressed: () => showNoticeCenter(context, ref),
                  icon: Badge(
                    isLabelVisible: unseen > 0,
                    backgroundColor: stageColors[Stage.danger]!.ink,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    label: Text('$unseen'),
                    child: const Icon(Icons.notifications_outlined, color: inkMain),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: Stack(children: [
        IndexedStack(index: _tab, children: const [
          HandoverScreen(),
          ScheduleScreen(),
        ]),
        // 퀵 체온: 가운데 버튼에서 펼쳐지는 전체 화면 레이어
        IgnorePointer(
          ignoring: !qtOpen,
          child: AnimatedScale(
            scale: qtOpen ? 1 : 0.2,
            alignment: Alignment.bottomCenter,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: qtOpen ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const QuickTempScreen(),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: _BottomBar(
        tab: _tab,
        qtOpen: qtOpen,
        onTab: (i) {
          ref.read(quickTempProvider.notifier).close();
          setState(() => _tab = i);
        },
        onQuick: () => ref.read(quickTempProvider.notifier).toggle(),
      ),
    );
  }
}

/// 시연용 역할 바꾸기 (통합 명세 10-2). 실제 앱으로는 옮기지 않는다.
class _RoleSwitch extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    const choices = ['kim_haneul', 'park_soyeon', 'park_seoyeon', 'han_kyungsoo', 'oh_jimin'];
    return PopupMenuButton<String>(
      tooltip: '역할 바꾸기 (시연)',
      initialValue: me,
      onSelected: (v) async {
        if (v == '_skip30') {
          repo.advanceClock(const Duration(minutes: 30));
        } else if (v == '_reset') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('시연 처음 상태로 돌릴까요?'),
              content: const Text('이 기기에 저장된 기록이 모두 지워지고 10월 28일 09:41 상태로 돌아가요.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('처음 상태로')),
              ],
            ),
          );
          if (ok == true) {
            await repo.resetDemo();
            ref.invalidate(quickTempProvider);
            ref.read(currentUserProvider.notifier).state = 'kim_haneul';
          }
        } else {
          ref.read(currentUserProvider.notifier).state = v;
        }
      },
      itemBuilder: (_) => [
        for (final id in choices) PopupMenuItem(value: id, child: Text(repo.staff(id).displayName)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '_skip30', child: Text('⏩ 시계 30분 앞으로')),
        const PopupMenuItem(value: '_reset', child: Text('↺ 시연 처음 상태로')),
      ],
      // 지금 쓰는 사람 (시연에서는 눌러서 바꾼다)
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: line, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline, size: 22, color: inkSub),
          const SizedBox(width: 4),
          Text(repo.staff(me).name, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkMain)),
          const Icon(Icons.arrow_drop_down, color: inkSub),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tab, required this.qtOpen, required this.onTab, required this.onQuick});
  final int tab;
  final bool qtOpen;
  final ValueChanged<int> onTab;
  final VoidCallback onQuick;

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData icon, IconData iconOn, String label) {
      final on = !qtOpen && tab == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            onTap: () => onTab(i),
            child: SizedBox(
              height: 76,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(on ? iconOn : icon, size: 30, color: on ? brandDark : inkSub),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: TextStyle(fontSize: T.caption, fontWeight: on ? FontWeight.w800 : FontWeight.w500, color: on ? brandDark : inkSub)),
              ]),
            ),
          ),
        ),
      );
    }

    return Material(
      color: surface,
      shape: const Border(top: BorderSide(color: line)),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          item(0, Icons.article_outlined, Icons.article, '인수인계'),
          // 가장 자주 누르는 버튼: 노란 '체온 재기'
          Semantics(
            button: true,
            label: qtOpen ? '퀵 체온 접기' : '퀵 체온 열기',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onQuick,
              child: Container(
                width: 132,
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: qtOpen ? inkMain : starYellow,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                // 큰 글자 설정에서도 넘치지 않게 버튼 안에서 줄인다
                child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(qtOpen ? Icons.close : Icons.thermostat, color: qtOpen ? Colors.white : inkMain, size: 28),
                  const SizedBox(width: 4),
                  Text(qtOpen ? '닫기' : '체온 재기',
                      style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: qtOpen ? Colors.white : inkMain)),
                ])),
              ),
            ),
          ),
          item(1, Icons.calendar_month_outlined, Icons.calendar_month, '일정'),
        ]),
      ),
    );
  }
}
