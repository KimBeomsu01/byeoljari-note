// PC 02 통합 일정 관리 (Claude Design PcSchedule.dc.html) 화면 흐름.
// 시연 DB = 2026-10-28(수) 14:00 고정 시계 (오늘 일과 10건). 개발 DB = 예시 일정.
import 'package:byeoljari_note/core/ds.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/theme.dart';
import 'package:byeoljari_note/features/pc/pc_schedule_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final at = DateTime(2026, 10, 28, 14, 0);
final today = DateTime(2026, 10, 28);

void main() {
  late InMemoryRepository repo;

  /// PC 셸과 같은 자리 (레일 80 + 머리 64) 안에 일정 화면만 그린다.
  Future<void> pumpPage(WidgetTester tester, {Dataset dataset = Dataset.demo, double width = 1440}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = InMemoryRepository(dataset: dataset, clock: () => at);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repoProvider.overrideWith((_) => repo), screenKindProvider.overrideWithValue('pc')],
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
                      Expanded(child: PcSchedulePage()),
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

  Future<void> waitToast(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

  group('시연 DB', () {
    testWidgets('월간 캘린더 · 오늘 칸 · 공휴일 · 선택 일과표 (1440폭에서 넘치지 않음)', (tester) async {
      await pumpPage(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('혜진원 시설 & 생활관 통합 일정 관리'), findsOneWidget);
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.text('오늘 (2026. 10. 28 수)'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('일 (SUN)'), findsOneWidget);
      // 공휴일 표시
      expect(find.text('개천절'), findsOneWidget);
      expect(find.text('한글날'), findsOneWidget);
      // 오늘 칸: 최대 2건 + 나머지
      final n = repo.calendarOn(today).length;
      expect(n, 10);
      expect(find.text('외 ${n - 2}건 추가'), findsOneWidget);
      // 범례 5색
      for (final c in CalendarCategory.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      // 선택 일과표 = 오늘
      expect(find.text('선택 일과표'), findsOneWidget);
      expect(find.text('2026년 10월 28일 (수)'), findsOneWidget);
      expect(find.text('총 10건의 일정'), findsOneWidget);
      expect(find.text('전체 온수 보일러 점검 및 난방 시운전'), findsOneWidget);
      expect(find.text('관리팀 박서연'), findsOneWidget);
      expect(find.text('생활관 필터:'), findsOneWidget);
      expect(find.text('전체 생활관 (6개 반)'), findsOneWidget);
      expect(find.text('고래자리 (중증 1명)'), findsOneWidget);
      expect(find.byType(ExampleWrap), findsNothing);
    });

    testWidgets('1280폭 (가장 좁은 PC)에서도 넘치지 않는다', (tester) async {
      await pumpPage(tester, width: 1280);
      expect(tester.takeException(), isNull);
    });

    testWidgets('날짜를 누르면 선택 일과표가 그 날로 바뀐다', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('09:30 특수교육 개학'));
      expect(find.text('2026년 10월 5일 (월)'), findsOneWidget);
      expect(find.text('총 2건의 일정'), findsOneWidget);
      expect(find.text('특수교육 개학'), findsOneWidget);
      expect(find.text('수질 검사'), findsOneWidget);
    });

    testWidgets('일과표 검색은 글자로 거른다', (tester) async {
      await pumpPage(tester);
      await tester.enterText(find.byKey(const ValueKey('agenda-search')), '물리');
      await tester.pumpAndSettle();
      expect(find.text('2층 물리치료실 관절 가동성 훈련'), findsOneWidget);
      expect(find.text('전체 온수 보일러 점검 및 난방 시운전'), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('agenda-search')), '없는말');
      await tester.pumpAndSettle();
      expect(find.text('"없는말"에 맞는 일정이 없어요'), findsOneWidget);
    });

    testWidgets('생활관 필터는 선택 표시 + 다른 반 일정을 숨긴다', (tester) async {
      await pumpPage(tester);
      expect(find.text('13:00 물병자리 목욕'), findsOneWidget);
      await tapVisible(tester, find.text('은하수자리'));
      expect(find.text('13:00 물병자리 목욕'), findsNothing);
      // 시설 전체 일정 + 은하수자리 일정은 남는다
      expect(find.text('총 10건의 일정'), findsOneWidget);
      await tapVisible(tester, find.text('곰자리'));
      expect(find.text('총 8건의 일정'), findsOneWidget);
      expect(find.text('1층 개별화 교육실 인지 촉진 활동'), findsNothing);
      await tapVisible(tester, find.text('전체 생활관 (6개 반)'));
      expect(find.text('13:00 물병자리 목욕'), findsOneWidget);
    });

    testWidgets('+ 일정 등록: 분류 선택 · 빈 이름 막기 · 등록하면 캘린더와 일과표에 반영', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.byKey(const ValueKey('schedule-create')));
      expect(find.text('신규 일정 등록'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('event-submit')));
      expect(find.text('일정명을 적어 주세요'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('event-title')), '소화 설비 점검');
      await tester.enterText(find.byKey(const ValueKey('event-owner')), '관리팀 박서연');
      await tapVisible(tester, find.text('촉탁의 진료'));
      await tapVisible(tester, find.byKey(const ValueKey('event-submit')));
      expect(find.text('신규 일정 등록'), findsNothing);

      final e = repo.calendarOn(today).firstWhere((e) => e.title == '소화 설비 점검');
      expect(e.category, CalendarCategory.medical);
      expect(e.time, '10:00');
      expect(e.createdBy, 'park_soyeon');
      expect(find.text('총 11건의 일정'), findsOneWidget);
      expect(find.text('소화 설비 점검'), findsOneWidget);
      expect(find.text('신규 일정이 성공적으로 등록되었으며 실시간 타임라인에 반영되었습니다.'), findsOneWidget);
      await waitToast(tester);
    });

    testWidgets('달 이동 · 오늘 · 달 고르기', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.byTooltip('다음 달'));
      expect(find.text('2026년 11월'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
      await tapVisible(tester, find.byTooltip('이전 달'));
      await tapVisible(tester, find.byTooltip('이전 달'));
      expect(find.text('2026년 9월'), findsOneWidget);
      expect(find.text('추석'), findsWidgets);
      await tapVisible(tester, find.text('오늘 (2026. 10. 28 수)'));
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);

      await tapVisible(tester, find.text('2026년 10월'));
      await tapVisible(tester, find.text('2026년 12월').last);
      expect(find.text('25'), findsWidgets);
      expect(find.text('성탄절'), findsOneWidget);
    });

    testWidgets('보기 탭: 주간 · 일간 · 목록 · 월간', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('주간 뷰'));
      expect(find.text('10/28'), findsOneWidget);
      expect(find.text('10/25'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.byTooltip('다음 주'));
      expect(find.text('11/4'), findsOneWidget);
      expect(find.text('2026년 11월 4일 (수)'), findsOneWidget);

      await tapVisible(tester, find.text('오늘 (2026. 10. 28 수)'));
      await tapVisible(tester, find.text('일간 시간표'));
      expect(find.text('2026년 10월 28일 (수) 일간 시간표'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapVisible(tester, find.text('목록형 전체보기'));
      final month = repo.calendarEvents.where((e) => e.date.year == 2026 && e.date.month == 10).length;
      expect(find.text('2026년 10월 전체 일정 $month건'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapVisible(tester, find.text('월간 캘린더'));
      expect(find.text('TODAY'), findsOneWidget);
    });

    testWidgets('일정 상세 · 엑셀 · 인쇄 버튼', (tester) async {
      await pumpPage(tester);
      await tapVisible(tester, find.text('2층 물리치료실 관절 가동성 훈련'));
      expect(find.text('일정 상세'), findsOneWidget);
      expect(find.text('물리치료사 이원호'), findsWidgets);
      await tapVisible(tester, find.text('닫기'));

      await tapVisible(tester, find.text('엑셀(XLSX) 가져오기 / 내보내기'));
      expect(find.textContaining('엑셀 파일 가져오기 · 내보내기는 아직 연결되지 않았어요'), findsOneWidget);
      await waitToast(tester);
      await tapVisible(tester, find.text('일과표 인쇄'));
      expect(find.textContaining('인쇄 기능은 아직 연결되지 않았어요'), findsOneWidget);
      await waitToast(tester);
    });
  });

  group('개발 DB', () {
    testWidgets('일정이 없으면 오늘 칸 · 일과표에 예시, 등록하면 사라진다', (tester) async {
      await pumpPage(tester, dataset: Dataset.dev);
      expect(tester.takeException(), isNull);
      expect(find.text('10:00 예시 일정'), findsOneWidget);
      expect(find.byType(ExampleWrap), findsOneWidget);
      expect(find.text('예시 · 온수 보일러 정기 점검'), findsOneWidget);
      expect(find.text('전체 생활관 (1개 반)'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('schedule-create')));
      await tester.enterText(find.byKey(const ValueKey('event-title')), '첫 일정');
      await tapVisible(tester, find.byKey(const ValueKey('event-submit')));
      expect(repo.calendarEvents.length, 1);
      expect(find.text('10:00 예시 일정'), findsNothing);
      expect(find.byType(ExampleWrap), findsNothing);
      expect(find.text('첫 일정'), findsOneWidget);
      expect(find.text('10:00 첫 일정'), findsOneWidget);
      await waitToast(tester);
    });
  });
}
