// 공통 틀. 모바일 = 인수인계 · 가운데 퀵 체온 · 별님카드 (Claude Design TabBar 3-tab-center-fab).
// PC(/pc 주소) = 왼쪽 레일 + 머리 (features/pc/pc_shell.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ds.dart';
import 'core/models.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'features/alert_case/notice_center.dart';
import 'features/handover/handover_screen.dart';
import 'features/pc/pc_shell.dart';
import 'features/quick_temp/quick_temp_controller.dart';
import 'features/quick_temp/quick_temp_screen.dart';
import 'features/resident_card/resident_card_screen.dart';

/// 로그아웃 (서버 연결 화면에서 덮어쓴다). 없으면 메뉴에 안 보인다.
final logoutProvider = Provider<Future<void> Function()?>((ref) => null);

class ByeoljariApp extends ConsumerWidget {
  const ByeoljariApp({super.key, this.pc = false, this.fontFamilyForScreenshots});

  /// PC 화면(/pc 오피스 웹 · /doctor 의료진 협진 포털)으로 들어왔는가.
  final bool pc;

  /// 스크린샷 테스트에서 한글 글꼴을 지정할 때만 쓴다.
  final String? fontFamilyForScreenshots;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: switch (ref.watch(screenKindProvider)) {
      'doctor' => '별자리노트 · 의료진 협진 포털',
      'pc' => '별자리노트 · 오피스 웹',
      _ => '별자리노트',
    },
    debugShowCheckedModeBanner: false,
    theme: buildTheme(fontFamily: fontFamilyForScreenshots),
    builder: (context, child) {
      if (pc) return child!;
      // 모바일 화면 폭(최대 440)으로 가운데에 보여준다.
      return ColoredBox(
        color: Ds.bg,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Ds.screenMax),
            child: child,
          ),
        ),
      );
    },
    home: pc ? const PcShell() : const NoticeBannerHost(child: AppShell()),
  );
}

/// 지금 고른 모바일 탭 (0 인수인계 · 1 별님카드). 다른 화면에서 별님카드로 보낼 때 쓴다.
final mobileTabProvider = NotifierProvider<MobileTab, int>(MobileTab.new);

class MobileTab extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

/// 별님카드 탭에서 보여줄 별님 (다른 화면에서 이름을 누르면 바뀐다).
final residentCardTargetProvider = NotifierProvider<ResidentCardTarget, String?>(ResidentCardTarget.new);

class ResidentCardTarget extends Notifier<String?> {
  @override
  String? build() => null;
  void show(String residentId) => state = residentId;
}

/// 다른 화면에서 별님카드 탭으로 이동.
void goResidentCard(WidgetRef ref, String residentId) {
  ref.read(quickTempProvider.notifier).close();
  ref.read(residentCardTargetProvider.notifier).show(residentId);
  ref.read(mobileTabProvider.notifier).go(1);
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qtOpen = ref.watch(quickTempProvider.select((s) => s.open));
    final tab = ref.watch(mobileTabProvider);

    return Scaffold(
      backgroundColor: Ds.bg,
      body: Stack(
        children: [
          IndexedStack(index: tab, children: const [HandoverScreen(), ResidentCardScreen()]),
          // 퀵 체온: 가운데 버튼에서 펼쳐지는 전체 화면 레이어 (팝업)
          Positioned.fill(
            child: IgnorePointer(
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
          ),
        ],
      ),
      bottomNavigationBar: _TabBar(
        tab: tab,
        qtOpen: qtOpen,
        onTab: (i) {
          ref.read(quickTempProvider.notifier).close();
          ref.read(mobileTabProvider.notifier).go(i);
        },
        onQuick: () => ref.read(quickTempProvider.notifier).toggle(),
      ),
    );
  }
}

