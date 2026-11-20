// 01 인수인계 (Claude Design Main.dc.html) 화면 흐름.
// 시연 DB: 긴급 카드 · 요약/칩 숫자 · [확인했어요] · 필터 · 기록하기 · 서명.
// 개발 DB: 자리마다 예시 카드 → 실제 기록이 생기면 그 자리 예시가 사라진다.
import 'package:byeoljari_note/app.dart';
import 'package:byeoljari_note/core/ds.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart' as seed;
import 'package:byeoljari_note/core/theme.dart';
import 'package:byeoljari_note/features/handover/handover_cards.dart';
import 'package:byeoljari_note/features/handover/handover_screen.dart';
import 'package:byeoljari_note/features/handover/shift_sheet.dart';
import 'package:byeoljari_note/features/handover/write_sheet.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_controller.dart';
import 'package:byeoljari_note/core/photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final clock = DateTime(2026, 10, 28, 14, 0);
const me = 'kim_haneul'; // 은하수자리 배치 → 인수인계에 은하수자리만
const nurse = 'park_soyeon'; // 수석간호사 → 전체 반
String rid(String name) => seed.residentByName(name).id;

final vList = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

class Harness {
  Harness(this.repo, this.container);
  final InMemoryRepository repo;
  final ProviderContainer container;
}

Future<Harness> pumpHandover(
  WidgetTester tester, {
  Dataset dataset = Dataset.demo,
  Size size = const Size(390, 844),
  String? user,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = InMemoryRepository(dataset: dataset, clock: () => clock);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repoProvider.overrideWith((_) => repo),
      screenKindProvider.overrideWithValue('mobile'),
      if (user != null) currentUserProvider.overrideWith((_) => user),
    ],
    child: MaterialApp(theme: buildTheme(), home: const Scaffold(body: HandoverScreen())),
  ));
  await tester.pumpAndSettle();
  return Harness(repo, ProviderScope.containerOf(tester.element(find.byType(HandoverScreen))));
}

final hList = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);

double viewHeight(WidgetTester tester) => tester.view.physicalSize.height / tester.view.devicePixelRatio;
double viewWidth(WidgetTester tester) => tester.view.physicalSize.width / tester.view.devicePixelRatio;

/// [f]가 보이도록 내린다. 머리(56)는 목록 위에 겹쳐 있으므로 머리 아래로 오게 맞춘다.
Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: vList);
  await tester.pumpAndSettle();
  final top = tester.getRect(f.first).top;
  if (top < 120) {
    await tester.drag(vList, Offset(0, 160 - top));
    await tester.pumpAndSettle();
  }
}

Future<void> toTop(WidgetTester tester) async {
  await tester.drag(vList, const Offset(0, 8000));
  await tester.pumpAndSettle();
}

/// 토스트가 사라질 때까지 (타이머가 남지 않게).
Future<void> waitToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Finder caseCard(String name) => find.ancestor(of: find.text(name), matching: find.byType(UrgentVitalCard));

int? chipCount(WidgetTester tester, String label) => tester.widget<DsChip>(find.widgetWithText(DsChip, label)).count;

