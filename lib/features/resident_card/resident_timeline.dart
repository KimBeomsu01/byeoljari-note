// 별님카드 기록 타임라인 (Claude Design ResidentTimeline.dc.html: Timeline · TimelineItem · TimelineDivider).
// 이 별님 기록 + 소속 반 공지(archiveEntriesOf) + 이 별님 체온 측정을 시간순(최신 먼저)으로 섞는다.
// 측정 한 건 = 한 줄: 측정에 붙은 자동 '체온 기록'은 그 측정 줄에 합친다.
import 'package:flutter/material.dart';

import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';

// ── 자료

sealed class TimelineRecord {
  const TimelineRecord();
  DateTime get at;
}

/// 체온 측정 한 건. [entry]는 측정에 붙은 자동 기록(할 일·이상 건).
class TempRecord extends TimelineRecord {
  const TempRecord(this.m, this.entry);
  final Measurement m;
  final Entry? entry;

  @override
  DateTime get at => m.measuredAt;

  /// 평소가 아닌 값 (vital-warning). 무효는 평소 줄 모양으로 지운 표시만.
  bool get isWarning => !m.isVoided && m.judgment.stage != Stage.normal;
}

/// 관찰 기록 · 감각 메모 · 반 공지.
class EntryRecord extends TimelineRecord {
  const EntryRecord(this.e);
  final Entry e;

  @override
  DateTime get at => e.createdAt;

  bool get isNotice => e.scope == EntryScope.classScope;
  bool get isSensory => e.kindLabel == '감각 메모';
}

/// 필터 칩: 모두 · 별님 이름(반 공지 숨김) · 반 공지(개인 기록 숨김).
enum ChipFilter { all, resident, notice }

/// [전체] 버튼 시트의 기록 종류.
enum KindFilter { all, temp, observation, sensory }

/// [전체] 버튼 시트의 기간.
enum PeriodFilter { all, today, week, month }

extension KindFilterLabel on KindFilter {
  String get label => switch (this) {
        KindFilter.all => '전체',
        KindFilter.temp => '체온',
        KindFilter.observation => '관찰 기록',
        KindFilter.sensory => '감각 메모',
      };
  String get short => switch (this) {
        KindFilter.all => '전체',
        KindFilter.temp => '체온',
        KindFilter.observation => '관찰',
        KindFilter.sensory => '감각',
      };
}

extension PeriodFilterLabel on PeriodFilter {
  String get label => switch (this) {
        PeriodFilter.all => '전체 기간',
        PeriodFilter.today => '오늘',
        PeriodFilter.week => '최근 7일',
        PeriodFilter.month => '최근 30일',
      };
  String get short => switch (this) {
        PeriodFilter.all => '전체',
        PeriodFilter.today => '오늘',
        PeriodFilter.week => '7일',
        PeriodFilter.month => '30일',
      };
}

/// 이 별님 타임라인 (최신 먼저).
/// 체온은 어제·오늘 것 전부 + 그 전은 평소가 아닌 값·기록이 붙은 값만 (평소 값이 줄줄이 쌓이지 않게).
List<TimelineRecord> buildTimeline(InMemoryRepository repo, String residentId, DateTime now) {
  final entries = repo.archiveEntriesOf(residentId);
  final linked = <String, Entry>{
    for (final e in entries)
      if (e.measurementId != null) e.measurementId!: e,
  };
  final since = DateTime(now.year, now.month, now.day - 1);
  final ms = repo
      .measurementsOf(residentId)
      .where((m) => !m.measuredAt.isBefore(since) || m.judgment.stage != Stage.normal || linked.containsKey(m.id))
      .toList();
  final ids = {for (final m in ms) m.id};
  return <TimelineRecord>[
    for (final m in ms) TempRecord(m, linked[m.id]),
    for (final e in entries)
      if (e.measurementId == null || !ids.contains(e.measurementId)) EntryRecord(e),
  ]..sort((a, b) => b.at.compareTo(a.at));
}