/// TabBar (3-tab-center-fab / 3-tab-center-close). 높이 64, 가운데 violet 동그라미가 20 떠 있다.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.qtOpen, required this.onTab, required this.onQuick});
  final int tab;
  final bool qtOpen;
  final ValueChanged<int> onTab;
  final VoidCallback onQuick;

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData on, IconData off, String label) {
      final selected = !qtOpen && tab == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => onTab(i),
            radius: 36,
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? on : off, size: 24, color: selected ? Ds.gray900 : Ds.gray500),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: T.micro,
                      height: 1.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Ds.gray900 : Ds.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF2FFFFFF),
        boxShadow: [BoxShadow(color: Color(0x0D000000), offset: Offset(0, -1))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                item(0, Icons.assignment, Icons.assignment_outlined, '인수인계'),
                Expanded(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Semantics(
                        button: true,
                        label: qtOpen ? '퀵 체온 닫기' : '퀵 체온',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: onQuick,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: qtOpen ? Ds.gray900 : Ds.violet500,
                              shape: BoxShape.circle,
                              boxShadow: [
                                const BoxShadow(color: Colors.white, spreadRadius: 4),
                                BoxShadow(
                                  color: (qtOpen ? Ds.gray900 : Ds.violet500).withValues(alpha: 0.36),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              qtOpen ? Icons.close_rounded : Icons.thermostat_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                item(1, Icons.badge, Icons.badge_outlined, '별님카드'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 머리 오른쪽 "프로필" 버튼이 여는 메뉴: 지금 사용자 · 사용자 바꾸기 · 자료 처음으로 · 로그아웃.
Future<void> showProfileSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final repo = ref.watch(repoProvider);
        final me = ref.watch(currentUserProvider);
        final logout = ref.watch(logoutProvider);
        // 의료진 주소(/doctor)에서는 의사만, 그 밖(모바일 · 오피스 웹)에서는 의사를 뺀 직원으로 바꿀 수 있다.
        final doctorScreen = ref.watch(screenKindProvider) == 'doctor';
        final staff = repo.allStaff.where((s) => (s.role == Role.doctor) == doctorScreen).toList();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Row(
                  children: [
                    InitialAvatar(
                      repo.staff(me).name.characters.first,
                      size: 44,
                      background: Ds.gray900,
                      foreground: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repo.staff(me).displayName,
                            style: const TextStyle(fontSize: T.heading, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            repo.isDev ? '개발 DB · 예시 자료' : '시연 DB · 가상 자료',
                            style: const TextStyle(fontSize: T.caption, color: Ds.gray500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '사용자 바꾸기',
                  style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: Ds.gray500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in staff)
                      DsChip(
                        label: s.displayName,
                        selected: s.id == me,
                        onTap: () {
                          ref.read(currentUserProvider.notifier).state = s.id;
                          Navigator.pop(sheet);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                DsButton(
                  repo.isDev ? '개발 DB 비우기 (예시만 남기기)' : '시연 자료 처음 상태로',
                  kind: DsButtonKind.gray,
                  expand: true,
                  icon: Icons.restart_alt_rounded,
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: Text(repo.isDev ? '개발 DB를 비울까요?' : '시연 자료를 처음 상태로 돌릴까요?'),
                        content: Text(
                          repo.isDev ? '입력한 기록이 모두 사라지고 자리마다 예시 한 건만 남아요.' : '입력한 기록이 모두 사라지고 오늘 날짜 기준 가상 자료로 다시 채워져요.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('처음 상태로')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await repo.resetDataset();
                    ref.invalidate(quickTempProvider);
                    ref.read(currentUserProvider.notifier).state = repo.defaultUser(ref.read(screenKindProvider));
                    if (sheet.mounted) Navigator.pop(sheet);
                  },
                ),
                if (logout != null) ...[
                  const SizedBox(height: 8),
                  DsButton(
                    '로그아웃',
                    kind: DsButtonKind.outline,
                    expand: true,
                    icon: Icons.logout_rounded,
                    onPressed: () async {
                      Navigator.pop(sheet);
                      await repo.flushSave();
                      await logout();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// 모바일 머리 (AppBar · tab): "별자리노트 | 화면이름" + 알림 + 프로필. 화면마다 이걸 쓴다.
class MobileAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const MobileAppBar({super.key, required this.section});
  final String section;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final unseen = repo.unseenNoticeCount(me);
    return Container(
      height: 56,
      color: const Color(0xE6F2F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Text(
            '별자리노트',
            style: TextStyle(fontSize: T.title, height: 1.5, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          const SizedBox(width: 6),
          const Text(
            '|',
            style: TextStyle(fontSize: T.caption, color: Ds.gray300),
          ),
          const SizedBox(width: 6),
          Text(
            section,
            style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: Ds.gray600),
          ),
          if (repo.isDev) ...[const SizedBox(width: 8), const ExampleTag()],
          const Spacer(),
          Tooltip(
            message: '알림',
            child: InkResponse(
              radius: 22,
              onTap: () => showNoticeCenter(context, ref),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_rounded, size: 23, color: Ds.gray700),
                    if (unseen > 0)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Ds.red500, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: '프로필',
            child: InkResponse(
              radius: 20,
              onTap: () => showProfileSheet(context, ref),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Ds.gray200, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, size: 20, color: Ds.gray700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
