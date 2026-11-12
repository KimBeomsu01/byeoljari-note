// AR 별님 아카이브 · PF 별님카드 (통합 명세 6-4·6-6, 시연 10단계).
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:byeoljari_note/features/alert_case/case_detail_screen.dart';
import 'package:byeoljari_note/features/archive/archive_screen.dart';
import 'package:byeoljari_note/features/archive/archive_timeline.dart';
import 'package:byeoljari_note/features/resident_card/resident_card_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String get seojun => residentByName('이서준').id;

Future<InMemoryRepository> pumpArchive(WidgetTester tester, String residentId, {Size size = const Size(400, 820)}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: ArchiveScreen(residentId: residentId))));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ArchiveScreen))).read(repoProvider);
}

Finder get list => find.byType(Scrollable).first;

void main() {
  group('타임라인 계산', () {
    test('측정 한 건 = 한 줄: measurementId가 있는 기록은 체온 행에 합쳐진다', () {
      final repo = InMemoryRepository();
      final recs = buildArchiveRecords(repo, seojun);
      final temps = recs.whereType<TempRecord>().toList();
      expect(temps.length, repo.measurementsOf(seojun).length);
      final today = temps.first;
      expect(today.m.value, 376);
      expect(today.entry, isNotNull); // 주의 → 자동 생긴 체온 기록이 행 안에 연결
      expect(recs.whereType<EntryRecord>().any((e) => e.e.measurementId == today.m.id), isFalse);
      // 반 공지는 은하수자리 것만
      final notices = recs.whereType<EntryRecord>().where((e) => e.isClassNotice).toList();
      expect(notices, isNotEmpty);
      expect(notices.every((e) => e.e.classId == 'milkyway'), isTrue);
    });

    test('날짜 묶음 문구', () {
      final now = DateTime(2026, 10, 28, 9, 41);
      expect(dayLabel(DateTime(2026, 10, 28, 1), now), '오늘');
      expect(dayLabel(DateTime(2026, 10, 27, 23), now), '어제 · 10월 27일');
      expect(dayLabel(DateTime(2026, 10, 20), now), '10월 20일 (화)');
      expect(dayLabel(DateTime(2025, 9, 1), now), '2025년 9월 1일 (월)');
    });

    test("'소리' 검색은 2025-09-01 박지은 선생님 기록을 찾는다", () {
      final repo = InMemoryRepository();
      final hits = buildArchiveRecords(repo, seojun).where((r) => matchesQuery(repo, r, '  소리 ')).toList();
      expect(hits.whereType<EntryRecord>().any((r) => r.e.id == 'past-1' && r.e.authorId == 'park_jieun'), isTrue);
      expect(hits.whereType<TempRecord>(), isEmpty);
      // 기록자 이름으로도 찾는다
      final byAuthor = buildArchiveRecords(repo, seojun).where((r) => matchesQuery(repo, r, '박지은')).toList();
      expect(byAuthor.whereType<EntryRecord>().map((r) => r.e.id), containsAll(['past-1', 'past-2', 'past-3']));
    });
  });

  group('AR 화면', () {
    testWidgets('열면 오늘 체온 한 줄 · 판정 기호와 글자 · 날짜 묶음 · 지난 평소 체온은 접힘', (tester) async {
      final repo = await pumpArchive(tester, seojun);

      expect(find.text('이서준'), findsOneWidget);
      expect(find.text('은하수자리 · 담임 이수진 선생님'), findsOneWidget);
      expect(find.text('별님카드 ›'), findsOneWidget);
      expect(find.text('오늘'), findsOneWidget);
      expect(find.text('37.6℃'), findsOneWidget); // 측정과 자동 기록이 한 줄
      expect(find.text('! 주의'), findsOneWidget);
      expect(find.text('○ 할 일 열림 · 재측정'), findsOneWidget);
      expect(find.textContaining('반 공지 · 은하수자리 전원'), findsOneWidget);
      expect(find.text('이서준 별님 기록 남기기'), findsOneWidget);

      // 어제 묶음: 평소 체온 2건이 한 줄로 접혀 있다 → 누르면 펼쳐진다
      await tester.scrollUntilVisible(find.text('어제 · 10월 27일'), 200, scrollable: list);
      final group = find.textContaining('✓ 평소 체온 기록 2건');
      await tester.scrollUntilVisible(group.first, 200, scrollable: list);
      await tester.drag(list, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(group, findsWidgets);
      final before = find.text('✓ 평소', skipOffstage: false).evaluate().length;
      await tester.tap(group.first);
      await tester.pumpAndSettle();
      expect(find.text('✓ 평소', skipOffstage: false).evaluate().length, greaterThan(before));

      // 열기만 해서는 읽음 처리하지 않는다
      expect(repo.isRead('past-1', 'kim_haneul'), isFalse);
    });

    testWidgets("'소리' 검색 → 2025년 박지은 기록 + 담임 변경선, 결과 수, [새 기록 확인] 숨김", (tester) async {
      final repo = await pumpArchive(tester, seojun);
      final n = buildArchiveRecords(repo, seojun).where((r) => matchesQuery(repo, r, '소리')).length;
      expect(find.text('새 기록 확인'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '소리');
      await tester.pumpAndSettle();

      expect(find.text('새 기록 확인'), findsNothing);
      expect(find.text('검색 결과 $n건'), findsOneWidget);
      expect(find.textContaining('2026년 3월 · 담임 박지은 → 이수진 선생님'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('낯선 소리(드라이기)'), 200, scrollable: list);
      expect(find.text('2025년 9월 1일 (월)'), findsOneWidget);
      expect(find.textContaining('박지은 선생님 · 당시 담임'), findsWidgets);

      // 없는 말 → 빈 상태 → 전체 기록 보기
      await tester.drag(list, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '없는검색어');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 기록이 없어요'), findsOneWidget);
      await tester.tap(find.text('전체 기록 보기'));
      await tester.pumpAndSettle();
      expect(find.text('새 기록 확인'), findsOneWidget);
    });

    testWidgets('범위 칩: 반 공지 / 체온 / 관찰 기록, 칩을 고르면 [새 기록 확인]이 숨는다', (tester) async {
      final repo = await pumpArchive(tester, seojun);
      final recs = buildArchiveRecords(repo, seojun);
      final nNotice = recs.where((r) => r.matches(ArchiveFilter.classNotice)).length;
      final nObs = recs.where((r) => r.matches(ArchiveFilter.observation)).length;

      await tester.tap(find.text('반 공지 $nNotice'));
      await tester.pumpAndSettle();
      expect(find.text('새 기록 확인'), findsNothing);
      expect(find.textContaining('반 공지 · 은하수자리 전원'), findsNWidgets(nNotice));
      expect(find.text('37.6℃'), findsNothing);
      expect(find.textContaining('담임 박지은 →'), findsNothing); // 반 공지만 볼 때는 담임 변경선 생략

      await tester.tap(find.text('관찰 기록 $nObs'));
      await tester.pumpAndSettle();
      expect(find.text('37.6℃'), findsNothing);
      expect(find.textContaining('블록 쌓기'), findsOneWidget);

      await tester.tap(find.textContaining('체온 '));
      await tester.pumpAndSettle();
      expect(find.text('37.6℃'), findsOneWidget);
      expect(find.textContaining('블록 쌓기'), findsNothing);
    });

    testWidgets('[새 기록 확인]은 이 별님 기록과 반 공지를 archive로 확인 처리한다', (tester) async {
      final repo = await pumpArchive(tester, seojun);
      final unread = buildArchiveRecords(repo, seojun).where((r) => isUnread(repo, r, 'kim_haneul')).toList();
      expect(unread, isNotEmpty);
      expect(find.text('새 기록 ${unread.length}건 · 아직 확인하지 않았어요'), findsOneWidget);

      await tester.tap(find.text('새 기록 확인'));
      await tester.pumpAndSettle();

      expect(find.text('새 기록을 확인했어요 · 최신 기록에도 반영돼요'), findsOneWidget);
      expect(find.text('새 기록 확인'), findsNothing);
      for (final r in unread) {
        expect(repo.isRead(r.readTarget!.id, 'kim_haneul'), isTrue);
        expect(repo.readersOf(r.readTarget!.id).firstWhere((x) => x.staffId == 'kim_haneul').source, 'archive');
      }
      // 같은 반 다른 별님(최도윤)의 개인 기록은 그대로 미확인
      final doyun = residentByName('최도윤').id;
      final doyunNote = repo.archiveEntriesOf(doyun).firstWhere((e) => e.scope == EntryScope.resident && e.authorId != 'kim_haneul');
      expect(repo.isRead(doyunNote.id, 'kim_haneul'), isFalse);
    });

    testWidgets('기록 상세: 답글·확인 상태를 보여주고 열어도 읽음 처리하지 않는다', (tester) async {
      final nari = residentByName('한나리').id;
      final repo = await pumpArchive(tester, nari);
      await tester.tap(find.textContaining('왼쪽 무릎이 조금 긁혀'));
      await tester.pumpAndSettle();

      expect(find.text('관찰 기록'), findsWidgets);
      expect(find.text('답글 1'), findsWidgets);
      expect(find.text('확인했어요. 점심 후에 한 번 더 볼게요.'), findsOneWidget);
      expect(find.text('사진 1장'), findsWidgets);
      expect(find.textContaining('열어 보기만으로는 확인되지 않아요'), findsOneWidget);
      final e = repo.archiveEntriesOf(nari).firstWhere((x) => x.body?.contains('긁혀') ?? false);
      expect(repo.isRead(e.id, 'kim_haneul'), isFalse);

      await tester.tap(find.text('목록으로'));
      await tester.pumpAndSettle();
      expect(find.text('목록으로'), findsNothing);
    });

    testWidgets('잘못 잰 값은 취소선 + 글자로 보인다', (tester) async {
      final repo = await pumpArchive(tester, seojun);
      final m = repo.measurementsOf(seojun).first;
      repo.voidMeasurement(m.id, by: 'lee_sujin', at: repo.now());
      await tester.pumpAndSettle();

      expect(find.text('잘못 잰 값'), findsOneWidget);
      final t = tester.widget<Text>(find.text('37.6℃'));
      expect(t.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('이상 건이 연결된 체온 행 → [대응 이력 보기] → S3', (tester) async {
      await pumpArchive(tester, residentByName('박승민').id);
      expect(find.text('38.2℃'), findsOneWidget);
      expect(find.text('▲ 이상'), findsOneWidget);
      await tester.tap(find.text('대응 이력 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(CaseDetailScreen), findsOneWidget);
    });

    testWidgets('작은 폰(360×640)에서도 넘치지 않는다', (tester) async {
      await pumpArchive(tester, seojun, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '소리');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('PF 별님카드', () {
    testWidgets('평소 체온·그래프·대응 이력, 아카이브로 돌아가기 (화면이 쌓이지 않음)', (tester) async {
      final repo = await pumpArchive(tester, seojun);
      // 이서준에게 이상 건을 만들고 종료해 대응 이력(종료 포함)을 보인다
      final s = repo.saveMeasurement(residentId: seojun, value: 384, by: 'kim_haneul', at: repo.now());
      repo.close(s.caseItem!.id, 'park_soyeon', repo.now(), '회복');
      await tester.pumpAndSettle();

      await tester.tap(find.text('별님카드 ›'));
      await tester.pumpAndSettle();
      expect(find.byType(ResidentCardScreen), findsOneWidget);
      expect(find.text('37.1℃'), findsOneWidget);
      expect(find.text('최근 14일 중앙값'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('최근 14일 체온 그래프')), findsOneWidget);
      expect(find.text('투약 지침 보기'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('이 별님의 기록 아카이브'), 200, scrollable: list);
      expect(find.text('이상 대응'), findsOneWidget);
      expect(find.text('종료 · 회복'), findsOneWidget);

      await tester.tap(find.text('이 별님의 기록 아카이브'));
      await tester.pumpAndSettle();
      expect(find.byType(ResidentCardScreen), findsNothing);
      expect(find.byType(ArchiveScreen), findsOneWidget);
    });

    testWidgets('투약 지침 보기 → S4, 작은 폰에서 넘치지 않음', (tester) async {
      tester.view.physicalSize = const Size(360, 640) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: ResidentCardScreen(residentId: seojun))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('대응 이력이 없어요.', skipOffstage: false), findsOneWidget); // 시작 상태: 이서준은 이상 건 없음
      await tester.tap(find.text('투약 지침 보기'));
      await tester.pumpAndSettle();
      expect(find.text('이서준 투약 지침'), findsOneWidget);
    });
  });
}
