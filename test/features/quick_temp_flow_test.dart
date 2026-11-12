// 시연 3단계: 이서준 재측정 할 일 [완료하기] → 퀵 체온 → 38.4 → 0.5초 → 기록 완료 → 이상 대응 시트.
import 'package:byeoljari_note/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('할 일에서 퀵 체온을 열고 0.5초 눌러 기록하면 이상 대응이 생긴다', (tester) async {
    tester.view.physicalSize = const Size(400 * 2, 820 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
    await tester.pumpAndSettle();

    expect(find.text('긴급 0 · 이상 대응 1 · 남은 할 일 3'), findsOneWidget);

    // 이서준 할 일의 [완료하기]
    final seojunTask = find.ancestor(of: find.text('이서준 · 재측정'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: seojunTask, matching: find.text('완료하기')));
    await tester.pumpAndSettle();

    // 퀵 체온이 은하수자리·이서준으로 열림, 36.5에서 시작
    expect(find.text('이서준'), findsOneWidget);
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
    expect(find.text('38.4℃ · 평소보다 +1.3℃ · 이상'), findsOneWidget);
    expect(find.text('투약 지침 보기'), findsOneWidget);

    // 지침 보기 → 의료진 글 그대로
    await tester.tap(find.text('투약 지침 보기'));
    await tester.pumpAndSettle();
    expect(find.text('이서준 투약 지침'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30분 뒤 다시 재기'));
    await tester.pumpAndSettle();

    // 퀵 체온 접고 인수인계로
    await tester.tap(find.bySemanticsLabel('퀵 체온 접기'));
    await tester.pumpAndSettle();
    expect(find.text('긴급 0 · 이상 대응 2 · 남은 할 일 2'), findsOneWidget);
  });

  testWidgets('권한 없는 반은 잠겨 있다 (김하늘은 은하수자리만)', (tester) async {
    tester.view.physicalSize = const Size(800, 1640);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
    await tester.tap(find.bySemanticsLabel('퀵 체온 열기'));
    await tester.pumpAndSettle();
    expect(find.text('김민준'), findsOneWidget, reason: '담당 반 첫 별님');
    await tester.ensureVisible(find.text('고래자리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고래자리'));
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
}
