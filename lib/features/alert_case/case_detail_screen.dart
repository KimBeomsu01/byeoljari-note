// S3 이상 건 상세 (이상 대응 명세 6장 S3, 통합 명세 6-2).
// 버튼 한 번 = 기록 한 줄. 기록은 지우지 않고 취소 표시만 한다.
// 투약은 의료진이 쓴 지침을 보여주고, 간호사가 한 일을 글로 남길 뿐이다. 용량 계산·추천 없음.
// 화면 순서 (docs/design.md): 누구·몇 도 → 할 일 버튼 → 대응 단계 → 기록. 작성자·시각은 맨 아래 작은 글자.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'alert_sheet.dart' show showGuideline;
import 'case_sheets.dart';
import 'case_ui.dart';

const _tabular = [FontFeature.tabularFigures()];

class CaseDetailScreen extends ConsumerWidget {
  const CaseDetailScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    Case? found;
    try {
      found = repo.caseById(caseId);
    } catch (_) {
      found = null;
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('이상 건 상세')),
        body: const Center(
            child: Text('이 이상 건을 찾지 못했어요.\n앱을 다시 열어 주세요.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: T.body, color: inkSub))),
      );
    }
    final c = found;
    final now = repo.now();
    final p = CasePerms(repo, me, c, now);
    final r = repo.resident(c.residentId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text('${r.name} · ${c.kindLabel}'),
      ),
      // 내용이 짧으니 한 번에 다 그려 둔다 (화면 밖 기록도 바로 찾을 수 있게).
      body: ListView(scrollCacheExtent: const ScrollCacheExtent.pixels(4000), padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, Gap.xl * 2), children: [
        _Header(c: c, now: now),
        if (c.isOpen && c.recoveredAt != null) ...[
          const SizedBox(height: Gap.m),
          _RecoveredCard(c: c, p: p),
        ],
        _Actions(c: c, p: p),
        _StageStepper(stage: c.stage, closed: !c.isOpen),
        _InfoRows(c: c),
        _MeasurementList(c: c),
        _Timeline(c: c, p: p),
        const SizedBox(height: Gap.xl),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('별님 카드로'),
          onPressed: () => openResidentCard(context, c.residentId),
        ),
      ]),
      bottomNavigationBar: p.readOnly || (p.hasAcked && c.assigneeId != null) ? null : _PrimaryBar(c: c, p: p),
    );
  }
}

// ── 머리: 긴급/이상 대응 알약 → 별님 이름(크게) → 체온(크게) + 판정 → 평소와 차이 → 시작 시각
class _Header extends ConsumerWidget {
  const _Header({required this.c, required this.now});
  final Case c;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final col = caseColors(c);
    final r = repo.resident(c.residentId);
    final cls = repo.classOf(c.classId);
    final latest = latestOfCase(repo, c.id);
    final status = caseStatusLabel(c);
    final changed = latest != null && latest.id != c.firstMeasurementId;
    final unacked = status == '미확인';
    return Container(
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(
        color: col.soft,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: col.line, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: Gap.s, runSpacing: Gap.s, crossAxisAlignment: WrapCrossAlignment.center, children: [
          CaseBadge(c),
          StatusPill(status, color: unacked ? stageColors[Stage.danger]!.ink : inkMain, background: surface),
        ]),
        const SizedBox(height: Gap.m),
        Text('${r.name} 별님', style: const TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800, height: 1.25)),
        Text(cls.name, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub)),
        const SizedBox(height: Gap.s),
        Wrap(spacing: Gap.m, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${formatTemp(latest?.value ?? c.firstTemp)}℃',
              style: TextStyle(fontSize: T.number, fontWeight: FontWeight.w800, color: col.ink, fontFeatures: _tabular)),
          if (latest != null) StageTag(latest.judgment.stage, large: true),
        ]),
        if (latest != null)
          Text(plainDiff(latest.judgment.diff),
              style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: col.ink)),
        if (changed)
          Text('처음 ${formatTemp(c.firstTemp)}℃ → 최근 ${formatTemp(latest.value)}℃',
              style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain)),
        if (latest != null)
          Text('평소 체온 ${formatTemp(latest.judgment.baseline)}℃', style: const TextStyle(fontSize: T.caption, color: inkSub)),
        const SizedBox(height: Gap.s),
        Text('${hm(c.createdAt)}에 시작 (${agoText(now, c.createdAt)})',
            style: const TextStyle(fontSize: T.caption, color: inkSub)),
      ]),
    );
  }
}

