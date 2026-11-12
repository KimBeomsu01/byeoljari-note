// 화면 확인용 스크린샷 (앱과 같은 카카오 글씨로 그린다).
// 실행: flutter test --update-goldens --tags screenshots test/screenshots
// 결과: test/screenshots/out/*.png  (보통 테스트에서는 건너뛴다)
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:byeoljari_note/app.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/routes.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  Future<ByteData> f(String p) async => ByteData.view(Uint8List.fromList(await File(p).readAsBytes()).buffer);
  // 앱과 같은 카카오 글씨를 올린다 (테스트에서는 pubspec 글꼴이 자동으로 안 올라온다).
  final small = FontLoader('KakaoSmall')
    ..addFont(f('assets/fonts/KakaoSmallSans-Regular.ttf'))
    ..addFont(f('assets/fonts/KakaoSmallSans-Bold.ttf'));
  await small.load();
  final big = FontLoader('KakaoBig')..addFont(f('assets/fonts/KakaoBigSans-Bold.ttf'));
  await big.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(f(r'D:\dev\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf'));
  await icons.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
}

void main() {
  setUpAll(_loadFonts);

  Future<void> start(WidgetTester tester, {double w = 390, double h = 844}) async {
    tester.view.physicalSize = Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
    await tester.pumpAndSettle();
  }

  BuildContext ctx(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  testWidgets('01 인수인계', (t) async {
    await start(t);
    await _shot(t, '01_handover');
    await t.drag(find.byType(Scrollable).at(1), const Offset(0, -500));
    await _shot(t, '02_handover_scrolled');
  });

  testWidgets('03 별님별 기록', (t) async {
    await start(t);
    await t.tap(find.text('별님별 기록'));
    await _shot(t, '03_board');
  });

  testWidgets('04 체온 재기', (t) async {
    await start(t);
    await t.tap(find.bySemanticsLabel('퀵 체온 열기'));
    await _shot(t, '04_quick_temp');
  });

  testWidgets('05 일정', (t) async {
    await start(t);
    await t.tap(find.bySemanticsLabel('일정'));
    await _shot(t, '05_schedule');
  });

  testWidgets('06 하루 일정', (t) async {
    await start(t);
    openDaySchedule(ctx(t), residentByName('이서준').id, demoStart);
    await _shot(t, '06_day');
  });

  testWidgets('07 아카이브', (t) async {
    await start(t);
    openArchive(ctx(t), residentByName('이서준').id);
    await _shot(t, '07_archive');
  });

  testWidgets('08 별님카드', (t) async {
    await start(t);
    openResidentCard(ctx(t), residentByName('이서준').id);
    await _shot(t, '08_card');
  });

  testWidgets('09 이상 대응 상세', (t) async {
    await start(t);
    final container = ProviderScope.containerOf(ctx(t));
    final c = container.read(repoProvider).openCases.first;
    openCaseDetail(ctx(t), c.id);
    await _shot(t, '09_case');
  });

  testWidgets('10 작은 폰 인수인계', (t) async {
    await start(t, w: 360, h: 640);
    await _shot(t, '10_small');
  });

  testWidgets('11 PC 오늘 현황', (t) async {
    await start(t, w: 1440, h: 900);
    await _shot(t, '11_desk_today');
  });

  testWidgets('12 PC 대응 현황', (t) async {
    await start(t, w: 1440, h: 900);
    await t.tap(find.byKey(const ValueKey('desk-menu-cases')));
    await t.pumpAndSettle();
    final row = find.textContaining('박승민');
    if (row.evaluate().isNotEmpty) await t.tap(row.first);
    await _shot(t, '12_desk_cases');
  });

  testWidgets('13 PC 별님 기록', (t) async {
    await start(t, w: 1440, h: 900);
    await t.tap(find.byKey(const ValueKey('desk-menu-residents')));
    await _shot(t, '13_desk_resident');
  });

  for (final (w, h) in [(1280.0, 720.0), (1366.0, 768.0), (1024.0, 700.0), (920.0, 640.0)]) {
    testWidgets('14 PC ${w.toInt()}x${h.toInt()}', (t) async {
      await start(t, w: w, h: h);
      await _shot(t, '14_desk_${w.toInt()}');
      await t.tap(find.byKey(const ValueKey('desk-menu-cases')));
      await t.pumpAndSettle();
      final row = find.textContaining('박승민');
      if (row.evaluate().isNotEmpty) await t.tap(row.first);
      await _shot(t, '15_desk_cases_${w.toInt()}');
    });
  }
}
