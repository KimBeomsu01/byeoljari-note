// PC 01 현황판 대화상자: 인계 리포트(인쇄 대신 요약) · 이상 알림 이력 · 긴급 방송/호출 · 별님 상태.
// 앱은 투약을 계산하지 않는다. 의료진이 쓴 글은 그대로 보여주기만 한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_dashboard_status.dart';
import 'pc_dashboard_ui.dart';
import 'pc_shell.dart';

Widget _sectionTitle(String text, {String? count}) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 6),
  child: Row(
    children: [
      Text(
        text,
        style: pcText(14, weight: FontWeight.w700, color: Ds.gray700),
      ),
      if (count != null) ...[
        const SizedBox(width: 6),
        Text(
          count,
          style: pcText(14, weight: FontWeight.w700, color: Ds.blue500, mono: true),
        ),
      ],
    ],
  ),
);

Widget _line(String text, {Color color = Ds.gray900, FontWeight weight = FontWeight.w500}) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(top: 8, right: 8), child: PcDot(4, color == Ds.gray900 ? Ds.gray400 : color)),
      Expanded(
        child: Text(
          text,
          style: pcText(14, weight: weight, color: color),
        ),
      ),
    ],
  ),
);

// ─────────────────────────── 인계 리포트 (인쇄 대신 요약)

Future<void> showHandoverReport(BuildContext context) {
  showDsToast(context, '인쇄는 아직 연결되지 않아 인계 요약을 화면에 띄웠어요', icon: Icons.print_outlined, iconColor: Colors.white);
  return showPcDialog(context, maxWidth: 640, builder: (_) => const _HandoverReport());
}