// ── 대응 단계 ①~④: 세로로 한 줄씩. 지금 단계는 남색으로 채우고 '지금'.
class _StageStepper extends StatelessWidget {
  const _StageStepper({required this.stage, required this.closed});
  final int stage;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('대응 단계'),
      Semantics(
        label: '대응 단계 $stage, ${InMemoryRepository.stageLabel(stage)}',
        child: ExcludeSemantics(
          child: Column(children: [
            for (var s = 1; s <= 4; s++) ...[
              _stageRow(s),
              if (s < 4) const SizedBox(height: Gap.xs),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _stageRow(int s) {
    final current = s == stage;
    final past = s < stage;
    final fg = current ? Colors.white : (past ? inkMain : inkSub);
    return Container(
      constraints: const BoxConstraints(minHeight: tapHeight),
      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.s),
      decoration: BoxDecoration(
        color: current ? brandDark : surface,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: current ? brandDark : line, width: current ? 2 : 1),
      ),
      child: Row(children: [
        Icon(past ? Icons.check_circle : (current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            size: 24, color: current ? Colors.white : (past ? brandDark : inkSub)),
        const SizedBox(width: Gap.m),
        Expanded(
          child: Text('${circledStage[s - 1]} ${InMemoryRepository.stageLabel(s)}',
              style: TextStyle(
                  fontSize: current ? T.title : T.body,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                  color: fg)),
        ),
        if (current)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(Radii.pill)),
            child: Text(closed ? '마지막' : '지금',
                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: brandDark)),
          )
        else if (past)
          const Text('지남', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub)),
      ]),
    );
  }
}

// ── 담당 · 확인한 사람 · 다음 재측정 · 종료 (한 줄에 한 가지)
class _InfoRows extends ConsumerWidget {
  const _InfoRows({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final acks = acksOf(repo, c.id);
    Widget row(String k, List<String> values) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 96,
                child: Text(k,
                    style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub, height: 1.6))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final v in values) Text(v, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('누가 보고 있나요'),
      InfoCard(
        padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.s),
        child: Column(children: [
          row('담당', [c.assigneeId == null ? '아직 없어요' : staffName(repo, c.assigneeId!)]),
          const Divider(),
          row('확인한 사람',
              acks.isEmpty ? ['아직 아무도 확인 안 했어요'] : [for (final e in acks) '${staffName(repo, e.actorId)} ${hm(e.at)}']),
          const Divider(),
          if (c.isOpen)
            row('다음에 잴 때', [
              c.remeasureAt != null && c.status == CaseStatus.waitingRemeasure ? '${hm(c.remeasureAt!)} 예정' : '정해진 시각 없음'
            ]),
          if (!c.isOpen) row('종료', [c.closeReason ?? '', if (c.closedAt != null) '${hm(c.closedAt!)}에 종료']),
        ]),
      ),
    ]);
  }
}

