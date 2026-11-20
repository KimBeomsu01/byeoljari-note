// 01 인수인계 화면에 보이는 것 계산 (요약 숫자 · 필터 칩 숫자 · 목록).
// 화면 그리기와 떼어 두어 숫자가 한 곳에서만 나오게 한다. 판정은 계산하지 않고 측정에 저장된 판정을 읽는다.
import '../../core/models.dart';
import '../../core/repository.dart';

/// 필터 칩: 모두 · 미확인 · 할 일 · 공지사항 · 별님 기록.
enum HoFilter { all, unread, todo, notice, record }

extension HoFilterInfo on HoFilter {
  String get label => switch (this) {
        HoFilter.all => '모두',
        HoFilter.unread => '미확인',
        HoFilter.todo => '할 일',
        HoFilter.notice => '공지사항',
        HoFilter.record => '별님 기록',
      };

  /// 거른 결과가 비었을 때 문구 (시연 DB).
  String get emptyText => switch (this) {
        HoFilter.all => '아직 기록이 없어요',
        HoFilter.unread => '모두 확인했어요',
        HoFilter.todo => '남은 할 일이 없어요',
        HoFilter.notice => '공지가 없어요',
        HoFilter.record => '별님 기록이 없어요',
      };
}

/// 한 필터로 거른 화면 목록.
class HoView {
  const HoView({required this.cases, required this.todos, required this.feed});
  final List<Case> cases;
  final List<Entry> todos;
  final List<Entry> feed;

  bool get isEmpty => cases.isEmpty && todos.isEmpty && feed.isEmpty;
}

class HandoverData {
  HandoverData(this.repo, this.me, this.now) {
    since = repo.handoverSince(me, now);
    shift = repo.shiftAt(now, staffId: me) ?? repo.shiftAt(now);
    // 내 담당 반만 (간호·사무·야간 당직은 전체 반)
    myClasses = repo.myClasses(me);
    cases = repo.openCases.where((c) => myClasses.contains(c.classId)).toList();
    final openCaseIds = {for (final c in cases) c.id};
    bool onCaseCard(Entry e) => e.caseId != null && openCaseIds.contains(e.caseId);

    final all = repo.entries.where((e) => repo.isMyEntry(e, myClasses)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // 할 일 줄: 체온 기록이 아닌 기록의 열린 할 일 (체온 기록의 재측정 할 일은 체온 카드 안에 [재측정 완료]로 보인다).
    todos = all.where((e) => isOpenTask(e) && e.measurementId == null && !onCaseCard(e)).toList()..sort(_byDue);
    // 최신 기록: 직전 근무 이후 기록 + 열린 할 일이 있는 체온 기록 + 고정 공지. 긴급 카드·할 일 줄에 올라간 기록은 뺀다.
    feed = all
        .where((e) =>
            !onCaseCard(e) &&
            !(isOpenTask(e) && e.measurementId == null) &&
            (!e.createdAt.isBefore(since) || isOpenTask(e) || (e.scope == EntryScope.facility && e.pinned)))
        .toList();
    missed = repo.missedTempResidents(now).where((r) => myClasses.contains(r.classId)).toList();
  }

  final InMemoryRepository repo;
  final String me;
  final DateTime now;

  /// 내 담당 반 id.
  late final Set<String> myClasses;

  /// "내 직전 근무 시작 이후" 기준 시각.
  late final DateTime since;

  /// 지금 근무조 (내 근무조가 우선). 근무조가 없으면 null.
  late final Shift? shift;

  /// 열린 이상 건 (긴급 먼저).
  late final List<Case> cases;
  late final List<Entry> todos;
  late final List<Entry> feed;

  /// 오늘 측정 시점이 지났는데 기록이 없는 별님.
  late final List<Resident> missed;

  static bool isOpenTask(Entry e) => e.task != null && !e.task!.done;

  /// 미확인 = 쓴 사람이 내가 아니고 내 확인 기록이 없음.
  bool isUnread(Entry e) => e.authorId != me && !repo.isRead(e.id, me);

  static bool isNotice(Entry e) => e.scope != EntryScope.resident;

  /// "오전 근무조 인계". 근무조가 없으면 시각으로 정한다.
  String get shiftTitle => '${shift?.label ?? _labelByHour(now.hour)} 근무조 인계';

  static String _labelByHour(int h) => h >= 7 && h < 14 ? '오전' : (h >= 14 && h < 22 ? '오후' : '야간');

  // ── 숫자 (요약 카드와 칩이 같은 값을 쓴다)
  int get caseCount => cases.length;
  int get taskCount => todos.length + feed.where(isOpenTask).length;
  int get unreadCount => todos.where(isUnread).length + feed.where(isUnread).length;
  int get allCount => cases.length + todos.length + feed.length;

  int? countFor(HoFilter f) => switch (f) {
        HoFilter.all => allCount,
        HoFilter.unread => unreadCount,
        HoFilter.todo => taskCount,
        _ => null,
      };

  HoView viewFor(HoFilter f) => switch (f) {
        HoFilter.all => HoView(cases: cases, todos: todos, feed: feed),
        HoFilter.unread => HoView(cases: const [], todos: todos.where(isUnread).toList(), feed: feed.where(isUnread).toList()),
        HoFilter.todo => HoView(cases: const [], todos: todos, feed: feed.where(isOpenTask).toList()),
        HoFilter.notice => HoView(cases: const [], todos: const [], feed: feed.where(isNotice).toList()),
        HoFilter.record => HoView(
            cases: const [],
            todos: todos.where((e) => e.scope == EntryScope.resident).toList(),
            feed: feed.where((e) => e.scope == EntryScope.resident).toList(),
          ),
      };

  /// 할 일: 기한이 이른 것부터, 기한 없는 것은 뒤로.
  static int _byDue(Entry a, Entry b) {
    final da = a.task!.dueAt, db = b.task!.dueAt;
    if (da != null && db != null && da != db) return da.compareTo(db);
    if ((da == null) != (db == null)) return da == null ? 1 : -1;
    return a.createdAt.compareTo(b.createdAt);
  }
}

/// '10분' · '1시간' · '4시간 9분'.
String spanText(int minutes) {
  final m = minutes.abs();
  if (m < 60) return '$m분';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h시간' : '$h시간 $r분';
}

/// 앞으로 남은 시간 / 지난 시간: '10분 후' · '4시간 9분 지남'.
String untilText(DateTime at, DateTime now) {
  final mins = at.difference(now).inMinutes;
  if (mins == 0) return '지금';
  return mins > 0 ? '${spanText(mins)} 후' : '${spanText(mins)} 지남';
}