/// 검색·종류·기간 (칩 제외).
bool matchesQuery(
  TimelineRecord r,
  InMemoryRepository repo,
  DateTime now, {
  required KindFilter kind,
  required PeriodFilter period,
  required String text,
}) {
  final kindOk = switch (kind) {
    KindFilter.all => true,
    KindFilter.temp => r is TempRecord,
    KindFilter.observation => r is EntryRecord && !r.isNotice && !r.isSensory,
    KindFilter.sensory => r is EntryRecord && r.isSensory,
  };
  if (!kindOk) return false;
  final from = switch (period) {
    PeriodFilter.all => null,
    PeriodFilter.today => DateTime(now.year, now.month, now.day),
    PeriodFilter.week => now.subtract(const Duration(days: 7)),
    PeriodFilter.month => now.subtract(const Duration(days: 30)),
  };
  if (from != null && r.at.isBefore(from)) return false;
  final q = text.trim().toLowerCase();
  if (q.isEmpty) return true;
  return searchTextOf(r, repo).toLowerCase().contains(q);
}

bool matchesChip(TimelineRecord r, ChipFilter chip) => switch (chip) {
      ChipFilter.all => true,
      ChipFilter.resident => !(r is EntryRecord && r.isNotice),
      ChipFilter.notice => r is EntryRecord && r.isNotice,
    };

String searchTextOf(TimelineRecord r, InMemoryRepository repo) => switch (r) {
      TempRecord(:final m, :final entry) => [
          '체온',
          formatTemp(m.value),
          _stageWord(m),
          if (m.isVoided) '무효 잘못 잰 값',
          repo.staff(m.recordedBy).name,
          entry?.body ?? '',
        ].join(' '),
      EntryRecord(:final e) => [e.kindLabel, kindTagOf(e), e.title ?? '', e.body ?? '', repo.staff(e.authorId).name].join(' '),
    };

/// 기록 종류 꼬리표 글자 (디자인: 관찰 · 감각 특이사항 · 반 공지).
String kindTagOf(Entry e) => switch (e.kindLabel) {
      '관찰 기록' => '관찰',
      '감각 메모' => '감각 특이사항',
      _ => e.kindLabel,
    };

String _stageWord(Measurement m) => m.judgment.stage == Stage.normal ? '정상' : m.judgment.stage.label;

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 이 별님 기록 건수 (자동 체온 기록은 측정과 한 건으로 센다).
({int count, DateTime? since}) recordTotalOf(InMemoryRepository repo, String residentId) {
  final own = repo
      .archiveEntriesOf(residentId)
      .where((e) => e.scope == EntryScope.resident && e.measurementId == null)
      .map((e) => e.createdAt);
  final ms = repo.measurementsOf(residentId).map((m) => m.measuredAt);
  final all = [...own, ...ms];
  if (all.isEmpty) return (count: 0, since: null);
  return (count: all.length, since: all.reduce((a, b) => a.isBefore(b) ? a : b));
}

// ── 화면

/// 날짜별로 묶은 타임라인. [records]는 이미 거른 것 (최신 먼저).
class ResidentTimeline extends StatelessWidget {
  const ResidentTimeline({super.key, required this.records, required this.repo, required this.now, required this.classId});
  final List<TimelineRecord> records;
  final InMemoryRepository repo;
  final DateTime now;
  final String classId;

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<TimelineRecord>>{};
    for (final r in records) {
      groups.putIfAbsent(_day(r.at), () => []).add(r);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    // 담임 바뀐 때 (TimelineDivider). 그 앞뒤에 기록이 있을 때만.
    final history = repo.homeroomHistoryOf(classId).toList()..sort((a, b) => a.from.compareTo(b.from));
    final dividers = <(DateTime, String)>[];
    for (var i = 0; i < history.length; i++) {
      final h = history[i];
      final yy = (h.from.year % 100).toString().padLeft(2, '0');
      final mm = h.from.month.toString().padLeft(2, '0');
      final cur = repo.staff(h.staffId).name;
      final label = i > 0 ? '$yy.$mm 담임 변경 (${repo.staff(history[i - 1].staffId).name} → $cur)' : '$yy.$mm 담임 시작 ($cur)';
      dividers.add((_day(h.from), label));
    }
    dividers.sort((a, b) => b.$1.compareTo(a.$1));

    final children = <Widget>[];
    var afterDivider = true;
    final pending = [...dividers];
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      if (i > 0) {
        // 가장 최근 기록보다 뒤에 바뀐 것은 앞뒤 기록이 없으니 뺀다.
        while (pending.isNotEmpty && pending.first.$1.isAfter(days[i - 1])) {
          pending.removeAt(0);
        }
        // 앞 날짜(바뀐 뒤)와 이 날짜(바뀌기 전) 사이.
        while (pending.isNotEmpty && d.isBefore(pending.first.$1)) {
          children.add(TimelineDivider(label: pending.first.$2));
          pending.removeAt(0);
          afterDivider = true;
        }
      }
      children.add(_DaySection(
        day: d,
        now: now,
        topPad: afterDivider ? 0 : 8,
        children: [for (final r in groups[d]!) TimelineItem(record: r, repo: repo, now: now)],
      ));
      afterDivider = false;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gap(children, 16)),
    );
  }
}