// ── 종료 대기 (C3): 평소로 내려옴 → [지금 종료하기] / [한 번 더 재고 종료하기]
class _RecoveredCard extends ConsumerWidget {
  const _RecoveredCard({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final latest = latestOfCase(repo, c.id);
    final col = stageColors[Stage.normal]!;
    final denied = p.closeDenied != null;
    return InfoCard(
      accent: col.line,
      background: col.soft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('✓ 평소 체온으로 돌아왔어요', style: TextStyle(color: col.ink, fontWeight: FontWeight.w800, fontSize: T.title)),
        if (latest != null)
          Text(plainDiff(latest.judgment.diff),
              style: TextStyle(color: col.ink, fontWeight: FontWeight.w600, fontSize: T.body)),
        if (!p.readOnly) ...[
          const SizedBox(height: Gap.m),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(tapHeight),
              backgroundColor: denied ? line : brandDark,
              foregroundColor: denied ? inkMain : Colors.white,
            ),
            icon: Icon(denied ? Icons.lock_outline : Icons.check_circle_outline),
            onPressed: () => denied
                ? toast(context, p.closeDenied!)
                : runClose(context, ref, c, p, initial: p.fullClose ? closeReasons.first : null),
            label: const Text('지금 종료하기'),
          ),
          const SizedBox(height: Gap.s),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
            icon: const Icon(Icons.alarm),
            onPressed: () {
              final now = repo.now();
              repo.scheduleRemeasure(c.id, p.me, now, const Duration(minutes: 30));
              toast(context, '${hm(now.add(const Duration(minutes: 30)))}에 한 번 더 재고 종료해요');
            },
            label: const Text('한 번 더 재고 종료하기'),
          ),
        ],
      ]),
    );
  }
}

