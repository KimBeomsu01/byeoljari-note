// 03 체온 측정 (QuickVital): 반·별님 다이얼, ±·프리셋·링 돌리기, 길게 눌러 기록, 알림 시트, 잘못 쟀어요.
// 다른 화면이 고쳐지는 중이어도 이 화면만 보도록 app.dart 대신 같은 틀(Scaffold + 탭 바 64)에 띄운다.
import 'dart:math' as math;

import 'package:byeoljari_note/core/ds.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:byeoljari_note/core/theme.dart';
import 'package:byeoljari_note/features/alert_case/alert_sheet.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_controller.dart';
import 'package:byeoljari_note/features/quick_temp/quick_temp_screen.dart';
import 'package:byeoljari_note/core/photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _clock = DateTime(2026, 10, 28, 14, 0);

class _Harness {
  _Harness(this.repo, this.container);
  final InMemoryRepository repo;
  final ProviderContainer container;
  QuickTempState get st => container.read(quickTempProvider);
  QuickTempController get ctrl => container.read(quickTempProvider.notifier);
}

Future<_Harness> _open(
  WidgetTester tester, {
  Dataset dataset = Dataset.demo,
  Size size = const Size(390, 844),
  String? user,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = InMemoryRepository(dataset: dataset, clock: () => _clock);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repoProvider.overrideWith((_) => repo),
      screenKindProvider.overrideWithValue('mobile'),
    ],
    child: MaterialApp(
      theme: buildTheme(),
      home: const Scaffold(body: QuickTempScreen(), bottomNavigationBar: SizedBox(height: 64)),
    ),
  ));
  final container = ProviderScope.containerOf(tester.element(find.byType(QuickTempScreen)));
  if (user != null) container.read(currentUserProvider.notifier).state = user;
  container.read(quickTempProvider.notifier).toggle();
  await tester.pump();
  await _settle(tester);
  return _Harness(repo, container);
}

/// 알림 시트의 빨간 점이 계속 깜빡여서 pumpAndSettle 대신 시간만 흘린다.
Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 가운데 버튼을 [ms] 동안 누른다.
Future<void> _hold(WidgetTester tester, int ms) async {
  final g = await tester.startGesture(tester.getCenter(find.text('길게 눌러서')));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(Duration(milliseconds: ms));
  await g.up();
  await tester.pump();
}

int _base(InMemoryRepository repo, String rid) => repo.baselineOf(rid, repo.now()).value;

