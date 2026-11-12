import 'package:byeoljari_note/core/models.dart';
import 'package:byeoljari_note/core/repository.dart';
import 'package:byeoljari_note/core/seed.dart';
import 'package:byeoljari_note/core/storage.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime t(int h, int m) => DateTime(2026, 10, 28, h, m);

void main() {
  test('저장했다가 다시 열면 기록이 이어진다', () async {
    final store = MemorySnapshotStore();
    final repo = InMemoryRepository(store: store);
    final seojun = residentByName('이서준').id;
    final r = repo.saveMeasurement(residentId: seojun, value: 384, by: 'kim_haneul', at: t(9, 45));
    repo.assign(r.caseItem!.id, 'park_soyeon', t(9, 47));
    final entry = repo.entries.firstWhere((e) => e.residentId == residentByName('한나리').id);
    repo.addReply(entry.id, 'kim_haneul', '저도 봤어요', t(9, 50));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(store.value, isNotNull);

    final reopened = InMemoryRepository(snapshot: store.value, store: store);
    expect(reopened.openCases.length, 2);
    expect(reopened.caseById(r.caseItem!.id).assigneeId, 'park_soyeon');
    expect(reopened.latestOf(seojun)!.value, 384);
    expect(reopened.repliesOf(entry.id).map((x) => x.body), contains('저도 봤어요'));
    expect(reopened.baselineOf(seojun, t(10, 0)).value, 371, reason: '시드 기록도 다시 만들어짐');
    expect(reopened.now().isAfter(t(9, 40)), isTrue, reason: '시계도 이어짐');
  });

  test('시연 초기화하면 처음 상태로', () async {
    final store = MemorySnapshotStore();
    final repo = InMemoryRepository(store: store);
    repo.saveMeasurement(residentId: residentByName('이서준').id, value: 391, by: 'kim_haneul', at: t(9, 45));
    expect(repo.openCases.length, 2);
    await repo.resetDemo();
    expect(repo.openCases.length, 1);
    expect(repo.now().difference(demoStart).inMinutes, lessThan(1));
  });

  test('망가진 저장 데이터면 시연 시작 상태로 연다', () {
    final repo = InMemoryRepository(snapshot: '{깨진 데이터');
    expect(repo.openCases.length, 1);
  });

  test('측정 시점: 최도윤 오전 미기록, 이서준 오전 기록됨, 오후는 예정', () {
    final repo = InMemoryRepository();
    final doyun = repo.slotStatuses(residentByName('최도윤').id, t(0, 0), t(9, 41));
    expect(doyun.first.slot, TempSlot.am);
    expect(doyun.first.state, SlotState.missed);
    expect(doyun.last.state, SlotState.upcoming);
    final seojun = repo.slotStatuses(residentByName('이서준').id, t(0, 0), t(9, 41));
    expect(seojun.first.state, SlotState.recorded);
    expect(seojun.first.measurement!.value, 376);
    expect(repo.missedTempResidents(t(9, 41)).map((r) => r.name), contains('최도윤'));
  });

  test('아카이브: 이서준 기록 + 은하수자리 반 공지, 2025년 기록 포함', () {
    final repo = InMemoryRepository();
    final list = repo.archiveEntriesOf(residentByName('이서준').id);
    expect(list.any((e) => e.createdAt.year == 2025 && (e.body ?? '').contains('소리')), isTrue);
    expect(list.any((e) => e.kindLabel == '반 공지' && e.classId == 'milkyway'), isTrue);
    expect(list.any((e) => e.classId == 'aquarius'), isFalse);
  });
}