List<Widget> _gap(List<Widget> items, double gap) => [
      for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
    ];

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.now, required this.topPad, required this.children});
  final DateTime day;
  final DateTime now;
  final double topPad;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final diff = _day(now).difference(day).inDays;
    final rel = diff == 0 ? '오늘' : (diff == 1 ? '어제' : null);
    final Widget header = rel != null
        ? Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(rel, style: const TextStyle(fontSize: T.bodyMd, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900)),
            const SizedBox(width: 8),
            Flexible(
              child: Text('${day.month}월 ${day.day}일 (${_weekdays[day.weekday - 1]})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: T.label, height: 1.5, color: Ds.gray500)),
            ),
          ])
        : Text('${day.year}년 ${day.month}월 ${day.day}일',
            style: const TextStyle(fontSize: T.body, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray600));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: EdgeInsets.fromLTRB(4, topPad, 4, 0), child: Semantics(header: true, child: header)),
      const SizedBox(height: 10),
      ..._gap(children, 10),
    ]);
  }
}

/// TimelineDivider: 가운데 알약 글자 + 양옆 선.
class TimelineDivider extends StatelessWidget {
  const TimelineDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (context, c) => Row(children: [
          const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: Ds.gray300))),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: (c.maxWidth - 56).clamp(40, double.infinity)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Ds.gray100,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: Ds.gray200),
              ),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w500, color: Ds.gray500, letterSpacing: 0.55)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: Ds.gray300))),
        ]),
        ),
      );
}

/// 흰 카드 (TimelineItem 바탕).
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.child, this.radius = 24, this.padding = 16});
  final Widget child;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Ds.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Ds.borderCard),
          boxShadow: Ds.shadowSm,
        ),
        child: child,
      );
}

/// 종류 꼬리표 (radius 6).
class _KindTag extends StatelessWidget {
  const _KindTag(this.text, {required this.bg, required this.fg, this.size = T.micro});
  final String text;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.tag)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, height: 1.5, fontWeight: FontWeight.w700, color: fg, fontFeatures: tabular)),
      );
}

const _metaStyle = TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500);
const _authorStyle = TextStyle(fontSize: T.caption, height: 1.5, fontWeight: FontWeight.w500, color: Ds.gray700);
const _timeStyle = TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500, fontFeatures: tabular);

/// 오른쪽 "이수진 · 09:15". 폭이 정해진 부품이라 Row의 고정 칸에 둔다 (이름은 80까지, 넘치면 …).
class _Meta extends StatelessWidget {
  const _Meta({required this.author, required this.time, this.extra, this.dot = true});
  final String author;
  final String time;
  final String? extra;
  final bool dot;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Text(author, maxLines: 1, overflow: TextOverflow.ellipsis, style: _authorStyle),
        ),
        if (extra != null) ...[
          const SizedBox(width: 6),
          Text(extra!, style: _authorStyle.copyWith(color: Ds.blue500, fontWeight: FontWeight.w600)),
        ],
        SizedBox(width: dot ? 6 : 8),
        if (dot) ...[const Text('·', style: _metaStyle), const SizedBox(width: 6)],
        Text(time, style: _timeStyle),
      ]);
}

const _bodyStyle = TextStyle(fontSize: T.label, height: 1.625, fontWeight: FontWeight.w500, color: Ds.gray800);

