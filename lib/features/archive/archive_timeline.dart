// AR 별님 아카이브의 타임라인 만들기 (화면과 분리한 순수 계산).
// 조회 규칙: 통합 명세 8장 끝 — 측정 + 그 별님 기록 + 소속 반 공지를 최신순으로 합친다.
// measurementId가 있는 기록은 그 측정 행에 합쳐 한 줄로 보인다 (6-4, 아카이브 5장).
import '../../core/models.dart';
import '../../core/repository.dart';

/// 범위 칩. 모두 / 체온 / 관찰 기록 / 반 공지.
enum ArchiveFilter { all, temp, observation, classNotice }

extension ArchiveFilterLabel on ArchiveFilter {
  String get label => switch (this) {
        ArchiveFilter.all => '모두',
        ArchiveFilter.temp => '체온',
        ArchiveFilter.observation => '관찰 기록',
        ArchiveFilter.classNotice => '반 공지',
      };
}

/// 타임라인 한 건.
sealed class ArchiveRecord {
  const ArchiveRecord();
  DateTime get at;
  String get key;

  /// 확인(읽음) 대상 기록. 체온 행은 합쳐진 인수인계 기록.
  Entry? get readTarget;

  bool matches(ArchiveFilter f);
}

/// 측정 한 건 = 한 줄. 그 측정으로 생긴 인수인계 기록([entry])은 행 안에서만 연결.
class TempRecord extends ArchiveRecord {
  const TempRecord(this.m, this.entry);
  final Measurement m;
  final Entry? entry;

  @override
  DateTime get at => m.measuredAt;
  @override
  String get key => 'm:${m.id}';
  @override
  Entry? get readTarget => entry;
  @override
  bool matches(ArchiveFilter f) => f == ArchiveFilter.all || f == ArchiveFilter.temp;

  /// 접어도 되는 평범한 체온 (평소, 무효 아님, 이상 건·기록·할 일 연결 없음).
  bool get isPlainNormal => m.judgment.stage == Stage.normal && !m.isVoided && m.caseId == null && entry == null;
}

/// 관찰 기록 또는 반 공지.
class EntryRecord extends ArchiveRecord {
  const EntryRecord(this.e);
  final Entry e;

  bool get isClassNotice => e.scope == EntryScope.classScope;

  @override
  DateTime get at => e.createdAt;
  @override
  String get key => 'e:${e.id}';
  @override
  Entry? get readTarget => e;
  @override
  bool matches(ArchiveFilter f) => switch (f) {
        ArchiveFilter.all => true,
        ArchiveFilter.temp => false,
        ArchiveFilter.observation => !isClassNotice,
        ArchiveFilter.classNotice => isClassNotice,
      };
}

