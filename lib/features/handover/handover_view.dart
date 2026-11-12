// 인수인계 화면 계산 (범위·미확인·필터). 화면 그리기와 떼어 두어 테스트하기 쉽게 한다.
// 판정은 계산하지 않는다. 측정에 저장된 판정을 읽기만 한다 (통합 명세 5-2).
import '../../core/models.dart';
import '../../core/repository.dart';

enum FeedFilter { all, unread, task, facility, classNotice, resident }

extension FeedFilterInfo on FeedFilter {
  String get label => switch (this) {
        FeedFilter.all => '모두',
        FeedFilter.unread => '미확인',
        FeedFilter.task => '할 일',
        FeedFilter.facility => '전체 공지',
        FeedFilter.classNotice => '반별 공지',
        FeedFilter.resident => '별님 기록',
      };

  String get emptyText => switch (this) {
        FeedFilter.unread => '안 본 기록이 없어요. 모두 확인했어요.',
        FeedFilter.task => '남은 할 일이 없어요.',
        _ => '기록이 없어요.',
      };
}

/// 최신 기록(HO-1)과 별님별 기록(HO-2)이 같이 쓰는 계산.
class HandoverView {
  HandoverView(this.repo, this.me, this.now, {Set<String> keep = const {}}) : keepIds = keep {
    since = repo.handoverSince(me, now);
    shift = repo.shiftAt(now, staffId: me) ?? repo.shiftAt(now);
    activeCases = repo.openCases.where((c) => c.recoveredAt == null).toList();
    _activeCaseIds = {for (final c in activeCases) c.id};
    final all = repo.entries.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    allSorted = all;
    visible = all.where((e) => !isActiveCaseEntry(e) && (inRange(e) || hasOpenTask(e) || isPinnedNotice(e) || keepIds.contains(e.id))).toList();
  }

  final InMemoryRepository repo;
  final String me;
  final DateTime now;
  /// 이 화면에서 방금 완료해 남겨 둘 기록.
  final Set<String> keepIds;

  /// "내 직전 근무 시작 이후" 기준 시각 (방식 C).
  late final DateTime since;

  /// 지금 근무조. 확인 분모(n/4)로 쓴다.
  late final Shift? shift;

  /// 대응 칸: 종료 안 됐고 회복 전인 이상 건. 긴급 먼저, 그다음 최근 순 (6-3).
  late final List<Case> activeCases;
  late final Set<String> _activeCaseIds;
  late final List<Entry> allSorted;

  /// 최신 기록에 보이는 기록 (대응 칸에 올라간 기록은 뺀다).
  late final List<Entry> visible;

  int get urgentCount => activeCases.where((c) => c.isUrgent).length;
  int get abnormalCount => activeCases.length - urgentCount;

  bool isActiveCaseEntry(Entry e) => e.caseId != null && _activeCaseIds.contains(e.caseId);
  bool hasOpenTask(Entry e) => e.task != null && !e.task!.done;
  bool inRange(Entry e) => !e.createdAt.isBefore(since);
  bool isPinnedNotice(Entry e) => e.scope == EntryScope.facility && e.pinned;

  /// 미확인 = 작성자 ≠ 나 AND 내 확인 기록 없음 (4.3).
  bool isUnread(Entry e) => e.authorId != me && !repo.isRead(e.id, me);

  /// 세는 범위 안의 미확인 (범위 안 + 열린 할 일, 대응 칸 제외).
  bool countsAsUnread(Entry e) => isUnread(e) && !isActiveCaseEntry(e) && (inRange(e) || hasOpenTask(e));

  /// 완료 안 된 할 일 전체 (작성자·범위 무관, 4.4).
  List<Entry> get openTasks => allSorted.where(hasOpenTask).toList();

  /// 이전 근무에서 넘어온 할 일: 범위 밖에서 들어온 열린 할 일 (+ 이 화면에서 방금 완료한 것).
  List<Entry> get carried =>
      visible.where((e) => e.task != null && !inRange(e) && (hasOpenTask(e) || keepIds.contains(e.id))).toList();

  List<Entry> get unread => allSorted.where(countsAsUnread).toList();

  /// 필터별 목록. "모두"는 고정 공지·넘어온 할 일을 따로 그리므로 나머지만 돌려준다.
  List<Entry> listFor(FeedFilter f) {
    switch (f) {
      case FeedFilter.all:
        final carriedIds = {for (final e in carried) e.id};
        return visible.where((e) => !isPinnedNotice(e) && !carriedIds.contains(e.id)).toList();
      case FeedFilter.unread:
        final list = visible.where(countsAsUnread).toList();
        list.sort((a, b) {
          final fa = a.scope == EntryScope.facility, fb = b.scope == EntryScope.facility;
          if (fa != fb) return fa ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        return list;
      case FeedFilter.task:
        final list = visible.where((e) => e.task != null).toList();
        list.sort((a, b) {
          final oa = hasOpenTask(a), ob = hasOpenTask(b);
          if (oa != ob) return oa ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        return list;
      case FeedFilter.facility:
        return visible.where((e) => e.scope == EntryScope.facility).toList();
      case FeedFilter.classNotice:
        return visible.where((e) => e.scope == EntryScope.classScope).toList();
      case FeedFilter.resident:
        return visible.where((e) => e.scope == EntryScope.resident).toList();
    }
  }

  List<Entry> get pinnedNotices => visible.where(isPinnedNotice).toList();

  /// 칩 옆 숫자. 미확인만 "남은 수".
  int countFor(FeedFilter f) => switch (f) {
        FeedFilter.all => visible.length,
        FeedFilter.unread => unread.length,
        _ => listFor(f).length,
      };

  /// 확인한 사람 중 지금 근무조 인원.
  List<String> shiftReaders(String entryId) {
    final ids = repo.readersOf(entryId).map((r) => r.staffId);
    final s = shift;
    return s == null ? ids.toList() : ids.where(s.staffIds.contains).toList();
  }

  /// 반 탭 배지: 그 반의 반 공지와 별님 기록 중 내가 확인 안 한 것 (3.2).
  int unreadInClass(String classId) => unread
      .where((e) => e.scope != EntryScope.facility && e.classId == classId)
      .length;

  /// 별님 카드 "새 n": 그 별님 대상 미확인 별님 기록 수.
  int unreadOfResident(String residentId) =>
      unread.where((e) => e.scope == EntryScope.resident && e.residentId == residentId).length;

  Case? activeCaseOf(String residentId) {
    for (final c in activeCases) {
      if (c.residentId == residentId) return c;
    }
    return null;
  }
}
