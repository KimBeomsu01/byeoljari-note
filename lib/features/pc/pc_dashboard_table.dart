// PC 01 현황판 가운데: "N개 생활관 전수 거주인 현황" 표 + 생활관별 요약 칩 줄.
// 디자인 PcDashboard.dc.html section(span 8). 표는 이상 있는 별님이 위, 10명씩 나눠 본다.
import 'package:flutter/material.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_dashboard_status.dart';
import 'pc_dashboard_ui.dart';

/// 한 쪽에 보이는 별님 수 (디자인 "이전 10명 / 다음 10명").
const residentPageSize = 10;

/// 표 열 비율: 생활관/담당 · 별님 · 체온 · 상태 판정 · 현재 위치 · 투약&케어 · 대응 현황.
const _flexWide = [13, 15, 13, 12, 11, 21, 15];
const _flexNarrow = [14, 14, 12, 13, 12, 18, 17];
const _heads = ['생활관 / 담당', '별님 (거주인)', '활력징후 (체온)', '상태 판정', '현재 위치 및 일과', '투약 & 케어', '대응 현황'];

class ResidentBoard extends StatelessWidget {
  const ResidentBoard({
    super.key,
    required this.repo,
    required this.statuses,
    required this.room,
    required this.page,
    required this.onRoom,
    required this.onPage,
    required this.onRow,
  });
  final InMemoryRepository repo;
  final List<ResidentStatus> statuses;

  /// 고른 반 (null = 전체).
  final String? room;
  final int page;
  final ValueChanged<String?> onRoom;
  final ValueChanged<int> onPage;
  final ValueChanged<ResidentStatus> onRow;

  @override
  Widget build(BuildContext context) {
    final classes = repo.classes;
    final shown = room == null ? statuses : statuses.where((s) => s.cls.id == room).toList();
    final pages = shown.isEmpty ? 1 : (shown.length / residentPageSize).ceil();
    final p = page.clamp(0, pages - 1);
    final from = p * residentPageSize;
    final to = (from + residentPageSize).clamp(0, shown.length);
    final rows = shown.sublist(from, to);
    final allNormal = classes.where((c) {
      final mine = statuses.where((s) => s.cls.id == c.id).toList();
      return mine.isNotEmpty && mine.every((s) => s.tone == RowTone.normal || (s.tone == RowTone.school && s.latest != null));
    }).length;

    Widget chip(String label, String? id) {
      final on = room == id;
      return PcButton(
        label: label,
        onTap: () => onRoom(id),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        bg: on ? Ds.gray900 : Ds.gray100,
        fg: on ? Colors.white : Ds.gray700,
        border: on ? null : Ds.gray200,
        hoverBg: on ? Ds.gray900 : Ds.gray200,
        weight: on ? FontWeight.w700 : FontWeight.w500,
        shadow: on ? Ds.shadowSm : null,
      );
    }

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('${classes.length}개 생활관 전수 거주인 현황', style: pcText(pcBase, weight: FontWeight.w700)),
                const SizedBox(width: 8),
                PcPill(
                  '총 ${statuses.length}명',
                  bg: Ds.blue50,
                  fg: Ds.blue500,
                  border: Ds.borderInfo,
                  size: 12,
                  mono: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        chip('전체 (${statuses.length})', null),
                        for (final c in classes) chip('${c.name} (${statuses.where((s) => s.cls.id == c.id).length})', c.id),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Table(repo: repo, rows: rows, onRow: onRow),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const PcDot(8, Ds.green500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '총 ${classes.length}개 생활실 중 $allNormal개 생활실 전원 정상 상태',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pcText(pcBase, color: Ds.gray600),
                  ),
                ),
                const SizedBox(width: 8),
                _PageButton('이전 $residentPageSize명', p > 0 ? () => onPage(p - 1) : null),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    shown.isEmpty ? '0 / 0' : '${from + 1} - $to / ${shown.length}',
                    style: pcText(pcBase, weight: FontWeight.w700, mono: true),
                  ),
                ),
                _PageButton('다음 $residentPageSize명', p < pages - 1 ? () => onPage(p + 1) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PcButton(
    label: label,
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    bg: Ds.gray100,
    fg: Ds.gray700,
    border: Ds.gray200,
    hoverBg: Ds.gray200,
    weight: FontWeight.w400,
  );
}

