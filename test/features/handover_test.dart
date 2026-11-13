// 인수인계 (첫 화면 · 전체 기록[HO-1 최신 기록 · HO-2 별님별 기록] · HO-W 작성 시트) 화면 흐름.
// 시연 시작 상태(통합 명세 10-3)와 인수인계 명세 14장 테스트 시나리오를 바탕으로 한다.
import 'package:byeoljari_note/app.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart' as seed;
import 'package:byeoljari_note/core/theme.dart';
import 'package:byeoljari_note/features/alert_case/case_detail_screen.dart';
import 'package:byeoljari_note/features/archive/archive_screen.dart';
import 'package:byeoljari_note/features/handover/handover_screen.dart';
import 'package:byeoljari_note/features/handover/handover_view.dart';
import 'package:byeoljari_note/features/handover/records_screen.dart';
import 'package:byeoljari_note/features/handover/write_sheet.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const me = 'kim_haneul';
String rid(String name) => seed.residentByName(name).id;

/// 최신 기록의 세로 목록.
final feed = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

final hList = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);

Future<void> toTop(WidgetTester tester) async {
  await tester.drag(feed, const Offset(0, 6000));
  await tester.pumpAndSettle();
}

/// 최신 기록에서 [f]가 보이도록 내린 뒤 맨 위로 맞춘다 (아래쪽 "기록 남기기" 버튼에 가리지 않게).
Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: feed);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

/// 첫 화면의 "안 본 기록 n개 ›" 줄을 눌러 전체 기록을 연다.
Future<void> openRecords(WidgetTester tester) async {
  final row = find.bySemanticsLabel(RegExp(r'전체 기록 열기$'));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(find.byType(HandoverRecordsScreen), findsOneWidget);
}