/// 이 별님의 모든 기록 (최신순, 같은 시각은 키로 안정 정렬).
List<ArchiveRecord> buildArchiveRecords(InMemoryRepository repo, String residentId) {
  final entries = repo.archiveEntriesOf(residentId);
  final measurements = repo.measurementsOf(residentId);
  final mIds = {for (final m in measurements) m.id};
  final byMeasurement = <String, Entry>{};
  for (final e in entries.reversed) {
    // 오래된 것부터 넣어 같은 측정에 기록이 여럿이면 가장 처음 생긴 것을 쓴다.
    if (e.measurementId != null) byMeasurement.putIfAbsent(e.measurementId!, () => e);
  }
  final out = <ArchiveRecord>[
    for (final m in measurements) TempRecord(m, byMeasurement[m.id]),
    for (final e in entries)
      if (e.measurementId == null || !mIds.contains(e.measurementId) || byMeasurement[e.measurementId] != e) EntryRecord(e),
  ];
  out.sort((a, b) {
    final c = b.at.compareTo(a.at);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return out;
}

/// 검색: 앞뒤 공백 제거 → 내용·기록자·종류 부분 일치 (아카이브 3장 검색 규칙).
bool matchesQuery(InMemoryRepository repo, ArchiveRecord r, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final fields = <String?>[];
  void addEntry(Entry e) {
    fields
      ..add(e.body)
      ..add(e.title)
      ..add(e.kindLabel)
      ..add(_staffName(repo, e.authorId));
  }

  switch (r) {
    case TempRecord(:final m, :final entry):
      fields
        ..add('체온')
        ..add(_staffName(repo, m.recordedBy));
      if (entry != null) addEntry(entry);
    case EntryRecord(:final e):
      addEntry(e);
  }
  return fields.any((f) => f != null && f.toLowerCase().contains(q));
}

String? _staffName(InMemoryRepository repo, String id) {
  for (final s in repo.allStaff) {
    if (s.id == id) return s.displayName;
  }
  return null;
}

/// 확인하지 않은 기록인가 (인수인계 4.3: 작성자 ≠ 나 AND 내 확인 없음).
bool isUnread(InMemoryRepository repo, ArchiveRecord r, String me) {
  final e = r.readTarget;
  return e != null && e.authorId != me && !repo.isRead(e.id, me);
}

// ── 화면 줄

sealed class ArchiveRow {
  const ArchiveRow();
}

class DayHeaderRow extends ArchiveRow {
  const DayHeaderRow(this.label);
  final String label;
}

class RecordRow extends ArchiveRow {
  const RecordRow(this.record);
  final ArchiveRecord record;
}

/// 지난 날의 평범한 체온 묶음 (펼칠 수 있음).
class NormalGroupRow extends ArchiveRow {
  const NormalGroupRow(this.groupKey, this.records);
  final String groupKey;
  final List<TempRecord> records;
}

class HomeroomDividerRow extends ArchiveRow {
  const HomeroomDividerRow(this.at, this.fromStaffId, this.toStaffId);
  final DateTime at;
  final String fromStaffId;
  final String toStaffId;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 날짜 묶음 "오늘 · 10월 28일 / 어제 · 10월 27일 / 날짜" (통합 명세 5-8, 시제품 문구).
String dayLabel(DateTime day, DateTime now) {
  final d = _day(day);
  final today = _day(now);
  if (d == today) return '오늘 · ${d.month}월 ${d.day}일';
  if (d == DateTime(today.year, today.month, today.day - 1)) return '어제 · ${d.month}월 ${d.day}일';
  final wd = _weekdays[d.weekday - 1];
  if (d.year == today.year) return '${d.month}월 ${d.day}일 ($wd)';
  return '${d.year}년 ${d.month}월 ${d.day}일 ($wd)';
}

/// 보이는 기록으로 화면 줄을 만든다.
/// [collapseNormals]: 오늘이 아닌 날의 평범한 체온이 연달아 있으면 한 줄로 접는다.
/// [expanded]: 펼친 묶음 키.
List<ArchiveRow> buildRows({
  required List<ArchiveRecord> visible,
  required List<ClassHomeroomHistory> homeroomHistory,
  required DateTime now,
  required bool showHomeroomDividers,
  bool collapseNormals = true,
  Set<String> expanded = const {},
}) {
  final dividers = <HomeroomDividerRow>[
    if (showHomeroomDividers)
      for (var i = 1; i < homeroomHistory.length; i++)
        HomeroomDividerRow(homeroomHistory[i].from, homeroomHistory[i - 1].staffId, homeroomHistory[i].staffId),
  ]..sort((a, b) => b.at.compareTo(a.at));

  final rows = <ArchiveRow>[];
  final today = _day(now);
  DateTime? currentDay;
  List<TempRecord>? run;
  String? runKey;

  void flushRun() {
    if (run == null) return;
    if (expanded.contains(runKey)) {
      rows.addAll(run!.map(RecordRow.new));
    } else {
      rows.add(NormalGroupRow(runKey!, run!));
    }
    run = null;
    runKey = null;
  }

  var di = 0;
  for (final r in visible) {
    // 이 기록보다 나중에 생긴 담임 변경선을 먼저 넣는다 (이전 담임 기록 앞에 한 번).
    while (di < dividers.length && dividers[di].at.isAfter(r.at)) {
      flushRun();
      rows.add(dividers[di++]);
      currentDay = null;
    }
    final d = _day(r.at);
    if (d != currentDay) {
      flushRun();
      rows.add(DayHeaderRow(dayLabel(d, now)));
      currentDay = d;
    }
    final collapsible = collapseNormals && d != today && r is TempRecord && r.isPlainNormal;
    if (collapsible) {
      run ??= [];
      runKey ??= r.key;
      run!.add(r);
    } else {
      flushRun();
      rows.add(RecordRow(r));
    }
  }
  flushRun();
  return rows;
}
