import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime t(int h, int m) => DateTime(2026, 10, 28, h, m);

void main() {
  test('명단: 6반 36명, 반별 인원·성별이 명세와 같다', () {
    final repo = InMemoryRepository();
    final counts = {for (final c in repo.classes) c.name: repo.residentsOf(c.id).length};
    expect(counts, {'물병자리': 7, '물고기자리': 6, '곰자리': 5, '은하수자리': 6, '양자리': 6, '고래자리': 6});
    expect(residents.length, 36);
    expect(repo.classes.where((c) => c.sex == '여').map((c) => c.name), ['물병자리', '물고기자리']);
  });

  test('시드 기록으로 계산한 기저치 = 명세 값 (이서준 37.1, 박승민 36.8)', () {
    final repo = InMemoryRepository(withDemoState: false);
    expect(repo.baselineOf(residentByName('이서준').id, demoStart).value, 371);
    expect(repo.baselineOf(residentByName('박승민').id, demoStart).value, 368);
  });

  test('시작 상태: 이상 대응 1건(박승민), 긴급 0건, 이서준·최도윤·정현우 할 일 열림', () {
    final repo = InMemoryRepository();
    expect(repo.openCases.length, 1);
    expect(repo.resident(repo.openCases.single.residentId).name, '박승민');
    expect(repo.openCases.single.isUrgent, isFalse);
    expect(repo.openTempTasksOf(residentByName('이서준').id), hasLength(1));
    expect(repo.openTempTasksOf(residentByName('최도윤').id), hasLength(1));
    expect(repo.openTempTasksOf(residentByName('정현우').id), hasLength(1));
    expect(repo.openTempTasksOf(residentByName('한지호').id), isEmpty, reason: '36.8 저장으로 자동 완료');
  });

  test('시연 흐름: 37.6 주의 → 38.4 이상 대응 → 39.1 긴급 → 종료', () {
    final repo = InMemoryRepository();
    final seojun = residentByName('이서준').id;

    final r1 = repo.saveMeasurement(residentId: seojun, value: 384, by: 'kim_haneul', at: t(9, 45));
    expect(r1.caseCreated, isTrue);
    expect(r1.caseItem!.kindLabel, '이상 대응');
    expect(r1.measurement.judgment.diff, 13);
    expect(repo.openTempTasksOf(seojun), isEmpty, reason: '재측정 할 일 자동 완료');

    repo.acknowledge(r1.caseItem!.id, 'park_soyeon', t(9, 47));
    repo.assign(r1.caseItem!.id, 'park_soyeon', t(9, 47));
    expect(repo.noticesFor('kim_haneul').first.body, '박소연 간호사가 맡았어요');

    final r2 = repo.saveMeasurement(residentId: seojun, value: 391, by: 'kim_haneul', at: t(10, 15));
    expect(r2.caseCreated, isFalse, reason: '같은 이상 건에 붙음');
    expect(r2.escalated, isTrue);
    expect(repo.caseById(r1.caseItem!.id).isUrgent, isTrue);
    expect(repo.openCases.first.id, r1.caseItem!.id, reason: '긴급이 맨 위');
    expect(repo.noticesFor('han_kyungsoo').first.important, isTrue, reason: '원장에게 중요 알림');

    repo.close(r1.caseItem!.id, 'park_soyeon', t(11, 30), '병원 진료 후 해열');
    expect(repo.openCaseOf(seojun), isNull);
  });

  test('체온이 내려가면 종료 대기, 다시 오르면 해제 (C3)', () {
    final repo = InMemoryRepository();
    final c = repo.openCases.single;
    repo.saveMeasurement(residentId: c.residentId, value: 369, by: 'kim_haneul', at: t(10, 0));
    expect(repo.caseById(c.id).recoveredAt, isNotNull);
    expect(repo.caseById(c.id).isOpen, isTrue);
    repo.saveMeasurement(residentId: c.residentId, value: 381, by: 'kim_haneul', at: t(10, 30));
    expect(repo.caseById(c.id).recoveredAt, isNull);
  });

  test('잘못 잰 값은 지우지 않고 무효 표시, 최근 값에서 빠짐 (C7)', () {
    final repo = InMemoryRepository();
    final id = residentByName('김민준').id;
    final r = repo.saveMeasurement(residentId: id, value: 366, by: 'kim_haneul', at: t(10, 0));
    repo.voidMeasurement(r.measurement.id, by: 'kim_haneul', at: t(10, 1));
    expect(repo.measurementsOf(id).first.isVoided, isTrue);
    expect(repo.latestOf(id)!.id, isNot(r.measurement.id));
  });

  test('범위 밖 체온은 저장하지 않는다', () {
    final repo = InMemoryRepository();
    expect(() => repo.saveMeasurement(residentId: residents.first.id, value: 425, by: 'kim_haneul', at: t(10, 0)),
        throwsArgumentError);
  });

  test('주의 저장 → 30분 재측정 할 일 자동 생성 (C10)', () {
    final repo = InMemoryRepository();
    final r = repo.saveMeasurement(residentId: residentByName('김민준').id, value: 371, by: 'kim_haneul', at: t(10, 0));
    expect(r.measurement.judgment.stage, Stage.caution);
    expect(r.task!.dueAt, t(10, 30));
  });
}
