// 사무국 PC 웹 (DESK) 공통: 집계 계산 + 넓은 화면용 표·카드 부품.
// 판정은 측정에 저장된 judgment만 읽는다. 웹에서 새로 계산하지 않는다 (통합 명세 6-7-2).
// 이 폴더의 화면은 모두 조회용이다. 저장소의 상태를 바꾸는 메서드를 부르지 않는다.
import 'package:flutter/material.dart';

import '../../core/baseline.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

export '../../core/ui.dart' show hhmm;

// ── 날짜

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

const _wd = ['월', '화', '수', '목', '금', '토', '일'];

/// "10월 28일 (수)"
String mdLabel(DateTime d) => '${d.month}월 ${d.day}일 (${_wd[d.weekday - 1]})';

/// "10/28 09:41" (오늘이면 "09:41")
String whenLabel(DateTime t, DateTime now) => sameDay(t, now) ? hhmm(t) : '${t.month}/${t.day} ${hhmm(t)}';

/// 체온 문구. 값이 없으면 '기록 없음' (0℃로 보이지 않게).
String tempText(Measurement? m) => m == null ? '기록 없음' : '${formatTemp(m.value)}℃';

/// 기저치 문구: "기준 37.1℃" 또는 "기저치 계산 중 (기록 n/10)".
String baselineText(BaselineResult b) =>
    b.source == BaselineSource.provisional ? b.note : '기준 ${formatTemp(b.value)}℃';

String sourceLabel(String s) => switch (s) {
      'quick' => '퀵 체온',
      'seed' => '지난 기록',
      _ => s,
    };

// ── 오늘 현황 계산 (원본 2장 + 통합 6-7-4·5)

/// 오늘 잰 측정 (무효 제외).
List<Measurement> todayMeasurementsOf(InMemoryRepository repo, String residentId, DateTime now) =>
    repo.measurementsOf(residentId).where((m) => !m.isVoided && sameDay(m.measuredAt, now)).toList();

class ClassStat {
  ClassStat(this.c, this.members, this.recorded, this.lastAt, this.openCases);
  final Class c;
  final int members;

  /// 오늘 체온 기록이 하나라도 있는 별님 수 (같은 별님 여러 번 = 한 명).
  final int recorded;
  final DateTime? lastAt;
  final int openCases;
}

List<ClassStat> classStats(InMemoryRepository repo, DateTime now) {
  final open = repo.openCases;
  return [
    for (final c in repo.classes)
      () {
        final rs = repo.residentsOf(c.id);
        var recorded = 0;
        DateTime? last;
        for (final r in rs) {
          final ms = todayMeasurementsOf(repo, r.id, now);
          if (ms.isNotEmpty) {
            recorded++;
            if (last == null || ms.first.measuredAt.isAfter(last)) last = ms.first.measuredAt;
          }
        }
        return ClassStat(c, rs.length, recorded, last, open.where((x) => x.classId == c.id).length);
      }(),
  ];
}

/// '먼저 살펴볼 별님' 한 줄. 열린 이상 건이거나, 오늘 주의 측정 + 재측정 할 일이 열린 것.
class AttentionItem {
  AttentionItem({required this.resident, this.caseItem, this.measurement, this.task});
  final Resident resident;
  final Case? caseItem;

  /// 이 줄에 보여줄 최근 측정 (무효 제외).
  final Measurement? measurement;

  /// 열린 재측정 할 일 (주의 측정 줄).
  final Task? task;
}

List<AttentionItem> attentionItems(InMemoryRepository repo, DateTime now, {String? classId}) {
  final out = <AttentionItem>[];
  final withCase = <String>{};
  for (final c in repo.openCases) {
    // openCases는 긴급 → 이상 대응 순
    withCase.add(c.residentId);
    if (classId != null && c.classId != classId) continue;
    final ms = repo.measurementsOfCase(c.id).where((m) => !m.isVoided).toList();
    out.add(AttentionItem(
      resident: repo.resident(c.residentId),
      caseItem: c,
      measurement: ms.isEmpty ? repo.latestOf(c.residentId) : ms.last,
    ));
  }
  final seen = <String>{};
  for (final e in repo.entries) {
    // entries는 최신순
    final t = e.task;
    if (e.residentId == null || e.measurementId == null || t == null || t.done || t.kind != TaskKind.temp) continue;
    if (withCase.contains(e.residentId) || !seen.add(e.residentId!)) continue;
    final Measurement m;
    try {
      m = repo.measurement(e.measurementId!);
    } catch (_) {
      continue;
    }
    if (m.isVoided || m.judgment.stage != Stage.caution || !sameDay(m.measuredAt, now)) continue;
    final r = repo.resident(e.residentId!);
    if (classId != null && r.classId != classId) continue;
    out.add(AttentionItem(resident: r, measurement: m, task: t));
  }
  return out;
}