/// 기록 한 줄 (TimelineItem). 종류에 따라 vital-warning · vital-normal · class-notice · observation · sensory-note.
class TimelineItem extends StatelessWidget {
  const TimelineItem({super.key, required this.record, required this.repo, required this.now});
  final TimelineRecord record;
  final InMemoryRepository repo;
  final DateTime now;

  @override
  Widget build(BuildContext context) => switch (record) {
        TempRecord r when r.isWarning => _VitalWarning(r: r, repo: repo, now: now),
        TempRecord r => _VitalNormal(r: r, repo: repo),
        EntryRecord r => _EntryItem(r: r, repo: repo),
      };
}

class _VitalWarning extends StatelessWidget {
  const _VitalWarning({required this.r, required this.repo, required this.now});
  final TempRecord r;
  final InMemoryRepository repo;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final m = r.m;
    final low = m.judgment.stage == Stage.low;
    final fg = low ? Ds.blue500 : Ds.red500;
    final bg = low ? Ds.blue50 : Ds.red50;
    final diff = m.judgment.diff;
    final diffText = diff == 0 ? '평소와 같음' : '${fmtDiffDeg(diff)} ${diff > 0 ? '상승' : '하강'}';
    final c = m.caseId == null ? null : repo.allCases.where((x) => x.id == m.caseId).firstOrNull;
    final task = r.entry?.task;
    final body = r.entry?.body;

    String? status;
    if (c != null) {
      if (!c.isOpen) {
        status = '대응 종료';
      } else if (c.remeasureAt != null) {
        status = c.remeasureAt!.isBefore(now) ? '${hhmm(c.remeasureAt!)} 재측정 시간 지남' : '${hhmm(c.remeasureAt!)} 재측정 예정';
      } else {
        status = '${c.kindLabel} 중';
      }
    } else if (task != null) {
      status = task.done ? '재측정 완료' : (task.dueAt != null ? '${hhmm(task.dueAt!)} 재측정 예정' : '재측정 예정');
    }

    return Semantics(
      container: true,
      label: '체온 ${formatTemp(m.value)}도 ${m.judgment.stage.label}',
      child: _ItemCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _KindTag('${formatTemp(m.value)}° ${m.judgment.stage.label}', bg: bg, fg: fg, size: T.caption),
                Text(diffText, style: TextStyle(fontSize: T.caption, height: 1.5, fontWeight: FontWeight.w600, color: fg)),
              ]),
            ),
            const SizedBox(width: 8),
            _Meta(author: repo.staff(m.recordedBy).name, time: hhmm(m.measuredAt)),
          ]),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(body, style: _bodyStyle.copyWith(fontSize: T.body)),
          ],
          if (c != null || status != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ds.gray100))),
              child: Row(children: [
                if (c != null)
                  _CaseLink(caseItem: c)
                else
                  const SizedBox.shrink(),
                const SizedBox(width: 8),
                if (status != null)
                  Expanded(
                    child: Text(status,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: T.caption, height: 1.5, fontWeight: FontWeight.w500, color: Ds.gray500)),
                  ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// "대응 이력 #102 >" → 이상 건 상세.
class _CaseLink extends StatelessWidget {
  const _CaseLink({required this.caseItem});
  final Case caseItem;

  @override
  Widget build(BuildContext context) {
    final n = RegExp(r'(\d+)$').firstMatch(caseItem.id)?.group(1);
    return InkWell(
      onTap: () => openCaseDetail(context, caseItem.id),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(n == null ? '대응 이력' : '대응 이력 #$n',
              style: const TextStyle(fontSize: T.caption, height: 1.5, fontWeight: FontWeight.w700, color: Ds.blue500)),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded, size: 14, color: Ds.blue500),
        ]),
      ),
    );
  }
}

class _VitalNormal extends StatelessWidget {
  const _VitalNormal({required this.r, required this.repo});
  final TempRecord r;
  final InMemoryRepository repo;