/// 필터 칩 누르기. 칩 줄은 가로로 밀리므로 화면 밖이면 먼저 민다.
Future<void> pickFilter(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(DsChip, label);
  final x = tester.getCenter(chip).dx;
  final w = viewWidth(tester);
  if (x > w - 24 || x < 24) {
    await tester.drag(hList, Offset(w / 2 - x, 0));
    await tester.pumpAndSettle();
  }
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  group('시연 DB', () {
    testWidgets('머리 · 근무조 요약 · 박승민 긴급 카드', (tester) async {
      final h = await pumpHandover(tester, user: nurse);
      expect(find.byType(MobileAppBar), findsOneWidget);
      expect(find.text('오후 근무조 인계'), findsOneWidget, reason: '간호사는 근무조 밖 → 지금 시각(14:00) 근무조');
      expect(find.textContaining('14:00 기준'), findsOneWidget);
      expect(find.textContaining('6개 반 36명'), findsOneWidget);

      final card = caseCard('박승민');
      expect(card, findsOneWidget);
      // 수석간호사는 박승민 건을 이미 확인했다 (시연 자료)
      for (final t in ['고래자리', '38.2°C', '+1.4°C 급상승', '09:51 재측정 예정', '4시간 9분 지남', '확인함', '재측정하기']) {
        expect(find.descendant(of: card, matching: find.text(t)), findsOneWidget, reason: t);
      }
      // 열린 이상 건마다 카드 하나 (긴급 먼저)
      expect(find.byType(UrgentVitalCard), findsNWidgets(h.repo.openCases.length));
      expect(caseCard('이서준'), findsOneWidget);
    });

    testWidgets('요약 숫자 = 필터 칩 숫자 = 저장소', (tester) async {
      final h = await pumpHandover(tester, user: nurse);
      final s = tester.widget<ShiftSummaryCard>(find.byType(ShiftSummaryCard));
      final openTasks = h.repo.entries.where((e) => e.task != null && !e.task!.done).length;
      expect(s.urgent, h.repo.openCases.length);
      expect(s.urgent, 2);
      expect(s.todo, openTasks);
      expect(s.missed, h.repo.missedTempResidents(clock).length);
      expect(s.missed, greaterThan(0));
      expect(s.unread, greaterThan(0));

      expect(chipCount(tester, '할 일'), s.todo);
      expect(chipCount(tester, '미확인'), s.unread);
      expect(chipCount(tester, '모두'), greaterThanOrEqualTo(s.urgent + s.todo));
      expect(chipCount(tester, '공지사항'), isNull);
      expect(chipCount(tester, '별님 기록'), isNull);

      // 카드를 누르면 확인 → 미확인이 하나 준다
      final notice = find.text('오늘 10:00 목욕실 온수 보일러 점검 안내');
      await reveal(tester, notice);
      await tester.tap(notice);
      await tester.pumpAndSettle();
      await toTop(tester);
      expect(tester.widget<ShiftSummaryCard>(find.byType(ShiftSummaryCard)).unread, s.unread - 1);
      expect(chipCount(tester, '미확인'), s.unread - 1);
    });

    testWidgets('[확인했어요] → 확인함, [재측정하기] → 퀵 체온', (tester) async {
      final h = await pumpHandover(tester, user: 'choi_minho'); // 고래자리 배치
      final caseId = h.repo.openCaseOf(rid('박승민'))!.id;
      expect(h.repo.isAcknowledged(caseId, 'choi_minho'), isFalse);

      final ack = find.descendant(of: caseCard('박승민'), matching: find.text('확인했어요'));
      await reveal(tester, ack);
      await tester.tap(ack);
      await tester.pump();
      expect(h.repo.isAcknowledged(caseId, 'choi_minho'), isTrue);
      expect(find.text('확인했다고 알렸어요'), findsOneWidget);
      await waitToast(tester);
      expect(find.descendant(of: caseCard('박승민'), matching: find.text('확인함')), findsOneWidget);
      expect(find.descendant(of: caseCard('박승민'), matching: find.text('확인했어요')), findsNothing);

      await tester.tap(find.descendant(of: caseCard('박승민'), matching: find.text('재측정하기')));
      await tester.pumpAndSettle();
      final qt = h.container.read(quickTempProvider);
      expect(qt.open, isTrue);
      expect(qt.residentId, rid('박승민'));
    });

    testWidgets('필터 칩이 아래 목록을 거른다', (tester) async {
      await pumpHandover(tester, size: const Size(390, 3000), user: nurse);
      expect(find.byType(UrgentVitalCard), findsNWidgets(2));
      expect(find.byType(TodoRow), findsOneWidget);
      expect(find.byType(ObservationFeedCard), findsWidgets);

      await pickFilter(tester, '공지사항');
      expect(find.byType(UrgentVitalCard), findsNothing);
      expect(find.byType(TodoRow), findsNothing);
      expect(find.byType(ObservationFeedCard), findsNothing);
      expect(find.byType(VitalFeedCard), findsNothing);
      expect(find.text('오늘 10:00 목욕실 온수 보일러 점검 안내'), findsOneWidget);
      expect(find.byType(NoticeClassFeedCard), findsNWidgets(2));
      expect(find.text('박지은 담임'), findsWidgets);

      await pickFilter(tester, '할 일');
      expect(find.byType(TodoRow), findsOneWidget);
      expect(find.descendant(of: find.byType(TodoRow), matching: find.text('정현우')), findsOneWidget);
      expect(find.byType(NoticeAllFeedCard), findsNothing);
      expect(find.byType(ObservationFeedCard), findsNothing);

      await pickFilter(tester, '별님 기록');
      expect(find.byType(NoticeAllFeedCard), findsNothing);
      expect(find.byType(NoticeClassFeedCard), findsNothing);
      expect(find.byType(ObservationFeedCard), findsWidgets);
      expect(find.byType(VitalFeedCard), findsWidgets);
      expect(find.text('한나리'), findsOneWidget);

      await pickFilter(tester, '미확인');
      final unread = chipCount(tester, '미확인')!;
      final shown = find.byType(TodoRow).evaluate().length +
          find.byType(VitalFeedCard).evaluate().length +
          find.byType(NoticeAllFeedCard).evaluate().length +
          find.byType(NoticeClassFeedCard).evaluate().length +
          find.byType(ObservationFeedCard).evaluate().length;
      expect(shown, unread);
      expect(find.byType(UrgentVitalCard), findsNothing);

      await pickFilter(tester, '모두');
      expect(find.byType(UrgentVitalCard), findsNWidgets(2));
    });

    testWidgets('할 일 [완료] (체온 할 일) → 그 별님으로 퀵 체온', (tester) async {
      final h = await pumpHandover(tester, user: nurse);
      final done = find.descendant(of: find.byType(TodoRow), matching: find.text('완료'));
      await reveal(tester, done);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(h.container.read(quickTempProvider).open, isTrue);
      expect(h.container.read(quickTempProvider).residentId, rid('정현우'));
    });

    testWidgets('메모 할 일 [완료] → completeTask', (tester) async {
      final repo = InMemoryRepository(dataset: Dataset.demo, clock: () => clock);
      final e = repo.addEntry(Entry(
        id: '',
        scope: EntryScope.classScope,
        authorId: 'park_jieun',
        kindLabel: '반 공지',
        createdAt: clock.subtract(const Duration(minutes: 5)),
        classId: 'milkyway',
        body: '저녁 전에 이불 바꿔 주세요',
        task: const Task(id: '', label: '이불 바꾸기', kind: TaskKind.memo, dueAt: null),
      ));
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [repoProvider.overrideWith((_) => repo), screenKindProvider.overrideWithValue('mobile')],
        child: MaterialApp(theme: buildTheme(), home: const Scaffold(body: HandoverScreen())),
      ));
      await tester.pumpAndSettle();
      final row = find.ancestor(of: find.text('저녁 전에 이불 바꿔 주세요'), matching: find.byType(TodoRow));
      expect(row, findsOneWidget);
      await tester.tap(find.descendant(of: row, matching: find.text('완료')));
      await tester.pump();
      expect(repo.entry(e.id).task!.done, isTrue);
      await waitToast(tester);
      expect(find.text('저녁 전에 이불 바꿔 주세요'), findsOneWidget, reason: '완료한 기록은 최신 기록으로 내려간다');
      expect(row, findsNothing);
    });

    testWidgets('관찰 기록 좋아요 · 이름 → 별님카드', (tester) async {
      final h = await pumpHandover(tester, user: nurse);
      final nari = h.repo.entries.firstWhere((e) => e.residentId == rid('한나리') && e.createdAt.day == clock.day);
      expect(h.repo.likesOf(nari.id).length, 2);
      final card = find.ancestor(of: find.text('한나리'), matching: find.byType(ObservationFeedCard));
      await reveal(tester, card);
      await tester.tap(find.descendant(of: card, matching: find.text('2명')));
      await tester.pumpAndSettle();
      expect(h.repo.likesOf(nari.id), contains(nurse));
      expect(find.descendant(of: card, matching: find.text('3명')), findsOneWidget);

      await tester.tap(find.descendant(of: card, matching: find.text('한나리')));
      await tester.pumpAndSettle();
      expect(h.container.read(mobileTabProvider), 1);
      expect(h.container.read(residentCardTargetProvider), rid('한나리'));
      expect(h.repo.isRead(nari.id, nurse), isTrue);
    });

    testWidgets('기록하기 → 별님 기록 저장 → 최신 기록 맨 위', (tester) async {
      final h = await pumpHandover(tester);
      final before = h.repo.entries.length;
      await tester.tap(find.text('기록하기'));
      await tester.pumpAndSettle();
      expect(find.byType(WriteSheet), findsOneWidget);

      // 대상을 안 고르면 저장되지 않는다
      await tester.enterText(find.byType(TextField), '오늘 산책을 즐겁게 했어요.');
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      expect(find.text('어떤 별님의 기록인지 골라 주세요'), findsOneWidget);
      expect(h.repo.entries.length, before);

      await tester.tap(find.descendant(of: find.byType(WriteSheet), matching: find.text('김민준')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장하기'));
      await tester.pump();
      expect(h.repo.entries.length, before + 1);
      final saved = h.repo.entries.firstWhere((e) => e.body == '오늘 산책을 즐겁게 했어요.');
      expect(saved.scope, EntryScope.resident);
      expect(saved.residentId, rid('김민준'));
      expect(saved.authorId, me);
      await waitToast(tester);
      expect(find.byType(WriteSheet), findsNothing);

      final card = find.ancestor(of: find.text('"오늘 산책을 즐겁게 했어요."'), matching: find.byType(ObservationFeedCard));
      await reveal(tester, card);
      expect(card, findsOneWidget);
      // 최신 기록의 첫 카드
      final firstFeed = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('feed-')).first;
      expect(tester.widget(firstFeed).key, ValueKey('feed-${saved.id}'));
    });

    testWidgets('기록하기 → 반 공지 저장', (tester) async {
      final h = await pumpHandover(tester);
      await tester.tap(find.text('기록하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(WriteSheet), matching: find.text('반 공지')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '은하수자리 저녁 목욕은 18:00에 해요.');
      await tester.tap(find.text('저장하기'));
      await tester.pump();
      final saved = h.repo.entries.firstWhere((e) => e.body == '은하수자리 저녁 목욕은 18:00에 해요.');
      expect(saved.scope, EntryScope.classScope);
      expect(saved.classId, 'milkyway');
      await waitToast(tester);
      await pickFilter(tester, '공지사항');
      expect(find.ancestor(of: find.textContaining('저녁 목욕은 18:00에'), matching: find.byType(NoticeClassFeedCard)), findsOneWidget);
    });

    testWidgets('근무조 요약 시트 → 서명', (tester) async {
      final h = await pumpHandover(tester, user: 'choi_minho');
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(ShiftSheet), findsOneWidget);
      final sheet = find.byType(ShiftSheet);
      expect(find.descendant(of: sheet, matching: find.text('오전 근무조 인계')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('근무조 4명')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.textContaining('최민호')), findsOneWidget);

      final shift = h.repo.shiftAt(clock, staffId: 'choi_minho')!;
      expect(h.repo.hasSigned(shift.id, 'choi_minho'), isFalse);
      await tester.tap(find.text('인계 확인 서명'));
      await tester.pump();
      expect(h.repo.hasSigned(shift.id, 'choi_minho'), isTrue);
      await waitToast(tester);
      expect(find.text('서명했어요 · 14:00'), findsOneWidget);
    });
  });

  group('개발 DB', () {
    testWidgets('빈 자리마다 예시 카드 → 기록 하나 저장하면 그 자리 예시가 사라진다', (tester) async {
      final h = await pumpHandover(tester, dataset: Dataset.dev, size: const Size(390, 2000));
      expect(h.repo.isDev, isTrue);
      expect(find.byType(ExampleWrap), findsNWidgets(3));
      expect(find.descendant(of: find.byType(ExampleWrap), matching: find.byType(UrgentVitalCard)), findsOneWidget);
      expect(find.descendant(of: find.byType(ExampleWrap), matching: find.byType(TodoRow)), findsOneWidget);
      expect(find.descendant(of: find.byType(ExampleWrap), matching: find.byType(ObservationFeedCard)), findsOneWidget);
      expect(find.text('최신 기록'), findsOneWidget);
      // 예시를 뺀 실제 숫자는 0 (체온 미기록은 예시 별님 일정으로 계산)
      final s = tester.widget<ShiftSummaryCard>(find.byType(ShiftSummaryCard));
      expect([s.urgent, s.todo, s.unread], [0, 0, 0]);

      await tester.tap(find.text('기록하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(WriteSheet), matching: find.text('예시 별님')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '점심을 다 드셨어요.');
      await tester.tap(find.text('저장하기'));
      await tester.pump();
      await waitToast(tester);

      expect(find.descendant(of: find.byType(ExampleWrap), matching: find.byType(ObservationFeedCard)), findsNothing);
      expect(find.byType(ExampleWrap), findsNWidgets(2));
      expect(find.text('"점심을 다 드셨어요."'), findsOneWidget);
    });

    testWidgets('예시 카드의 버튼은 눌리지 않는다', (tester) async {
      final h = await pumpHandover(tester, dataset: Dataset.dev, size: const Size(390, 2000));
      await tester.tap(find.descendant(of: find.byType(ExampleWrap), matching: find.text('재측정하기')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(h.container.read(quickTempProvider).open, isFalse);
    });

    testWidgets('근무조가 없으면 시트에 예시 한 줄', (tester) async {
      await pumpHandover(tester, dataset: Dataset.dev);
      await tester.tap(find.byType(ShiftSummaryCard));
      await tester.pumpAndSettle();
      expect(find.text('근무조가 아직 정해지지 않았어요'), findsOneWidget);
      expect(find.descendant(of: find.byType(ShiftSheet), matching: find.byType(ExampleWrap)), findsOneWidget);
    });
  });

  group('작은 폰 360×640', () {
    testWidgets('목록 · 시트가 넘치지 않는다', (tester) async {
      await pumpHandover(tester, size: const Size(360, 640));
      // 끝까지 내리며 모든 카드를 그린다
      for (var i = 0; i < 12; i++) {
        await tester.drag(vList, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.byType(ObservationFeedCard), findsWidgets);
      for (final f in ['미확인', '할 일', '공지사항', '별님 기록', '모두']) {
        await tester.drag(vList, const Offset(0, 6000));
        await tester.pumpAndSettle();
        await pickFilter(tester, f);
      }

      await tester.tap(find.byType(ShiftSummaryCard));
      await tester.pumpAndSettle();
      expect(find.byType(ShiftSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(ShiftSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('기록하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(WriteSheet), matching: find.text('반 공지')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(WriteSheet), matching: find.text('전체 공지')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('개발 DB도 넘치지 않는다', (tester) async {
      await pumpHandover(tester, dataset: Dataset.dev, size: const Size(360, 640));
      for (var i = 0; i < 4; i++) {
        await tester.drag(vList, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('이름 옆 동그란 프로필 사진: 사진이 있으면 사진, 없으면 이름 두 글자', (tester) async {
    final h = await pumpHandover(tester, user: nurse);
    final seojun = rid('이서준');
    final withPhoto = find.byWidgetPredicate((w) => w is ResidentCircle && w.url == h.repo.profilePhotoOf(seojun)!.url);
    expect(withPhoto, findsWidgets, reason: '이서준 긴급 카드');
    expect(find.byWidgetPredicate((w) => w is ResidentCircle && w.url == null && w.label == '승민'), findsWidgets,
        reason: '박승민은 사진이 없어 이름 두 글자');
  });

  testWidgets('내 담당 반만: 김하늘(은하수자리)은 은하수자리 기록 + 전체 공지만', (tester) async {
    final h = await pumpHandover(tester, size: const Size(390, 3000));
    expect(find.textContaining('은하수자리 6명'), findsOneWidget);
    expect(caseCard('이서준'), findsOneWidget);
    expect(caseCard('박승민'), findsNothing, reason: '고래자리');
    expect(find.text('한나리'), findsNothing, reason: '물병자리');
    expect(find.text('정현우'), findsNothing, reason: '양자리');
    expect(find.text('오늘 10:00 목욕실 온수 보일러 점검 안내'), findsOneWidget, reason: '전체 공지는 모두에게');
    final s = tester.widget<ShiftSummaryCard>(find.byType(ShiftSummaryCard));
    expect(s.urgent, 1);
    final mine = h.repo.myClasses(me);
    expect(mine, {'milkyway'});
    expect(s.missed, h.repo.missedTempResidents(clock).where((r) => r.classId == 'milkyway').length);
  });
}
