// 사무국 PC 웹 (DESK, 통합 명세 6-7 · 사무국PC 웹 기능명세).
// 왼쪽 메뉴 고정 + 위 조건 줄 + 오른쪽 조회 화면. 조회용이라 확인·담당·종료 상태를 바꾸지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'desk_cases.dart';
import 'desk_common.dart';
import 'desk_resident.dart';
import 'desk_today.dart';

enum DeskMenu { today, residents, cases, schedule, export }

extension DeskMenuInfo on DeskMenu {
  String get label => switch (this) {
        DeskMenu.today => '오늘 현황',
        DeskMenu.residents => '별님 기록',
        DeskMenu.cases => '긴급·이상 대응 현황',
        DeskMenu.schedule => '반별 일정',
        DeskMenu.export => '기록 내보내기',
      };

  /// 좁은 메뉴 띠에 쓰는 짧은 이름.
  String get shortLabel => switch (this) {
        DeskMenu.today => '오늘',
        DeskMenu.residents => '별님 기록',
        DeskMenu.cases => '대응 현황',
        DeskMenu.schedule => '일정',
        DeskMenu.export => '내보내기',
      };

  IconData get icon => switch (this) {
        DeskMenu.today => Icons.dashboard_outlined,
        DeskMenu.residents => Icons.menu_book_outlined,
        DeskMenu.cases => Icons.warning_amber_rounded,
        DeskMenu.schedule => Icons.calendar_month_outlined,
        DeskMenu.export => Icons.file_download_outlined,
      };

  bool get later => this == DeskMenu.schedule || this == DeskMenu.export;
}

/// 사무국 PC 화면 전체. [onPhoneView]가 있으면 위 줄에 '폰 화면으로 보기'.
class DeskShell extends ConsumerStatefulWidget {
  const DeskShell({super.key, this.onPhoneView});
  final VoidCallback? onPhoneView;

  @override
  ConsumerState<DeskShell> createState() => _DeskShellState();
}

class _DeskShellState extends ConsumerState<DeskShell> {
  DeskMenu menu = DeskMenu.today;

  /// 별님 기록에서 고른 별님 / 대응 현황에서 고른 건 (메뉴를 오가도 유지).
  String? residentId;
  String? caseId;

  /// 다른 메뉴에서 넘어올 때 미리 열 기록 (예: 최초 측정 `m:측정ID`).
  String? openRecordKey;
  int navSeq = 0;

  void goResident(String id, {String? recordKey}) => setState(() {
        menu = DeskMenu.residents;
        residentId = id;
        openRecordKey = recordKey;
        navSeq++;
      });

  void goCase(String id) => setState(() {
        menu = DeskMenu.cases;
        caseId = id;
        navSeq++;
      });

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider); // 새 측정·이상 건이 오면 다시 그린다 (6-7-7)
    final now = repo.now();
    final me = ref.watch(currentUserProvider);
    String meName;
    try {
      meName = repo.staff(me).displayName;
    } catch (_) {
      meName = me;
    }

    final Widget content = switch (menu) {
      DeskMenu.today => DeskTodayView(onResident: (id) => goResident(id), onCase: goCase),
      DeskMenu.residents => DeskResidentView(
          key: ValueKey('res-$navSeq'),
          residentId: residentId,
          initialRecordKey: openRecordKey,
          onSelect: (id) => setState(() {
            residentId = id;
            openRecordKey = null;
          }),
          onCase: goCase,
        ),
      DeskMenu.cases => DeskCasesView(
          key: ValueKey('case-$navSeq'),
          caseId: caseId,
          onSelect: (id) => setState(() => caseId = id),
          onResident: (id, {recordKey}) => goResident(id, recordKey: recordKey),
        ),
      DeskMenu.schedule || DeskMenu.export => _LaterCard(menu),
    };

    // 화면 크기에 맞춰 조절: 좁은 창(1280 미만)에서는 메뉴를 아이콘 띠로 접고 글자를 조금 줄인다.
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1280;
    final scale = (width / 1280).clamp(0.88, 1.0);
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: _ScaledTextScaler(mq.textScaler, scale)),
      child: Scaffold(
      backgroundColor: paper,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SideMenu(compact: compact, current: menu, openCount: repo.openCases.length, onTap: (m) => setState(() => menu = m)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _TopBar(
              condition: '${mdLabel(now)} · 전체 ${repo.classes.length}개 반',
              updated: hhmm(now),
              user: meName,
              onPhoneView: widget.onPhoneView,
            ),
            const Divider(height: 1),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: Padding(padding: EdgeInsets.fromLTRB(compact ? 16 : 24, compact ? 12 : 20, compact ? 16 : 24, 0), child: content),
                ),
              ),
            ),
          ]),
        ),
      ]),
    ),
    );
  }
}

