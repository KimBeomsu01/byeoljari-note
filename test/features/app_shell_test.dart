import 'package:byeoljari_note/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (w, h) in [(390.0, 844.0), (360.0, 640.0)]) {
    testWidgets('하단 메뉴가 ${w.toInt()}×${h.toInt()} 큰 글자(1.3배)에서도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = Size(w * 2, h * 2);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('퀵 체온 열기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
