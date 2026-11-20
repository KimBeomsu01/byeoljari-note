import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:byeoljari_note/core/storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시연 자료 기준일 14:00 (오전 시나리오가 다 지난 시각).
final clockAt = DateTime(2026, 10, 28, 14, 0);
DateTime t(int h, int m) => DateTime(2026, 10, 28, h, m);
InMemoryRepository demo({SnapshotStore? store, String? snapshot}) =>
    InMemoryRepository(dataset: Dataset.demo, store: store, snapshot: snapshot, clock: () => clockAt);

void main() {
  test('시연 명단: 6반 36명 (Claude Design 반 이름)', () {
    final repo = demo();
    final counts = {for (final c in repo.classes) c.name: repo.residentsOf(c.id).length};
    expect(counts, {'물병자리': 7, '물고기자리': 6, '곰자리': 5, '은하수자리': 6, '양자리': 6, '고래자리': 6});
    expect(repo.residents.length, 36);
    expect(repo.rosterIsExample, isFalse);
  });

  test('기저치는 14일 기록 중앙값 (이서준 37.1, 박승민 36.8)', () {
    final repo = demo();
    expect(repo.baselineOf(residentByName('이서준').id, t(9, 0)).value, 371);
    expect(repo.baselineOf(residentByName('박승민').id, t(9, 0)).value, 368);
  });

  test('시연 시작 상태: 디자인 화면 내용 (이상 건 2, 열린 호출 4, 결재 2, 정현우 할 일)', () {
    final repo = demo();
    expect(repo.openCases.map((c) => repo.resident(c.residentId).name), containsAll(['박승민', '이서준']));
    expect(repo.latestOf(residentByName('이서준').id)!.value, 384);
    expect(repo.caseById(repo.openCaseOf(residentByName('박승민').id)!.id).remeasureAt, t(9, 51));
    expect(repo.openCalls.map((c) => repo.resident(c.residentId).name), ['강시우', '이서준', '최도윤', '박승민']);
    final seojunCall = repo.openCalls.firstWhere((c) => c.residentId == residentByName('이서준').id);
    expect(seojunCall.level, CallLevel.urgent);
    expect(repo.doneCallsOn(clockAt), 14);
    expect(repo.messagesOf(seojunCall.id).where((m) => m.kind == 'text'), hasLength(4));
    expect(repo.prescriptionOf(seojunCall.id)!.code, 'J06.9');
    expect(repo.pendingApprovals, hasLength(2));
    expect(repo.openTempTasksOf(residentByName('정현우').id), hasLength(1));
    expect(repo.openTempTasksOf(residentByName('이서준').id), isEmpty, reason: '10:11 측정으로 자동 완료');
    expect(repo.calendarOn(clockAt), hasLength(10));
    final nari = repo.entries.firstWhere((e) => e.residentId == residentByName('한나리').id && e.createdAt == t(7, 50));
    expect(repo.likesOf(nari.id), hasLength(2));
  });

  test('체온 흐름: 37.6(평소 36.5) → 이상 대응 + 간호 호출, 39.1 → 긴급 + 호출 긴급, 종료', () {
    final repo = demo();
    final minjun = residentByName('김민준').id;

    final r1 = repo.saveMeasurement(residentId: minjun, value: 376, by: 'kim_haneul', at: t(14, 0));
    expect(r1.caseCreated, isTrue);
    expect(r1.caseItem!.kindLabel, '이상 대응');
    expect(r1.call, isNotNull);
    expect(r1.call!.level, CallLevel.observe);
    expect(repo.messagesOf(r1.call!.id).single.kind, 'vital');

    repo.assign(r1.caseItem!.id, 'park_soyeon', t(14, 2));
    expect(repo.noticesFor('kim_haneul').first.body, '박소연 수석간호사가 맡았어요');

    final r2 = repo.saveMeasurement(residentId: minjun, value: 391, by: 'kim_haneul', at: t(14, 30));
    expect(r2.caseCreated, isFalse, reason: '같은 이상 건에 붙음');
    expect(r2.escalated, isTrue);
    expect(repo.callById(r1.call!.id).level, CallLevel.urgent);
    expect(repo.messagesOf(r1.call!.id).where((m) => m.kind == 'vital'), hasLength(2), reason: '재측정 값 자동 첨부');
    expect(repo.noticesFor('han_kyungsoo').first.important, isTrue, reason: '원장에게 중요 알림');

    repo.close(r1.caseItem!.id, 'park_soyeon', t(15, 30), '해열 확인');
    expect(repo.openCaseOf(minjun), isNull);
  });

  test('처방: 임시 저장 → 발행하면 번호가 붙고 대화에 안내, 그 뒤로는 고칠 수 없다', () {
    final repo = demo();
    final call = repo.openCalls.first;
    repo.saveDraft(callId: call.id, doctorId: 'kang_dahye', code: 'J06.9', codeName: '급성 상기도 감염', opinion: '수분 섭취', items: const []);
    final p = repo.issuePrescription(call.id, 'kang_dahye');
    expect(p.issued, isTrue);
    expect(p.number, startsWith('Rx#'));
    expect(repo.messagesOf(call.id).last.kind, 'system');
    final again = repo.saveDraft(callId: call.id, doctorId: 'kang_dahye', code: 'X', codeName: 'X', opinion: 'X', items: const []);
    expect(again.code, 'J06.9');
  });

  test('결재 일괄 확인', () {
    final repo = demo();
    repo.approveAll('park_soyeon');
    expect(repo.pendingApprovals, isEmpty);
  });

  test('개발 DB: 예시 명단만, 실제 반·별님이 생기면 예시는 숨겨진다', () {
    final repo = InMemoryRepository(dataset: Dataset.dev, clock: () => clockAt);
    expect(repo.isDev, isTrue);
    expect(repo.residents.single.example, isTrue);
    expect(repo.entries, isEmpty);
    expect(repo.openCalls, isEmpty);
    expect(repo.calendarEvents, isEmpty);
    expect(repo.defaultUser('pc'), 'ex_nurse');

    final c = repo.addClass(name: '은하수자리', sex: '남');
    final r = repo.addResident(classId: c.id, name: '홍길동');
    expect(repo.classes.map((x) => x.name), ['은하수자리']);
    expect(repo.residents.map((x) => x.name), ['홍길동']);
    expect(repo.rosterIsExample, isFalse);
    expect(repo.measurableClasses('ex_care'), {c.id});
    final s = repo.saveMeasurement(residentId: r.id, value: 365, by: 'ex_care', at: t(14, 0));
    expect(s.measurement.judgment.stage, Stage.normal);
  });

  test('저장했다가 다시 열면 이어진다 (명단 · 호출 · 대화 포함)', () async {
    final store = MemorySnapshotStore();
    final repo = demo(store: store);
    final call = repo.openCalls.first;
    repo.sendMessage(call.id, 'park_soyeon', '확인했어요');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(store.value, isNotNull);

    final reopened = demo(snapshot: store.value);
    expect(reopened.residents.length, 36);
    expect(reopened.messagesOf(call.id).last.body, '확인했어요');
    expect(reopened.openCases.length, repo.openCases.length);
    expect(reopened.baselineOf(residentByName('이서준').id, t(9, 0)).value, 371);
  });

  test('다른 화면의 변경 받아오기 (loadRemote)는 다시 저장하지 않는다', () async {
    final store = MemorySnapshotStore();
    final a = demo();
    final b = demo(store: store);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    store.value = null;
    a.approveAll('park_soyeon');
    expect(b.loadRemote(a.toSnapshot()), isTrue);
    expect(b.pendingApprovals, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(store.value, isNull);
    expect(b.loadRemote('{깨진'), isFalse);
    expect(b.residents.length, 36, reason: '실패하면 그대로');
  });

  test('처음 상태로: 시연은 가상 자료로 다시, 개발은 예시만', () async {
    final repo = demo();
    repo.saveMeasurement(residentId: residentByName('김민준').id, value: 391, by: 'kim_haneul', at: t(14, 0));
    expect(repo.openCases.length, 3);
    await repo.resetDataset();
    expect(repo.openCases.length, 2);

    final dev = InMemoryRepository(dataset: Dataset.dev, clock: () => clockAt);
    dev.addResident(classId: 'ex_class', name: '홍길동');
    await dev.resetDataset();
    expect(dev.rosterIsExample, isTrue);
  });

  test('망가진 저장 자료면 처음 상태로 연다', () {
    final repo = demo(snapshot: '{깨진 데이터');
    expect(repo.residents.length, 36);
  });

  test('측정 시점: 양자리 늦은 순서 별님은 오전 미기록', () {
    final repo = demo();
    final missed = repo.missedTempResidents(clockAt).map((r) => r.name);
    expect(missed, contains('남정우'));
    expect(missed, isNot(contains('김민준')));
    expect(missed.length, lessThanOrEqualTo(4));
  });

  test('프로필 사진: 최신순 기록, 그 반 담당(담임·배치)만 올리고, 저장했다 열어도 남는다', () {
    final repo = demo();
    final seojun = residentByName('이서준').id;
    final photos = repo.photosOf(seojun);
    expect(photos.length, 3);
    expect(photos.first.uploadedAt.isAfter(photos.last.uploadedAt), isTrue);

    expect(repo.canUploadPhoto('kim_haneul', seojun), isTrue); // 은하수자리 배치
    expect(repo.canUploadPhoto('lee_sujin', seojun), isTrue); // 은하수자리 담임
    expect(repo.canUploadPhoto('park_jieun', seojun), isFalse); // 물병자리 담임
    expect(() => repo.addPhoto(seojun, 'data:x', by: 'park_jieun'), throwsStateError);

    final p = repo.addPhoto(seojun, '/api/photo/abc', by: 'kim_haneul');
    expect(repo.profilePhotoOf(seojun)!.id, p.id);
    final again = demo(snapshot: repo.toSnapshot());
    expect(again.photosOf(seojun).map((x) => x.url), contains('/api/photo/abc'));
    expect(again.profilePhotoOf(seojun)!.url, '/api/photo/abc');
  });

  test('개발 DB: 프로필 사진 기록은 비어 있다 (예시는 화면에서만)', () {
    final repo = InMemoryRepository(dataset: Dataset.dev, clock: () => clockAt);
    expect(repo.photosOf(repo.residents.first.id), isEmpty);
  });
}
