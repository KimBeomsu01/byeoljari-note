// 일정 SC-1·SC-2·SC-U 완료 기준 (일정 명세 12장, 통합 명세 6-5) + 클로드 디자인 개선 시안 '4 반별 일정'.
// 시연 시계: 2026-10-28 (수) 09:41. 기본 사용자 김하늘 = 은하수자리 배치.
import 'package:byeoljari_note/features/alert_case/case_detail_screen.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/seed.dart' as seed;
import 'package:byeoljari_note/core/theme.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_controller.dart';
import 'package:byeoljari_note/features/schedule/day_schedule_screen.dart';
import 'package:byeoljari_note/features/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _pump(WidgetTester tester, {Size size = const Size(390, 844), double textScale = 1}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(body: ScheduleScreen()),
    ),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ScheduleScreen)));
}

/// 목록의 별님 한 줄 (이름 Text를 품은 가장 가까운 InkWell).
Finder _row(String name) => find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

Finder get _priority => find.ancestor(of: find.textContaining('먼저 챙길 별님'), matching: find.byType(Container)).first;

Future<void> _openUpload(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('파일로 일정 올리기'), 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('파일로 일정 올리기'));
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

/// 줄의 이름 글자를 누른다 (오른쪽 이상 대응 칩은 따로 상세로 가므로 피한다).
Future<void> _tapRow(WidgetTester tester, String name) => _tapVisible(tester, find.text(name));

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byTooltip('뒤로'));
  await tester.pumpAndSettle();
}

Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
  await tester.pumpAndSettle();
}

/// Semantics 위젯의 label로 찾는다 (줄 전체가 하나로 합쳐 읽혀도 찾을 수 있게).
Finder _sem(Pattern p) => find.byWidgetPredicate((w) {
      final l = w is Semantics ? w.properties.label : null;
      if (l == null) return false;
      return p is String ? l == p : (p as RegExp).hasMatch(l);
    });

Finder get _classPill => _sem(RegExp('^반 고르기'));
Finder get _dateLine => _sem(RegExp('날짜 바꾸기|달력 접기'));

