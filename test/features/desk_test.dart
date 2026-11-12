// 사무국 PC 웹 (DESK) · 사무국PC 웹 기능명세 7장 완료 기준.
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:byeoljari_note/core/theme.dart';
import 'package:byeoljari_note/features/desk/desk_common.dart';
import 'package:byeoljari_note/features/desk/desk_resident.dart';
import 'package:byeoljari_note/features/desk/desk_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<InMemoryRepository> pumpDesk(WidgetTester tester, {Size size = const Size(1440, 900)}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: buildTheme(), home: const DeskShell())));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskShell))).read(repoProvider);
}

String textOf(WidgetTester tester, Finder f) {
  final w = tester.widget(f);
  if (w is Text) return w.data ?? w.textSpan!.toPlainText();
  return tester.widgetList<Text>(find.descendant(of: f, matching: find.byType(Text))).map((t) => t.data ?? '').join(' ');
}

Finder get residentScroll => find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;

Future<void> openMenu(WidgetTester tester, DeskMenu m) async {
  await tester.tap(find.byKey(ValueKey('desk-menu-${m.name}')));
  await tester.pumpAndSettle();
}

Future<void> pickResident(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const ValueKey('desk-res-search')), name);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('desk-res-${residentByName(name).id}')));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  // 위로 돌아간 뒤 아래로 찾는다 (타임라인은 최신순, 화면 밖 줄은 아직 안 그려져 있음).
  tester.state<ScrollableState>(residentScroll).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(f, 200, scrollable: residentScroll, maxScrolls: 80);
  await tester.pumpAndSettle();
}

