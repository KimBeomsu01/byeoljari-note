// PC 01 통합 관제 현황판 (Claude Design PcDashboard.dc.html) 화면 흐름.
// 시연 DB = 2026-10-28(수) 14:00 고정 시계. 개발 DB = 예시 카드 · 명부에서 실제 명단 넣기.
import 'package:byeoljari_note/core/ds.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart' as seed;
import 'package:byeoljari_note/core/theme.dart';
import 'package:byeoljari_note/features/pc/pc_dashboard_page.dart';
import 'package:byeoljari_note/features/pc/pc_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final at = DateTime(2026, 10, 28, 14, 0);
String rid(String name) => seed.residentByName(name).id;

void main() {
  late InMemoryRepository repo;
  late ProviderContainer container;

  /// PC 셸과 같은 자리 (레일 80 + 머리 64) 안에 현황판만 그린다.
  Future<void> pumpPage(WidgetTester tester, {Dataset dataset = Dataset.demo, double width = 1440}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = InMemoryRepository(dataset: dataset, clock: () => at);
    container = ProviderContainer(overrides: [repoProvider.overrideWith((_) => repo), screenKindProvider.overrideWithValue('pc')]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            body: Row(
              children: [
                SizedBox(width: 80),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: 64),
                      Expanded(child: PcDashboardPage()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// 토스트가 사라질 때까지 (타이머가 남지 않게).
  Future<void> waitToast(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

  group('시연 DB', () {
    testWidgets('제목 · 요약 카드 · 표가 저장소 자료로 그려진다 (1440폭에서 넘치지 않음)', (tester) async {
      await pumpPage(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('울산 혜진원 통합 관제 현황판'), findsOneWidget);
      expect(find.text('실시간 관제 활성'), findsOneWidget);
      expect(find.text('2026.10.28 수 14:00 KST'), findsOneWidget);
      // 재실: 별님 36명, 6개 생활관
      expect(find.text('36'), findsOneWidget);
      expect(find.text('6개 생활관 정상 운영'), findsOneWidget);
      expect(find.text('6개 생활관 전수 거주인 현황'), findsOneWidget);
      expect(find.text('총 36명'), findsOneWidget);
      expect(find.text('전체 (36)'), findsOneWidget);
      // 모니터링: 열린 이상 건 2건 (이서준 · 박승민)
      expect(find.text('${repo.openCases.length}건 활성'), findsOneWidget);
      expect(repo.openCases.length, 2);
      expect(find.text('의료호출 발송완료'), findsWidgets);
      // 표: 이상 있는 별님이 위 (이서준 → 박승민), 10명씩
      expect(find.text('1 - 10 / 36'), findsOneWidget);
      final seojun = tester.getTopLeft(find.text('이서준'));
      final seungmin = tester.getTopLeft(find.text('박승민'));
      final yuna = tester.getTopLeft(find.text('임유나'));
      expect(seojun.dy, lessThan(seungmin.dy));
      expect(seungmin.dy, lessThan(yuna.dy));
      expect(find.text('의료호출 연결됨'), findsOneWidget); // 이서준 긴급 호출
      expect(find.text('이상 고온'), findsNWidgets(2));
      // 오른쪽: 타임라인 · 인계 · 결재
      expect(find.text('실시간 응급·의료 타임라인'), findsOneWidget);
      expect(find.text('LIVE FEED'), findsOneWidget);
      expect(find.text('교대 근무조 인계 및 공지'), findsOneWidget);
      expect(find.text('일괄 확인 (2건)'), findsOneWidget);
      expect(find.text('고래자리 박승민 비상 해열제 선투약 품의'), findsOneWidget);
      expect(find.text('오늘 10:00 목욕실 온수 보일러 점검 안내'), findsOneWidget);
      expect(find.byType(ExampleWrap), findsNothing);
    });

    testWidgets('1280폭 (가장 좁은 PC)에서도 넘치지 않는다', (tester) async {
      await pumpPage(tester, width: 1280);
      expect(tester.takeException(), isNull);
    });

    testWidgets('생활관 필터 칩 · 페이지 나누기 · 생활관 요약 칩', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('고래자리 (6)'));
      expect(find.text('1 - 6 / 6'), findsOneWidget);
      expect(find.text('박승민'), findsOneWidget);
      expect(find.text('이서준'), findsNothing);

      await tapVisible(tester, find.text('전체 (36)'));
      expect(find.text('1 - 10 / 36'), findsOneWidget);
      await tapVisible(tester, find.text('다음 10명'));
      expect(find.text('11 - 20 / 36'), findsOneWidget);
      await tapVisible(tester, find.text('이전 10명'));
      expect(find.text('1 - 10 / 36'), findsOneWidget);

      // 아래 생활관 요약 칩을 누르면 그 반으로 거른다.
      await tapVisible(tester, find.text('물병자리'));
      expect(find.text('1 - 7 / 7'), findsOneWidget);
      expect(find.text('한나리'), findsOneWidget);
    });

    testWidgets('열린 호출이 있는 줄을 누르면 의료 호출함으로 간다', (tester) async {
      await pumpPage(tester);
      final call = repo.openCalls.firstWhere((c) => c.residentId == rid('이서준'));
      await tapVisible(tester, find.text('이서준'));
      expect(container.read(pcPageProvider), PcPage.calls);
      expect(container.read(selectedCallProvider), call.id);
    });

    testWidgets('호출 없는 줄은 별님 상태 창 → 의료 호출 보내기', (tester) async {
      await pumpPage(tester);
      final before = repo.openCalls.length;
      await tapVisible(tester, find.text('임유나'));
      expect(find.text('임유나 별님'), findsOneWidget);
      expect(find.text('최근 체온'), findsOneWidget);
      await tapVisible(tester, find.text('의료 호출 보내기'));
      expect(repo.openCalls.length, before + 1);
      final c = repo.openCalls.firstWhere((c) => c.residentId == rid('임유나'));
      expect(container.read(selectedCallProvider), c.id);
      expect(container.read(pcPageProvider), PcPage.calls);
    });

    testWidgets('결재: 하나씩 승인 · 일괄 확인 → 승인 완료(초록) + 완료 안내', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('승인').first);
      expect(repo.pendingApprovals.length, 1);
      expect(find.text('일괄 확인 (1건)'), findsOneWidget);
      await waitToast(tester);

      await tapVisible(tester, find.text('일괄 확인 (1건)'));
      expect(repo.pendingApprovals, isEmpty);
      expect(repo.approvals.every((a) => a.approvedBy == 'park_soyeon'), isTrue);
      expect(find.text('승인 완료'), findsOneWidget);
      expect(find.text('대기 중인 결재 업무가 모두 완료되었습니다.'), findsOneWidget);
      expect(find.text('0건 대기'), findsOneWidget);
      await waitToast(tester);
    });

    testWidgets('타임라인: 호출 열기 · 현장 확인 요청', (tester) async {
      await pumpPage(tester);
      final call = repo.calls.where((c) => c.isOpen).reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
      final msgs = repo.messagesOf(call.id).length;
      await tapVisible(tester, find.text('현장 확인 요청').first);
      expect(repo.messagesOf(call.id).length, msgs + 1);
      expect(repo.messagesOf(call.id).last.authorId, 'park_soyeon');
      await waitToast(tester);

      await tapVisible(tester, find.text('호출 열기').first);
      expect(container.read(pcPageProvider), PcPage.calls);
      expect(container.read(selectedCallProvider), call.id);
    });

    testWidgets('인계 리포트 인쇄 → 인쇄 대신 요약 창 + 안내', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('인계 리포트 인쇄'));
      expect(find.text('인계 리포트'), findsOneWidget);
      expect(find.textContaining('인쇄는 아직 연결되지 않아'), findsOneWidget);
      expect(find.text('열린 이상 건 · 체온 이상'), findsOneWidget);
      await tapVisible(tester, find.text('닫기'));
      expect(find.text('인계 리포트'), findsNothing);
      await waitToast(tester);
    });

    testWidgets('이상 알림 이력: 모든 알림 목록 + 본 것으로 표시', (tester) async {
      await pumpPage(tester);
      expect(repo.unseenNoticeCount('park_soyeon'), greaterThan(0));
      await tapVisible(tester, find.text('이상 알림 이력'));
      expect(find.textContaining('전체 ${repo.allNotices.length}건'), findsOneWidget);
      expect(find.textContaining('새 이상 대응'), findsWidgets);
      expect(repo.unseenNoticeCount('park_soyeon'), 0);
    });

    testWidgets('긴급 방송/호출: 별님 골라 긴급 호출을 보낸다', (tester) async {
      await pumpPage(tester);
      final before = repo.openCalls.length;
      await tapVisible(tester, find.text('긴급 방송/호출'));
      await tapVisible(tester, find.text('물병자리 · 임유나'));
      await tapVisible(tester, find.text('긴급 호출 보내기'));
      expect(repo.openCalls.length, before + 1);
      final c = repo.openCalls.firstWhere((c) => c.residentId == rid('임유나'));
      expect(c.level, CallLevel.urgent);
      expect(c.createdBy, 'park_soyeon');
      expect(find.textContaining('임유나 별님 긴급 호출을 보냈어요'), findsOneWidget);
      await waitToast(tester);
    });

    testWidgets('새로고침 버튼은 0.7초 돌고 다시 그린다', (tester) async {
      await pumpPage(tester);
      final spin = find.ancestor(of: find.byIcon(Icons.sync_rounded), matching: find.byType(RotationTransition));
      await tester.tap(find.byIcon(Icons.sync_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final turns = tester.widget<RotationTransition>(spin).turns.value;
      expect(turns, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<RotationTransition>(spin).turns.value, 1);
    });

    testWidgets('명부: 반별 표 + 반 추가 · 별님 추가', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('전체 거주인 명부'));
      expect(find.text('전체 거주인 명부'), findsNWidgets(2));
      expect(find.text('반 추가'), findsWidgets);

      await tester.enterText(find.byKey(const ValueKey('roster-class-name')), '햇살자리');
      await tester.enterText(find.byKey(const ValueKey('roster-class-room')), '301호');
      await tapVisible(tester, find.byKey(const ValueKey('roster-add-class')));
      final cls = repo.classes.firstWhere((c) => c.name == '햇살자리');
      expect(cls.room, '301호');
      await waitToast(tester);

      await tester.enterText(find.byKey(const ValueKey('roster-resident-name')), '김햇살');
      await tester.enterText(find.byKey(const ValueKey('roster-resident-age')), '22');
      await tapVisible(tester, find.byKey(const ValueKey('roster-add-resident')));
      final r = repo.residents.firstWhere((r) => r.name == '김햇살');
      expect(r.classId, cls.id);
      expect(r.age, 22);
      await waitToast(tester);

      await tapVisible(tester, find.byIcon(Icons.close_rounded));
      expect(find.text('전체 (37)'), findsOneWidget);
      expect(find.text('햇살자리 (1)'), findsOneWidget);
    });
  });

  group('개발 DB', () {
    testWidgets('빈 자리마다 예시 카드 · 예시 명단', (tester) async {
      await pumpPage(tester, dataset: Dataset.dev);
      expect(tester.takeException(), isNull);
      expect(find.byType(ExampleWrap), findsWidgets);
      expect(find.text('예시 별님'), findsOneWidget);
      expect(find.text('전체 (1)'), findsOneWidget);
      expect(find.text('[예시반] 예시 별님 (38.2℃ 고온 감지)'), findsOneWidget); // 타임라인 예시
      expect(find.text('예시 · 비상 해열제 선투약 품의'), findsOneWidget); // 결재 예시
      expect(find.text('일괄 확인 (0건)'), findsOneWidget);
    });

    testWidgets('명부에서 실제 반 · 별님을 넣으면 예시 명단이 사라진다', (tester) async {
      await pumpPage(tester, dataset: Dataset.dev);
      await tapVisible(tester, find.text('전체 거주인 명부'));
      expect(find.textContaining('지금은 예시 명단이에요'), findsOneWidget);
      expect(find.text('먼저 위에서 반을 추가해 주세요'), findsOneWidget);

      // 빈 이름은 막는다
      await tapVisible(tester, find.byKey(const ValueKey('roster-add-class')));
      expect(find.text('반 이름을 적어 주세요'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('roster-class-name')), '은하수자리');
      await tapVisible(tester, find.byKey(const ValueKey('roster-add-class')));
      await waitToast(tester);
      await tester.enterText(find.byKey(const ValueKey('roster-resident-name')), '이별님');
      await tapVisible(tester, find.byKey(const ValueKey('roster-add-resident')));
      await waitToast(tester);
      expect(repo.rosterIsExample, isFalse);
      expect(find.textContaining('지금은 예시 명단이에요'), findsNothing);

      await tapVisible(tester, find.byIcon(Icons.close_rounded));
      expect(find.text('예시 별님'), findsNothing);
      expect(find.text('이별님'), findsOneWidget);
      expect(find.text('전체 (1)'), findsOneWidget);
      expect(find.text('은하수자리 (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('PC 셸 안에서 기본 화면으로 열린다', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = InMemoryRepository(clock: () => at);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repoProvider.overrideWith((_) => repo), screenKindProvider.overrideWithValue('pc')],
        child: MaterialApp(theme: buildTheme(), home: const PcShell()),
      ),
    );
    await tester.pump();
    expect(find.byType(PcDashboardPage), findsOneWidget);
    expect(find.text('울산 혜진원 통합 관제 현황판'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
