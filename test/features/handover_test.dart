// 인수인계 (HO-1 최신 기록 · HO-2 별님별 기록 · HO-W 작성 시트) 화면 흐름.
// 시연 시작 상태(통합 명세 10-3)와 인수인계 명세 14장 테스트 시나리오를 바탕으로 한다.
import 'package:byeoljari_note/app.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart' as seed;
import 'package:byeoljari_note/features/archive/archive_screen.dart';
import 'package:byeoljari_note/features/handover/handover_screen.dart';
import 'package:byeoljari_note/features/handover/handover_view.dart';
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

    test('위험이 나오면 긴급이 맨 위', () {
      repo.saveMeasurement(residentId: rid('이서준'), value: 395, by: me, at: repo.now());
      final v = HandoverView(repo, me, repo.now());
      expect(v.activeCases.first.residentId, rid('이서준'));
      expect(v.activeCases.first.isUrgent, isTrue);
      expect(v.urgentCount, 1);
    });
  });

  group('HO-1 최신 기록', () {
    testWidgets('교대 요약 · 대응 칸 · 고정 공지 · 기록 카드가 보인다', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      expect(find.text('교대 요약'), findsOneWidget);
      expect(find.bySemanticsLabel('긴급 0'), findsOneWidget);
      expect(find.bySemanticsLabel('이상 대응 1'), findsOneWidget);
      expect(find.bySemanticsLabel('남은 할 일 3'), findsOneWidget);
      expect(find.textContaining('긴급 · 이상 대응'), findsOneWidget);
      expect(find.textContaining('▲ 이상 대응 · 이상 38.2℃'), findsOneWidget);
      expect(find.textContaining('아직 아무도 확인 안 함'), findsOneWidget);
      expect(find.text('전체 공지 · 위에 고정'), findsOneWidget);
      expect(find.text('독감 예방접종'), findsOneWidget);
    });

    testWidgets('[확인했어요]를 누르면 이상 건 확인 기록이 남고 ✓ 확인함으로 바뀐다', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      await tester.tap(find.text('확인했어요'));
      await tester.pumpAndSettle();
      final c = repo.openCases.first;
      expect(repo.eventsOf(c.id).any((e) => e.type == 'acked' && e.actorId == me), isTrue);
      expect(find.text('확인했어요'), findsNothing);
      expect(find.textContaining('김하늘 선생님 확인'), findsOneWidget);
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

    testWidgets('체온 할 일 [완료하기] → 퀵 체온이 그 별님으로 열림, 저장하면 자동 완료', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      await tester.tap(find.textContaining(RegExp(r'^할 일 \d+$'))); // 필터 칩
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
      expect(find.textContaining('김하늘 선생님 완료 · 36.9℃'), findsOneWidget);
      await toTop(tester);
      expect(find.bySemanticsLabel('남은 할 일 2'), findsOneWidget);
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
      await pumpHandover(tester);
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

    testWidgets('미확인 필터에서 [확인]을 누를 때마다 줄고 0이면 빈 문구', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      final n = HandoverView(repo, me, repo.now()).unread.length;
      await tester.tap(find.text('미확인 $n'));
      await tester.pumpAndSettle();
      for (var i = n; i > 0; i--) {
        final btn = find.widgetWithText(OutlinedButton, '확인');
        await reveal(tester, btn.first);
        await tester.tap(btn.first);
        await tester.pumpAndSettle();
        expect(HandoverView(repo, me, repo.now()).unread.length, i - 1);
      }
      await toTop(tester);
      expect(find.text('미확인 0'), findsOneWidget);
      expect(find.text('안 본 기록이 없어요. 모두 확인했어요.'), findsOneWidget);
    });

    testWidgets('답글을 쓰면 답글 수가 늘고 확인 처리 + 토스트', (tester) async {
      phone(tester);
      await pumpHandover(tester);
      final nari = repo.archiveEntriesOf(rid('한나리')).firstWhere((e) => e.authorId == 'choi_minho' && e.photoCount == 1);
      expect(repo.isRead(nari.id, me), isFalse);
      final card = find.byKey(ValueKey('entry-${nari.id}'));
      await reveal(tester, card);
      await tester.tap(find.descendant(of: card, matching: find.text('답글 1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('점심 후에 한 번 더 볼게요'), findsOneWidget);
      await tester.enterText(find.descendant(of: card, matching: find.byType(TextField)), '저녁에도 볼게요');
      await tester.tap(find.descendant(of: card, matching: find.text('보내기')));
      await tester.pumpAndSettle();
      expect(repo.repliesOf(nari.id).length, 2);
      expect(repo.isRead(nari.id, me), isTrue);
      expect(find.text('답글을 남겼어요 · 이 기록도 확인으로 표시했어요'), findsOneWidget);
    });

    testWidgets('확인한 전체 공지는 "모두"에서 접히고 "전체 공지" 필터에서는 펼쳐진다', (tester) async {
      phone(tester);
      final flu = repo.entries.firstWhere((e) => e.title == '독감 예방접종');
      repo.markRead(flu.id, me, repo.now());
      await pumpHandover(tester);
      expect(find.text('11월 3일(월) 오전, 별님 전원 예방접종이 있어요.'), findsNothing);
      expect(find.text('확인한 공지 · 눌러서 펼치기'), findsOneWidget);
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
      await pumpHandover(tester);
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
      await pumpHandover(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^별님별 기록')));
      await tester.pumpAndSettle();
      // 김하늘 배치 반 = 은하수자리
      final names = repo.residentsOf('milkyway').map((r) => r.name).toList();
      final ys = [for (final n in names) tester.getTopLeft(find.text(n).last)];
      for (var i = 1; i < ys.length; i++) {
        final a = ys[i - 1], b = ys[i];
        expect(b.dy > a.dy || (b.dy == a.dy && b.dx > a.dx), isTrue, reason: '그리드 순서 고정');
      }
      expect(find.textContaining('☐ 할 일'), findsWidgets); // 이서준·최도윤 할 일
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
      await pumpHandover(tester);
      await tester.tap(find.text('기록 남기기'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, '기록 남기기');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.tap(find.bySemanticsLabel('이서준'));
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pump();
      expect(find.text('⚠ 메모를 한 줄이라도 적어주세요.'), findsOneWidget);

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
      expect(find.text('할 일로 넘겼어요 · 완료할 때까지 교대 요약에 남아요'), findsOneWidget);
      expect(find.bySemanticsLabel('남은 할 일 4'), findsOneWidget);
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
      expect(find.textContaining('인수인계 + 이서준 별님 아카이브'), findsOneWidget);

      // 반 공지로 바꿔 저장
      await tester.tap(find.bySemanticsLabel('반 공지'));
      await tester.pump();
      expect(find.text('은하수자리 반 공지'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '오늘 산책은 쉬어요.');
      await tester.tap(find.widgetWithText(FilledButton, '기록 남기기'));
      await tester.pumpAndSettle();
      final e = repo.entries.firstWhere((x) => x.body == '오늘 산책은 쉬어요.');
      expect(e.scope, EntryScope.classScope);
      expect(e.classId, 'milkyway');
      expect(find.text('반 공지로 은하수자리 ${repo.residentsOf('milkyway').length}명 아카이브에 함께 담겼어요'), findsOneWidget);
    });
  });

  group('작은 폰 (360×640)', () {
    testWidgets('앱 전체에서 인수인계 두 화면과 작성 시트가 넘치지 않는다', (tester) async {
      phone(tester, w: 360, h: 640);
      await tester.pumpWidget(ProviderScope(
        overrides: [repoProvider.overrideWith((ref) => repo)],
        child: const ByeoljariApp(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
}
