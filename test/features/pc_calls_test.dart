// PC 의료 호출 흐름: 앱 간호쌤 호출 → 의료 호출함(간호사) → 의료진 채팅으로 보내기 → 의료진 협진 포털(의사).
// 채팅함은 목록 사이에서 아래로 펼쳐진다. 간호사 = 의료진별 방, 의사 = 별님별 방. 오른쪽 처방 기록은 날짜순.
import 'package:byeoljari_note/core/ds.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart' as seed;
import 'package:byeoljari_note/core/theme.dart';
import 'package:byeoljari_note/features/pc/pc_calls_page.dart';
import 'package:byeoljari_note/features/pc/pc_doctor_page.dart';
import 'package:byeoljari_note/features/pc/pc_medical_rooms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final clock = DateTime(2026, 10, 28, 14, 0);
String rid(String name) => seed.residentByName(name).id;

InMemoryRepository demo() => InMemoryRepository(dataset: Dataset.demo, clock: () => clock);

void screen(WidgetTester tester, {double w = 1440, double h = 1000}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// pc_shell 처럼 왼쪽 레일(80) · 머리(64) 자리를 비우고 페이지를 그린다. [doctor]가 바뀌면 의사 ↔ 간호사 화면.
Future<ProviderContainer> pumpPc(WidgetTester tester, InMemoryRepository repo,
    {String? user, ValueNotifier<bool>? doctor}) async {
  final showDoctor = doctor ?? ValueNotifier(false);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repoProvider.overrideWith((_) => repo),
      screenKindProvider.overrideWithValue('pc'),
      if (user != null) currentUserProvider.overrideWith((_) => user),
    ],
    child: MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: Ds.gray100,
        body: Row(children: [
          const SizedBox(width: 80),
          Expanded(
            child: Column(children: [
              const SizedBox(height: 64),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  key: const ValueKey('page-switch'),
                  valueListenable: showDoctor,
                  builder: (_, d, _) => d ? const PcDoctorPage() : const PcCallsPage(),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byKey(const ValueKey('page-switch'))));
}

/// 토스트가 사라질 때까지 기다린다.
Future<void> waitToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;
void main() {
  testWidgets('간호사: 호출함(새 호출 · 보낸 곳) · 의료진 채팅함(닫힘, 안 읽은 수) · 처방 기록(날짜)', (tester) async {
    screen(tester);
    final repo = demo();
    await pumpPc(tester, repo);

    // 호출함: 앱에서 온 강시우 호출은 새 호출
    expect(find.text('새 1'), findsWidgets);
    final siwoo = find.byKey(ValueKey('nurse-call-${repo.openCalls.firstWhere((c) => c.residentId == rid('강시우')).id}'));
    expect(find.descendant(of: siwoo, matching: find.text('김하늘 선생님 호출')), findsOneWidget);
    expect(find.descendant(of: siwoo, matching: find.text('아직 의료진에게 보내지 않았어요')), findsOneWidget);
    expect(find.descendant(of: siwoo, matching: find.text('의료진에게 보내기')), findsOneWidget);
    expect(find.textContaining('강다혜 촉탁의 (원장)에게 보냄'), findsOneWidget);
    expect(find.textContaining('문재호 전문의에게 보냄'), findsOneWidget);

    // 채팅함: 의료진 3명, 처음엔 모두 닫힘. 문재호 전문의 답장 1개 안 읽음
    for (final d in ['kang_dahye', 'moon_jaeho', 'yoon_seojin']) {
      expect(find.byKey(ValueKey('room-doc:$d')), findsOneWidget);
      expect(find.byKey(ValueKey('body-doc:$d')), findsNothing);
    }
    expect(repo.roomUnread('park_soyeon', 'doc:moon_jaeho'), 1);

    // 오른쪽: 비대면 진단·처방 기록 (날짜순)
    expect(find.text('비대면 진단·처방 기록'), findsOneWidget);
    final issued = repo.prescriptions.firstWhere((p) => p.issued);
    expect(find.textContaining(dateLabel(issued.issuedAt!)), findsWidgets);
    expect(find.byType(RxRecordCard), findsNWidgets(repo.prescriptions.length));
  });

  testWidgets('채팅방을 누르면 목록 사이에서 아래로 펼쳐지고, 펼치면 읽음 · 다른 방은 닫힌다', (tester) async {
    screen(tester);
    final repo = demo();
    await pumpPc(tester, repo);
    await tester.tap(find.byKey(const ValueKey('room-doc:moon_jaeho')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('body-doc:moon_jaeho')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('body-doc:moon_jaeho')), matching: find.textContaining('다음 주 화요일 오후 비대면 상담')), findsOneWidget);
    expect(repo.roomUnread('park_soyeon', 'doc:moon_jaeho'), 0);
    // 펼친 대화는 그 방 머리 바로 아래 (목록 사이)
    final body = tester.getRect(find.byKey(const ValueKey('body-doc:moon_jaeho')));
    final roomTop = tester.getTopLeft(find.byKey(const ValueKey('room-doc:moon_jaeho'))).dy;
    expect(body.top, greaterThan(roomTop));

    await tester.tap(find.byKey(const ValueKey('room-doc:kang_dahye')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('body-doc:moon_jaeho')), findsNothing);
    expect(find.byKey(const ValueKey('body-doc:kang_dahye')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('room-input-doc:kang_dahye')), '체온 37.9로 내려가는 중입니다');
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('body-doc:kang_dahye')), matching: find.text('전송')));
    await tester.pumpAndSettle();
    final seojun = repo.openCalls.firstWhere((c) => c.residentId == rid('이서준'));
    expect(repo.messagesOf(seojun.id).last.body, '체온 37.9로 내려가는 중입니다');
    expect(repo.roomUnread('kang_dahye', 'res:${rid('이서준')}'), greaterThan(0), reason: '의사 쪽 별님 채팅방에 알림');
  });

  testWidgets('간호사가 의료진에게 보내기 → 의료진 협진 포털 호출함(혜진원) · 별님 채팅방 알림', (tester) async {
    screen(tester);
    final repo = demo();
    final doctor = ValueNotifier(false);
    final container = await pumpPc(tester, repo, doctor: doctor);
    final call = repo.openCalls.firstWhere((c) => c.residentId == rid('강시우'));

    await tester.tap(find.byKey(ValueKey('forward-${call.id}')));
    await tester.pumpAndSettle();
    expect(find.text('어느 의료진에게 보낼까요?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pick-yoon_seojin')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pick-send')));
    await tester.pumpAndSettle();
    expect(repo.callById(call.id).doctorId, 'yoon_seojin');
    expect(repo.callById(call.id).forwardedBy, 'park_soyeon');
    expect(find.byKey(const ValueKey('body-doc:yoon_seojin')), findsOneWidget, reason: '보낸 의료진 채팅이 펼쳐진다');
    expect(find.textContaining('윤서진 원장에게 강시우 별님 호출을 보냈어요'), findsWidgets);
    await waitToast(tester);

    // 의사(윤서진) 포털
    container.read(currentUserProvider.notifier).state = 'yoon_seojin';
    container.read(openRoomProvider.notifier).open(null);
    doctor.value = true;
    await tester.pumpAndSettle();
    expect(find.text('혜진원'), findsWidgets);
    expect(find.byKey(ValueKey('doctor-call-${call.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('room-res:${rid('강시우')}')), findsOneWidget);
    expect(find.byKey(ValueKey('room-res:${rid('이서준')}')), findsNothing, reason: '다른 의사에게 간 호출은 안 보인다');
    expect(repo.roomUnread('yoon_seojin', 'res:${rid('강시우')}'), greaterThan(0));

    await tester.tap(find.byKey(ValueKey('doctor-call-${call.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('body-res:${rid('강시우')}')), findsOneWidget);
    expect(repo.roomUnread('yoon_seojin', 'res:${rid('강시우')}'), 0);
    expect(find.text('비대면 진단서 및 전자처방전 작성'), findsOneWidget);
  });

  testWidgets('앱에서 간호쌤 호출이 오면 간호사 호출함에 알림 · 별님카드 기록', (tester) async {
    screen(tester);
    final repo = demo();
    await pumpPc(tester, repo);
    final c = repo.callNurse(residentId: rid('한지호'), by: 'kim_haneul', reason: '열이 나요');
    await tester.pump();
    await tester.pump();
    expect(find.text('새 간호사 호출 · 한지호 별님 (은하수자리)'), findsOneWidget);
    expect(find.byKey(ValueKey('nurse-call-${c.id}')), findsOneWidget);
    expect(repo.isNewCall(c, 'park_soyeon'), isTrue);
    expect(repo.archiveEntriesOf(rid('한지호')).any((e) => e.kindLabel == '간호사 호출' && e.body!.contains('열이 나요')), isTrue);
    await waitToast(tester);

    await tester.tap(find.byKey(ValueKey('nurse-call-${c.id}')));
    await tester.pumpAndSettle();
    expect(repo.isNewCall(c, 'park_soyeon'), isFalse);
  });

  testWidgets('의사: 처방 고치기(실시간 저장) → 발행 → 간호사 프리뷰가 발행됨', (tester) async {
    screen(tester);
    final repo = demo();
    final doctor = ValueNotifier(true);
    final container = await pumpPc(tester, repo, user: 'kang_dahye', doctor: doctor);
    final call = repo.openCalls.firstWhere((c) => c.residentId == rid('이서준'));

    expect(find.text('비대면 진단서 및 전자처방전 작성'), findsOneWidget);
    expect(find.text('진단 작성중'), findsOneWidget);
    expect(find.text('처방 주의: 페니실린계 · 세파계 항생제 절대 금기'), findsOneWidget);
    // 초안이 채워져 있다
    String fieldText(String key) => tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
    expect(fieldText('rx-code'), 'J06.9');
    expect(fieldText('rx-code-name'), '상세불명의 급성 상기도 감염');
    expect(fieldText('rx-name-0'), startsWith('어린이타이레놀현탁액'));

    // 소견 고치기 → 잠깐 뒤 저장
    await tester.enterText(find.byKey(const ValueKey('rx-opinion')), '해열 조치 지시. 1시간 후 재측정 요망.');
    await tester.pump();
    expect(find.text('저장 중…'), findsOneWidget);
    await tester.pump(rxSaveDelay + const Duration(milliseconds: 50));
    expect(repo.prescriptionOf(call.id)!.opinion, '해열 조치 지시. 1시간 후 재측정 요망.');
    expect(find.text('실시간 동기화'), findsOneWidget);

    // 처방약 한 줄 추가 (의사가 쓴 글 그대로)
    await tester.ensureVisible(find.text('처방약 추가'));
    await tester.tap(find.text('처방약 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rx-name-2')), '예시 시럽');
    await tester.enterText(find.byKey(const ValueKey('rx-usage-2')), '의사 지시대로');
    await tester.enterText(find.byKey(const ValueKey('rx-amount-2')), '1병');
    await tester.pump(rxSaveDelay + const Duration(milliseconds: 50));
    final draft = repo.prescriptionOf(call.id)!;
    expect(draft.issued, isFalse);
    expect(draft.items, hasLength(3));
    expect(draft.items.last.name, '예시 시럽');
    expect(draft.items.last.amount, '1병');

    // 발행 → 확인 대화상자 → 읽기 전용 + 처방전 번호
    await tester.tap(find.text('전자서명 완료 및 전자처방전 발행·전송'));
    await tester.pumpAndSettle();
    expect(find.text('전자처방전을 발행할까요?'), findsOneWidget);
    await tester.tap(find.text('서명하고 발행'));
    await tester.pumpAndSettle();
    final p = repo.prescriptionOf(call.id)!;
    expect(p.issued, isTrue);
    expect(p.number, isNotNull);
    expect(find.text('발행 완료'), findsOneWidget);
    expect(find.textContaining(p.number!), findsWidgets);
    expect(find.byKey(const ValueKey('rx-opinion')), findsNothing);
    await waitToast(tester);

    // 간호사 화면: 같은 저장소라 프리뷰가 바로 발행됨
    container.read(currentUserProvider.notifier).state = 'park_soyeon';
    doctor.value = false;
    await tester.pumpAndSettle();
    // 간호사 오른쪽 비대면 진단·처방 기록에 날짜와 함께 발행본이 보인다
    expect(find.text('비대면 진단·처방 기록'), findsOneWidget);
    expect(find.textContaining(p.number!), findsWidgets);
    expect(find.textContaining(dateLabel(p.issuedAt!)), findsWidgets);
    expect(find.textContaining('예시 시럽'), findsOneWidget);
  });

  testWidgets('의사: 질병코드 없이 발행하면 안내만 하고 발행하지 않는다', (tester) async {
    screen(tester);
    final repo = demo();
    await pumpPc(tester, repo, user: 'kang_dahye', doctor: ValueNotifier(true));
    final call = repo.openCalls.firstWhere((c) => c.residentId == rid('이서준'));
    await tester.enterText(find.byKey(const ValueKey('rx-code')), '');
    await tester.pump(rxSaveDelay + const Duration(milliseconds: 50));
    await tester.tap(find.text('전자서명 완료 및 전자처방전 발행·전송'));
    await tester.pumpAndSettle();
    expect(find.text('전자처방전을 발행할까요?'), findsNothing);
    expect(repo.prescriptionOf(call.id)!.issued, isFalse);
    await waitToast(tester);
  });

  testWidgets('개발 DB: 호출함 · 처방 기록 자리에 예시, 호출이 생기면 호출함 예시가 사라진다', (tester) async {
    screen(tester);
    final repo = InMemoryRepository(dataset: Dataset.dev, clock: () => clock);
    await pumpPc(tester, repo);
    expect(find.byType(ExampleWrap), findsNWidgets(2));
    repo.requestCall(residentId: 'ex_resident', level: CallLevel.general, by: 'ex_care', summary: '식욕 부진 확인 의뢰');
    await tester.pumpAndSettle();
    expect(find.text('식욕 부진 확인 의뢰'), findsOneWidget);
    expect(find.byType(ExampleWrap), findsOneWidget, reason: '처방 기록 예시만 남는다');
    await waitToast(tester);
  });

  testWidgets('개발 DB 의사 포털: 호출함 · 처방 작성 자리에 예시', (tester) async {
    screen(tester);
    final repo = InMemoryRepository(dataset: Dataset.dev, clock: () => clock);
    await pumpPc(tester, repo, user: 'ex_doctor', doctor: ValueNotifier(true));
    expect(find.byType(ExampleWrap), findsNWidgets(2));
  });

  for (final w in [1280.0, 1920.0]) {
    testWidgets('폭 ${w.toInt()}에서 넘치지 않는다 (간호사 · 의사, 채팅 펼침)', (tester) async {
      screen(tester, w: w, h: 900);
      final repo = demo();
      final doctor = ValueNotifier(false);
      final container = await pumpPc(tester, repo, doctor: doctor);
      await tester.tap(find.byKey(const ValueKey('room-doc:kang_dahye')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      container.read(currentUserProvider.notifier).state = 'kang_dahye';
      container.read(openRoomProvider.notifier).open('res:${rid('이서준')}');
      doctor.value = true;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('비대면 진단서 및 전자처방전 작성'), findsOneWidget);
    });
  }
}