void main() {
  late InMemoryRepository repo;
  late ProviderContainer container;

  setUp(() => repo = InMemoryRepository());

  void phone(WidgetTester tester, {double w = 400, double h = 820}) {
    tester.view.physicalSize = Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  /// 인수인계 화면만 띄운다 (다른 기능 화면과 상관없이).
  Future<void> pumpHandover(WidgetTester tester) async {
    container = ProviderContainer(overrides: [repoProvider.overrideWith((ref) => repo)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: HandoverScreen())),
    ));
    await tester.pumpAndSettle();
  }

  /// 전체 기록 화면 (첫 화면 "안 본 기록 n개 ›" 안). [filter]를 안 주면 '모두'로 연다.
  Future<void> pumpRecords(WidgetTester tester, {FeedFilter filter = FeedFilter.all}) async {
    container = ProviderContainer(overrides: [repoProvider.overrideWith((ref) => repo)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: HandoverRecordsScreen(initialFilter: filter)),
    ));
    await tester.pumpAndSettle();
  }

  group('계산 (HandoverView)', () {
    test('시작 상태: 대응 칸에 박승민 이상 대응 1건, 남은 할 일 3, 범위는 내 직전 근무 시작부터', () {
      final v = HandoverView(repo, me, repo.now());
      expect(v.activeCases.map((c) => c.residentId), [rid('박승민')]);
      expect(v.urgentCount, 0);
      expect(v.abnormalCount, 1);
      expect(v.openTasks.map((e) => e.residentId).toSet(), {rid('이서준'), rid('최도윤'), rid('정현우')});
      expect(v.since, repo.handoverSince(me, repo.now()));
      // 대응 칸에 올라간 기록은 목록에서 빠진다
      expect(v.visible.any((e) => e.caseId != null && e.residentId == rid('박승민')), isFalse);
      // 내가 쓴 기록은 미확인이 아니다
      expect(v.unread.every((e) => e.authorId != me), isTrue);
      expect(v.unread, isNotEmpty);
    });

    test('확인하면 미확인에서 빠지고 확인 수는 지금 근무조 인원 기준', () {
      final now = repo.now();
      var v = HandoverView(repo, me, now);
      final e = v.unread.first;
      final before = v.unread.length;
      repo.markRead(e.id, me, now);
      v = HandoverView(repo, me, now);
      expect(v.unread.length, before - 1);
      expect(v.shift!.staffIds, seed.amShiftStaff);
      expect(v.shiftReaders(e.id), contains(me));
    });

    test('회복(평소로 내려옴)하면 대응 칸에서 내려가고 기록은 최신 기록으로', () {
      repo.saveMeasurement(residentId: rid('박승민'), value: 368, by: me, at: repo.now());
      final v = HandoverView(repo, me, repo.now());
      expect(v.activeCases, isEmpty);
      expect(v.visible.any((e) => e.caseId != null && e.residentId == rid('박승민')), isTrue);
    });

    test('이어받은 할 일: 한 줄 = 한 별님, 기한이 이른 순 · 안 본 공지 수', () {
      final v = HandoverView(repo, me, repo.now());
      final rows = v.taskRows;
      expect(rows.map((r) => r.residentId), [rid('이서준'), rid('정현우'), rid('최도윤')]);
      expect(rows.every((r) => r.isTemp), isTrue);
      expect(v.unreadNotices, v.unread.where((e) => e.scope == EntryScope.facility).length);
      expect(v.unreadNotices, greaterThan(0));
    });

    test('위험이 나오면 긴급이 맨 위', () {
      repo.saveMeasurement(residentId: rid('이서준'), value: 395, by: me, at: repo.now());
      final v = HandoverView(repo, me, repo.now());
      expect(v.activeCases.first.residentId, rid('이서준'));
      expect(v.activeCases.first.isUrgent, isTrue);
      expect(v.urgentCount, 1);
    });
  });

  group('첫 화면 (개선 시안 1)', () {
    testWidgets('한 문장 요약 · 이상 대응 카드 · 이어받은 할 일 3 · 안 본 기록 줄', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      expect(find.bySemanticsLabel('이상 대응 1건이 있고, 이어받은 할 일이 3개 있어요.'), findsOneWidget);
      expect(find.text('▲ 이상 대응'), findsOneWidget);
      expect(find.text('09:20 · 21분 전 ›'), findsOneWidget);
      expect(find.text('박승민 별님'), findsOneWidget);
      expect(find.text('고래자리'), findsOneWidget);
      expect(find.text('38.2℃'), findsOneWidget);
      expect(find.text('평소보다 1.4도 높아요'), findsOneWidget);
      expect(find.text('아직 아무도 확인 안 했어요'), findsOneWidget);
      expect(find.text('확인했어요'), findsOneWidget);
      expect(find.text('재측정 입력'), findsOneWidget);
      // 할 일: 급한 순, 한 줄 = 한 별님 = 한 버튼
      expect(find.text('이어받은 할 일 3'), findsOneWidget);
      expect(find.text('급한 순'), findsOneWidget);
      expect(find.text('이서준 · 다시 재기'), findsOneWidget);
      expect(find.text('! 주의 37.6℃ · 09:45까지'), findsOneWidget);
      expect(find.text('정현우 · 다시 재기'), findsOneWidget);
      expect(find.text('양자리 · 어제 15:20부터'), findsOneWidget);
      expect(find.text('최도윤 · 오전 체온'), findsOneWidget);
      expect(find.text('아직 안 쟀어요 · 점심 전까지'), findsOneWidget);
      expect(find.text('재기'), findsNWidgets(3));
      final ys = [
        for (final t in ['이서준 · 다시 재기', '정현우 · 다시 재기', '최도윤 · 오전 체온']) tester.getTopLeft(find.text(t)).dy,
      ];
      expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue, reason: '급한 순');
      // 안 본 기록 줄
      final v = HandoverView(repo, me, repo.now());
      expect(
        find.bySemanticsLabel('안 본 기록 ${v.unread.length}개 · 공지 ${v.unreadNotices}, 전체 기록 열기'),
        findsOneWidget,
      );
      // 예전 숫자 칸·칩·기록 남기기는 첫 화면에 없다
      expect(find.text('기록 남기기'), findsNothing);
      expect(find.text('별님별 기록'), findsNothing);
    });

    testWidgets('[확인했어요]를 누르면 확인 기록이 남고 ✓ 확인함으로 바뀐다', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      await tester.tap(find.text('확인했어요'));
      await tester.pumpAndSettle();
      final c = repo.openCases.first;
      expect(repo.eventsOf(c.id).any((e) => e.type == 'acked' && e.actorId == me), isTrue);
      expect(find.text('확인했어요'), findsNothing);
      expect(find.text('✓ 확인함'), findsOneWidget);
      expect(find.text('김하늘 선생님 확인했어요'), findsOneWidget);
    });

    testWidgets('[재측정 입력]은 퀵 체온을 그 별님으로 연다', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      await tester.tap(find.text('재측정 입력'));
      await tester.pump();
      final qt = container.read(quickTempProvider);
      expect(qt.open, isTrue);
      expect(qt.residentId, rid('박승민'));
    });

    testWidgets('할 일 [재기] → 퀵 체온이 그 별님으로, 저장하면 줄이 빠지고 문장이 바뀐다', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      await tester.tap(find.bySemanticsLabel('이서준 체온 재기'));
      await tester.pump();
      expect(container.read(quickTempProvider).open, isTrue);
      expect(container.read(quickTempProvider).residentId, rid('이서준'));
      repo.saveMeasurement(residentId: rid('이서준'), value: 369, by: me, at: repo.now());
      await tester.pumpAndSettle();
      expect(find.text('이서준 · 다시 재기'), findsNothing);
      expect(find.text('이어받은 할 일 2'), findsOneWidget);
      expect(find.bySemanticsLabel('이상 대응 1건이 있고, 이어받은 할 일이 2개 있어요.'), findsOneWidget);
    });

    testWidgets('메모 할 일 [완료] → "완료할까요?" 확인 시트 → 완료', (tester) async {
      phone(tester);
      final e = repo.addEntry(Entry(
        id: '',
        scope: EntryScope.resident,
        authorId: 'park_jieun',
        kindLabel: '관찰 기록',
        createdAt: repo.now(),
        classId: 'milkyway',
        residentId: rid('최도윤'),
        body: '양말 갈아 신겨 주세요',
        task: const Task(id: '', label: '양말 갈아 신기기', kind: TaskKind.memo, dueAt: null, duePreset: '점심 전'),
      ));
      await pumpHandover(tester);
      expect(find.text('최도윤 · 양말 갈아 신기기'), findsOneWidget);
      expect(find.text('은하수자리 · 점심 전까지'), findsOneWidget);
      final done = find.bySemanticsLabel('양말 갈아 신기기 완료');
      await tester.ensureVisible(done);
      await tester.pumpAndSettle();
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(find.text('완료할까요?'), findsOneWidget);
      expect(container.read(quickTempProvider).open, isFalse); // 숫자 입력 없음
      await tester.tap(find.text('완료했어요'));
      await tester.pumpAndSettle();
      expect(repo.entry(e.id).task!.done, isTrue);
      expect(find.text('양말 갈아 신기기 완료'), findsOneWidget); // 토스트
      expect(find.text('최도윤 · 양말 갈아 신기기'), findsNothing);
    });

    testWidgets('위험이 나오면 ⚠ 긴급 카드가 맨 위, 문장에 긴급이 먼저', (tester) async {
      phone(tester);
      repo.saveMeasurement(residentId: rid('이서준'), value: 395, by: me, at: repo.now());
      await pumpHandover(tester);
      expect(find.bySemanticsLabel('긴급 1건과 이상 대응 1건이 있고, 이어받은 할 일이 2개 있어요.'), findsOneWidget);
      expect(find.text('⚠ 긴급'), findsOneWidget);
      expect(tester.getTopLeft(find.text('⚠ 긴급')).dy, lessThan(tester.getTopLeft(find.text('▲ 이상 대응')).dy));
    });

    testWidgets('아무 일도 없으면 차분한 문장 하나', (tester) async {
      phone(tester);
      repo.saveMeasurement(residentId: rid('박승민'), value: 368, by: me, at: repo.now());
      for (final e in HandoverView(repo, me, repo.now()).openTasks) {
        repo.completeTask(e.id, me, repo.now());
      }
      await pumpHandover(tester);
      expect(find.bySemanticsLabel('지금 아픈 별님도, 이어받은 할 일도 없어요.'), findsOneWidget);
      expect(find.textContaining('이어받은 할 일 '), findsNothing);
      expect(find.text('확인했어요'), findsNothing);
    });

    testWidgets('카드를 누르면 이상 대응 상세로 간다', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      await tester.tap(find.text('평소보다 1.4도 높아요'));
      await tester.pumpAndSettle();
      expect(find.byType(CaseDetailScreen), findsOneWidget);
    });

    testWidgets('"안 본 기록 n개" 줄 → 전체 기록 (안 본 기록 보기 · 머리말 · 기록 남기기 · 별님별 기록)', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      final n = HandoverView(repo, me, repo.now()).unread.length;
      await tester.tap(find.bySemanticsLabel(RegExp('^안 본 기록 $n개')));
      await tester.pumpAndSettle();
      expect(find.byType(HandoverRecordsScreen), findsOneWidget);
      expect(find.text('기록 남기기'), findsOneWidget);
      expect(find.textContaining('이후 기록이에요'), findsOneWidget);
      expect(find.text('안 본 기록 $n건'), findsOneWidget); // '안 본 기록' 보기로 시작
      expect(find.bySemanticsLabel(RegExp('^별님별 기록')), findsOneWidget);
    });
  });

  group('HO-1 최신 기록 (전체 기록 안)', () {
    testWidgets('체온 미기록 링크 → 별님 고르면 퀵 체온', (tester) async {
      phone(tester);
      await pumpRecords(tester);
      final missed = repo.missedTempResidents(repo.now());
      expect(missed, isNotEmpty);
      await tester.tap(find.text('체온 미기록 ${missed.length}명 ›'));
      await tester.pumpAndSettle();
      expect(find.text('체온을 아직 안 잰 별님 ${missed.length}명'), findsOneWidget);
      await tester.tap(find.text('${missed.first.name} 별님'));
      await tester.pumpAndSettle();
      expect(container.read(quickTempProvider).open, isTrue);
      expect(container.read(quickTempProvider).residentId, missed.first.id);
    });

    testWidgets('고정 공지 · 최신 기록이 보이고 이상 대응 카드는 없다', (tester) async {
      phone(tester);
      await pumpRecords(tester);
      expect(find.text('확인했어요'), findsNothing); // 이상 대응 카드는 첫 화면에
      await reveal(tester, find.text('전체 공지 · 위에 고정'));
      expect(find.text('독감 예방접종'), findsOneWidget);
      await reveal(tester, find.textContaining(RegExp(r'^최신 기록 \d+$')));
    });

    testWidgets('체온 할 일 [완료하기] → 퀵 체온이 그 별님으로 열림, 저장하면 자동 완료', (tester) async {
      phone(tester);
      await pumpRecords(tester);
      final taskChip = find.textContaining(RegExp(r'^할 일 \d+$')); // 보기 칩
      await tester.ensureVisible(taskChip);
      await tester.pumpAndSettle();
      await tester.tap(taskChip);
      await tester.pumpAndSettle();
      final seojun = repo.openTempTasksOf(rid('이서준')).single;
      final card = find.byKey(ValueKey('entry-${seojun.id}'));
      await reveal(tester, find.descendant(of: card, matching: find.text('완료하기')));
      await tester.tap(find.descendant(of: card, matching: find.text('완료하기')));
      await tester.pump();
      expect(container.read(quickTempProvider).open, isTrue);
      expect(container.read(quickTempProvider).residentId, rid('이서준'));

      // 퀵 체온에서 저장 (저장 흐름은 저장소 한 곳)
      repo.saveMeasurement(residentId: rid('이서준'), value: 369, by: me, at: repo.now());
      await tester.pumpAndSettle();
      expect(repo.entry(seojun.id).task!.done, isTrue);
      await reveal(tester, find.descendant(of: card, matching: find.textContaining('잰 체온 36.9℃')));
      expect(find.descendant(of: card, matching: find.textContaining('김하늘 선생님 완료')), findsOneWidget);
      expect(HandoverView(repo, me, repo.now()).openTasks.length, 2);
    });

    testWidgets('메모 할 일 [완료하기] → "완료할까요?" 확인 시트 → 완료', (tester) async {
      phone(tester);
      final e = repo.addEntry(Entry(
        id: '',
        scope: EntryScope.resident,
        authorId: 'park_jieun',
        kindLabel: '관찰 기록',
        createdAt: repo.now(),
        classId: 'milkyway',
        residentId: rid('최도윤'),
        body: '양말 갈아 신겨 주세요',
        task: const Task(id: '', label: '양말 갈아 신기기', kind: TaskKind.memo, dueAt: null, duePreset: '점심 전'),
      ));
      await pumpRecords(tester);
      final card = find.byKey(ValueKey('entry-${e.id}'));
      await reveal(tester, find.descendant(of: card, matching: find.text('완료하기')));
      await tester.tap(find.descendant(of: card, matching: find.text('완료하기')));
      await tester.pumpAndSettle();
      expect(find.text('완료할까요?'), findsOneWidget);
      expect(container.read(quickTempProvider).open, isFalse); // 숫자 입력 없음
      await tester.tap(find.text('완료했어요'));
      await tester.pumpAndSettle();
      expect(repo.entry(e.id).task!.done, isTrue);
      expect(repo.isRead(e.id, me), isTrue);
      expect(find.text('양말 갈아 신기기 완료'), findsOneWidget); // 토스트
    });

    testWidgets('안 본 기록 보기에서 [확인]을 누를 때마다 줄고 0이면 빈 문구', (tester) async {
      phone(tester);
      await pumpRecords(tester);
      final n = HandoverView(repo, me, repo.now()).unread.length;
      await tester.tap(find.text('안 본 기록 $n'));
      await tester.pumpAndSettle();
      for (var i = n; i > 0; i--) {
        final btn = find.widgetWithText(OutlinedButton, '확인');
        for (var k = 0; k < 40 && btn.evaluate().isEmpty; k++) {
          await tester.drag(feed, const Offset(0, -200));
          await tester.pump();
        }
        await tester.ensureVisible(btn.first);
        await tester.pumpAndSettle();
        await tester.tap(btn.first);
        await tester.pumpAndSettle();
        expect(HandoverView(repo, me, repo.now()).unread.length, i - 1);
      }
      await toTop(tester);
      expect(find.text('안 본 기록 0'), findsOneWidget);
      await reveal(tester, find.text('안 본 기록이 없어요. 모두 확인했어요.'));
      expect(find.text('안 본 기록이 없어요. 모두 확인했어요.'), findsOneWidget);
    });

    testWidgets('답글을 쓰면 답글 수가 늘고 확인 처리 + 토스트', (tester) async {
      phone(tester);
      await pumpRecords(tester);
      final nari = repo.archiveEntriesOf(rid('한나리')).firstWhere((e) => e.authorId == 'choi_minho' && e.photoCount == 1);
      expect(repo.isRead(nari.id, me), isFalse);
      final card = find.byKey(ValueKey('entry-${nari.id}'));
      await reveal(tester, card);
      await tester.tap(find.descendant(of: card, matching: find.text('답글 1개')));
      await tester.pumpAndSettle();
      expect(find.textContaining('점심 후에 한 번 더 볼게요'), findsOneWidget);
      await tester.enterText(find.descendant(of: card, matching: find.byType(TextField)), '저녁에도 볼게요');
      await tester.tap(find.descendant(of: card, matching: find.text('보내기')));
      await tester.pumpAndSettle();
      expect(repo.repliesOf(nari.id).length, 2);
      expect(repo.isRead(nari.id, me), isTrue);
      expect(find.text('답글을 남겼어요 · 이 기록도 확인으로 표시했어요'), findsOneWidget);
    });

    testWidgets('확인한 전체 공지는 "모두"에서 접히고 "전체 공지" 보기에서는 펼쳐진다', (tester) async {
      phone(tester);
      final flu = repo.entries.firstWhere((e) => e.title == '독감 예방접종');
      repo.markRead(flu.id, me, repo.now());
      await pumpRecords(tester);
      expect(find.text('11월 3일(월) 오전, 별님 전원 예방접종이 있어요.'), findsNothing);
      await reveal(tester, find.text('확인한 공지 · 눌러서 펼치기'));
      expect(find.text('확인한 공지 · 눌러서 펼치기'), findsOneWidget);
      expect(find.text('11월 3일(월) 오전, 별님 전원 예방접종이 있어요.'), findsNothing);
      await toTop(tester);
      final chip = find.textContaining(RegExp(r'^전체 공지 \d+$'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('11월 3일(월) 오전, 별님 전원 예방접종이 있어요.'));
      expect(find.text('11월 3일(월) 오전, 별님 전원 예방접종이 있어요.'), findsOneWidget);
    });

    testWidgets('별님 이름을 누르면 아카이브로 간다', (tester) async {
      phone(tester);
      await pumpRecords(tester);
      final memo = repo.entries.firstWhere((e) => e.residentId == rid('최도윤') && e.authorId == 'park_jieun' && e.task != null);
      final chip = find.descendant(of: find.byKey(ValueKey('entry-${memo.id}')), matching: find.text('최도윤'));
      await reveal(tester, chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveScreen), findsOneWidget);
    });
  });

  group('HO-2 별님별 기록', () {
    testWidgets('반 탭 + 별님 그리드는 정해진 순서, 상태 표시, 누르면 아카이브', (tester) async {
      phone(tester);
      await pumpRecords(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^별님별 기록')));
      await tester.pumpAndSettle();
      // 김하늘 배치 반 = 은하수자리
      final names = repo.residentsOf('milkyway').map((r) => r.name).toList();
      final ys = [for (final n in names) tester.getTopLeft(find.text(n).last)];
      for (var i = 1; i < ys.length; i++) {
        final a = ys[i - 1], b = ys[i];
        expect(b.dy > a.dy || (b.dy == a.dy && b.dx > a.dx), isTrue, reason: '그리드 순서 고정');
      }
      expect(find.textContaining(RegExp(r'^할 일 ')), findsWidgets); // 이서준·최도윤 할 일
      // 고래자리 → 박승민 이상 대응
      await tester.scrollUntilVisible(find.text('고래자리'), 100, scrollable: hList);
      await tester.pumpAndSettle();
      await tester.tap(find.text('고래자리'));
      await tester.pumpAndSettle();
      expect(find.text('▲ 이상 대응'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^박승민 별님')));
      await tester.pumpAndSettle();
      expect(find.byType(ArchiveScreen), findsOneWidget);
    });
  });

  group('HO-W 작성 시트', () {
    testWidgets('대상 전에는 비활성, 메모 없으면 오류, 빠른 문구 + 할 일(저녁 전) 저장', (tester) async {
      phone(tester);
      await pumpRecords(tester);
      await tester.tap(find.text('기록 남기기'));
      await tester.pumpAndSettle();
      final save = find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(FilledButton, '기록 남기기'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.tap(find.bySemanticsLabel('이서준'));
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pump();
      expect(find.text('⚠ 메모를 한 줄이라도 적어주세요.'), findsOneWidget);

      await tester.ensureVisible(find.text('절반'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('절반'));
      await tester.pump();
      await tester.ensureVisible(find.text('할 일로 넘기기'));
      await tester.tap(find.text('할 일로 넘기기'));
      await tester.pump();
      await tester.ensureVisible(find.bySemanticsLabel('저녁 전'));
      await tester.tap(find.bySemanticsLabel('저녁 전'));
      await tester.pump();
      final before = repo.entries.length;
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repo.entries.length, before + 1);
      final e = repo.entries.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
      expect(e.id, isNotEmpty);
      expect(e.residentId, rid('이서준'));
      expect(e.body, '식사를 절반만 드셨어요.');
      expect(e.task!.id, isNotEmpty);
      expect(e.task!.duePreset, '저녁 전');
      expect(e.task!.kind, TaskKind.memo);
      expect(find.text('할 일로 넘겼어요 · 완료할 때까지 남은 할 일에 보여요'), findsOneWidget);
      expect(HandoverView(repo, me, repo.now()).openTasks.length, 4);
      // 내 기록 + 열린 할 일 → [완료하기]만 (확인 버튼 없음)
      final card = find.byKey(ValueKey('entry-${e.id}'));
      await reveal(tester, card);
      expect(find.descendant(of: card, matching: find.text('완료하기')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.widgetWithText(OutlinedButton, '확인')), findsNothing);
    });

    testWidgets('아카이브에서 열면 반·별님이 미리 선택된다 + 반 공지 저장', (tester) async {
      phone(tester);
      container = ProviderContainer(overrides: [repoProvider.overrideWith((ref) => repo)]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (c, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () => showWriteSheet(c, ref, residentId: rid('이서준')),
                  child: const Text('아카이브에서 열기'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('아카이브에서 열기'));
      await tester.pumpAndSettle();
      expect(find.text('이서준 별님에 대한 메모'), findsOneWidget);
      expect(find.text('인수인계와 이서준 별님 아카이브에 남아요'), findsOneWidget);

      // 반 공지로 바꿔 저장
      await tester.tap(find.bySemanticsLabel('반 공지'));
      await tester.pump();
      expect(find.text('은하수자리 반 공지'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '오늘 산책은 쉬어요.');
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(FilledButton, '기록 남기기')));
      await tester.pumpAndSettle();
      final e = repo.entries.firstWhere((x) => x.body == '오늘 산책은 쉬어요.');
      expect(e.scope, EntryScope.classScope);
      expect(e.classId, 'milkyway');
      expect(find.text('반 공지로 은하수자리 ${repo.residentsOf('milkyway').length}명 아카이브에 함께 담겼어요'), findsOneWidget);
    });
  });

  group('작은 폰 (360×640)', () {
    testWidgets('앱 전체에서 인수인계 첫 화면 · 전체 기록 두 화면 · 작성 시트가 넘치지 않는다', (tester) async {
      phone(tester, w: 360, h: 640);
      await tester.pumpWidget(ProviderScope(
        overrides: [repoProvider.overrideWith((ref) => repo)],
        child: const ByeoljariApp(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 첫 화면 끝까지 → "안 본 기록" 줄로 전체 기록
      await tester.drag(feed, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openRecords(tester);
      // 최신 기록 끝까지 스크롤
      await tester.drag(feed, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.bySemanticsLabel(RegExp('^별님별 기록')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final c in repo.classes) {
        await tester.scrollUntilVisible(find.text(c.name).first, 100, scrollable: hList.first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(c.name).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.text('기록 남기기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('어떤 별님인가요?'), findsOneWidget);
    });
  });

  group('크기·큰 글자 (390×844 · 360×640 · 1.3배)', () {
    for (final (w, h, scale) in [(390.0, 844.0, 1.0), (360.0, 640.0, 1.0), (390.0, 844.0, 1.3), (360.0, 640.0, 1.3)]) {
      testWidgets('${w.toInt()}×${h.toInt()} 글자 $scale배: 첫 화면 · 최신 기록 · 별님별 기록 · 작성 시트가 넘치지 않는다', (tester) async {
        phone(tester, w: w, h: h);
        container = ProviderContainer(overrides: [repoProvider.overrideWith((ref) => repo)]);
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildTheme(),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(body: HandoverScreen()),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 첫 화면: 긴급 카드까지 띄워서 끝까지 내리며 확인
        repo.saveMeasurement(residentId: rid('이서준'), value: 395, by: me, at: repo.now());
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          await tester.drag(feed, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await openRecords(tester);

        // 최신 기록: 끝까지 내리며 확인, 답글 펼치기, 보기 칩마다
        for (var i = 0; i < 12; i++) {
          await tester.drag(feed, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        final reply = find.textContaining(RegExp(r'^답글 \d+개$'));
        if (reply.evaluate().isNotEmpty) {
          await tester.ensureVisible(reply.first);
          await tester.pumpAndSettle();
          await tester.tap(reply.first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await toTop(tester);
        for (final f in FeedFilter.values) {
          final chip = find.text('${f.label} ${HandoverView(repo, me, repo.now()).countFor(f)}');
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        // 별님별 기록: 반마다
        await tester.tap(find.bySemanticsLabel(RegExp('^별님별 기록')));
        await tester.pumpAndSettle();
        for (final c in repo.classes) {
          await tester.scrollUntilVisible(find.text(c.name).first, 100, scrollable: hList.last);
          await tester.pumpAndSettle();
          await tester.tap(find.text(c.name).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        // 작성 시트: 할 일까지 펼친다
        await tester.tap(find.text('기록 남기기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('할 일로 넘기기'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('할 일로 넘기기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