  @override
  Widget build(BuildContext context) {
    final m = r.m;
    final voided = m.isVoided;
    final note = voided
        ? '${m.voidReason ?? '잘못 잰 값'} · 무효'
        : '${_stageWord(m)} (${fmtDiffDeg(m.judgment.diff)})${m.correctsId != null ? ' · 다시 잼' : ''}';
    return Semantics(
      container: true,
      label: voided ? '무효 처리된 체온 ${formatTemp(m.value)}도' : '체온 ${formatTemp(m.value)}도 ${_stageWord(m)}',
      child: _ItemCard(
        radius: 20,
        padding: 14,
        child: Row(children: [
          Expanded(
            child: Row(children: [
              Text('${formatTemp(m.value)}°',
                  style: TextStyle(
                    fontSize: T.body,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: voided ? Ds.gray500 : Ds.gray900,
                    fontFeatures: tabular,
                    decoration: voided ? TextDecoration.lineThrough : null,
                    decorationColor: Ds.gray500,
                  )),
              const SizedBox(width: 8),
              Flexible(
                child: Text(note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: T.caption, height: 1.5, fontWeight: FontWeight.w500, color: Ds.gray500)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          _Meta(author: repo.staff(m.recordedBy).name, time: hhmm(m.measuredAt), dot: false),
        ]),
      ),
    );
  }
}

class _EntryItem extends StatelessWidget {
  const _EntryItem({required this.r, required this.repo});
  final EntryRecord r;
  final InMemoryRepository repo;

  /// "확인 3/4": 그 기록을 쓴 근무조(+쓴 사람) 중 확인한 사람. 쓴 사람은 확인한 것으로 센다.
  String _readLabel(Entry e) {
    final readers = {for (final x in repo.readersOf(e.id)) x.staffId, e.authorId};
    final shift = repo.shiftAt(e.createdAt);
    if (shift == null) return '확인 ${readers.length}명';
    final team = {...shift.staffIds, e.authorId};
    return '확인 ${readers.where(team.contains).length}/${team.length}';
  }

  @override
  Widget build(BuildContext context) {
    final e = r.e;
    final (bg, fg) = r.isSensory ? (Ds.blue50, Ds.blue500) : (Ds.gray100, Ds.gray700);
    final observation = !r.isNotice && !r.isSensory;
    final readers = {for (final x in repo.readersOf(e.id)) x.staffId, e.authorId}.length;
    return Semantics(
      container: true,
      child: _ItemCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Align(alignment: Alignment.centerLeft, child: _KindTag(kindTagOf(e), bg: bg, fg: fg))),
            const SizedBox(width: 8),
            _Meta(
              author: repo.staff(e.authorId).name,
              time: hhmm(e.createdAt),
              extra: observation ? '· ${_readLabel(e)}' : null,
            ),
          ]),
          const SizedBox(height: 8),
          if (e.title != null && e.title!.isNotEmpty)
            Text(e.title!, style: _bodyStyle.copyWith(fontWeight: FontWeight.w700, color: Ds.gray900)),
          if (e.body != null && e.body!.isNotEmpty) Text(e.body!, style: _bodyStyle),
          if (e.photoCount > 0) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.photo_outlined, size: 14, color: Ds.gray500),
              const SizedBox(width: 4),
              Text('사진 ${e.photoCount}장', style: const TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500)),
            ]),
          ],
          if (r.isSensory) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ds.gray100))),
              child: Row(children: [
                Text('확인 $readers명',
                    style: const TextStyle(fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w600, color: Ds.blue500)),
                const SizedBox(width: 8),
                const Text('·', style: TextStyle(fontSize: T.micro, height: 1.5, color: Ds.gray500)),
                const SizedBox(width: 8),
                const Text('케어팀 공유', style: TextStyle(fontSize: T.micro, height: 1.5, color: Ds.gray500)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// 개발 DB에서 기록이 하나도 없을 때 타임라인 자리의 예시 카드 (observation 모양).
class ExampleTimelineCard extends StatelessWidget {
  const ExampleTimelineCard({super.key});

  @override
  Widget build(BuildContext context) => ExampleWrap(
        child: _ItemCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
            Row(children: [
              _KindTag('관찰', bg: Ds.gray100, fg: Ds.gray700),
              SizedBox(width: 8),
              Flexible(child: _Meta(author: '예시 선생님', time: '09:15')),
              SizedBox(width: 48),
            ]),
            SizedBox(height: 8),
            Text('아침 식사를 남김없이 먹고 낮잠도 1시간 푹 잤어요. 기분 좋게 노래를 흥얼거렸어요.', style: _bodyStyle),
          ]),
        ),
      );
}