class _Table extends StatelessWidget {
  const _Table({required this.repo, required this.rows, required this.onRow});
  final InMemoryRepository repo;
  final List<ResidentStatus> rows;
  final ValueChanged<ResidentStatus> onRow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth < 760 ? 760.0 : c.maxWidth;
        final wide = width >= 1000;
        final pad = wide ? 16.0 : 10.0;
        final flex = wide ? _flexWide : _flexNarrow;
        Widget cells(List<Widget> children) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < children.length; i++)
              Expanded(
                flex: flex[i],
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: children[i],
                ),
              ),
          ],
        );
        final now = repo.now();
        final table = Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Ds.gray200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: Ds.gray50,
                  border: Border(
                    bottom: BorderSide(color: Ds.gray200),
                    left: BorderSide(color: Colors.transparent, width: 4),
                  ),
                ),
                child: cells([
                  for (var i = 0; i < _heads.length; i++)
                    Text(
                      _heads[i],
                      textAlign: i == _heads.length - 1 ? TextAlign.right : TextAlign.left,
                      style: pcText(pcBase, weight: FontWeight.w700, color: Ds.gray600),
                    ),
                ]),
              ),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    '이 생활관에 등록된 별님이 없어요',
                    textAlign: TextAlign.center,
                    style: pcText(14, color: Ds.gray500),
                  ),
                ),
              for (var i = 0; i < rows.length; i++)
                _Row(repo: repo, s: rows[i], first: i == 0, now: now, cells: cells, onTap: () => onRow(rows[i])),
            ],
          ),
        );
        if (width <= c.maxWidth) return table;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.repo, required this.s, required this.first, required this.now, required this.cells, required this.onTap});
  final InMemoryRepository repo;
  final ResidentStatus s;
  final bool first;
  final DateTime now;
  final Widget Function(List<Widget>) cells;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = s.tone;
    final (Color bg, Color hoverBg, Color edge, Color? dot) = switch (tone) {
      RowTone.danger || RowTone.abnormal => (const Color(0xB3FEF2F2), Tw.red50, Ds.red500, Ds.red500),
      RowTone.low => (const Color(0x66E8F3FF), Ds.blue50, Ds.blue500, Ds.blue500),
      RowTone.caution => (const Color(0x66FFFBEB), const Color(0xB3FFFBEB), Tw.amber500, Tw.amber500),
      RowTone.normal => (Colors.white, Ds.gray50, Colors.transparent, Ds.green500),
      RowTone.school => (Colors.white, Ds.gray50, Colors.transparent, s.latest?.judgment.stage == null ? null : Ds.green500),
      RowTone.none => (Colors.white, Ds.gray50, Colors.transparent, null),
    };
    final alert = s.isAlert;
    final r = s.resident;
    final tStyle = toneStyle(tone);
    final resp = responseStyle(s);
    final m = s.latest;
    final (Color avBg, Color avFg, Color avBorder) = alert
        ? (Tw.red100, Ds.red500, Tw.red200)
        : (s.isCaution ? (Ds.blue50, Ds.blue500, Ds.borderInfo) : (Ds.gray100, Ds.gray800, Ds.gray200));
    final body = pcText(14, height: 20 / 14);

    // 투약 & 케어: 열린 재측정 할 일 → 최근 기록 → 상시 복약 순.
    final task = s.openTask;
    final last = s.lastEntry;
    final String care1;
    final String care2;
    var care1Style = body.copyWith(color: Ds.gray900, fontWeight: FontWeight.w500);
    if (task != null) {
      final t = task.task!;
      care1 = '${t.label} ${t.duePreset ?? (t.dueAt == null ? '' : '${hm(t.dueAt!)}까지')}'.trim();
      care2 = entryText(repo, task);
      care1Style = body.copyWith(color: Tw.amber700, fontWeight: FontWeight.w600);
    } else if (last != null) {
      care1 = entryText(repo, last);
      care2 = '${relTime(last.createdAt, now)} · ${repo.staff(last.authorId).name} ${last.kindLabel}';
      if (!sameDay(last.createdAt, now)) care1Style = body.copyWith(color: Ds.gray700, fontWeight: FontWeight.w500);
    } else if ((r.regularMeds ?? '').isNotEmpty) {
      care1 = '상시 복약';
      care2 = r.regularMeds!;
      care1Style = body.copyWith(color: Ds.gray700, fontWeight: FontWeight.w500);
    } else {
      care1 = '최근 기록 없음';
      care2 = '';
      care1Style = body.copyWith(color: Ds.gray500);
    }

    final act = s.activity;
    return PcHover(
      onTap: onTap,
      semanticsLabel: '${r.name} 별님 줄',
      builder: (hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: alert ? 14 : 12),
        decoration: BoxDecoration(
          color: hover ? hoverBg : bg,
          border: Border(
            left: BorderSide(color: edge, width: 4),
            top: first ? BorderSide.none : const BorderSide(color: Ds.gray100),
          ),
        ),
        child: cells([
          // 생활관 / 담당
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 생활관 이름은 한 줄로 (좁으면 살짝 줄인다).
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(classRoom(s.cls), maxLines: 1, style: body.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      '담당: ${s.homeroom.displayName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: body.copyWith(color: Ds.gray500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 별님
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: avBorder),
                ),
                child: Text(
                  r.shortName,
                  maxLines: 1,
                  style: pcText(12, weight: FontWeight.w700, color: avFg, height: 16 / 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(r.name, style: body.copyWith(fontWeight: FontWeight.w700)),
                        if (r.example) const ExampleTag(),
                      ],
                    ),
                    Text(residentMeta(r), style: body.copyWith(color: Ds.gray500)),
                  ],
                ),
              ),
            ],
          ),
          // 체온
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m == null ? '-' : degC(m.value),
                style: pcText(
                  20,
                  weight: alert || s.isCaution ? FontWeight.w800 : FontWeight.w700,
                  color: m == null ? Ds.gray900 : tempColor(m.judgment.stage),
                  height: 1,
                  spacing: -0.3,
                  mono: true,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tempNote(s),
                style: pcText(
                  11,
                  mono: true,
                  weight: m == null ? FontWeight.w500 : (m.judgment.stage == Stage.normal ? FontWeight.w400 : FontWeight.w700),
                  color: m == null || m.judgment.stage == Stage.normal ? Ds.gray500 : tempColor(m.judgment.stage),
                ),
              ),
            ],
          ),
          // 상태 판정
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PcPill(
                tStyle.label,
                bg: tStyle.bg,
                fg: tStyle.fg,
                border: tStyle.border,
                icon: tStyle.icon,
                iconColor: tStyle.iconColor,
                size: 14,
                weight: tStyle.weight,
                shadow: tStyle.border == null ? Ds.shadowSm : null,
              ),
            ),
          ),
          // 현재 위치 및 일과
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                act?.title ?? '자유 시간',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: body.copyWith(fontWeight: alert ? FontWeight.w700 : FontWeight.w500),
              ),
              Text(
                act?.place ?? '${s.cls.name} 생활실',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body.copyWith(color: Ds.gray600),
              ),
            ],
          ),
          // 투약 & 케어
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(care1, maxLines: 2, overflow: TextOverflow.ellipsis, style: care1Style),
              if (care2.isNotEmpty)
                Text(
                  care2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body.copyWith(color: Ds.gray500),
                ),
            ],
          ),
          // 대응 현황
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PcPill(
                resp.label,
                bg: resp.bg,
                fg: resp.fg,
                border: resp.border,
                icon: resp.icon,
                iconColor: resp.iconColor,
                size: 14,
                weight: resp.weight,
                padding: EdgeInsets.symmetric(horizontal: s.openCall?.level == CallLevel.urgent ? 12 : 10, vertical: 4),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 생활관별 요약 칩 줄 (반별 위험 / 주의 / 전원정상). 누르면 표를 그 반으로 거른다.
class ClassSummaryStrip extends StatelessWidget {
  const ClassSummaryStrip({super.key, required this.repo, required this.statuses, required this.onPick});
  final InMemoryRepository repo;
  final List<ResidentStatus> statuses;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final classes = repo.classes;
    final tiles = [for (final c in classes) _summaryTile(c.id, c.name, statuses.where((s) => s.cls.id == c.id).toList())];
    const perRow = 6;
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += perRow) {
      final chunk = tiles.sublist(i, (i + perRow).clamp(0, tiles.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < perRow; j++) ...[
                if (j > 0) const SizedBox(width: 8),
                Expanded(child: j < chunk.length ? chunk[j] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
      ],
    );
  }

  Widget _summaryTile(String classId, String name, List<ResidentStatus> mine) {
    final alerts = mine.where((s) => s.isAlert).toList();
    final cautions = mine.where((s) => s.isCaution).toList();
    final normal = mine.where((s) => s.latest != null && !s.isAlert && !s.isCaution).length;
    final total = mine.length;
    final String count;
    final String label;
    final String note;
    final Color ink;
    final Color bg;
    final Color border;
    final Color dot;
    if (alerts.isNotEmpty) {
      final top = alerts.first;
      count = '${alerts.length}';
      label = alerts.any((s) => s.alertStage == Stage.danger) ? '위험' : (alerts.every((s) => s.tone == RowTone.low) ? '저온' : '이상');
      note = '${top.cls.room ?? ''} ${top.resident.name} ${top.tone == RowTone.low ? '저온' : '발열'}'.trim();
      (ink, bg, border, dot) = (Ds.red500, const Color(0xFFFFFBFB), Tw.red200, Ds.red500);
    } else if (cautions.isNotEmpty) {
      final top = cautions.first;
      count = '${cautions.length}';
      label = '주의';
      note = '${top.cls.room ?? ''} ${top.resident.name} 미열'.trim();
      (ink, bg, border, dot) = (Tw.amber700, const Color(0xFFFFFEF9), Tw.amber200, Tw.amber500);
    } else {
      count = '$normal';
      label = normal == total && total > 0 ? '전원정상' : '정상';
      // 반 별님들이 지금 가장 많이 하는 일과
      final acts = <String, int>{};
      for (final s in mine) {
        final t = s.activity?.title;
        if (t != null) acts[t] = (acts[t] ?? 0) + 1;
      }
      final top = acts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      note = top.isEmpty ? '자유 시간' : top.first.key;
      (ink, bg, border, dot) = (Tw.emerald700, Colors.white, Ds.gray200, Ds.green500);
    }
    return PcHover(
      onTap: () => onPick(classId),
      semanticsLabel: '$name 요약',
      builder: (hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: hover ? Ds.blue500.withValues(alpha: 0.4) : border),
          boxShadow: Ds.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pcText(pcBase, weight: FontWeight.w700),
                  ),
                ),
                PcDot(8, dot),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: count,
                    style: pcText(pcBase, weight: FontWeight.w700, color: ink, mono: true),
                  ),
                  TextSpan(
                    text: '/$total $label',
                    style: pcText(12, weight: FontWeight.w500, color: Ds.gray500, height: 16 / 12),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pcText(11, color: alerts.isNotEmpty || cautions.isNotEmpty ? Ds.gray600 : Ds.gray500),
            ),
          ],
        ),
      ),
    );
  }
}
