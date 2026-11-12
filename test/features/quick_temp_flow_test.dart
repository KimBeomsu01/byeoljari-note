// 시연 3단계: 이서준 재측정 할 일 [완료하기] → 퀵 체온 → 38.4 → 0.5초 → 기록 완료 → 이상 대응 시트.
import 'package:byeoljari_note/app.dart';
import 'package:byeoljari_note/features/handover/entry_card.dart';
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

    expect(find.bySemanticsLabel('이상 대응 1'), findsOneWidget);
    expect(find.bySemanticsLabel('남은 할 일 3'), findsOneWidget);

    // 이서준 할 일의 [완료하기] (인수인계 기록 카드)
    final card = find.ancestor(of: find.text('이서준'), matching: find.byType(EntryCard));
    final done = find.descendant(of: card, matching: find.text('완료하기'));
    await tester.scrollUntilVisible(done, 200,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await tester.ensureVisible(done); // 하단 메뉴에 가리지 않게 위로
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();

    // 퀵 체온이 은하수자리·이서준으로 열림, 36.5에서 시작
    expect(find.descendant(of: find.byType(QuickTempScreen), matching: find.text('이서준')), findsOneWidget);
    expect(find.text('은하수자리 · 2 / 6'), findsOneWidget);
    expect(find.text('36.5'), findsOneWidget);

    // + 19번 → 38.4
    final plus = find.bySemanticsLabel('0.1도 올리기');
    for (var i = 0; i < 19; i++) {
      await tester.tap(plus);
    }
    await tester.pump();
    expect(find.text('38.4'), findsOneWidget);

    // 0.3초만 누르면 저장 안 됨
    final dial = find.text('눌러서 기록');
    var g = await tester.startGesture(tester.getCenter(dial));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pump();
    expect(find.text('체온 기록 완료'), findsNothing);

    // 0.5초 넘게 누르면 기록
    g = await tester.startGesture(tester.getCenter(dial));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(find.text('체온 기록 완료'), findsOneWidget);

    // 0.6초 뒤 이상 대응 시트
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('이상 대응'), findsWidgets);
    Finder inSheet(String t) => find.descendant(of: find.byType(BottomSheet), matching: find.text(t));
    expect(inSheet('38.4℃'), findsOneWidget);
    expect(inSheet('평소보다 1.3도 높아요'), findsOneWidget);
    expect(find.text('투약 지침 보기'), findsOneWidget);

    // 지침 보기 → 의료진 글 그대로
    await tester.tap(find.text('투약 지침 보기'));
    await tester.pumpAndSettle();
    expect(find.text('이서준 투약 지침'), findsOneWidget);
    // 하단 노란 버튼도 '닫기'라서, 지침 창 안의 '닫기'만 누른다.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('닫기')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30분 뒤 다시 재기'));
    await tester.pumpAndSettle();

    // 퀵 체온 접고 인수인계로
    await tester.tap(find.bySemanticsLabel('퀵 체온 접기'));
    await tester.pumpAndSettle();
    // 아까 아래로 내려 둔 목록을 맨 위로 (요약 카드)
    await tester.fling(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
        const Offset(0, 3000),
        3000);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('이상 대응 2'), findsOneWidget);
    expect(find.bySemanticsLabel('남은 할 일 2'), findsOneWidget);
  });

  testWidgets('권한 없는 반은 잠겨 있다 (김하늘은 은하수자리만)', (tester) async {
    tester.view.physicalSize = const Size(800, 1640);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
    await tester.tap(find.bySemanticsLabel('퀵 체온 열기'));
    await tester.pumpAndSettle();
    expect(find.text('김민준'), findsOneWidget, reason: '담당 반 첫 별님');
    final whale = find.descendant(of: find.byType(QuickTempScreen), matching: find.text('고래자리'));
    await tester.ensureVisible(whale);
    await tester.pumpAndSettle();
    await tester.tap(whale);
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
    expect(find.text('눌러서 기록'), findsOneWidget);
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
        expect(find.text('눌러서 기록'), findsOneWidget);
        // 기록 완료 상태도 넘치지 않는다
        final g = await tester.startGesture(tester.getCenter(find.text('눌러서 기록')));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pump();
        await g.up();
        await tester.pumpAndSettle();
        expect(find.text('체온 기록 완료'), findsOneWidget);
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