// ── 대응 건 표시

/// 사람이 한 조치·자동 기록 중 마지막 것 (취소된 것 제외). 'created'는 조치가 아니다.
CaseEvent? lastActionOf(InMemoryRepository repo, String caseId) {
  final list = repo.eventsOf(caseId).where((e) => e.voidedBy == null && e.type != 'created').toList();
  return list.isEmpty ? null : list.last;
}

// ── 부품

/// 표 열 정의.
class DeskCol {
  const DeskCol(this.label, {this.flex = 1, this.width});
  final String label;
  final int flex;
  final double? width;
}

/// 행 높이 56 이상, 머리줄 있는 표. 셀은 위젯.
class DeskTable extends StatelessWidget {
  const DeskTable({super.key, required this.cols, required this.rows, this.empty = '조건에 맞는 기록이 없어요', this.rowHeight = 56});
  final double rowHeight;
  final List<DeskCol> cols;
  final List<DeskRow> rows;
  final String empty;

  Widget _cells(List<Widget> cells) => Row(children: [
        for (var i = 0; i < cols.length; i++)
          cols[i].width != null
              ? SizedBox(width: cols[i].width, child: _pad(cells[i]))
              : Expanded(flex: cols[i].flex, child: _pad(cells[i])),
      ]);

  Widget _pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: w);

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: const Color(0xFFFBEFEB),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: _cells([
              for (final c in cols)
                Text(c.label, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: inkSub)),
            ]),
          ),
          if (rows.isEmpty) EmptyNote(empty),
          for (final r in rows) ...[
            const Divider(height: 1),
            Material(
              key: r.key,
              color: r.selected ? sage : (r.highlight ?? surface),
              child: InkWell(
                onTap: r.onTap,
                child: Container(
                  constraints: BoxConstraints(minHeight: rowHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: r.selected
                      ? const BoxDecoration(border: Border(left: BorderSide(color: brandDark, width: 4)))
                      : null,
                  alignment: Alignment.centerLeft,
                  child: _cells(r.cells),
                ),
              ),
            ),
          ],
        ]),
      );
}

class DeskRow {
  const DeskRow({required this.cells, this.onTap, this.selected = false, this.key, this.highlight});
  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool selected;
  final Key? key;
  final Color? highlight;
}

/// 표 안 텍스트 두 줄 (굵은 위 + 작은 아래).
class TwoLine extends StatelessWidget {
  const TwoLine(this.top, [this.bottom, this.topStyle]) : super(key: null);
  final String top;
  final String? bottom;
  final TextStyle? topStyle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(top, style: topStyle ?? const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
        if (bottom != null) Text(bottom!, style: const TextStyle(fontSize: T.caption, color: inkSub)),
      ]);
}

/// 흰 카드 + 제목.
class DeskCard extends StatelessWidget {
  const DeskCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(Gap.l)});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.m),
              child: Row(children: [
                Expanded(child: Text(title!, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain))),
                ?trailing,
              ]),
            ),
          child,
        ]),
      );
}

/// 화면 제목 줄: ✦ 제목 + 설명.
class DeskHeading extends StatelessWidget {
  const DeskHeading(this.title, {super.key, this.sub, this.trailing});
  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.l),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: '✦ ', style: TextStyle(color: coral)),
                TextSpan(text: title),
              ]), style: const TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain)),
              if (sub != null) Text(sub!, style: const TextStyle(fontSize: T.body, color: inkSub)),
            ]),
          ),
          ?trailing,
        ]),
      );
}

/// 이름 셀처럼 표 안에서 누르는 글자 버튼 (키보드 초점 가능).
class LinkCell extends StatelessWidget {
  const LinkCell({super.key, required this.child, required this.onTap, this.tooltip});
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final w = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.button),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Align(alignment: Alignment.centerLeft, widthFactor: 1, child: child)),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}
