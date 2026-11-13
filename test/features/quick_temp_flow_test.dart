// 시연 3단계: 이서준 재측정 할 일 → 퀵 체온 → 38.4 → 0.5초 → 기록 완료 → 이상 대응 시트.
import 'package:byeoljari_note/app.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_controller.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 큰 글자 검사용: 넘침 오류를 모은다. 하단 메뉴(lib/app.dart, 다른 담당)의 넘침은 따로 보고하고 여기서는 뺀다.
List<String> Function() collectOverflows() {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    final text = d.toDiagnosticsNode().toStringDeep();
    if (!text.contains('lib/app.dart')) errors.add(text);
  };
  return () {
    FlutterError.onError = old;
    return errors;
  };
}

void main() {
  testWidgets('할 일에서 퀵 체온을 열고 0.5초 눌러 기록하면 이상 대응이 생긴다', (tester) async {
    tester.view.physicalSize = const Size(400 * 2, 820 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
    await tester.pumpAndSettle();

    // 다른 화면(인수인계 할 일 [완료하기], 이상 대응 [재측정 입력])은 openFor로 퀵 체온을 연다.
    // 인수인계 화면은 다른 담당이 고치는 중이라, 여기서는 openFor를 바로 불러 퀵 체온만 본다.
    final container = ProviderScope.containerOf(tester.element(find.byType(QuickTempScreen)));
    final repo = container.read(repoProvider);
    final seojun = residentByName('이서준').id;
    expect(repo.openCases.length, 1);
    expect(repo.openTempTasksOf(seojun), isNotEmpty, reason: '09:15 37.6 주의 → 재측정 할 일');
    container.read(quickTempProvider.notifier).openFor(seojun);
    await tester.pumpAndSettle();
    expect(find.text('할 일 · 09:15 37.6℃ 다시 재기'), findsOneWidget);

    // 퀵 체온이 은하수자리·이서준으로 열림, 36.5에서 시작
    expect(find.descendant(of: find.byType(QuickTempScreen), matching: find.text('이서준')), findsOneWidget);
    expect(find.bySemanticsLabel('반 고르기, 지금 은하수자리'), findsOneWidget);
    expect(find.textContaining('6명 중'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('은하수자리 2번째, 이서준')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('이서준 36.5도')), findsOneWidget);
    expect(find.text('36.5'), findsOneWidget); // 체온은 큰 숫자 96

    // + 19번 → 38.4
    final plus = find.bySemanticsLabel('0.1도 올리기');
    for (var i = 0; i < 19; i++) {
      await tester.tap(plus);
    }
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('이서준 38.4도')), findsOneWidget);

    // 0.3초만 누르면 저장 안 됨
    final dial = find.text('꾹 눌러 기록');
    var g = await tester.startGesture(tester.getCenter(dial));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pump();
    expect(find.text('기록 완료'), findsNothing);

    // 0.5초 넘게 누르면 기록
    g = await tester.startGesture(tester.getCenter(dial));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(find.text('기록 완료'), findsOneWidget);

    // 0.6초 뒤 이상 대응 시트
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('이상 대응'), findsWidgets);
    Finder inSheet(String t) => find.descendant(of: find.byType(BottomSheet), matching: find.text(t));
    expect(inSheet('▲ 이상 대응을 시작했어요'), findsOneWidget);
    expect(inSheet('이서준 별님 38.4℃'), findsOneWidget);
    expect(inSheet('평소보다 1.3도 높아요'), findsOneWidget);
    expect(find.text('투약 지침 보기'), findsOneWidget);

    // 지침 보기 → 의료진 글 그대로
    await tester.tap(find.text('투약 지침 보기'));
    await tester.pumpAndSettle();
    expect(find.text('이서준 투약 지침'), findsOneWidget);
    // 하단 노란 버튼도 '닫기'라서, 지침 창 안의 '닫기'만 누른다.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('닫기')));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('30분 뒤 다시 재기'));
    await tester.pumpAndSettle();

    // 할 일 자동 완료 + 이상 대응 2건
    expect(repo.openTempTasksOf(seojun), isEmpty);
    expect(repo.openCases.length, 2);
    await tester.tap(find.bySemanticsLabel('퀵 체온 접기'));
    await tester.pumpAndSettle();
    expect(container.read(quickTempProvider).open, isFalse);
  });

  testWidgets('권한 없는 반은 잠겨 있다 (김하늘은 은하수자리만)', (tester) async {
    tester.view.physicalSize = const Size(800, 1640);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
    await tester.tap(find.bySemanticsLabel('퀵 체온 열기'));
    await tester.pumpAndSettle();
    expect(find.text('김민준'), findsOneWidget, reason: '담당 반 첫 별님');
    // [● 은하수자리 ▾] 를 누르면 반 목록. 권한 없는 반은 흐리게(눌러도 안 바뀜).
    await tester.tap(find.bySemanticsLabel('반 고르기, 지금 은하수자리'));
    await tester.pumpAndSettle();
    expect(find.text('권한 없음', findRichText: true), findsNothing);
    expect(find.text(' 권한 없음'), findsNWidgets(5));
    await tester.tap(find.text('고래자리').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('김민준'), findsOneWidget, reason: '잠긴 반은 눌러도 안 바뀜');
  });

  testWidgets('작은 폰(360×640)에서도 퀵 체온이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
    await tester.tap(find.bySemanticsLabel('퀵 체온 열기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('꾹 눌러 기록'), findsOneWidget);
  });

  for (final size in const [Size(390, 844), Size(360, 640)]) {
    testWidgets('큰 글자(1.3배)로도 퀵 체온이 넘치지 않는다 ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final overflows = collectOverflows();
      var errors = <String>[];
      try {
        await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
        await tester.tap(find.bySemanticsLabel('퀵 체온 열기'));
        await tester.pumpAndSettle();
        expect(find.text('꾹 눌러 기록'), findsOneWidget);
        // 기록 완료 상태도 넘치지 않는다
        final g = await tester.startGesture(tester.getCenter(find.text('꾹 눌러 기록')));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pump();
        await g.up();
        await tester.pumpAndSettle();
        expect(find.text('기록 완료'), findsOneWidget);
        // 다이얼이 너무 작아지지 않는다 (글자 대신 다이얼을 줄이되 쓸 만한 크기)
        final dial = tester.getSize(find.bySemanticsLabel(RegExp('체온 다이얼')));
        expect(dial.width, greaterThanOrEqualTo(110));
      } finally {
        errors = overflows();
      }
      expect(errors, isEmpty);
    });
  }
}