// ── 하단 고정: [확인했어요] [제가 맡을게요] (같은 폭, 높이 56)
class _PrimaryBar extends ConsumerWidget {
  const _PrimaryBar({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return Material(
      color: surface,
      shape: const Border(top: BorderSide(color: line)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.page, Gap.m),
          child: Row(children: [
            if (!p.hasAcked)
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('확인했어요'),
                  onPressed: () => repo.acknowledge(c.id, p.me, repo.now()),
                ),
              ),
            if (!p.hasAcked && c.assigneeId == null) const SizedBox(width: Gap.s),
            if (c.assigneeId == null)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight), backgroundColor: brandDark),
                  icon: const Icon(Icons.front_hand_outlined),
                  label: const Text('제가 맡을게요'),
                  onPressed: () {
                    final now = repo.now();
                    if (!p.hasAcked) repo.acknowledge(c.id, p.me, now);
                    repo.assign(c.id, p.me, now);
                    toast(context, '이 건을 맡았어요. 모두에게 알렸어요');
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// S7: 사유 고르기 → (회복인데 아직 높으면 한 번 더 묻기) → 종료.
Future<void> runClose(BuildContext context, WidgetRef ref, Case c, CasePerms p, {String? initial}) async {
  final repo = ref.read(repoProvider);
  final res = await closeSheet(context, p, initial: initial);
  if (res == null || !context.mounted) return;
  final latest = latestOfCase(repo, c.id);
  if (res.chip == closeReasons.first && latest != null && latest.judgment.stage.opensCase) {
    final ok = await confirm(context, '아직 평소보다 높아요', '마지막 체온 ${formatTemp(latest.value)}℃예요.\n그래도 종료할까요?', '종료하기');
    if (!ok || !context.mounted) return;
  }
  repo.close(c.id, p.me, repo.now(), res.joined);
  toast(context, '${c.kindLabel} 건을 종료했어요. 모두에게 알렸어요');
}

// ── 할 일 버튼들: 주 행동(재측정 입력) 한 개는 폭 전체, 나머지는 2칸 격자.
// 권한 없는 버튼은 자물쇠 + 누르면 이유.
class _Actions extends ConsumerWidget {
  const _Actions({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final guideline = _Btn('투약 지침 보기', Icons.menu_book_outlined, () => showGuideline(context, ref, c.residentId));

    if (p.isOffice) {
      return _Section(title: '할 일', children: [
        const Text('사무국은 보기만 할 수 있어요.\n확인·담당·단계는 생활관·간호사·원장님이 기록해요.',
            style: TextStyle(color: inkSub, fontSize: T.body)),
        const SizedBox(height: Gap.m),
        _WideBtn(guideline),
      ]);
    }
    if (!c.isOpen) {
      return _Section(title: '할 일', children: [
        const Text('종료된 건이에요. 기록은 그대로 남아 있어요.', style: TextStyle(color: inkSub, fontSize: T.body)),
        const SizedBox(height: Gap.m),
        _WideBtn(guideline),
      ]);
    }

    DateTime now() => repo.now();
    final primary = _Btn('재측정 입력', Icons.thermostat, () {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ref.read(quickTempProvider.notifier).openFor(c.residentId);
    }, denied: p.remeasureDenied, primary: true);
    final buttons = <_Btn>[
      _Btn('30분 뒤 다시 재기', Icons.alarm, () {
        final t = now();
        repo.scheduleRemeasure(c.id, p.me, t, const Duration(minutes: 30));
        toast(context, '${hm(t.add(const Duration(minutes: 30)))}에 다시 알려 드릴게요');
      }),
      guideline,
      _Btn('투약 기록', Icons.medication_outlined, () => _recordMedication(context, ref), denied: p.medicationDenied),
      _Btn('조치 기록', Icons.edit_note, () async {
        final res = await showNoteSheet(context,
            title: '조치 기록',
            chips: const ['💧 수분 섭취', '👕 옷·이불 조절', '🧊 미온수 마사지', '🌡 실내 온도 조절', '👀 상태 관찰', '✏️ 직접 쓰기'],
            chipRequired: true,
            textRequiredFor: const {'✏️ 직접 쓰기'},
            submitLabel: '기록하기');
        if (res != null) repo.addNote(c.id, 'note', p.me, now(), res.joined);
      }),
      if (c.stage < 4) _Btn('단계 올리기', Icons.trending_up, () => _raise(context, ref), denied: p.raiseDenied),
      if (p.isDirector && c.stage < 4)
        _Btn('병원으로 보내세요', Icons.local_hospital_outlined, () => _sendHospital(context, ref), danger: true),
      if (p.isDirector) _Btn('원장 지시', Icons.assignment_outlined, () => _directorOrder(context, ref)),
      if (c.stage == 4)
        _Btn('병원 결과 기록', Icons.local_hospital_outlined, () async {
          final res = await showNoteSheet(context,
              title: '병원 결과 기록',
              chips: const ['병원 도착', '진료 후 귀원', '입원'],
              chipRequired: true,
              hint: '진단·처방 메모 (선택)',
              submitLabel: '기록하기');
          if (res != null) repo.addNote(c.id, 'hospital_result', p.me, now(), res.joined);
        }),
      _Btn('대응 종료', Icons.check_circle_outline, () => runClose(context, ref, c, p), denied: p.closeDenied),
    ];
    return _Section(title: '할 일', children: [
      if (c.assigneeId != null && c.assigneeId != p.me)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.m),
          child: IconLine(
              icon: Icons.front_hand_outlined, text: '${withSubject(staffName(repo, c.assigneeId!))} 맡고 있어요', strong: true),
        ),
      _WideBtn(primary),
      const SizedBox(height: Gap.s),
      _BtnGrid(buttons),
    ]);
  }

  Future<void> _recordMedication(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repoProvider);
    final res = await showNoteSheet(context,
        title: '투약 기록',
        subtitle: '지침과 지시대로 한 일을 그대로 적어 주세요.\n앱은 용량을 계산하거나 추천하지 않아요.',
        textRequired: true,
        hint: '예: 지침대로 해열제 줌, 원장님 지시 (선택)',
        submitLabel: '기록하기');
    if (res == null || !context.mounted) return;
    repo.addNote(c.id, 'medication', p.me, repo.now(), res.joined);
    if (repo.caseById(c.id).stage == 1) {
      final up = await confirm(context, '② 원내 조제로 올릴까요?', '투약을 기록했어요.\n대응 단계를 ② 원내 조제로 올릴 수 있어요.', '올리기');
      if (up) repo.setStage(c.id, 2, p.me, repo.now(), note: '투약 기록');
    }
  }

  Future<void> _raise(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repoProvider);
    final s = await pickStage(context, p);
    if (s == null || !context.mounted) return;
    final res = await stageInputSheet(context, s, p);
    if (res == null) return;
    repo.setStage(c.id, s, p.me, repo.now(), note: res.joined.isEmpty ? null : res.joined);
    if (context.mounted) toast(context, '대응 단계를 ${circledStage[s - 1]} ${InMemoryRepository.stageLabel(s)}(으)로 올렸어요');
  }