/// [● 반 ▾] 알약 → 반 고르기 시트에서 고른다.
Future<void> _tapClass(WidgetTester tester, String name) async {
  await _toTop(tester);
  await tester.tap(_classPill);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(name)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('머리: 작은 날짜 줄 위 큰 "일정", 오른쪽 반 알약. 한 줄 = 한 별님, 오른쪽 체온 칩', (tester) async {
    await _pump(tester);

    expect(find.text('일정'), findsOneWidget);
    expect(find.textContaining('오늘 10월 28일 수요일'), findsOneWidget);
    expect(find.descendant(of: _classPill, matching: find.text('은하수자리')), findsOneWidget);
    expect(_sem('반 고르기, 지금 은하수자리, 내 반'), findsOneWidget);
    expect(find.text('별님 6명 · 지금 09:41'), findsOneWidget);
    expect(find.text('오전 체온'), findsOneWidget);
    expect(find.text('오늘로'), findsNothing);
    for (final n in ['김민준', '이서준', '한지호', '류은호', '최도윤', '강시우']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('박승민'), findsNothing);

    // 체온 칩: 평소는 '✓ 36.8', 주의는 '! 37.6 주의', 안 잰 별님은 '아직 안 잼' (기호 + 글자)
    expect(find.descendant(of: _row('이서준'), matching: find.text('! 37.6 주의')), findsOneWidget);
    expect(find.descendant(of: _row('한지호'), matching: find.text('✓ 36.8')), findsOneWidget);
    expect(find.descendant(of: _row('최도윤'), matching: find.text('아직 안 잼')), findsOneWidget);
    expect(_sem('오전 체온 37.6도 주의'), findsOneWidget);

    // 두 번째 줄: 생활실에 있으면 다음 일정만, 통학 김민준은 '학교 · 다음'.
    expect(find.descendant(of: _row('최도윤'), matching: find.text('10:00 작업 치료')), findsOneWidget);
    expect(find.descendant(of: _row('김민준'), matching: find.textContaining('학교 · ')), findsOneWidget);

    // 한 열: 이름들이 위아래로
    expect(tester.getTopLeft(find.text('김민준')).dx, tester.getTopLeft(find.text('이서준')).dx);
    expect(tester.getTopLeft(find.text('김민준')).dy, lessThan(tester.getTopLeft(find.text('이서준')).dy));

    expect(find.text('▲ 이상 대응 중'), findsNothing);
    await tester.scrollUntilVisible(find.text('일정은 사무국에서 바꿔요'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('일정은 사무국에서 바꿔요'), findsOneWidget);
  });

  testWidgets('먼저 챙길 별님: 주의 재측정 · 미기록 별님만, [재기] → 그 별님 퀵 체온', (tester) async {
    final c = await _pump(tester);
    expect(find.text('먼저 챙길 별님 2'), findsOneWidget);
    expect(find.descendant(of: _priority, matching: find.text('이서준 · 09:45 다시 재기')), findsOneWidget);
    expect(find.descendant(of: _priority, matching: find.text('최도윤 · 오전 체온 아직')), findsOneWidget);
    // 순서: 주의 먼저, 미기록 다음
    expect(tester.getTopLeft(find.text('이서준 · 09:45 다시 재기')).dy,
        lessThan(tester.getTopLeft(find.text('최도윤 · 오전 체온 아직')).dy));

    final btn = _sem('최도윤 체온 재기');
    expect(tester.getSize(btn).height, greaterThanOrEqualTo(48));
    await tester.tap(btn);
    await tester.pumpAndSettle();
    final qt = c.read(quickTempProvider);
    expect(qt.open, isTrue);
    expect(qt.residentId, seed.residentByName('최도윤').id);
  });

  testWidgets('반을 바꾸면 그 반 별님으로, 열린 이상 건 별님은 "▲ 이상 대응 중" + 먼저 챙길 별님 맨 위', (tester) async {
    await _pump(tester);
    await _tapClass(tester, '고래자리');

    expect(find.text('이서준'), findsNothing);
    expect(find.text('박승민'), findsOneWidget);
    expect(find.descendant(of: _classPill, matching: find.text('고래자리')), findsOneWidget);
    expect(find.descendant(of: _row('박승민'), matching: find.text('▲ 이상 대응 중')), findsOneWidget);
    expect(find.textContaining('박승민 · 이상 대응 중'), findsOneWidget);
  });

  testWidgets('측정 권한이 없는 반의 [재기]는 안내만', (tester) async {
    final c = await _pump(tester);
    await _tapClass(tester, '고래자리');
    await tester.tap(_sem('박승민 체온 재기'));
    await tester.pump();
    expect(find.text('이 반은 체온 측정 권한이 없어요'), findsOneWidget);
    expect(c.read(quickTempProvider).open, isFalse);
  });

  testWidgets('위험이 나오면 칩이 "⚠ 긴급"으로 바뀌고 먼저 챙길 별님 맨 위 (저장소가 바뀌면 다시 그림)', (tester) async {
    final c = await _pump(tester);
    final repo = c.read(repoProvider);
    repo.saveMeasurement(residentId: seed.residentByName('최도윤').id, value: 391, by: 'kim_haneul', at: repo.now());
    await tester.pumpAndSettle();

    expect(find.descendant(of: _row('최도윤'), matching: find.text('⚠ 긴급')), findsOneWidget);
    final urgent = find.textContaining('최도윤 · 긴급');
    expect(urgent, findsOneWidget);
    expect(tester.getTopLeft(urgent).dy, lessThan(tester.getTopLeft(find.text('이서준 · 09:45 다시 재기')).dy));
  });

  testWidgets('날짜 줄을 누르면 달력, 토요일을 고르면 주말 안내와 일정 개수, 오늘로 돌아오기', (tester) async {
    await _pump(tester);
    await tester.tap(_dateLine);
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(_sem(RegExp('달력 접기')), findsOneWidget);

    await _tapVisible(tester, find.text('31'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsNothing); // 고르면 접힘
    await _toTop(tester);
    expect(find.textContaining('10월 31일 토요일'), findsOneWidget);
    expect(find.text('주말에는 식사와 여가 활동만 있어요'), findsOneWidget);
    expect(find.text('오늘로'), findsOneWidget);
    expect(find.text('일정 6개가 있어요'), findsWidgets);
    expect(find.textContaining('먼저 챙길 별님'), findsNothing); // 오늘만

    await _tapVisible(tester, find.text('오늘로'));
    await tester.pumpAndSettle();
    expect(find.textContaining('오늘 10월 28일 수요일'), findsOneWidget);
    expect(find.text('오늘로'), findsNothing);
  });

  testWidgets('지난 날은 "하루 일정이 끝났어요"', (tester) async {
    await _pump(tester);
    await tester.tap(_dateLine);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('27'));
    await tester.pumpAndSettle();
    expect(find.text('하루 일정이 끝났어요'), findsWidgets);
  });

  testWidgets('줄 → 하루 일정: 시간 순, 지금·지남, 체온 재기 버튼 → 퀵 체온 그 별님', (tester) async {
    final c = await _pump(tester);
    await _tapRow(tester, '최도윤');
    await tester.pumpAndSettle();

    expect(find.byType(DayScheduleScreen), findsOneWidget);
    expect(find.text('최도윤 별님의 하루'), findsOneWidget);
    expect(_sem('뒤로, 은하수자리'), findsOneWidget);
    expect(find.textContaining('일정 7개'), findsOneWidget);
    expect(find.text('지남'), findsNWidgets(2)); // 아침 식사, 건강 확인
    expect(find.text('오전 체온 재기'), findsOneWidget);
    expect(find.text('아직 안 잼'), findsWidgets);

    // 시간 순
    final breakfast = tester.getTopLeft(find.text('아침 식사')).dy;
    final therapy = tester.getTopLeft(find.text('작업 치료')).dy;
    expect(breakfast, lessThan(therapy));

    await _tapVisible(tester, find.text('오전 체온 재기'));
    await tester.pumpAndSettle();
    expect(find.byType(DayScheduleScreen), findsNothing); // 첫 화면으로 돌아옴
    final qt = c.read(quickTempProvider);
    expect(qt.open, isTrue);
    expect(qt.residentId, seed.residentByName('최도윤').id);
  });

  testWidgets('지금 진행 중인 일정은 "지금" 표시 (통학 별님 학교)', (tester) async {
    await _pump(tester);
    await _tapRow(tester, '김민준');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('지금'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('지금'), findsOneWidget);
    expect(find.text('학교'), findsWidgets);
  });

  testWidgets('측정 권한이 없는 반의 하루 일정 체온 재기 버튼은 안내만', (tester) async {
    final c = await _pump(tester);
    await _tapClass(tester, '고래자리');
    await _tapRow(tester, '서연우');
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.textContaining('체온 재기').first);
    await tester.pump();
    expect(find.text('이 반은 체온 측정 권한이 없어요'), findsOneWidget);
    expect(find.byType(DayScheduleScreen), findsOneWidget);
    expect(c.read(quickTempProvider).open, isFalse);
  });

  testWidgets('파일로 일정 올리기: 올리기 → 표 확인 → 반영 (시연 안내, 일정은 그대로)', (tester) async {
    final c = await _pump(tester);
    final before = c.read(repoProvider).scheduleOf(seed.residentByName('이서준').id, DateTime(2026, 10, 29)).length;

    await _openUpload(tester);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('파일 고르기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('일정 5개를 표로 정리했어요'), findsOneWidget);
    expect(find.text('작업 치료'), findsOneWidget);

    await tester.tap(find.text('다시 올리기'));
    await tester.pumpAndSettle();
    expect(find.text('파일 고르기'), findsOneWidget);
    await _tapVisible(tester, find.text('파일 고르기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('일정에 반영 (시연)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일정에 반영 (시연)'));
    await tester.pumpAndSettle();
    expect(find.text('시연용 예시라 실제 일정은 바뀌지 않아요'), findsOneWidget);
    expect(c.read(repoProvider).scheduleOf(seed.residentByName('이서준').id, DateTime(2026, 10, 29)).length, before);
  });

  testWidgets('작은 폰(360×640)에서 넘치지 않는다', (tester) async {
    await _pump(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    await _openUpload(tester);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('파일 고르기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await _tapClass(tester, '고래자리');
    expect(tester.takeException(), isNull);
    await _tapRow(tester, '박승민');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('이상 대응 중 칩 탭 영역은 48 이상, 누르면 이상 건 상세(S3)', (tester) async {
    await _pump(tester);
    await _tapClass(tester, '고래자리');
    final chip = find.ancestor(of: find.text('▲ 이상 대응 중'), matching: find.byType(InkWell)).first;
    final size = tester.getSize(chip);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));

    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byType(CaseDetailScreen), findsOneWidget);
    expect(find.byType(DayScheduleScreen), findsNothing);
  });

  for (final (label, size) in [
    ('390×844', const Size(390, 844)),
    ('360×640', const Size(360, 640)),
    ('320×640', const Size(320, 640)),
  ]) {
    testWidgets('$label + 큰 글자(1.3배)에서도 넘치지 않는다 (SC-1, SC-2, SC-U)', (tester) async {
      await _pump(tester, size: size, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(_dateLine);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, find.text('31'));
      await tester.pumpAndSettle();
      await _toTop(tester);
      expect(find.text('오늘로'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, find.text('오늘로'));
      await tester.pumpAndSettle();

      await _tapClass(tester, '고래자리');
      expect(tester.takeException(), isNull);
      await _tapRow(tester, '박승민');
      await tester.pumpAndSettle();
      expect(find.byType(DayScheduleScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _back(tester);

      await _tapClass(tester, '은하수자리');
      await _tapRow(tester, '김민준');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _back(tester);

      await _openUpload(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, find.text('파일 고르기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('누르는 것은 모두 48 이상: 반 알약, 날짜 줄, 별님 줄, 하루 일정 뒤로·체온 재기 버튼', (tester) async {
    await _pump(tester);
    expect(tester.getSize(_classPill).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(_dateLine).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(_row('최도윤')).height, greaterThanOrEqualTo(48));
    await _tapRow(tester, '최도윤');
    await tester.pumpAndSettle();
    final btn = find.ancestor(of: find.text('오전 체온 재기'), matching: find.byType(FilledButton));
    expect(tester.getSize(btn).height, greaterThanOrEqualTo(48));
    final back = find.ancestor(of: find.text('은하수자리'), matching: find.byType(InkWell)).first;
    expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
  });

  testWidgets('360×640: 별님 목록은 한 열, 화면 여백 20 안', (tester) async {
    const size = Size(360, 640);
    await _pump(tester, size: size);
    final a = tester.getRect(_row('김민준'));
    final b = tester.getRect(_row('이서준'));
    expect(a.left, b.left);
    expect(a.bottom, lessThanOrEqualTo(b.top + 1));
    expect(a.right, lessThanOrEqualTo(size.width - 20 + 0.5));
  });
}
