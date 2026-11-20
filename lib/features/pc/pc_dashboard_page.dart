// PC 01 통합 관제 현황판 (Claude Design PcDashboard.dc.html, 라우트 overview-dashboard).
// 레일 · 머리는 pc_shell.dart가 그린다. 여기는 main 안쪽: 제목 줄 → 요약 카드 4개 → 표(8) + 타임라인 · 인계(4).
// 숫자 · 이름 · 시각은 모두 저장소에서 계산한다. 개발 DB에서 빈 자리는 예시 카드(ExampleWrap)를 그린다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_dashboard_dialogs.dart';
import 'pc_dashboard_side.dart';
import 'pc_dashboard_status.dart';
import 'pc_dashboard_table.dart';
import 'pc_dashboard_ui.dart';
import 'pc_roster_dialog.dart';
import 'pc_shell.dart';

class PcDashboardPage extends ConsumerStatefulWidget {
  const PcDashboardPage({super.key});

  @override
  ConsumerState<PcDashboardPage> createState() => _PcDashboardPageState();
}

class _PcDashboardPageState extends ConsumerState<PcDashboardPage> with SingleTickerProviderStateMixin {
  /// 표 생활관 필터 (null = 전체). 디자인 상태 `room`.
  String? _room;
  int _page = 0;
  Timer? _tick;
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    // 시각 · "지금 일과"가 바뀌도록 가끔 다시 그린다.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _spin.dispose();
    super.dispose();
  }

  void _refresh() {
    _spin.forward(from: 0);
    setState(() {});
  }

  void _pickRoom(String? id) => setState(() {
    _room = id;
    _page = 0;
  });

  void _openRow(ResidentStatus s) {
    final call = s.openCall;
    if (call != null) {
      ref.read(selectedCallProvider.notifier).select(call.id);
      ref.read(pcPageProvider.notifier).go(PcPage.calls);
      return;
    }
    showResidentStatus(context, s.resident.id);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final statuses = buildStatuses(repo, now);
    if (_room != null && !repo.classes.any((c) => c.id == _room)) _room = null;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.only(bottom: 4), child: _titleRow(repo, now)),
                const SizedBox(height: 24),
                _SummaryCards(repo: repo, statuses: statuses, now: now),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, c) {
                    // 12칸 격자 (gap 24): 표 8칸 · 오른쪽 4칸.
                    final track = (c.maxWidth - 11 * 24) / 12;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: track * 8 + 7 * 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ResidentBoard(
                                repo: repo,
                                statuses: statuses,
                                room: _room,
                                page: _page,
                                onRoom: _pickRoom,
                                onPage: (p) => setState(() => _page = p),
                                onRow: _openRow,
                              ),
                              const SizedBox(height: 16),
                              ClassSummaryStrip(repo: repo, statuses: statuses, onPick: _pickRoom),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: track * 4 + 3 * 24,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [LiveFeedCard(), SizedBox(height: 16), HandoverApprovalCard()],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleRow(InMemoryRepository repo, DateTime now) {
    final me = ref.watch(currentUserProvider);
    final unseen = repo.unseenNoticeCount(me) > 0;
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const PcDot(10, Ds.green500, ring: Tw.emerald100),
        const SizedBox(width: 12),
        Text('울산 혜진원 통합 관제 현황판', style: pcText(pcBase, spacing: -0.4)),
        const SizedBox(width: 16),
        PcPill(
          '실시간 관제 활성',
          bg: Tw.emerald50,
          fg: Tw.emerald700,
          border: Tw.emerald200,
          dot: Ds.green500,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        const SizedBox(width: 4),
        Text('|', style: pcText(pcBase, color: Ds.gray300)),
        const SizedBox(width: 4),
        Text(
          '${dotDate(now)} ${hm(now)} KST',
          style: pcText(pcBase, weight: FontWeight.w500, color: Ds.gray800, mono: true),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '즉시 새로고침',
          child: PcHover(
            onTap: _refresh,
            semanticsLabel: '즉시 새로고침',
            builder: (hover) => Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: hover ? Ds.gray50 : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Ds.gray200),
                boxShadow: Ds.shadowSm,
              ),
              child: RotationTransition(
                turns: _spin,
                child: Icon(Icons.sync_rounded, size: 16, color: hover ? Ds.gray900 : Ds.gray600),
              ),
            ),
          ),
        ),
      ],
    );

    PcButton outline(
      String label,
      IconData icon,
      VoidCallback onTap, {
      Color fg = Ds.gray700,
      Color iconColor = Ds.gray500,
      Color border = Ds.gray200,
      Color hoverBg = Ds.gray50,
      Widget? trailing,
    }) => PcButton(
      label: label,
      icon: icon,
      iconColor: iconColor,
      onTap: onTap,
      height: 36,
      fg: fg,
      hoverFg: fg == Ds.gray700 ? Ds.gray900 : fg,
      border: border,
      hoverBg: hoverBg,
      shadow: Ds.shadowSm,
      trailing: trailing,
    );

    final buttons = [
      outline('인계 리포트 인쇄', Icons.print_outlined, () => showHandoverReport(context)),
      outline('전체 거주인 명부', Icons.badge_outlined, () => showRosterDialog(context)),
      outline(
        '이상 알림 이력',
        Icons.notifications_active_outlined,
        () => showNoticeHistory(context, ref),
        fg: Tw.amber700,
        iconColor: Tw.amber600,
        border: Tw.amber200,
        hoverBg: Tw.amber50,
        trailing: unseen ? const PcDot(8, Ds.red500) : null,
      ),
      PcButton(
        label: '긴급 방송/호출',
        icon: Icons.add_alert_outlined,
        onTap: () => showEmergencyCall(context),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        bg: Ds.blue500,
        fg: Colors.white,
        hoverBg: Ds.blue600,
        weight: FontWeight.w700,
        shadow: const [BoxShadow(color: Color(0x593182F6), blurRadius: 14, offset: Offset(0, 4))],
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        title,
        const SizedBox(width: 16),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: buttons),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── 요약 카드 4개

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.repo, required this.statuses, required this.now});
  final InMemoryRepository repo;
  final List<ResidentStatus> statuses;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cards = [_presence(), _monitoring(), _consults(), _handover()];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: cards[i])],
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color border = Ds.gray200, List<BoxShadow> shadow = pcTileShadow, Gradient? gradient}) =>
      PcCard(border: border, shadow: shadow, gradient: gradient, child: child);

  Widget _head(String title, Widget icon, {Widget? badge, Color color = Ds.gray600, FontWeight weight = FontWeight.w600}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: pcText(pcBase, weight: weight, color: color),
              ),
              ?badge,
            ],
          ),
        ),
        const SizedBox(width: 8),
        icon,
      ],
    ),
  );

  Widget _number(String n, String unit, {Color color = Ds.gray900, Color unitColor = Ds.gray600, Widget? after}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          n,
          style: pcText(pcBase, weight: FontWeight.w800, color: color, spacing: -0.4, mono: true),
        ),
        const SizedBox(width: 8),
        Text(
          unit,
          style: pcText(pcBase, weight: FontWeight.w700, color: unitColor),
        ),
        if (after != null) ...[const SizedBox(width: 8), Flexible(child: after)],
      ],
    ),
  );

  // 1. 전체 거주인 재실 현황
  Widget _presence() {
    final classes = repo.classes;
    final school = statuses.where((s) => s.atSchool).length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _head(
            '전체 거주인 재실 현황',
            const PcIconCircle(Icons.group_outlined, bg: Ds.blue50, fg: Ds.blue500),
            badge: repo.isDev && repo.rosterIsExample ? const ExampleTag() : null,
          ),
          _number('${statuses.length}', '명 재실'),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Ds.gray100)),
            ),
            child: Row(
              children: [
                const PcDot(6, Ds.green500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${classes.length}개 생활관 정상 운영',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pcText(pcBase, weight: FontWeight.w500, color: Ds.gray700),
                  ),
                ),
                const SizedBox(width: 6),
                PcPill(
                  '통학 $school명',
                  bg: Ds.blue50,
                  fg: Ds.blue500,
                  weight: FontWeight.w600,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. 집중 발열 / 이상 모니터링
  Widget _monitoring() {
    final active = repo.openCases.length;
    final watched = statuses.where((s) => s.isAlert || s.isCaution).toList();
    Widget line(String left, String right, {required bool strong, required Color rightColor}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pcText(11, weight: strong ? FontWeight.w700 : FontWeight.w500, color: strong ? Ds.gray900 : Ds.gray600),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            right,
            style: pcText(11, weight: FontWeight.w700, color: rightColor),
          ),
        ],
      ),
    );
    final lines = <Widget>[];
    for (final s in watched.take(2)) {
      final label = switch (s.tone) {
        RowTone.danger => '위험',
        RowTone.abnormal => '이상',
        RowTone.low => '저온',
        _ => '주의',
      };
      final temp = s.latest == null ? '' : ' (${degC(s.latest!.value)})';
      final (String right, Color rc) = s.openCall != null
          ? ('의료호출 발송완료', Ds.red500)
          : (s.openCase?.status == CaseStatus.waitingRemeasure && s.openCase?.remeasureAt != null)
          ? ('${hm(s.openCase!.remeasureAt!)} 재측정 대기', Tw.amber700)
          : (s.openTask?.task?.dueAt != null)
          ? ('${hm(s.openTask!.task!.dueAt!)} 재측정 대기', Tw.amber700)
          : (s.openCase?.status == CaseStatus.unacked ? ('확인 대기', Tw.amber700) : ('관찰 중', Ds.gray600));
      lines.add(line('$label: ${s.resident.name}$temp', right, strong: s.isAlert, rightColor: rc));
    }
    Widget footer;
    if (lines.isNotEmpty) {
      footer = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lines);
    } else if (repo.isDev) {
      footer = ExampleWrap(
        note: '체온 이상이 생기면 여기에 올라와요',
        child: exampleRoom(line('위험: 예시 별님 (38.2℃)', '의료호출 발송완료', strong: true, rightColor: Ds.red500)),
      );
    } else {
      footer = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '지금 이상 · 주의 별님이 없어요',
          style: pcText(11, weight: FontWeight.w500, color: Ds.gray500),
        ),
      );
    }
    return _card(
      border: Tw.red200,
      shadow: const [BoxShadow(color: Color(0x0FF04452), blurRadius: 8, offset: Offset(0, 2))],
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.white, Color(0x99FEF2F2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _head(
            '집중 발열 / 이상 모니터링',
            const PcIconCircle(Icons.monitor_heart_outlined, bg: Ds.red50, fg: Ds.red500),
            color: Ds.gray800,
            weight: FontWeight.w700,
            badge: PcPill(
              '$active건 활성',
              bg: Ds.red50,
              fg: Ds.red500,
              border: Tw.red200,
              dot: Ds.red500,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${watched.length}',
                  style: pcText(pcBase, weight: FontWeight.w800, color: Ds.red500, mono: true),
                ),
                const SizedBox(width: 8),
                Text(
                  '명 관제 중',
                  style: pcText(pcBase, weight: FontWeight.w700, color: Ds.red500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Tw.red100)),
            ),
            child: footer,
          ),
        ],
      ),
    );
  }

  // 3. 당일 비대면 의료 협진: 오늘 의료 일정 + 오늘 화상 예약 호출 (같은 시간대 ±30분은 한 건으로 본다)
  Widget _consults() {
    final today = dayOf(now);
    DateTime? at(CalendarEvent e) {
      final t = e.time;
      if (t == null || !t.contains(':')) return null;
      final p = t.split(':');
      return DateTime(today.year, today.month, today.day, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
    }

    final events = repo.calendarOn(today).where((e) => e.category == CalendarCategory.medical).toList();
    final sessions = <(DateTime?, bool)>[for (final e in events) (at(e), at(e) != null && at(e)!.isBefore(now))];
    String? issuedName;
    for (final c in repo.calls) {
      final rx = repo.prescriptionOf(c.id);
      if (rx != null && rx.issued && rx.issuedAt != null && sameDay(rx.issuedAt!, today)) issuedName ??= rx.codeName;
      final v = c.videoAt;
      if (v == null || !sameDay(v, today)) continue;
      if (events.any((e) => at(e) != null && at(e)!.difference(v).inMinutes.abs() <= 30)) continue;
      sessions.add((v, v.isBefore(now) || !c.isOpen));
    }
    final done = sessions.where((s) => s.$2).length;
    final waiting = sessions.where((s) => !s.$2).toList()..sort((a, b) => (a.$1 ?? today).compareTo(b.$1 ?? today));
    final next = waiting.firstOrNull?.$1;

    Widget body(int total, int doneN, String? name, int waitN, DateTime? nextAt) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _number('$total', '건 예정'),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Ds.gray100)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 14, color: Tw.emerald700),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$doneN건 완료${name == null ? '' : ' ($name)'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pcText(pcBase, weight: FontWeight.w700, color: Tw.emerald700),
                ),
              ),
              const SizedBox(width: 6),
              PcPill(
                waitN == 0 ? '대기 없음' : '$waitN건${nextAt == null ? '' : ' ${hm(nextAt)}'} 대기',
                bg: Ds.gray100,
                fg: Ds.gray700,
                weight: FontWeight.w500,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ],
          ),
        ),
      ],
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _head('당일 비대면 의료 협진', const PcIconCircle(Icons.medical_services_outlined, bg: Ds.blue50, fg: Ds.blue500)),
          if (sessions.isEmpty && repo.isDev)
            ExampleWrap(note: '오늘 의료 협진 일정이 생기면 여기에 세어져요', child: body(2, 1, '예시', 1, DateTime(today.year, today.month, today.day, 15, 30)))
          else
            body(sessions.length, done, issuedName, waiting.length, next),
        ],
      ),
    );
  }

  // 4. 교대조 인계 완료율 (지금 근무조 서명 비율)
  Widget _handover() {
    final shift = repo.shiftAt(now);
    Widget body(int pct, int left) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$pct',
                      style: pcText(pcBase, weight: FontWeight.w800, mono: true),
                    ),
                    TextSpan(
                      text: '%',
                      style: pcText(20, weight: FontWeight.w500, color: Ds.gray500, height: 1.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: left > 0
                    ? PcPill(
                        '미확인 $left건 잔여',
                        bg: Tw.amber50,
                        fg: Tw.amber700,
                        border: Tw.amber200,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      )
                    : PcPill(
                        '전원 서명 완료',
                        bg: Tw.emerald50,
                        fg: Tw.emerald700,
                        border: Tw.emerald200,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: Ds.gray100,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: pct / 100,
              child: Container(
                decoration: BoxDecoration(color: Ds.blue500, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
        ),
      ],
    );

    final Widget content;
    if (shift == null) {
      content = repo.isDev
          ? ExampleWrap(note: '근무조가 정해지면 서명 비율이 보여요', child: body(75, 1))
          : Text('지금 근무 중인 근무조가 없어요', style: pcText(14, color: Ds.gray500));
    } else {
      final total = shift.staffIds.length;
      final signed = repo.signsOf(shift.id).where((s) => shift.staffIds.contains(s.staffId)).length;
      content = body(total == 0 ? 0 : (signed * 100 / total).round(), total - signed);
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _head('${shift?.label ?? '오전'} 교대조 인계 완료율', const PcIconCircle(Icons.task_alt_rounded, bg: Tw.emerald50, fg: Tw.emerald600)),
          content,
        ],
      ),
    );
  }
}