void main() {
  final jiho = residentByName('한지호').id;
  final seojun = residentByName('이서준').id;

  testWidgets('① 오늘 두 번 잰 별님은 기록 있음 한 명, 타임라인 측정 두 줄', (tester) async {
    final repo = await pumpDesk(tester);
    final now = repo.now();
    final today = todayMeasurementsOf(repo, jiho, now);
    expect(today.length, 2); // 시연 시작 상태: 한지호 37.4 → 36.8

    final expected = repo.classes.expand((c) => repo.residentsOf(c.id)).where((r) => todayMeasurementsOf(repo, r.id, now).isNotEmpty).length;
    expect(textOf(tester, find.byKey(const ValueKey('desk-sum-recorded'))), contains('$expected명'));
    final mw = classStats(repo, now).firstWhere((s) => s.c.id == 'milkyway');
    final mwToday = repo.residentsOf('milkyway').where((r) => todayMeasurementsOf(repo, r.id, now).isNotEmpty).length;
    expect(mw.recorded, mwToday);
    expect(find.text('${mw.recorded} / ${mw.members}명'), findsOneWidget);
    expect(find.text('미기록'), findsNothing);

    // 별님 기록 → 한지호
    await openMenu(tester, DeskMenu.residents);
    await pickResident(tester, '한지호');
    for (final m in today) {
      await scrollTo(tester, find.byKey(ValueKey('desk-tl-m:${m.id}')));
      expect(find.byKey(ValueKey('desk-tl-m:${m.id}')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('② 어제 시작한 미종료 건이 오늘 현황·대응 현황에 보이고, 열어 봐도 상태가 그대로', (tester) async {
    final repo = await pumpDesk(tester);
    final jaehee = residentByName('노재희').id;
    final y = repo.now().subtract(const Duration(days: 1));
    final res = repo.saveMeasurement(residentId: jaehee, value: 384, by: 'choi_minho', at: DateTime(y.year, y.month, y.day, 18));
    final c = res.caseItem!;
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('desk-att-$jaehee')), findsOneWidget);
    final before = (repo.caseById(c.id).status, repo.eventsOf(c.id).length, repo.caseById(c.id).assigneeId, repo.noticesFor('park_seoyeon').length);

    // 오늘 현황의 상태 → 대응 현황에서 그 건이 선택됨
    await tester.ensureVisible(find.byKey(ValueKey('desk-att-case-${c.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('desk-att-case-${c.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('desk-case-${c.id}')), findsOneWidget);
    expect(textOf(tester, find.byKey(const ValueKey('desk-case-detail-title'))), contains('노재희'));
    expect(find.text('미지정'), findsWidgets);
    // 조회용: 확인·담당·종료 버튼 없음
    expect(find.text('확인했어요'), findsNothing);
    expect(find.text('제가 맡을게요'), findsNothing);
    expect(find.textContaining('대응 종료하기'), findsNothing);

    // 박승민 건도 눌러 보고 다시 돌아와도 상태 그대로
    final seungmin = repo.openCases.firstWhere((x) => x.residentId == residentByName('박승민').id);
    await tester.tap(find.byKey(ValueKey('desk-case-${seungmin.id}')));
    await tester.pumpAndSettle();
    await openMenu(tester, DeskMenu.today);
    final after = (repo.caseById(c.id).status, repo.eventsOf(c.id).length, repo.caseById(c.id).assigneeId, repo.noticesFor('park_seoyeon').length);
    expect(after, before);
    expect(repo.caseById(c.id).isOpen, isTrue);
  });

  testWidgets('③ 오늘 현황에서 이서준을 누르면 그 별님 기록, "소리" 검색에 2025년 박지은 기록 + 담임 변경선', (tester) async {
    await pumpDesk(tester);
    await tester.ensureVisible(find.byKey(ValueKey('desk-att-name-$seojun')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('desk-att-name-$seojun')));
    await tester.pumpAndSettle();
    expect(textOf(tester, find.byKey(const ValueKey('desk-resident-header'))), '이서준 별님');
    expect(find.textContaining('은하수자리 · 담임 이수진'), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('desk-tl-search')));
    await tester.enterText(find.byKey(const ValueKey('desk-tl-search')), '소리');
    await tester.pumpAndSettle();
    expect(textOf(tester, find.byKey(const ValueKey('desk-tl-count'))), contains('보이는 기록 3건'));
    await scrollTo(tester, find.byKey(const ValueKey('desk-tl-e:past-1')));
    expect(find.textContaining('담임 변경 · 2026년 3월 1일 · 박지은 선생님 → 이수진 선생님'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('desk-tl-e:past-1')), matching: find.textContaining('박지은 선생님')), findsOneWidget);
    expect(find.textContaining('2025년 9월 1일'), findsOneWidget); // 날짜 줄

    // 기록 열기 → 상세 패널, 닫아도 검색어·선택 유지
    await tester.tap(find.byKey(const ValueKey('desk-tl-e:past-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desk-panel-close')), findsOneWidget);
    expect(find.text('당시 기록자'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('desk-panel-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desk-panel-close')), findsNothing);
    expect(find.byKey(const ValueKey('desk-tl-e:past-1')), findsOneWidget);
    expect(textOf(tester, find.byKey(const ValueKey('desk-tl-count'))), contains('보이는 기록 3건'));
  });

  test('④ 반 공지와 이 별님 기록 필터는 겹치지 않는다', () {
    final repo = InMemoryRepository();
    final now = repo.now();
    final all = deskTimeline(repo, seojun, now: now).map((r) => r.key).toSet();
    final personal = deskTimeline(repo, seojun, kind: DeskKind.personal, now: now).map((r) => r.key).toSet();
    final notices = deskTimeline(repo, seojun, kind: DeskKind.classNotice, now: now).map((r) => r.key).toSet();
    expect(notices, isNotEmpty);
    expect(personal.intersection(notices), isEmpty);
    expect(personal.union(notices), all);
    // 반 공지는 원본 한 건 참조 (같은 은하수자리 별님끼리 같은 키)
    final other = deskTimeline(repo, residentByName('김민준').id, kind: DeskKind.classNotice, now: now).map((r) => r.key).toSet();
    expect(other, notices);
  });

  testWidgets('④ 화면: 반 공지 ↔ 이 별님 기록 전환, 검색어 지우면 원래 목록', (tester) async {
    final repo = await pumpDesk(tester);
    await openMenu(tester, DeskMenu.residents);
    await pickResident(tester, '이서준');
    await scrollTo(tester, find.byKey(const ValueKey('desk-tl-kind')));
    final original = textOf(tester, find.byKey(const ValueKey('desk-tl-count')));

    const notice = '오늘 목욕 순서가 바뀌었어요. 최도윤 별님이 먼저예요.';
    final noticeEntry = repo.entries.firstWhere((e) => e.body == notice);
    await tester.tap(find.text('반 공지').first);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('desk-tl-e:${noticeEntry.id}')), findsOneWidget);
    expect(find.textContaining('🌡 체온'), findsNothing);

    await tester.tap(find.text('이 별님 기록'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('desk-tl-e:${noticeEntry.id}')), findsNothing);
    expect(find.textContaining(notice), findsNothing);

    await tester.tap(find.text('모두'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('desk-tl-search')), '존재하지않는말');
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 기록이 없어요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('desk-tl-clear')));
    await tester.pumpAndSettle();
    expect(textOf(tester, find.byKey(const ValueKey('desk-tl-count'))), original);
  });

  testWidgets('⑤ 폰에서 이서준 39.1 저장 → 요약·표가 바로 바뀌고, 보던 상세는 그대로', (tester) async {
    final repo = await pumpDesk(tester);
    final openBefore = repo.openCases.length;
    expect(textOf(tester, find.byKey(const ValueKey('desk-sum-open'))), contains('$openBefore건'));

    // 대응 현황에서 박승민 건을 보고 있는 중
    final seungmin = repo.openCases.first;
    await openMenu(tester, DeskMenu.cases);
    await tester.tap(find.byKey(ValueKey('desk-case-${seungmin.id}')));
    await tester.pumpAndSettle();

    final res = repo.saveMeasurement(residentId: seojun, value: 391, by: 'lee_sujin', at: repo.now());
    await tester.pumpAndSettle();
    expect(res.caseItem!.isUrgent, isTrue);
    // 새 긴급 건이 맨 위에 생기고, 보던 상세는 그대로
    expect(find.byKey(ValueKey('desk-case-${res.caseItem!.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('desk-case-detail-${seungmin.id}')), findsOneWidget);
    expect(find.text('⚠ 긴급'), findsWidgets);

    await openMenu(tester, DeskMenu.today);
    expect(textOf(tester, find.byKey(const ValueKey('desk-sum-open'))), contains('${openBefore + 1}건'));
    final row = find.byKey(ValueKey('desk-att-$seojun'));
    expect(find.descendant(of: row, matching: find.text('39.1℃')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining('긴급')), findsWidgets);
  });

  testWidgets('최초 측정 보기 → 별님 기록에서 그 측정 상세가 열림', (tester) async {
    final repo = await pumpDesk(tester);
    final c = repo.openCases.first;
    await openMenu(tester, DeskMenu.cases);
    await tester.tap(find.byKey(ValueKey('desk-case-${c.id}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('desk-case-first')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desk-case-first')));
    await tester.pumpAndSettle();
    expect(textOf(tester, find.byKey(const ValueKey('desk-resident-header'))), '${repo.resident(c.residentId).name} 별님');
    expect(find.byKey(ValueKey('desk-panel-m:${c.firstMeasurementId}')), findsOneWidget);
  });

  testWidgets('무효 측정은 취소선 + 잘못 잰 값, 다시 잰 값 표시', (tester) async {
    final repo = await pumpDesk(tester);
    final m = repo.latestOf(jiho)!;
    repo.voidMeasurement(m.id, by: 'kim_haneul', at: repo.now());
    final again = repo.saveMeasurement(residentId: jiho, value: 366, by: 'kim_haneul', at: repo.now(), correctsId: m.id);
    await openMenu(tester, DeskMenu.residents);
    await pickResident(tester, '한지호');
    await scrollTo(tester, find.byKey(ValueKey('desk-tl-m:${m.id}')));
    expect(find.descendant(of: find.byKey(ValueKey('desk-tl-m:${m.id}')), matching: find.text('↩ 잘못 잰 값')), findsOneWidget);
    final t = tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('desk-tl-m:${m.id}')), matching: find.text('36.8℃')));
    expect(t.style!.decoration, TextDecoration.lineThrough);
    await scrollTo(tester, find.byKey(ValueKey('desk-tl-m:${again.measurement.id}')));
    expect(find.descendant(of: find.byKey(ValueKey('desk-tl-m:${again.measurement.id}')), matching: find.text('다시 잰 값')), findsOneWidget);
  });

  for (final size in const [Size(1024, 768), Size(1440, 900)]) {
    testWidgets('⑥ ${size.width.toInt()}×${size.height.toInt()} 모든 메뉴에서 넘침 없음', (tester) async {
      final repo = await pumpDesk(tester, size: size);
      expect(tester.takeException(), isNull);
      await openMenu(tester, DeskMenu.residents);
      await pickResident(tester, '이서준');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('표'));
      await tester.pumpAndSettle();
      final first = repo.measurementsOf(seojun).first;
      await scrollTo(tester, find.byKey(ValueKey('desk-tl-m:${first.id}')));
      await tester.tap(find.byKey(ValueKey('desk-tl-m:${first.id}')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openMenu(tester, DeskMenu.cases);
      await tester.tap(find.byKey(ValueKey('desk-case-${repo.openCases.first.id}')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openMenu(tester, DeskMenu.schedule);
      expect(find.textContaining('다음 단계'), findsOneWidget);
      await openMenu(tester, DeskMenu.export);
      expect(tester.takeException(), isNull);
    });
  }

  test('기저치 문구: 기록이 적으면 "기저치 계산 중 (기록 n/10)"', () {
    final repo = InMemoryRepository(withDemoState: false);
    final b = repo.baselineOf(seojun, DateTime(2027, 1, 1));
    expect(baselineText(b), '기저치 계산 중 (기록 0/10)');
    expect(tempText(null), '기록 없음');
    expect(Stage.values, isNotEmpty);
  });
}