class _HandoverReport extends ConsumerWidget {
  const _HandoverReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final shift = repo.shiftAt(now);
    final statuses = buildStatuses(repo, now);
    final alerts = statuses.where((s) => s.isAlert).toList();
    final cautions = statuses.where((s) => s.isCaution).toList();
    final missed = repo.missedTempResidents(now);
    final calls = repo.openCalls;
    final pending = repo.pendingApprovals;
    final notices = repo.entries.where((e) => e.scope == EntryScope.facility && sameDay(e.createdAt, now)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    String who(Resident r) => '${repo.classOf(r.classId).name} ${r.name}';

    final signed = shift == null ? 0 : repo.signsOf(shift.id).length;
    final unsigned = shift == null
        ? const <String>[]
        : [
            for (final id in shift.staffIds)
              if (!repo.hasSigned(shift.id, id)) repo.staff(id).displayName,
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PcDialogHeader('인계 리포트', subtitle: '${dotDate(now)} ${hm(now)} 기준'),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionTitle('근무조 인계 서명', count: shift == null ? null : '$signed/${shift.staffIds.length}'),
                if (shift == null)
                  _line('지금 근무 중인 근무조가 없어요', color: Ds.gray500)
                else ...[
                  _line('${shift.label} 근무조 ${hm(shift.startAt)}~${hm(shift.endAt)}'),
                  if (unsigned.isNotEmpty) _line('미서명: ${unsigned.join(', ')}', color: Tw.amber700),
                ],
                _sectionTitle('열린 이상 건 · 체온 이상', count: '${alerts.length}명'),
                if (alerts.isEmpty) _line('없음', color: Ds.gray500),
                for (final s in alerts)
                  _line(
                    '${who(s.resident)} · ${s.latest == null ? '-' : degC(s.latest!.value)} · ${toneStyle(s.tone).label}'
                    '${s.openCase == null ? '' : ' · ${s.openCase!.kindLabel}'}',
                    color: Ds.red500,
                    weight: FontWeight.w600,
                  ),
                _sectionTitle('주의 관찰', count: '${cautions.length}명'),
                if (cautions.isEmpty) _line('없음', color: Ds.gray500),
                for (final s in cautions) _line('${who(s.resident)} · ${s.latest == null ? '-' : degC(s.latest!.value)} · ${tempNote(s)}'),
                _sectionTitle('체온 미기록', count: '${missed.length}명'),
                if (missed.isEmpty) _line('없음', color: Ds.gray500) else _line(missed.map(who).join(', ')),
                _sectionTitle('의료 호출 대기', count: '${calls.length}건'),
                if (calls.isEmpty) _line('없음', color: Ds.gray500),
                for (final c in calls) _line('${who(repo.resident(c.residentId))} · ${c.level.label} · ${c.summary}'),
                _sectionTitle('결재 대기', count: '${pending.length}건'),
                if (pending.isEmpty) _line('없음', color: Ds.gray500),
                for (final a in pending) _line(a.title),
                _sectionTitle('오늘 전체 공지', count: '${notices.length}건'),
                if (notices.isEmpty) _line('없음', color: Ds.gray500),
                for (final e in notices) _line('${hm(e.createdAt)} ${e.title ?? e.kindLabel}${e.body == null ? '' : ' — ${e.body}'}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: PcButton(
            label: '닫기',
            onTap: () => Navigator.of(context).pop(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            bg: Ds.gray100,
            fg: Ds.gray700,
            hoverBg: Ds.gray200,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── 이상 알림 이력

Future<void> showNoticeHistory(BuildContext context, WidgetRef ref) {
  final repo = ref.read(repoProvider);
  repo.markNoticesSeen(ref.read(currentUserProvider), repo.now());
  return showPcDialog(context, maxWidth: 640, builder: (_) => const _NoticeHistory());
}

class _NoticeHistory extends ConsumerWidget {
  const _NoticeHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final notices = repo.allNotices;

    Widget tile(AppNotice n) {
      final call = () {
        try {
          final c = repo.caseById(n.caseId);
          return repo.openCalls.where((x) => x.residentId == c.residentId).firstOrNull;
        } catch (_) {
          return null;
        }
      }();
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.important ? const Color(0x99FEF2F2) : Ds.gray50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: n.important ? Tw.red200 : Ds.gray200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              n.important ? Icons.warning_amber_rounded : Icons.notifications_none_rounded,
              size: 18,
              color: n.important ? Ds.red500 : Tw.amber600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${relTime(n.at, now)} · ${n.title}',
                    style: pcText(14, weight: FontWeight.w700, color: n.important ? Ds.red500 : Ds.gray900),
                  ),
                  Text(n.body, style: pcText(13, color: Ds.gray600)),
                ],
              ),
            ),
            if (call != null) ...[
              const SizedBox(width: 8),
              PcButton(
                label: '호출 열기',
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(selectedCallProvider.notifier).select(call.id);
                  ref.read(pcPageProvider.notifier).go(PcPage.calls);
                },
                size: 13,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                bg: Ds.blue50,
                fg: Ds.blue500,
                hoverBg: Ds.blue50,
                weight: FontWeight.w700,
              ),
            ],
          ],
        ),
      );
    }

    Widget body;
    if (notices.isEmpty) {
      body = repo.isDev
          ? ExampleWrap(
              note: '체온 이상이 생기면 알림이 여기에 쌓여요',
              child: tile(
                AppNotice(
                  id: 'ex',
                  caseId: 'ex',
                  title: '새 이상 대응',
                  body: '예시반 예시 별님 38.2℃ · 평소보다 +1.4 · 이상',
                  at: now,
                  recipientIds: const {},
                  important: true,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                '아직 이상 알림이 없어요',
                textAlign: TextAlign.center,
                style: pcText(14, color: Ds.gray500),
              ),
            );
    } else {
      body = ListView(shrinkWrap: true, children: [for (final n in notices) tile(n)]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PcDialogHeader('이상 알림 이력', dot: Tw.amber600, subtitle: '전체 ${notices.length}건 · 최신순'),
        const SizedBox(height: 12),
        Flexible(child: body),
      ],
    );
  }
}

