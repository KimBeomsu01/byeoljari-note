// 04 별님카드 (Claude Design ResidentTimeline.dc.html) 화면 흐름.
import 'package:byeoljari_note/app.dart' show residentCardTargetProvider;
import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/photo.dart';
import 'package:byeoljari_note/core/providers.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/routes.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:byeoljari_note/features/alert_case/case_detail_screen.dart';
import 'package:byeoljari_note/features/resident_card/resident_card_screen.dart';
import 'package:byeoljari_note/features/resident_card/resident_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 28, 14, 0);
String rid(String name) => residentByName(name).id;

const _sensory = '아침 식사 때 숟가락 소리에 귀를 막았어요. 조용한 자리로 옮기니 다 먹었어요.';
const _notice = '보일러 점검으로 인해 목욕 순서가 은하수자리 1순위로 변경되었습니다. (09:30 순차 진행)';

Future<InMemoryRepository> pumpCard(
  WidgetTester tester, {
  Dataset dataset = Dataset.demo,
  Size size = const Size(390, 844),
  Widget? home,
  List<Override> extra = const [],
  String? user,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = InMemoryRepository(dataset: dataset, clock: () => _now);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repoProvider.overrideWith((_) => repo),
      screenKindProvider.overrideWithValue('mobile'),
      if (user != null) currentUserProvider.overrideWith((_) => user),
      ...extra,
    ],
    child: MaterialApp(home: home ?? const ResidentCardScreen()),
  ));
  await tester.pumpAndSettle();
  return repo;
}

String profileName(WidgetTester tester) =>
    (tester.widget<Text>(find.byKey(const Key('rc-profile-name'))).textSpan! as TextSpan).children!.first.toPlainText();

Future<void> scrollBy(WidgetTester tester, double dy) async {
  await tester.drag(find.byKey(const Key('rc-scroll')), Offset(0, -dy));
  await tester.pumpAndSettle();
}