void main() {
  testWidgets('처음: 담당 반(은하수자리) 첫 별님이 가운데, 평소 체온에서 시작', (tester) async {
    final h = await _open(tester);
    final minjun = residentByName('김민준').id;
    expect(find.text('은하수자리'), findsOneWidget);
    expect(find.text('물병자리'), findsNothing, reason: '김하늘 선생님은 은하수자리만 잴 수 있다');
    expect(h.st.residentId, minjun);
    expect(h.st.level, QtLevel.resident);
    expect(find.text('김민준'), findsOneWidget, reason: '선택한 별님은 이름 전체');
    expect(find.text('서준'), findsWidgets, reason: '나머지는 이름 두 글자');
    final base = _base(h.repo, minjun);
    expect(h.st.value, base);
    expect(find.text((base / 10).toStringAsFixed(1)), findsOneWidget);
    expect(find.text('평소 ${(base / 10).toStringAsFixed(1)}°'), findsOneWidget);
    expect(find.text('± 0.0°'), findsOneWidget);
    expect(find.textContaining('최근 기록 '), findsOneWidget);
    expect(find.byType(ExampleTag), findsNothing);
  });

  testWidgets('반·별님 선택: 탭 · 좌우 밀기 · 위아래 밀기 (반 2개는 나란히)', (tester) async {
    final h = await _open(tester, user: 'park_jieun'); // 물병자리 · 은하수자리
    expect(find.text('물병자리'), findsOneWidget);
    expect(find.text('은하수자리'), findsOneWidget);
    expect(h.st.classId, 'aquarius');
    expect(h.st.residentId, residentByName('임유나').id);

    // 반 탭 → 반 단계 (별님 선택 해제)
    await tester.tap(find.text('은하수자리'));
    await _settle(tester);
    expect(h.st.classId, 'milkyway');
    expect(h.st.level, QtLevel.classes);
    expect(find.text('별님을 선택해 주세요'), findsOneWidget);
    expect(find.text('김민준'), findsNothing);

    // 별님 탭 → 별님 단계
    await tester.tap(find.text('서준').first);
    await _settle(tester);
    expect(h.st.level, QtLevel.resident);
    expect(h.st.residentId, residentByName('이서준').id);
    expect(find.text('이서준'), findsOneWidget);
    expect(h.st.value, _base(h.repo, residentByName('이서준').id), reason: '별님을 고르면 평소 체온에서 시작');

    // 별님 다이얼 왼쪽으로 밀기 → 다음 별님
    await tester.drag(find.text('이서준'), const Offset(-60, 0));
    await _settle(tester);
    expect(h.st.residentId, residentByName('한지호').id);
    // 체온 표시를 오른쪽으로 밀기 → 지금 단계(별님) 앞으로
    await tester.drag(find.textContaining('평소 '), const Offset(60, 0));
    await _settle(tester);
    expect(h.st.residentId, residentByName('이서준').id);

    // 위로 밀기 → 반 단계, 아래로 밀기 → 별님 단계
    await tester.drag(find.textContaining('평소 '), const Offset(0, -50));
    await _settle(tester);
    expect(h.st.level, QtLevel.classes);
    await tester.drag(find.text('별님을 선택해 주세요'), const Offset(0, 50));
    await _settle(tester);
    expect(h.st.level, QtLevel.resident);
    expect(h.st.residentId, residentByName('이서준').id, reason: '반 단계에서도 별님 자리는 남는다');

    // 반 다이얼 오른쪽으로 밀기 → 앞 반 (물병자리), 첫 별님
    await tester.drag(find.text('은하수자리'), const Offset(60, 0));
    await _settle(tester);
    expect(h.st.classId, 'aquarius');
    expect(h.st.level, QtLevel.classes);
  });

  testWidgets('반 3개 이상은 선택한 반이 가운데 (간호 선생님 = 전체 반)', (tester) async {
    final h = await _open(tester, user: 'park_soyeon');
    expect(h.ctrl.view().classes.length, 6);
    final center = tester.getSize(find.byType(QuickTempScreen)).width / 2;
    expect(tester.getCenter(find.text('물병자리')).dx, moreOrLessEquals(center, epsilon: 1));
    h.ctrl.selectClass('milkyway');
    await _settle(tester);
    expect(tester.getCenter(find.text('은하수자리')).dx, moreOrLessEquals(center, epsilon: 1));
    // 선택한 별님도 가운데
    h.ctrl.selectResident(residentByName('류은호').id);
    await _settle(tester);
    expect(tester.getCenter(find.text('류은호')).dx, moreOrLessEquals(center, epsilon: 1));
  });

  testWidgets('± 0.1° · 프리셋 · 링 돌리기 (34.0~42.0)', (tester) async {
    final h = await _open(tester);
    final base = h.st.value;
    await tester.tap(find.bySemanticsLabel('체온 증가'));
    await tester.pump();
    expect(h.st.value, base + 1);
    await tester.tap(find.bySemanticsLabel('체온 감소'));
    await tester.tap(find.bySemanticsLabel('체온 감소'));
    await tester.pump();
    expect(h.st.value, base - 1);

    await tester.tap(find.text('38.4°'));
    await tester.pump();
    expect(h.st.value, 384);
    expect(find.text('38.4'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('38.4도')), isSemantics(isSelected: true));
    expect(tester.getSemantics(find.bySemanticsLabel('36.5도')), isSemantics(isSelected: false));

    // 링을 시계 방향으로 95° 돌리면 9°마다 +0.1° → +1.0°
    final c = (tester.getCenter(find.text('-')) + tester.getCenter(find.text('+'))) / 2;
    const r = 105.0;
    Offset at(double deg) => c + Offset(math.sin(deg * math.pi / 180) * r, -math.cos(deg * math.pi / 180) * r);
    final g = await tester.startGesture(at(0));
    for (var d = 5.0; d <= 95; d += 5) {
      await g.moveTo(at(d));
    }
    await g.up();
    await tester.pump();
    expect(h.st.value, 394);
    expect(h.st.recorded, isNull);

    // 범위 끝에서 멈춘다
    h.ctrl.setValue(500);
    expect(h.st.value, 420);
    h.ctrl.nudge(-200);
    expect(h.st.value, 340);
  });

  testWidgets('0.5초 길게 눌러야 기록된다 (평소 체온이면 시트 없음)', (tester) async {
    final h = await _open(tester);
    final minjun = residentByName('김민준').id;
    final before = h.repo.measurementsOf(minjun).length;

    await _hold(tester, 300);
    expect(h.repo.measurementsOf(minjun).length, before, reason: '0.3초는 기록 안 됨');

    await _hold(tester, 600);
    expect(h.repo.measurementsOf(minjun).length, before + 1);
    final m = h.repo.latestOf(minjun)!;
    expect(m.value, _base(h.repo, minjun));
    expect(m.recordedBy, 'kim_haneul');
    expect(m.judgment.stage, Stage.normal);
    expect(find.text('체온 ${(m.value / 10).toStringAsFixed(1)}° 기록이 완료되었습니다.'), findsOneWidget);
    expect(find.byType(AlertActionSheet), findsNothing);

    // 반 단계에서 누르면 기록 대신 안내
    h.ctrl.setLevel(QtLevel.classes);
    await _settle(tester);
    await _hold(tester, 600);
    expect(h.repo.measurementsOf(minjun).length, before + 1);
    expect(find.text('별님을 먼저 선택해 주세요.'), findsOneWidget);
    await _settle(tester, 30); // 토스트 사라짐
    expect(find.text('별님을 먼저 선택해 주세요.'), findsNothing);
  });

  testWidgets('38.4 기록 → 알림 시트 + 간호 선생님 호출 · 통화 요청 · 30분 뒤 · 투약 지침', (tester) async {
    final h = await _open(tester);
    final minjun = residentByName('김민준').id;
    final callsBefore = h.repo.calls.length;
    await tester.tap(find.text('38.4°'));
    await tester.pump();
    await _hold(tester, 600);
    await _settle(tester);

    final m = h.repo.latestOf(minjun)!;
    expect(m.value, 384);
    expect(m.judgment.stage.opensCase, isTrue);
    final c = h.repo.openCaseOf(minjun)!;
    final call = h.repo.openCalls.where((x) => x.residentId == minjun).single;
    expect(h.repo.calls.length, callsBefore + 1);
    expect(call.caseId, c.id);
    expect(find.byType(AlertActionSheet), findsOneWidget);
    expect(find.text('간호 선생님에게 이상 알림이 전송됐어요'), findsOneWidget);
    expect(find.text('방금'), findsOneWidget);
    expect(find.text('▲ ${((384 - m.judgment.baseline) / 10).toStringAsFixed(1)}°'), findsOneWidget);

    // [간호 선생님 바로 통화] → 열린 호출에 통화 요청 (새 호출은 안 생김)
    await tester.ensureVisible(find.text('간호 선생님 바로 통화'));
    await tester.tap(find.text('간호 선생님 바로 통화'));
    await tester.pump();
    expect(h.repo.messagesOf(call.id).where((x) => x.body == callRequestText && x.authorId == 'kim_haneul'), hasLength(1));
    expect(h.repo.calls.length, callsBefore + 1);
    expect(find.text('간호 선생님에게 통화 요청을 보냈어요'), findsOneWidget);

    // [30분 뒤 다시 측정 알림] → 재측정 예약
    await tester.ensureVisible(find.text('30분 뒤 다시 측정 알림'));
    await tester.tap(find.text('30분 뒤 다시 측정 알림'));
    await tester.pump();
    expect(h.repo.caseById(c.id).remeasureAt, _clock.add(const Duration(minutes: 30)));
    expect(find.text('14:30에 다시 측정하도록 남겼어요'), findsOneWidget);

    // [투약 지침 확인] → 지침이 없으면 안내
    await tester.ensureVisible(find.text('투약 지침 확인'));
    await tester.tap(find.text('투약 지침 확인'));
    await _settle(tester);
    expect(find.text('김민준 투약 지침'), findsOneWidget);
    expect(find.text('등록된 지침이 없어요'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await _settle(tester);
    expect(find.text('김민준 투약 지침'), findsNothing);

    // 값을 바꾸면 시트는 사라진다
    await tester.tap(find.bySemanticsLabel('체온 감소'));
    await tester.pump();
    expect(find.byType(AlertActionSheet), findsNothing);
  });

  testWidgets('투약 지침은 의료진 글 그대로 (이서준)', (tester) async {
    final h = await _open(tester);
    final seojun = residentByName('이서준').id;
    h.ctrl.openFor(seojun);
    await _settle(tester);
    h.ctrl.setValue(384);
    await tester.pump();
    await _hold(tester, 600);
    await _settle(tester);
    // 이미 열린 이상 건 + 호출이 있어 재측정 값이 호출 대화에 붙는다 → 알림 전송 문구
    expect(find.text('간호 선생님에게 이상 알림이 전송됐어요'), findsOneWidget);
    await tester.ensureVisible(find.text('투약 지침 확인'));
    await tester.tap(find.text('투약 지침 확인'));
    await _settle(tester);
    expect(find.text('이서준 투약 지침'), findsOneWidget);
    expect(find.text(h.repo.guidelineOf(seojun)!.body), findsOneWidget);
  });

  testWidgets('잘못 쟀어요 → 무효 표시 (지우지 않음) · 새로 생긴 이상 건·호출은 오측정으로 끝', (tester) async {
    final h = await _open(tester);
    final minjun = residentByName('김민준').id;
    final count = h.repo.measurementsOf(minjun).length;
    h.ctrl.setValue(384);
    await tester.pump();
    await _hold(tester, 600);
    await _settle(tester);
    final m = h.st.recorded!.measurement;
    final caseId = h.repo.openCaseOf(minjun)!.id;
    final callId = h.repo.openCalls.where((x) => x.residentId == minjun).single.id;

    await tester.ensureVisible(find.text('잘못 쟀어요'));
    await tester.tap(find.text('잘못 쟀어요'));
    await _settle(tester);
    expect(h.repo.measurementsOf(minjun).length, count + 1, reason: '기록은 지우지 않는다');
    expect(h.repo.measurement(m.id).isVoided, isTrue);
    expect(h.repo.measurement(m.id).voidedBy, 'kim_haneul');
    expect(h.repo.caseById(caseId).isOpen, isFalse);
    expect(h.repo.callById(callId).isOpen, isFalse);
    expect(find.byType(AlertActionSheet), findsNothing);
    expect(find.text('기록을 취소했어요.'), findsOneWidget);
  });

  testWidgets('주의(평소 +0.5): 할 일이 생기고, 통화 요청은 새 긴급 호출로', (tester) async {
    final h = await _open(tester);
    final minjun = residentByName('김민준').id;
    h.ctrl.setValue(_base(h.repo, minjun) + 5);
    await tester.pump();
    await _hold(tester, 600);
    await _settle(tester);
    expect(h.repo.latestOf(minjun)!.judgment.stage, Stage.caution);
    expect(h.repo.openTempTasksOf(minjun), isNotEmpty);
    expect(find.text('30분 뒤 다시 측정할 일이 생겼어요'), findsOneWidget);

    await tester.ensureVisible(find.text('30분 뒤 다시 측정 알림'));
    await tester.tap(find.text('30분 뒤 다시 측정 알림'));
    await tester.pump();
    expect(find.text('14:30에 다시 측정할 일이 이미 생겼어요'), findsOneWidget);

    expect(h.repo.openCalls.where((c) => c.residentId == minjun), isEmpty);
    await tester.ensureVisible(find.text('간호 선생님 바로 통화'));
    await tester.tap(find.text('간호 선생님 바로 통화'));
    await tester.pump();
    final call = h.repo.openCalls.where((c) => c.residentId == minjun).single;
    expect(call.level, CallLevel.urgent);
    expect(call.summary, callRequestText);
  });

  testWidgets('권한 없는 반: 기록 버튼 비활성 + 이유', (tester) async {
    final h = await _open(tester);
    final seungmin = residentByName('박승민').id; // 고래자리 (김하늘 선생님은 은하수자리만)
    h.ctrl.openFor(seungmin);
    await _settle(tester);
    expect(find.text('고래자리'), findsOneWidget, reason: '열어 준 반은 다이얼에 보인다');
    expect(find.text('측정 권한 없음'), findsOneWidget);
    expect(find.text('담당 반이 아니에요'), findsOneWidget);
    final before = h.repo.measurementsOf(seungmin).length;
    final g = await tester.startGesture(tester.getCenter(find.text('측정 권한 없음')));
    await tester.pump(const Duration(milliseconds: 700));
    await g.up();
    await tester.pump();
    expect(h.repo.measurementsOf(seungmin).length, before);
    expect(find.text('고래자리 체온 측정 권한이 없어요'), findsOneWidget);
  });

  testWidgets('작은 폰 360×640: 넘치지 않고 기록 버튼까지 한 화면, 시트가 나와도 넘침 없음', (tester) async {
    final h = await _open(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    final btn = tester.getRect(find.text('길게 눌러서'));
    expect(btn.bottom, lessThan(640 - 64));
    expect(tester.getRect(find.text('39.0°')).bottom, lessThanOrEqualTo(640 - 64));

    h.ctrl.setValue(384);
    await tester.pump();
    await _hold(tester, 600);
    await _settle(tester);
    expect(find.byType(AlertActionSheet), findsOneWidget);
    // 시트가 화면 안으로 올라와 있다
    expect(tester.getRect(find.text('잘못 쟀어요')).bottom, lessThanOrEqualTo(640 - 64));
    expect(tester.takeException(), isNull);

    // 큰 글자에서도 넘치지 않는다
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('개발 DB: 예시 반 · 예시 별님 + 예시 표시', (tester) async {
    final h = await _open(tester, dataset: Dataset.dev);
    expect(find.text('예시반'), findsOneWidget);
    expect(find.text('예시 별님'), findsOneWidget);
    expect(find.byType(ExampleTag), findsOneWidget);
    await _hold(tester, 600);
    expect(h.repo.measurementsOf('ex_resident').length, 1);
  });

  testWidgets('openFor · toggle · close (다른 화면이 쓰는 API)', (tester) async {
    final h = await _open(tester);
    final seojun = residentByName('이서준').id;
    h.ctrl.close();
    expect(h.st.open, isFalse);
    h.ctrl.openFor(seojun);
    expect(h.st.open, isTrue);
    expect(h.st.residentId, seojun);
    expect(h.st.level, QtLevel.resident);
    h.ctrl.toggle();
    expect(h.st.open, isFalse);
    h.ctrl.toggle();
    expect(h.st.open, isTrue);
    expect(h.st.residentId, seojun, reason: '접었다 펴도 선택은 남는다');
  });

  testWidgets('별님 동그라미: 프로필 사진이 있으면 동그라미 안에 사진, 이름은 아래 그대로', (tester) async {
    final h = await _open(tester);
    final seojun = residentByName('이서준').id;
    expect(find.byWidgetPredicate((w) => w is ResidentCircle && w.url == h.repo.profilePhotoOf(seojun)!.url), findsOneWidget);
    expect(find.text('서준'), findsOneWidget, reason: '동그라미 아래 이름');
    expect(find.text('민준'), findsNothing, reason: '김민준은 선택되어 이름 전체');
  });

  testWidgets('간호쌤 호출: 이유를 골라 보내면 간호사 호출함으로 · 별님카드에 기록', (tester) async {
    final h = await _open(tester);
    final minjun = residentByName('김민준').id;
    final before = h.repo.calls.length;
    await tester.ensureVisible(find.byKey(const Key('qt-nurse-call')));
    await tester.tap(find.byKey(const Key('qt-nurse-call')));
    await _settle(tester);
    expect(find.text('간호 선생님 호출'), findsOneWidget);
    // 이유 없이는 못 보낸다
    expect(tester.widget<DsButton>(find.byKey(const Key('nurse-call-send'))).onPressed, isNull);
    await tester.tap(find.text('기침·콧물'));
    await tester.enterText(find.byKey(const Key('nurse-call-memo')), '밤새 기침했어요');
    await tester.pump();
    await tester.tap(find.byKey(const Key('nurse-call-send')));
    await _settle(tester);

    expect(h.repo.calls.length, before + 1);
    final call = h.repo.calls.firstWhere((c) => c.residentId == minjun && c.isOpen);
    expect(call.summary, '기침·콧물. 밤새 기침했어요');
    expect(call.createdBy, 'kim_haneul');
    expect(call.doctorId, isNull, reason: '먼저 간호사 호출함으로');
    final entry = h.repo.archiveEntriesOf(minjun).firstWhere((e) => e.kindLabel == '간호사 호출');
    expect(entry.body, contains('밤새 기침했어요'));
    expect(find.text('간호 선생님께 호출했어요 · 별님카드에 남겼어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