// ─────────────────────────── 긴급 방송/호출

Future<void> showEmergencyCall(BuildContext context) => showPcDialog(context, maxWidth: 560, builder: (_) => const _EmergencyCall());

class _EmergencyCall extends ConsumerStatefulWidget {
  const _EmergencyCall();

  @override
  ConsumerState<_EmergencyCall> createState() => _EmergencyCallState();
}

class _EmergencyCallState extends ConsumerState<_EmergencyCall> {
  String? _picked;
  final _summary = TextEditingController(text: '긴급 방송 · 간호 선생님 즉시 확인 요청');

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    // 예시 별님에게는 실제 호출을 만들지 않는다.
    final statuses = buildStatuses(repo, now).where((s) => !s.resident.example).toList();
    _picked ??= statuses.isEmpty ? null : statuses.first.resident.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PcDialogHeader('긴급 방송/호출', dot: Ds.red500),
        const SizedBox(height: 12),
        Text(
          '호출할 별님',
          style: pcText(pcBase, weight: FontWeight.w600, color: Ds.gray600),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Ds.gray200),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (statuses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('등록된 별님이 없어요. [전체 거주인 명부]에서 먼저 별님을 추가해 주세요.', style: pcText(14, color: Ds.gray500)),
                    ),
                  for (final s in statuses)
                    PcHover(
                      onTap: () => setState(() => _picked = s.resident.id),
                      semanticsLabel: '${s.resident.name} 고르기',
                      builder: (hover) {
                        final on = _picked == s.resident.id;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          color: on ? Ds.blue50 : (hover ? Ds.gray50 : Colors.white),
                          child: Row(
                            children: [
                              Icon(
                                on ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: on ? Ds.blue500 : Ds.gray400,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${s.cls.name} · ${s.resident.name}',
                                  style: pcText(14, weight: on ? FontWeight.w700 : FontWeight.w500),
                                ),
                              ),
                              Text(
                                s.latest == null ? '측정 전' : degC(s.latest!.value),
                                style: pcText(13, weight: FontWeight.w700, color: tempColor(s.latest?.judgment.stage), mono: true),
                              ),
                              const SizedBox(width: 8),
                              PcPill(
                                toneStyle(s.tone).label,
                                bg: toneStyle(s.tone).bg,
                                fg: toneStyle(s.tone).fg,
                                border: toneStyle(s.tone).border,
                                size: 11,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '호출 내용',
          style: pcText(pcBase, weight: FontWeight.w600, color: Ds.gray600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _summary,
          maxLength: 80,
          style: pcText(14),
          decoration: const InputDecoration(counterText: '', hintText: '예: 고열 · 즉시 확인 요청'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PcButton(
              label: '취소',
              onTap: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              bg: Ds.gray100,
              fg: Ds.gray700,
              hoverBg: Ds.gray200,
            ),
            const SizedBox(width: 8),
            PcButton(
              label: '긴급 호출 보내기',
              icon: Icons.add_alert_rounded,
              onTap: _picked == null ? null : _send,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              bg: Ds.red500,
              fg: Colors.white,
              hoverBg: Tw.red600,
              weight: FontWeight.w700,
            ),
          ],
        ),
      ],
    );
  }

  void _send() {
    final repo = ref.read(repoProvider);
    final r = repo.resident(_picked!);
    final text = _summary.text.trim().isEmpty ? '긴급 방송 · 즉시 확인 요청' : _summary.text.trim();
    repo.requestCall(residentId: r.id, level: CallLevel.urgent, by: ref.read(currentUserProvider), summary: text);
    // 토스트는 맨 위 오버레이에 붙으므로 창을 닫기 전에 띄운다.
    showDsToast(context, '${r.name} 별님 긴급 호출을 보냈어요. 의료 호출함에 올라갔어요', icon: Icons.campaign_rounded, iconColor: Ds.red500);
    Navigator.of(context).pop();
  }
}

// ─────────────────────────── 별님 상태 (열린 호출이 없는 줄을 눌렀을 때)

Future<void> showResidentStatus(BuildContext context, String residentId) =>
    showPcDialog(context, maxWidth: 560, builder: (_) => _ResidentStatus(residentId: residentId));

class _ResidentStatus extends ConsumerWidget {
  const _ResidentStatus({required this.residentId});
  final String residentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final s = buildStatuses(repo, now).firstWhere((x) => x.resident.id == residentId);
    final r = s.resident;
    final records = repo.archiveEntriesOf(r.id).where((e) => e.scope == EntryScope.resident).take(3).toList();
    final temps = repo.measurementsOf(r.id).where((m) => !m.isVoided).take(5).toList();
    final style = toneStyle(s.tone);