/// 사용자의 글자 크기 설정에 화면 폭 비율을 곱한다.
class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.base, this.factor);
  final TextScaler base;
  final double factor;
  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;
  @override
  double get textScaleFactor => base.scale(1) * factor;
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.current, required this.onTap, required this.openCount, this.compact = false});
  final bool compact;
  final DeskMenu current;
  final ValueChanged<DeskMenu> onTap;
  final int openCount;

  @override
  Widget build(BuildContext context) => compact ? _rail() : Container(
        width: 220,
        decoration: const BoxDecoration(color: surface, border: Border(right: BorderSide(color: line))),
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 20, 12, 20), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text.rich(TextSpan(children: [
                TextSpan(text: '✦ ', style: TextStyle(color: coral)),
                TextSpan(text: '별자리노트'),
              ]), style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: brandDark)),
              Text('사무국 PC', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
            ]),
          ),
          for (final m in DeskMenu.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: m == current ? sage : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.button),
                child: InkWell(
                  key: ValueKey('desk-menu-${m.name}'),
                  borderRadius: BorderRadius.circular(Radii.button),
                  onTap: () => onTap(m),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(children: [
                      Icon(m.icon, size: 22, color: m == current ? brandDark : inkSub),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(m.label,
                            style: TextStyle(
                              fontSize: T.body,
                              fontWeight: m == current ? FontWeight.w800 : FontWeight.w600,
                              color: m == current ? brandDark : inkMain,
                            )),
                      ),
                      if (m == DeskMenu.cases && openCount > 0)
                        Text('$openCount건', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: stageColors[Stage.danger]!.ink)),
                      if (m.later) const Text('후속', style: TextStyle(fontSize: T.caption, color: inkSub)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      );

  /// 좁은 창: 아이콘 + 짧은 이름만 있는 띠 (폭 88).
  Widget _rail() => Container(
        width: 88,
        decoration: const BoxDecoration(color: surface, border: Border(right: BorderSide(color: line))),
        child: ListView(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6), children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Icon(Icons.auto_awesome, color: coral, size: 26, semanticLabel: '별자리노트 사무국 PC'),
          ),
          for (final m in DeskMenu.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Tooltip(
                message: m.label,
                child: Material(
                  color: m == current ? sage : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.button),
                  child: InkWell(
                    key: ValueKey('desk-menu-${m.name}'),
                    borderRadius: BorderRadius.circular(Radii.button),
                    onTap: () => onTap(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(children: [
                        Badge(
                          isLabelVisible: m == DeskMenu.cases && openCount > 0,
                          label: Text('$openCount'),
                          backgroundColor: stageColors[Stage.danger]!.ink,
                          child: Icon(m.icon, size: 26, color: m == current ? brandDark : inkSub),
                        ),
                        const SizedBox(height: 4),
                        Text(m.shortLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.2,
                              fontWeight: m == current ? FontWeight.w800 : FontWeight.w600,
                              color: m == current ? brandDark : inkMain,
                            )),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.condition, required this.updated, required this.user, this.onPhoneView});
  final String condition;
  final String updated;
  final String user;
  final VoidCallback? onPhoneView;

  @override
  Widget build(BuildContext context) => Container(
        color: surface,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(children: [
          const Icon(Icons.today_outlined, color: inkSub, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(spacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(condition, key: const ValueKey('desk-condition'), style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
              Text('마지막 갱신 $updated', key: const ValueKey('desk-updated'), style: const TextStyle(fontSize: T.body, color: inkSub)),
            ]),
          ),
          Text(user, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
          if (onPhoneView != null) ...[
            const SizedBox(width: 12),
            TextButton.icon(onPressed: onPhoneView, icon: const Icon(Icons.smartphone, size: 20), label: const Text('폰 화면으로 보기')),
          ],
        ]),
      );
}

class _LaterCard extends StatelessWidget {
  const _LaterCard(this.menu);
  final DeskMenu menu;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DeskHeading(menu.label),
          DeskCard(
            child: Row(children: [
              const Icon(Icons.hourglass_empty_rounded, color: inkSub, size: 32),
              const SizedBox(width: Gap.l),
              Expanded(
                child: Text(
                  menu == DeskMenu.schedule
                      ? '반별 일정과 전체 시간표는 다음 단계에서 만들어요. 지금은 폰 앱의 일정 화면에서 볼 수 있어요.'
                      : '기록 내보내기(CSV)는 다음 단계에서 만들어요. 권한 있는 담당자만 반·별님·기간을 정해 내보낼 수 있게 할 예정이에요.',
                  style: const TextStyle(fontSize: T.body, color: inkMain, height: 1.5),
                ),
              ),
            ]),
          ),
        ]),
      );
}