  Future<void> _sendHospital(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repoProvider);
    final ok = await confirm(context, '병원으로 보낼까요?', '대응 단계가 ④ 인근 병원으로 올라가요.\n모두에게 알림이 가요.', '보내기');
    if (!ok) return;
    final now = repo.now();
    repo.addNote(c.id, 'director_order', p.me, now, '병원으로 보내세요');
    repo.setStage(c.id, 4, p.me, now, note: '원장님 지시');
    if (context.mounted) toast(context, '④ 인근 병원으로 올렸어요');
  }

  Future<void> _directorOrder(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repoProvider);
    final res = await showNoteSheet(context,
        title: '원장 지시',
        subtitle: '[지켜보세요]를 고르면 1시간 뒤에 다시 재도록 알려요.',
        chips: const ['처방했어요', '지켜보세요'],
        chipRequired: true,
        textRequiredFor: const {'처방했어요'},
        hint: '지시·처방 내용 (선택)',
        submitLabel: '지시 남기기');
    if (res == null) return;
    final now = repo.now();
    repo.addNote(c.id, 'director_order', p.me, now, res.joined);
    if (res.chip == '지켜보세요') repo.scheduleRemeasure(c.id, p.me, now, const Duration(hours: 1));
  }
}

class _Btn {
  const _Btn(this.label, this.icon, this.onTap, {this.denied, this.primary = false, this.danger = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? denied;
  final bool primary;
  final bool danger;
}

/// 폭 전체 버튼 (주 행동).
class _WideBtn extends StatelessWidget {
  const _WideBtn(this.b);
  final _Btn b;

  @override
  Widget build(BuildContext context) {
    final denied = b.denied != null;
    final icon = Icon(denied ? Icons.lock_outline : b.icon, size: 26);
    final label = Text(b.label);
    void onTap() => denied ? toast(context, b.denied!) : b.onTap();
    return Semantics(
      hint: b.denied,
      child: b.primary && !denied
          ? FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60), backgroundColor: brandDark),
              icon: icon,
              label: label,
              onPressed: onTap,
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                foregroundColor: denied ? inkSub : brandDark,
                backgroundColor: denied ? paper : surface,
                side: BorderSide(color: denied ? line : brandDark, width: 1.5),
              ),
              icon: icon,
              label: label,
              onPressed: onTap,
            ),
    );
  }
}

