// 공통 틀: 모바일 탭 · 퀵 체온 · 프로필 메뉴, PC 레일 이동 · 의사 모드.
import 'package:byeoljari_note/app.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/features/handover/handover_screen.dart';
import 'package:byeoljari_note/features/pc/pc_calls_page.dart';
import 'package:byeoljari_note/features/pc/pc_dashboard_page.dart';
import 'package:byeoljari_note/features/pc/pc_doctor_page.dart';
import 'package:byeoljari_note/features/pc/pc_schedule_page.dart';
import 'package:byeoljari_note/features/pc/pc_shell.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_controller.dart';
import 'package:byeoljari_note/features/resident_card/resident_card_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final clockAt = DateTime(2026, 10, 28, 14, 0);

Future<ProviderContainer> pump(WidgetTester tester, {required bool pc, Dataset dataset = Dataset.demo, bool withLogout = false}) async {
  tester.view.physicalSize = pc ? const Size(1440, 1000) : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = InMemoryRepository(dataset: dataset, clock: () => clockAt);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repoProvider.overrideWith((_) => repo),
      screenKindProvider.overrideWithValue(pc ? 'pc' : 'mobile'),
      if (withLogout) logoutProvider.overrideWithValue(() async {}),
    ],
    child: ByeoljariApp(pc: pc),
  ));
  await tester.pump(const Duration(milliseconds: 500));
  return ProviderScope.containerOf(tester.element(find.byType(pc ? PcShell : AppShell)));
}

void main() {
  testWidgets('모바일: 인수인계 → 별님카드 탭, 가운데 버튼은 퀵 체온 열고 닫기', (tester) async {
    final c = await pump(tester, pc: false);
    expect(c.read(currentUserProvider), 'kim_haneul');
    expect(find.byType(HandoverScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('별님카드'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.read(mobileTabProvider), 1);
    expect(find.byType(ResidentCardScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('퀵 체온'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.read(quickTempProvider).open, isTrue);
    await tester.tap(find.bySemanticsLabel('퀵 체온 닫기'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.read(quickTempProvider).open, isFalse);
  });

  testWidgets('모바일: 프로필 메뉴에서 사용자 바꾸기 · 로그아웃 버튼', (tester) async {
    final c = await pump(tester, pc: false, withLogout: true);
    await tester.tap(find.byTooltip('프로필'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('시연 DB · 가상 자료'), findsOneWidget);
    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.text('시연 자료 처음 상태로'), findsOneWidget);
    await tester.ensureVisible(find.text('박지은 선생님'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('박지은 선생님'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.read(currentUserProvider), 'park_jieun');
  });

  testWidgets('모바일 개발 DB: 머리에 예시 표시, 프로필 메뉴는 개발 DB 비우기', (tester) async {
    final c = await pump(tester, pc: false, dataset: Dataset.dev);
    expect(c.read(currentUserProvider), 'ex_care');
    await tester.tap(find.byTooltip('프로필'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('개발 DB · 예시 자료'), findsOneWidget);
    expect(find.text('개발 DB 비우기 (예시만 남기기)'), findsOneWidget);
  });

  testWidgets('PC: 레일로 현황판 · 일정 · 의료 호출함, 의사로 바꾸면 협진 포털', (tester) async {
    final c = await pump(tester, pc: true);
    expect(c.read(currentUserProvider), 'park_soyeon');
    expect(find.byType(PcDashboardPage), findsOneWidget);

    await tester.tap(find.byTooltip('일정 관리'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PcSchedulePage), findsOneWidget);

    await tester.tap(find.byTooltip('의료 호출함'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PcCallsPage), findsOneWidget);

    c.read(currentUserProvider.notifier).state = 'kang_dahye';
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PcDoctorPage), findsOneWidget);
    expect(find.byTooltip('의료진 협진 포털'), findsOneWidget);
    expect(find.byTooltip('전체 현황판'), findsNothing);
  });

  test('주소 → 화면 종류: /doctor 의료진 협진 포털, /pc 오피스 웹, 그 밖 모바일', () {
    expect(screenKindOf('/doctor'), 'doctor');
    expect(screenKindOf('/doctor/'), 'doctor');
    expect(screenKindOf('/pc'), 'pc');
    expect(screenKindOf('/pc/'), 'pc');
    expect(screenKindOf('/'), 'mobile');
    expect(screenKindOf('/login'), 'mobile');
    expect(screenKindOf('/pcx'), 'mobile');
  });

  testWidgets('의료진 주소(/doctor): 강다혜 촉탁의로 협진 포털만, 사용자 바꾸기는 의사만', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = InMemoryRepository(dataset: Dataset.demo, clock: () => clockAt);
    await tester.pumpWidget(ProviderScope(
      overrides: [repoProvider.overrideWith((_) => repo), screenKindProvider.overrideWithValue('doctor')],
      child: const ByeoljariApp(pc: true),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    final c = ProviderScope.containerOf(tester.element(find.byType(PcShell)));
    expect(c.read(currentUserProvider), 'kang_dahye');
    expect(find.byType(PcDoctorPage), findsOneWidget);
    expect(find.byTooltip('전체 현황판'), findsNothing);
    expect(find.byTooltip('의료 호출함'), findsNothing);
  });
}