void main() {
  group('타임라인 계산', () {
    test('측정에 붙은 자동 체온 기록은 그 측정 줄에 합치고, 반 공지는 소속 반 것만', () {
      final repo = InMemoryRepository(clock: () => _now);
      final recs = buildTimeline(repo, rid('이서준'), _now);
      final temps = recs.whereType<TempRecord>().toList();
      expect(temps.first.m.value, 384);
      expect(temps.first.m.caseId, isNotNull);
      expect(temps.where((t) => t.entry != null).length, 2); // 37.6 주의(할 일) · 38.4 이상(이상 건)
      expect(recs.whereType<EntryRecord>().any((e) => e.e.measurementId != null), isFalse);
      final notices = recs.whereType<EntryRecord>().where((e) => e.isNotice).toList();
      expect(notices.single.e.classId, 'milkyway');
      // 그저께 이전의 평소 값은 넣지 않는다
      final since = DateTime(2026, 10, 27);
      expect(temps.every((t) => !t.m.measuredAt.isBefore(since) || t.isWarning), isTrue);
    });
  });

  group('시연 DB', () {
    testWidgets('처음엔 내 반(은하수자리)의 이상 건 별님 이서준: 프로필 · 그래프 · 타임라인', (tester) async {
      final repo = await pumpCard(tester);
      final seojun = rid('이서준');
      expect(profileName(tester), '이서준');
      expect(find.text('은하수자리 · 담임 이수진'), findsOneWidget);
      expect(find.textContaining('만 19세 · 남', findRichText: true), findsOneWidget);
      final base = repo.baselineOf(seojun, _now).value;
      expect(find.text('${(base / 10).toStringAsFixed(1)}°'), findsOneWidget);
      expect(find.text('14일 중앙값'), findsOneWidget);
      expect(find.text('현재 38.4°'), findsOneWidget);
      expect(find.textContaining('총 '), findsOneWidget);
      // 타임라인: 오늘 · 어제 묶음, 감각 메모 · 반 공지 · 체온
      expect(find.text('오늘'), findsOneWidget);
      expect(find.text('10월 28일 (수)'), findsOneWidget);
      expect(find.text('어제'), findsOneWidget);
      expect(find.text(_sensory), findsOneWidget);
      expect(find.text(_notice), findsOneWidget);
      expect(find.text('38.4° 이상'), findsOneWidget);
      expect(find.text('37.6° 주의'), findsOneWidget);
      expect(find.text('재측정 완료'), findsOneWidget);
      expect(find.textContaining('담임 변경 (박지은 → 이수진)'), findsOneWidget);
    });

    testWidgets('다이얼: 별님 탭 · 반 탭 · 좌우 밀기', (tester) async {
      await pumpCard(tester, user: 'park_soyeon'); // 수석간호사: 전체 반
      ProviderScope.containerOf(tester.element(find.byType(ResidentCardScreen)))
          .read(residentCardTargetProvider.notifier)
          .show(rid('김민준'));
      await tester.pumpAndSettle();
      expect(profileName(tester), '김민준');

      // 좌우로 밀면 한 칸씩 (왼쪽으로 = 다음 별님)
      await tester.drag(find.byKey(const Key('rc-resident-dial')), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(profileName(tester), '이서준');

      // 반 다이얼을 오른쪽으로 밀면 이전 반(곰자리)의 첫 별님, 반을 누르면 그 반 첫 별님
      await tester.drag(find.byKey(const Key('rc-class-dial')), const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(profileName(tester), '문하준');
      await tester.tap(find.text('물고기자리'));
      await tester.pumpAndSettle();
      expect(profileName(tester), '정서아');
    });

    testWidgets('필터 칩: 별님 이름 = 반 공지 숨김, 반 공지 = 개인 기록 숨김', (tester) async {
      await pumpCard(tester);
      await tester.tap(find.byKey(const Key('rc-chip-notice')));
      await tester.pumpAndSettle();
      expect(find.text(_notice), findsOneWidget);
      expect(find.text(_sensory), findsNothing);
      expect(find.text('38.4° 이상'), findsNothing);

      await tester.tap(find.byKey(const Key('rc-chip-resident')));
      await tester.pumpAndSettle();
      expect(find.text(_notice), findsNothing);
      expect(find.text(_sensory), findsOneWidget);
      expect(find.text('38.4° 이상'), findsOneWidget);

      await tester.tap(find.byKey(const Key('rc-chip-all')));
      await tester.pumpAndSettle();
      expect(find.text(_notice), findsOneWidget);
      expect(find.text(_sensory), findsOneWidget);
    });

    testWidgets('검색: 글자로 거르고 60자까지만', (tester) async {
      await pumpCard(tester);
      await tester.enterText(find.byKey(const Key('rc-search')), '숟가락');
      await tester.pumpAndSettle();
      expect(find.text(_sensory), findsOneWidget);
      expect(find.text(_notice), findsNothing);
      expect(find.text('38.4° 이상'), findsNothing);

      await tester.enterText(find.byKey(const Key('rc-search')), '체온');
      await tester.pumpAndSettle();
      expect(find.text('38.4° 이상'), findsOneWidget);
      expect(find.text(_sensory), findsNothing);

      await tester.enterText(find.byKey(const Key('rc-search')), '없는말없는말');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 기록이 없어요'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('rc-search')), '가' * 70);
      await tester.pump();
      final field = tester.widget<TextField>(find.byKey(const Key('rc-search')));
      expect(field.controller!.text.length, 60);
    });

    testWidgets('[전체] 시트: 종류 · 기간으로 거르기', (tester) async {
      await pumpCard(tester);
      await tester.ensureVisible(find.byKey(const Key('rc-tune')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rc-tune')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('체온'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text(_sensory), findsNothing);
      expect(find.text(_notice), findsNothing);
      expect(find.text('38.4° 이상'), findsOneWidget);

      // ActionBar 필터 버튼도 같은 시트
      await tester.tap(find.byKey(const Key('rc-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('처음으로'));
      await tester.tap(find.text('최근 7일'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text(_sensory), findsOneWidget);
      expect(find.textContaining('담임 변경'), findsNothing); // 7일보다 오래된 기록은 빠짐
    });

    testWidgets('새 기록 배너: [모두 확인] → 내가 다 읽음 · 배너 사라짐', (tester) async {
      final repo = await pumpCard(tester);
      final seojun = rid('이서준');
      final unread = repo.archiveEntriesOf(seojun).where((e) => !repo.isRead(e.id, 'kim_haneul')).length;
      expect(unread, greaterThan(0));
      expect(find.text('새 기록 $unread건'), findsOneWidget);
      await tester.tap(find.text('모두 확인'));
      await tester.pumpAndSettle();
      expect(find.textContaining('새 기록'), findsNothing);
      expect(repo.archiveEntriesOf(seojun).every((e) => repo.isRead(e.id, 'kim_haneul')), isTrue);
    });

    testWidgets('[기록 남기기] → 감각 메모 저장 → 타임라인에 보임', (tester) async {
      final repo = await pumpCard(tester);
      final seojun = rid('이서준');
      await tester.tap(find.byKey(const Key('rc-write')));
      await tester.pumpAndSettle();
      expect(find.text('이서준 기록 남기기'), findsOneWidget);
      await tester.tap(find.text('감각 메모'));
      await tester.enterText(find.byKey(const Key('rc-write-field')), '박수 소리에 놀랐다가 금방 웃었어요.');
      await tester.pump();
      await tester.tap(find.byKey(const Key('rc-write-save')));
      await tester.pumpAndSettle();
      final e = repo.archiveEntriesOf(seojun).first;
      expect(e.kindLabel, '감각 메모');
      expect(e.scope, EntryScope.resident);
      expect(e.authorId, 'kim_haneul');
      expect(find.text('박수 소리에 놀랐다가 금방 웃었어요.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // 토스트
    });

    testWidgets('투약 지침: 간호 선생님이 쓴 글 그대로', (tester) async {
      final repo = await pumpCard(tester);
      final g = repo.guidelineOf(rid('이서준'))!;
      expect(find.text('박소연 수석간호사'), findsOneWidget);
      await tester.tap(find.text('투약 지침'));
      await tester.pumpAndSettle();
      expect(find.text(g.body), findsOneWidget);
      expect(find.text('뇌병변 2급, 경련성 질환 (발작 주의)'), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text(g.body), findsNothing);
    });

    testWidgets('투약 지침이 없는 별님은 안내 문구', (tester) async {
      await pumpCard(tester);
      await tester.tap(find.text('민준').first);
      await tester.pumpAndSettle();
      expect(find.text('등록된 지침 없음'), findsOneWidget);
      await tester.tap(find.text('투약 지침'));
      await tester.pumpAndSettle();
      expect(find.textContaining('등록된 투약 지침이 없어요'), findsOneWidget);
    });

    testWidgets('체온 줄의 [대응 이력] → 이상 건 상세', (tester) async {
      await pumpCard(tester);
      await scrollBy(tester, 320);
      await tester.tap(find.textContaining('대응 이력 #'));
      await tester.pumpAndSettle();
      expect(find.byType(CaseDetailScreen), findsOneWidget);
    });

    testWidgets('잘못 잰 값은 지우지 않고 무효 표시', (tester) async {
      final repo = await pumpCard(tester);
      final m = repo.latestOf(rid('이서준'))!;
      repo.voidMeasurement(m.id, by: 'kim_haneul', at: _now);
      await tester.pump();
      expect(find.text('잘못 잰 값 · 무효'), findsOneWidget);
      final t = tester.widget<Text>(find.text('${(m.value / 10).toStringAsFixed(1)}°'));
      expect(t.style!.decoration, TextDecoration.lineThrough);
    });

    testWidgets('residentCardTargetProvider가 바뀌면 그 별님을 보여준다', (tester) async {
      await pumpCard(tester, user: 'park_soyeon');
      final container = ProviderScope.containerOf(tester.element(find.byType(ResidentCardScreen)));
      container.read(residentCardTargetProvider.notifier).show(rid('박승민'));
      await tester.pumpAndSettle();
      expect(profileName(tester), '박승민');
      expect(find.text('고래자리 · 담임 정하은'), findsOneWidget);

      // 다이얼로 바꾼 뒤 같은 별님을 다시 보내도 따라간다
      await tester.tap(find.text('재희').first);
      await tester.pumpAndSettle();
      expect(profileName(tester), '노재희');
      container.read(residentCardTargetProvider.notifier).show(rid('박승민'));
      await tester.pumpAndSettle();
      expect(profileName(tester), '박승민');
    });

    testWidgets('따로 연 별님카드: 뒤로가기 버튼 하나', (tester) async {
      await pumpCard(
        tester,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(child: TextButton(onPressed: () => openResidentCard(ctx, rid('한나리')), child: const Text('열기'))),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(profileName(tester), '한나리');
      expect(find.text('물병자리 · 담임 박지은'), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.byType(ResidentCardScreen), findsNothing);
    });

    testWidgets('작은 폰 360×640: 넘침 없음 (화면 · 시트)', (tester) async {
      await pumpCard(tester, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      await scrollBy(tester, 2000);
      await tester.tap(find.byKey(const Key('rc-write')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byKey(const Key('rc-write-field')))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rc-filter')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      await scrollBy(tester, -4000);
      await tester.tap(find.text('투약 지침'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('개발 DB', () {
    testWidgets('예시 별님: 기록이 없으면 예시 카드 · 그래프 예시 문구, 기록을 남기면 사라짐', (tester) async {
      final repo = await pumpCard(tester, dataset: Dataset.dev);
      expect(profileName(tester), '예시 별님');
      expect(find.byType(ExampleTimelineCard), findsOneWidget);
      expect(find.text('체온을 재면 이 자리에 14일 추이가 그려져요'), findsOneWidget);
      expect(find.textContaining('새 기록'), findsNothing);

      await tester.tap(find.byKey(const Key('rc-write')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rc-write-field')), '처음 남기는 기록');
      await tester.pump();
      await tester.tap(find.byKey(const Key('rc-write-save')));
      await tester.pumpAndSettle();
      expect(find.byType(ExampleTimelineCard), findsNothing);
      expect(find.text('처음 남기는 기록'), findsOneWidget);
      expect(repo.archiveEntriesOf('ex_resident').single.authorId, 'ex_care');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('360×640에서도 넘침 없음', (tester) async {
      await pumpCard(tester, dataset: Dataset.dev, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      expect(find.byType(ExampleTimelineCard), findsOneWidget);
    });

    testWidgets('개발 DB: 프로필 사진 기록은 예시 한 장 + 담당이면 올리기', (tester) async {
      await pumpCard(tester, dataset: Dataset.dev);
      await tester.tap(find.byKey(const Key('rc-profile-photo')));
      await tester.pumpAndSettle();
      expect(find.text('예시 별님 프로필'), findsOneWidget);
      expect(find.textContaining('실제 사진을 올리면 이 예시는 사라져요'), findsOneWidget);
      expect(find.byKey(const Key('photo-upload')), findsOneWidget);
    });
  });

  group('프로필 사진 기록 (카카오톡처럼)', () {
    const png1x1 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

    testWidgets('프로필을 누르면 최신 사진부터, 담당 선생님은 올리면 맨 앞에', (tester) async {
      String? uploaded;
      final repo = await pumpCard(tester, extra: [
        photoPickerProvider.overrideWithValue(({bool camera = false}) async => png1x1),
        photoUploadProvider.overrideWithValue((dataUrl) async => uploaded = dataUrl),
      ]);
      expect(profileName(tester), '이서준');
      await tester.tap(find.byKey(const Key('rc-profile-photo')));
      await tester.pumpAndSettle();
      expect(find.text('이서준 프로필'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('지금 프로필'), findsOneWidget);

      // 옆으로 넘기면 예전 사진
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('지금 프로필'), findsNothing);

      await tester.tap(find.byKey(const Key('photo-upload')));
      await tester.pumpAndSettle();
      // 설치형 앱(테스트 = 웹 아님): 카메라 · 사진첩 고르기
      expect(find.text('사진 찍기'), findsOneWidget);
      await tester.tap(find.text('사진첩에서 고르기'));
      await tester.pumpAndSettle();
      expect(uploaded, png1x1);
      expect(repo.photosOf(rid('이서준')).length, 4);
      expect(repo.profilePhotoOf(rid('이서준'))!.uploadedBy, 'kim_haneul');
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('지금 프로필'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('이서준 프로필'), findsNothing);
    });

    testWidgets('다른 반 선생님은 보기만 (올리기 버튼 대신 안내)', (tester) async {
      await pumpCard(tester);
      final c = ProviderScope.containerOf(tester.element(find.byType(ResidentCardScreen)));
      c.read(currentUserProvider.notifier).state = 'park_jieun';
      await tester.pumpAndSettle();
      c.read(residentCardTargetProvider.notifier).show(rid('이서준'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget, reason: '카메라 표시는 누구에게나');
      await tester.tap(find.byKey(const Key('rc-profile-photo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('photo-upload')), findsNothing);
      expect(find.text('프로필 사진은 은하수자리 담당 선생님만 올릴 수 있어요'), findsOneWidget);
    });
  });

  testWidgets('내 담당 반만: 김하늘(은하수자리)은 반 다이얼에 은하수자리 하나', (tester) async {
    final repo = await pumpCard(tester);
    expect(find.text('은하수자리'), findsWidgets);
    for (final other in ['물병자리', '물고기자리', '곰자리', '양자리', '고래자리']) {
      expect(find.descendant(of: find.byKey(const Key('rc-class-dial')), matching: find.text(other)), findsNothing, reason: other);
    }
    // 다른 반 별님으로 보내도 담당 반 밖이면 따라가지 않는다
    final c = ProviderScope.containerOf(tester.element(find.byType(ResidentCardScreen)));
    c.read(residentCardTargetProvider.notifier).show(rid('박승민'));
    await tester.pumpAndSettle();
    expect(repo.resident(rid(profileName(tester))).classId, 'milkyway');
  });
}