/// 2칸 격자. 한 줄의 두 버튼은 같은 폭·같은 높이 (아이콘 위, 글자 아래).
class _BtnGrid extends StatelessWidget {
  const _BtnGrid(this.buttons);
  final List<_Btn> buttons;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < buttons.length; i += 2) {
      final a = buttons[i];
      final b = i + 1 < buttons.length ? buttons[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _GridBtn(a)),
          const SizedBox(width: Gap.s),
          Expanded(child: b == null ? const SizedBox() : _GridBtn(b)),
        ]),
      ));
      if (i + 2 < buttons.length) rows.add(const SizedBox(height: Gap.s));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _GridBtn extends StatelessWidget {
  const _GridBtn(this.b);
  final _Btn b;

  @override
  Widget build(BuildContext context) {
    final denied = b.denied != null;
    final danger = stageColors[Stage.danger]!;
    final fg = denied ? inkSub : (b.danger ? danger.ink : brandDark);
    return Semantics(
      hint: b.denied,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(76),
          padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.s),
          foregroundColor: fg,
          backgroundColor: denied ? paper : (b.danger ? danger.soft : surface),
          side: BorderSide(color: denied ? line : (b.danger ? danger.line : brandDark), width: 1.5),
        ),
        onPressed: () => denied ? toast(context, b.denied!) : b.onTap(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(denied ? Icons.lock_outline : b.icon, size: 28, color: fg),
          const SizedBox(height: Gap.xs),
          Text(b.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: T.body, fontWeight: FontWeight.w700, color: denied ? inkSub : inkMain, height: 1.3)),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(title),
        ...children,
      ]);
}

// ── 이 건의 체온 기록: 체온(크게) + 판정 / 평소와 차이 / 시각·잰 사람
class _MeasurementList extends ConsumerWidget {
  const _MeasurementList({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final list = repo.measurementsOfCase(c.id);
    return _Section(title: '체온 기록', children: [
      if (list.isEmpty) const EmptyNote('체온 기록이 없어요'),
      for (final m in list)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.s),
          child: InfoCard(
            accent: m.isVoided ? line : stageColors[m.judgment.stage]!.line,
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${formatTemp(m.value)}℃',
                    style: TextStyle(
                      fontSize: T.title,
                      fontWeight: FontWeight.w800,
                      fontFeatures: _tabular,
                      decoration: m.isVoided ? TextDecoration.lineThrough : null,
                      color: m.isVoided ? inkSub : inkMain,
                    )),
                if (m.isVoided) const StatusPill('잘못 잰 값', color: inkSub) else StageTag(m.judgment.stage),
              ]),
              if (!m.isVoided) Text(plainDiff(m.judgment.diff), style: const TextStyle(fontSize: T.body, color: inkMain)),
              Text('${hm(m.measuredAt)} · ${staffName(repo, m.recordedBy).split(' ').first}',
                  style: const TextStyle(fontSize: T.caption, color: inkSub)),
            ]),
          ),
        ),
    ]);
  }
}

// ── 대응 기록 타임라인: 무엇(본문) / 시각·누가(작은 글자). 취소된 줄은 취소선.
class _Timeline extends ConsumerWidget {
  const _Timeline({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final events = repo.eventsOf(c.id);
    return _Section(title: '대응 기록', children: [
      if (events.isEmpty) const EmptyNote('아직 기록이 없어요'),
      if (events.isNotEmpty)
        InfoCard(
          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0) const Divider(),
              _eventRow(context, repo, events[i]),
            ],
          ]),
        ),
    ]);
  }

  Widget _eventRow(BuildContext context, InMemoryRepository repo, CaseEvent e) {
    final voided = e.voidedBy != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          eventText(repo, e),
          style: TextStyle(
            fontSize: T.body,
            fontWeight: FontWeight.w600,
            decoration: voided ? TextDecoration.lineThrough : null,
            color: voided ? inkSub : inkMain,
          ),
        ),
        const SizedBox(height: 2),
        Text('${hm(e.at)} · ${eventActor(repo, e)}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
        if (voided)
          Text('취소됨 (${staffName(repo, e.voidedBy!)})',
              style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
        if (p.canVoid(e))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                  minimumSize: const Size(0, tapHeight), padding: const EdgeInsets.symmetric(horizontal: Gap.s)),
              icon: const Icon(Icons.undo),
              onPressed: () async {
                final ok = await confirm(context, '이 기록을 취소할까요?', "기록은 지워지지 않고\n'취소됨'으로 표시돼요.", '취소 표시');
                if (ok) repo.voidEvent(e.id, p.me);
              },
              label: const Text('기록 취소'),
            ),
          ),
      ]),
    );
  }
}
