// 일정 SC-1·SC-2·SC-U 완료 기준 (일정 명세 12장, 통합 명세 6-5).
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

Finder _card(String name) => find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

Future<void> _openUpload(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('파일로 일정 올리기'), 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('파일로 일정 올리기'));
}

Future<void> _tapCard(WidgetTester tester, String name) async {
  await tester.ensureVisible(_card(name));
  await tester.pumpAndSettle();
  await tester.tap(_card(name));
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
  await tester.pumpAndSettle();
}

Future<void> _tapClass(WidgetTester tester, String name) async {
  // 아래로 내려가 있으면 반 칩이 화면 밖에서 사라졌을 수 있다. 맨 위로 올린다.
  await _toTop(tester);
  await tester.ensureVisible(find.text(name));
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('처음엔 내 반(은하수자리)·오늘, 카드에 지금·다음과 오전·오후 체온 상태', (tester) async {
    await _pump(tester);

    expect(find.text('내 반'), findsOneWidget);
    expect(find.text('10월 28일 (수)'), findsOneWidget);
    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('오늘로'), findsNothing);
    for (final n in ['김민준', '이서준', '한지호', '류은호', '최도윤', '강시우']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('박승민'), findsNothing);

    // 이서준 09:15 37.6 주의 (기호 + 글자)
    final seojun = _card('이서준');
    expect(find.descendant(of: seojun, matching: find.text('37.6℃')), findsOneWidget);
    expect(find.descendant(of: seojun, matching: find.text('! 주의')), findsOneWidget);
    // 한지호: 같은 시점 최신 = 09:41 36.8 평소
    expect(find.descendant(of: _card('한지호'), matching: find.text('36.8℃')), findsOneWidget);
    // 최도윤: 09:00 시점 지남, 기록 없음 → 미기록 + 측정 전
    final doyoon = _card('최도윤');
    expect(find.descendant(of: doyoon, matching: find.text('미기록')), findsOneWidget);
    expect(find.descendant(of: doyoon, matching: find.text('아직 안 쟀어요')), findsOneWidget);
    // 오후는 아직 예정
    expect(find.descendant(of: doyoon, matching: find.text('예정 13:00')), findsOneWidget);

    // 09:41: 일반 별님은 지금 생활실, 다음 10:00 작업 치료. 통학 김민준은 지금 학교.
    expect(find.descendant(of: doyoon, matching: find.textContaining('은하수자리 생활실')), findsOneWidget);
    expect(find.descendant(of: doyoon, matching: find.textContaining('10:00 작업 치료')), findsOneWidget);
    expect(find.descendant(of: _card('김민준'), matching: find.text('학교 (08:40~14:30)')), findsOneWidget);

    expect(find.text('이상 대응 중'), findsNothing);
    await tester.scrollUntilVisible(find.text('일정은 사무국에서 바꿔요'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('일정은 사무국에서 바꿔요'), findsOneWidget);
  });

  testWidgets('반을 바꾸면 그 반 별님으로 바뀌고, 열린 이상 건 별님만 "이상 대응 중"', (tester) async {
    await _pump(tester);
    await _tapClass(tester, '고래자리');

    expect(find.text('이서준'), findsNothing);
    expect(find.text('박승민'), findsOneWidget);
    expect(find.text('이상 대응 중'), findsOneWidget);
    final seungmin = _card('박승민');
    expect(find.descendant(of: seungmin, matching: find.text('38.2℃')), findsOneWidget);
    expect(find.descendant(of: seungmin, matching: find.text('▲ 이상')), findsOneWidget);
  });

  testWidgets('위험이 나오면 배지가 "긴급"으로 바뀐다 (저장소가 바뀌면 다시 그림)', (tester) async {
    final c = await _pump(tester);
    final repo = c.read(repoProvider);
    repo.saveMeasurement(
        residentId: seed.residentByName('이서준').id, value: 391, by: 'kim_haneul', at: repo.now());
    await tester.pumpAndSettle();

    expect(find.text('긴급'), findsOneWidget);
    expect(find.descendant(of: _card('이서준'), matching: find.text('39.1℃')), findsOneWidget);
  });

  testWidgets('날짜 바꾸기로 다른 날(토요일)을 고르면 주말 안내와 일정 개수, 오늘로 돌아오기', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('날짜 바꾸기'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);

    await _tapVisible(tester, find.text('31'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsNothing); // 고르면 접힘
    await _toTop(tester);
    expect(find.text('10월 31일 (토)'), findsOneWidget);
    expect(find.text('주말에는 식사와 여가 활동만 있어요'), findsOneWidget);
    expect(find.text('오늘로'), findsOneWidget);
    expect(find.text('일정 6개가 있어요'), findsWidgets);

    await _tapVisible(tester, find.text('오늘로'));
    await tester.pumpAndSettle();
    expect(find.text('10월 28일 (수)'), findsOneWidget);
    expect(find.text('오늘로'), findsNothing);
  });

  testWidgets('지난 날은 "하루 일정이 끝났어요"', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('날짜 바꾸기'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('27'));
    await tester.pumpAndSettle();
    expect(find.text('하루 일정이 끝났어요'), findsWidgets);
  });

  testWidgets('카드 → 하루 일정: 시간 순, 지금·지남, 체온 재기 버튼 → 퀵 체온 그 별님', (tester) async {
    final c = await _pump(tester);
    await _tapCard(tester, '최도윤');
    await tester.pumpAndSettle();

    expect(find.byType(DayScheduleScreen), findsOneWidget);
    expect(find.text('하루 일정'), findsOneWidget);
    expect(find.textContaining('일정 7개'), findsOneWidget);
    expect(find.text('지남'), findsNWidgets(2)); // 아침 식사, 건강 확인
    expect(find.text('체온 재기 · 오전 체온'), findsOneWidget);

    // 시간 순
    final breakfast = tester.getTopLeft(find.text('아침 식사')).dy;
    final therapy = tester.getTopLeft(find.text('작업 치료')).dy;
    expect(breakfast, lessThan(therapy));

    await _tapVisible(tester, find.text('체온 재기 · 오전 체온'));
    await tester.pumpAndSettle();
    expect(find.byType(DayScheduleScreen), findsNothing); // 첫 화면으로 돌아옴
    final qt = c.read(quickTempProvider);
    expect(qt.open, isTrue);
    expect(qt.residentId, seed.residentByName('최도윤').id);
  });

  testWidgets('지금 진행 중인 일정은 "지금" 표시 (통학 별님 학교)', (tester) async {
    await _pump(tester);
    await _tapCard(tester, '김민준');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('지금'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('지금'), findsOneWidget);
    expect(find.text('학교'), findsWidgets);
  });

  testWidgets('측정 권한이 없는 반의 체온 재기 버튼은 안내만', (tester) async {
    final c = await _pump(tester);
    await _tapClass(tester, '고래자리');
    await _tapCard(tester, '서연우');
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.textContaining('체온 재기 ·').first);
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
    expect(find.text('일정 5건을 찾았어요'), findsOneWidget);
    expect(find.text('작업 치료'), findsOneWidget);

    await tester.tap(find.text('다른 파일 고르기'));
    await tester.pumpAndSettle();
    expect(find.text('파일 고르기'), findsOneWidget);
    await _tapVisible(tester, find.text('파일 고르기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('일정에 반영하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일정에 반영하기'));
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
    await _tapClass(tester, '고래자리'); // 이상 대응 중 배지가 있는 카드
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(_card('박승민'));
    await tester.pumpAndSettle();

    await _tapCard(tester, '박승민');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('배지 탭 영역은 48 이상, 누르면 이상 건 상세(S3)', (tester) async {
    await _pump(tester);
    await _tapClass(tester, '고래자리');
    final badge = find.ancestor(of: find.text('이상 대응 중'), matching: find.byType(InkWell)).first;
    final size = tester.getSize(badge);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));

    await tester.ensureVisible(badge);
    await tester.pumpAndSettle();
    await tester.tap(badge);
    await tester.pumpAndSettle();
    expect(find.byType(CaseDetailScreen), findsOneWidget);
    expect(find.byType(DayScheduleScreen), findsNothing);
  });

  for (final (label, size) in [('390×844', const Size(390, 844)), ('360×640', const Size(360, 640))]) {
    testWidgets('$label + 큰 글자(1.3배)에서도 넘치지 않는다 (SC-1, SC-2, SC-U)', (tester) async {
      await _pump(tester, size: size, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('날짜 바꾸기'));
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
      await tester.ensureVisible(_card('박승민'));
      await tester.pumpAndSettle();
      await _tapCard(tester, '박승민');
      await tester.pumpAndSettle();
      expect(find.byType(DayScheduleScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tapClass(tester, '은하수자리');
      await tester.ensureVisible(_card('김민준'));
      await tester.pumpAndSettle();
      await _tapCard(tester, '김민준');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _openUpload(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, find.text('파일 고르기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('누르는 것은 모두 크다: 반 칩 56, 날짜 바꾸기 56, 카드 체온 재기 버튼 56', (tester) async {
    await _pump(tester);
    final chip = find.ancestor(of: find.text('고래자리'), matching: find.byType(InkWell)).first;
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(56));
    expect(tester.getSize(find.ancestor(of: find.text('날짜 바꾸기'), matching: find.byType(OutlinedButton))).height,
        greaterThanOrEqualTo(56));
    await _tapCard(tester, '최도윤');
    await tester.pumpAndSettle();
    final btn = find.ancestor(of: find.text('체온 재기 · 오전 체온'), matching: find.byType(OutlinedButton));
    expect(tester.getSize(btn).height, greaterThanOrEqualTo(56));
  });
}
