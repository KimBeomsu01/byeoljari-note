// 이상 대응 S1·S2·S3·S5·S7 화면 흐름 (통합 명세 12장 시연 2·4·5·7·8·9단계).
import 'package:byeoljari_note/app.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/routes.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:byeoljari_note/features/alert_case/case_detail_screen.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void setSize(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

class Harness {
  Harness(this.tester);
  final WidgetTester tester;

  BuildContext get home => tester.element(find.byType(AppShell, skipOffstage: false));
  ProviderContainer get container => ProviderScope.containerOf(home);
  InMemoryRepository get repo => container.read(repoProvider);

  Future<void> start() async {
    await tester.pumpWidget(const ProviderScope(child: ByeoljariApp()));
    await tester.pumpAndSettle();
  }

  Future<void> switchTo(String staffId) async {
    container.read(currentUserProvider.notifier).state = staffId;
    await tester.pumpAndSettle();
  }

  Future<void> toRoot() async {
    Navigator.of(home).popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
  }

  Future<void> dismissBanner() async {
    final close = find.byTooltip('알림 닫기');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await tester.pumpAndSettle();
    }
  }

  Future<void> openCase(String caseId) async {
    await toRoot();
    await dismissBanner();
    openCaseDetail(home, caseId);
    await tester.pumpAndSettle();
  }

  /// 위에서 내려온 알림 배너가 버튼을 가리지 않도록 화면 가운데로 끌어온다.
  Future<void> tap(Finder f) async {
    final el = tester.element(f);
    if (Scrollable.maybeOf(el) != null) {
      await Scrollable.ensureVisible(el, alignment: 0.5);
    }
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(String text) => tap(find.text(text).last);

  /// 퀵 체온으로 체온 저장 (0.5초 누름) → S1까지.
  Future<void> saveViaQuickTemp(String residentId, int value) async {
    container.read(quickTempProvider.notifier).openFor(residentId);
    container.read(quickTempProvider.notifier).setValue(value);
    await tester.pumpAndSettle();
    final g = await tester.startGesture(tester.getCenter(find.text('눌러서 기록')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }
}

Finder inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

void main() {
  testWidgets('시연 흐름: 38.4 이상 대응 → 간호사 확인·담당·투약 기록 → 39.1 긴급 → 원장 병원 지시 → 간호사 종료', (tester) async {
    setSize(tester, 400, 820);
    final h = Harness(tester);
    await h.start();
    final seojun = residentByName('이서준').id;

    // ── 김하늘: 퀵 체온 38.4 → S1
    await h.saveViaQuickTemp(seojun, 384);
    expect(inSheet('▲ 이상 대응'), findsOneWidget);
    expect(find.text('38.4℃ · 평소보다 +1.3℃ · 이상'), findsOneWidget);
    expect(find.text('아직 아무도 확인 안 함'), findsOneWidget);
    expect(find.text('간호사에게 전화'), findsOneWidget);
    expect(find.text('새 이상 대응'), findsNothing, reason: '내가 잰 체온의 알림은 배너로 띄우지 않는다');
    final caseId = h.repo.openCaseOf(seojun)!.id;

    // S1 [자세히 보기] → S3
    await h.tapText('자세히 보기');
    expect(find.byType(CaseDetailScreen), findsOneWidget);
    expect(find.text('이서준 · 이상 대응'), findsOneWidget);
    expect(find.text('미확인'), findsOneWidget);
    expect(find.text('① 관찰·재측정'), findsOneWidget);
    // 생활관은 투약 기록 권한이 없다: 흐리게 + 누르면 이유
    await h.tapText('투약 기록');
    expect(find.text('간호사·원장님만 투약을 기록할 수 있어요'), findsOneWidget);

    // ── 간호사 박소연: 배너 → S3 → 확인 → 담당 → 투약 기록
    await h.toRoot();
    await h.switchTo('park_soyeon');
    expect(find.text('새 이상 대응'), findsOneWidget, reason: '역할을 바꾸면 안 본 알림이 배너로');
    await h.tap(find.text('새 이상 대응'));
    expect(find.text('이서준 · 이상 대응'), findsOneWidget);

    await h.tapText('확인했어요');
    expect(h.repo.caseById(caseId).status, CaseStatus.acked);
    expect(find.textContaining('박소연 간호사 '), findsWidgets); // 확인한 사람 줄
    await h.tapText('제가 맡을게요');
    expect(h.repo.caseById(caseId).assigneeId, 'park_soyeon');
    expect(find.text('박소연 간호사'), findsOneWidget, reason: '담당');
    expect(h.repo.noticesFor('kim_haneul').first.body, '박소연 간호사가 맡았어요');

    await h.tapText('투약 기록');
    expect(find.text('기록하기'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '지침대로 해열제 줌 (원장님 전화 지시)');
    await tester.pump();
    await h.tapText('기록하기');
    expect(find.text('② 원내 조제로 올릴까요?'), findsOneWidget);
    await h.tapText('올리기');
    expect(h.repo.caseById(caseId).stage, 2);
    expect(find.text('💊 투약 기록 · 지침대로 해열제 줌 (원장님 전화 지시)'), findsOneWidget);

    // 조치 기록 → 기록 취소 (지우지 않고 취소 표시)
    await h.tapText('조치 기록');
    await h.tapText('💧 수분 섭취');
    await h.tapText('기록하기');
    expect(find.text('📝 💧 수분 섭취'), findsOneWidget);
    await h.tap(find.text('기록 취소').last);
    await h.tapText('취소 표시');
    expect(find.textContaining('취소됨 (박소연 간호사)'), findsOneWidget);
    expect(find.text('📝 💧 수분 섭취'), findsOneWidget, reason: '기록은 남아 있다');
    expect(h.repo.eventsOf(caseId).where((e) => e.type == 'note').single.voidedBy, 'park_soyeon');

    // ── 김하늘: 39.1 → 긴급
    await h.toRoot();
    await h.switchTo('kim_haneul');
    final r2 = h.repo.saveMeasurement(residentId: seojun, value: 391, by: 'kim_haneul', at: h.repo.now());
    await tester.pumpAndSettle();
    expect(r2.escalated, isTrue);
    await h.openCase(caseId);
    expect(find.text('⚠ 긴급'), findsOneWidget);
    expect(find.text('이서준 · 긴급'), findsOneWidget);
    expect(find.text('처음 38.4℃ → 최근 39.1℃'), findsOneWidget);

    // ── 원장 한경수: 중요 알림 배너 → [병원으로 보내세요] → 단계 ④
    await h.toRoot();
    await h.switchTo('han_kyungsoo');
    expect(find.text('중요 알림 · 긴급으로 바뀌었어요'), findsOneWidget);
    await h.tap(find.text('중요 알림 · 긴급으로 바뀌었어요'));
    expect(find.text('이서준 · 긴급'), findsOneWidget);
    await h.tapText('병원으로 보내세요');
    await h.tapText('보내기');
    expect(h.repo.caseById(caseId).stage, 4);
    expect(find.text('🩺 원장님 지시 · 병원으로 보내세요'), findsOneWidget);
    expect(find.text('병원 결과 기록'), findsOneWidget);

    // ── 간호사: 병원 결과 기록 → 대응 종료
    await h.toRoot();
    await h.switchTo('park_soyeon');
    await h.openCase(caseId);
    await h.tapText('병원 결과 기록');
    await h.tapText('진료 후 귀원');
    await h.tapText('기록하기');
    expect(find.text('🏥 병원 · 진료 후 귀원'), findsOneWidget);
    await h.tapText('대응 종료');
    await h.tapText('병원 진료 후 귀원');
    await h.tapText('종료하기');
    final closed = h.repo.caseById(caseId);
    expect(closed.isOpen, isFalse);
    expect(closed.closeReason, '병원 진료 후 귀원');
    expect(find.text('종료'), findsWidgets);
    expect(find.text('종료된 건이에요. 기록은 그대로 남아 있어요.'), findsOneWidget);
    expect(find.text('대응 종료'), findsNothing);

    // ── 사무국 박서연: 보기만 (진행 중인 박승민 건)
    await h.toRoot();
    await h.switchTo('park_seoyeon');
    final seungmin = h.repo.openCaseOf(residentByName('박승민').id)!;
    await h.openCase(seungmin.id);
    expect(find.byType(CaseDetailScreen), findsOneWidget);
    for (final t in ['확인했어요', '제가 맡을게요', '재측정 입력', '투약 기록', '단계 올리기', '대응 종료', '30분 뒤 다시 재기']) {
      expect(find.text(t), findsNothing, reason: '사무국에는 $t 버튼이 없다');
    }
    expect(find.textContaining('사무국은 보기만 할 수 있어요'), findsOneWidget);
    expect(find.text('투약 지침 보기'), findsOneWidget);
  });

  testWidgets('종료 대기: 평소로 내려오면 [한 번 더 재고 종료하기]/[지금 종료하기]', (tester) async {
    setSize(tester, 400, 820);
    final h = Harness(tester);
    await h.start();
    final seungminId = residentByName('박승민').id;
    final c = h.repo.openCaseOf(seungminId)!;
    h.repo.saveMeasurement(residentId: seungminId, value: 368, by: 'park_soyeon', at: h.repo.now());
    await h.switchTo('park_soyeon');
    await h.openCase(c.id);
    expect(find.text('종료 대기'), findsOneWidget);
    expect(find.text('한 번 더 재고 종료하기'), findsOneWidget);
    await h.tapText('지금 종료하기');
    expect(find.text('대응을 종료할까요?'), findsOneWidget);
    await h.tapText('종료하기');
    expect(h.repo.caseById(c.id).closeReason, '평소 체온으로 회복');
  });

  testWidgets('생활관 선생님: 권한 없는 반은 재측정 입력이 잠기고, 종료는 담당·간호사만', (tester) async {
    setSize(tester, 400, 820);
    final h = Harness(tester);
    await h.start();
    final c = h.repo.openCaseOf(residentByName('박승민').id)!; // 고래자리, 김하늘은 은하수자리만
    await h.openCase(c.id);
    await h.tapText('재측정 입력');
    expect(find.text('이 반 체온 입력 권한이 없어요'), findsOneWidget);
    expect(find.byType(CaseDetailScreen), findsOneWidget);
    await h.tapText('대응 종료');
    expect(find.text('담당자·간호사·원장님이 종료할 수 있어요'), findsOneWidget);
    // [재측정 입력]은 퀵 체온을 그 별님으로 연다 (이서준: 김하늘 권한 있음)
    final seojun = residentByName('이서준').id;
    h.repo.saveMeasurement(residentId: seojun, value: 384, by: 'kim_haneul', at: h.repo.now());
    await h.openCase(h.repo.openCaseOf(seojun)!.id);
    await h.tapText('재측정 입력');
    expect(find.byType(CaseDetailScreen), findsNothing);
    final qt = h.container.read(quickTempProvider);
    expect(qt.open, isTrue);
    expect(qt.residentId, seojun);
  });

  testWidgets('작은 폰(360×640)에서 S1·S3가 넘치지 않는다', (tester) async {
    setSize(tester, 360, 640);
    final h = Harness(tester);
    await h.start();
    final seojun = residentByName('이서준').id;
    await h.saveViaQuickTemp(seojun, 391); // 위험: 전화 버튼이 맨 위
    expect(tester.takeException(), isNull);
    expect(inSheet('⚠ 긴급'), findsOneWidget);
    expect(inSheet('간호사에게 전화'), findsOneWidget);
    await h.tapText('자세히 보기');
    await h.switchTo('han_kyungsoo');
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('별님 카드로'), findsOneWidget);
  });
}