    Widget kv(String k, String v, {Color color = Ds.gray900}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(k, style: pcText(13, color: Ds.gray500)),
          ),
          Expanded(
            child: Text(
              v,
              style: pcText(14, weight: FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PcDialogHeader('${r.name} 별님', subtitle: '${classRoom(s.cls)} · ${residentMeta(r)}'),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    PcPill(
                      style.label,
                      bg: style.bg,
                      fg: style.fg,
                      border: style.border,
                      icon: style.icon,
                      iconColor: style.iconColor,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.latest == null ? '측정 전' : degC(s.latest!.value),
                      style: pcText(20, weight: FontWeight.w800, color: tempColor(s.latest?.judgment.stage), mono: true, height: 1),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(tempNote(s), style: pcText(12, color: Ds.gray500, mono: true)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                kv('기저치', degC(s.baseline)),
                kv('지금 일과', s.activity == null ? '자유 시간' : '${s.activity!.title} · ${s.activity!.place}'),
                kv('담당', s.homeroom.displayName),
                if (s.openCase != null)
                  kv('이상 대응', '${s.openCase!.kindLabel} · ${InMemoryRepository.stageLabel(s.openCase!.stage)} 단계', color: Ds.red500),
                if ((r.regularMeds ?? '').isNotEmpty) kv('상시 복약', r.regularMeds!),
                if ((r.cautions ?? '').isNotEmpty) kv('금기 · 주의', r.cautions!, color: Ds.red500),
                if (temps.isNotEmpty) ...[
                  _sectionTitle('최근 체온'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in temps)
                        PcPill(
                          '${relTime(m.measuredAt, now)} ${degC(m.value)}',
                          bg: Ds.gray50,
                          fg: tempColor(m.judgment.stage),
                          border: Ds.gray200,
                          size: 12,
                          mono: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                    ],
                  ),
                ],
                _sectionTitle('최근 기록'),
                if (records.isEmpty) _line('기록 없음', color: Ds.gray500),
                for (final e in records) _line('${relTime(e.createdAt, now)} · ${e.kindLabel} · ${entryText(repo, e)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PcButton(
              label: '닫기',
              onTap: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              bg: Ds.gray100,
              fg: Ds.gray700,
              hoverBg: Ds.gray200,
            ),
            const SizedBox(width: 8),
            PcButton(
              label: '의료 호출 보내기',
              icon: Icons.medical_services_outlined,
              onTap: r.example
                  ? null
                  : () {
                      final c = repo.requestCall(
                        residentId: r.id,
                        level: s.isAlert ? CallLevel.observe : CallLevel.general,
                        by: ref.read(currentUserProvider),
                        summary: '${r.name} 별님 상태 확인 요청 (현황판)',
                      );
                      Navigator.of(context).pop();
                      ref.read(selectedCallProvider.notifier).select(c.id);
                      ref.read(pcPageProvider.notifier).go(PcPage.calls);
                    },
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              bg: Ds.blue500,
              fg: Colors.white,
              hoverBg: Ds.blue600,
              weight: FontWeight.w700,
            ),
          ],
        ),
      ],
    );
  }
}
