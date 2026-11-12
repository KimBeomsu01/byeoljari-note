// S3 이상 건 상세 (이상 대응 명세 6장 S3, 통합 명세 6-2).
// 버튼 한 번 = 기록 한 줄. 기록은 지우지 않고 취소 표시만 한다.
// 투약은 의료진이 쓴 지침을 보여주고, 간호사가 한 일을 글로 남길 뿐이다. 용량 계산·추천 없음.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'alert_sheet.dart' show showGuideline;
import 'case_sheets.dart';
import 'case_ui.dart';

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
        body: const Center(child: Text('이 이상 건을 찾지 못했어요.\n앱을 다시 열어 주세요.', textAlign: TextAlign.center)),
      );
    }
    final c = found;
    final now = repo.now();
    final p = CasePerms(repo, me, c, now);
    final r = repo.resident(c.residentId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: paper,
        title: Text('${r.name} · ${c.kindLabel}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        _Header(c: c, now: now),
        const SizedBox(height: 14),
        _StageStepper(stage: c.stage, closed: !c.isOpen),
        const SizedBox(height: 14),
        _InfoRows(c: c),
        if (c.isOpen && c.recoveredAt != null) ...[
          const SizedBox(height: 12),
          _RecoveredCard(c: c, p: p),
        ],
        const SizedBox(height: 16),
        _Actions(c: c, p: p),
        const SizedBox(height: 20),
        _MeasurementList(c: c),
        const SizedBox(height: 20),
        _Timeline(c: c, p: p),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('별님 카드로'),
          onPressed: () => openResidentCard(context, c.residentId),
        ),
      ]),
      bottomNavigationBar: p.readOnly || (p.hasAcked && c.assigneeId != null) ? null : _PrimaryBar(c: c, p: p),
    );
  }
}

// ── 머리: 긴급/이상 대응 · 상태 · 별님 · 체온 요약
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: col.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.line, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          LabelChip(caseBadge(c), color: col.ink, filled: true),
          LabelChip(status, color: status == '미확인' ? stageColors[Stage.danger]!.ink : inkMain),
        ]),
        const SizedBox(height: 8),
        Text('${cls.name} ${r.name} 별님', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('${hm(c.createdAt)} 시작 · ${agoText(now, c.createdAt)}', style: const TextStyle(fontSize: 13, color: inkSub)),
        const SizedBox(height: 8),
        Text(
          latest == null || latest.id == c.firstMeasurementId
              ? '${formatTemp(c.firstTemp)}℃'
              : '처음 ${formatTemp(c.firstTemp)}℃ → 최근 ${formatTemp(latest.value)}℃',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: col.ink),
        ),
        if (latest != null)
          Text(
            '평소 ${formatTemp(latest.judgment.baseline)}℃ · 평소보다 ${formatDiff(latest.judgment.diff)}℃ · '
            '${latest.judgment.stage.symbol} ${latest.judgment.stage.label}',
            style: const TextStyle(fontSize: 13.5),
          ),
      ]),
    );
  }
}

// ── 대응 단계 ①~④
class _StageStepper extends StatelessWidget {
  const _StageStepper({required this.stage, required this.closed});
  final int stage;
  final bool closed;

  static const _grey = Color(0xFFCCD2CC);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '대응 단계 $stage, ${InMemoryRepository.stageLabel(stage)}',
      child: ExcludeSemantics(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var s = 1; s <= 4; s++)
            Expanded(
              child: Column(children: [
                Row(children: [
                  Expanded(child: Container(height: 2, color: s == 1 ? Colors.transparent : (s <= stage ? brandDark : _grey))),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s == stage ? brandDark : (s < stage ? const Color(0xFFDDE8E0) : Colors.white),
                      border: Border.all(color: s <= stage ? brandDark : _grey, width: 1.5),
                    ),
                    child: Text(s < stage ? '✓' : '$s',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: s == stage ? Colors.white : (s < stage ? brandDark : inkSub))),
                  ),
                  Expanded(child: Container(height: 2, color: s == 4 ? Colors.transparent : (s < stage ? brandDark : _grey))),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${circledStage[s - 1]} ${InMemoryRepository.stageLabel(s)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: s == stage ? FontWeight.w800 : FontWeight.w500,
                    color: s == stage ? inkMain : inkSub,
                  ),
                ),
                if (s == stage)
                  Text(closed ? '마지막 단계' : '지금',
                      style: const TextStyle(fontSize: 11, color: brandDark, fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ── 담당 · 확인한 사람 · 다음 재측정 · 종료
class _InfoRows extends ConsumerWidget {
  const _InfoRows({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final acks = acksOf(repo, c.id);
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 84, child: Text(k, style: const TextStyle(color: inkSub, fontSize: 14))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        row('담당', c.assigneeId == null ? '아직 없음' : staffName(repo, c.assigneeId!)),
        row('확인한 사람',
            acks.isEmpty ? '아직 아무도 확인 안 함' : acks.map((e) => '${staffName(repo, e.actorId)} ${hm(e.at)}').join(' · ')),
        if (c.isOpen)
          row('다음 재측정',
              c.remeasureAt != null && c.status == CaseStatus.waitingRemeasure ? '${hm(c.remeasureAt!)} 예정' : '예약 없음'),
        if (!c.isOpen) row('종료', '${c.closeReason ?? ''}${c.closedAt == null ? '' : ' · ${hm(c.closedAt!)}'}'),
      ]),
    );
  }
}

// ── 종료 대기 (C3): 평소로 내려옴 → [한 번 더 재고 종료하기] / [지금 종료하기]
class _RecoveredCard extends ConsumerWidget {
  const _RecoveredCard({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final latest = latestOfCase(repo, c.id);
    final col = stageColors[Stage.normal]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: col.soft, borderRadius: BorderRadius.circular(14), border: Border.all(color: col.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          '✓ 평소 체온으로 돌아왔어요${latest == null ? '' : ' (${formatDiff(latest.judgment.diff)}℃)'} · 종료 대기',
          style: TextStyle(color: col.ink, fontWeight: FontWeight.w800, fontSize: 15),
        ),
        if (!p.readOnly) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  final now = repo.now();
                  repo.scheduleRemeasure(c.id, p.me, now, const Duration(minutes: 30));
                  toast(context, '${hm(now.add(const Duration(minutes: 30)))}에 한 번 더 재고 종료해요');
                },
                child: const Text('한 번 더 재고 종료하기', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: p.closeDenied == null ? brandDark : const Color(0xFFB9C0BB)),
                onPressed: () => p.closeDenied != null
                    ? toast(context, p.closeDenied!)
                    : runClose(context, ref, c, p, initial: p.fullClose ? closeReasons.first : null),
                child: const Text('지금 종료하기', textAlign: TextAlign.center),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── 하단 고정: [확인했어요] [제가 맡을게요]
class _PrimaryBar extends ConsumerWidget {
  const _PrimaryBar({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            if (!p.hasAcked)
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('확인했어요'),
                  onPressed: () => repo.acknowledge(c.id, p.me, repo.now()),
                ),
              ),
            if (!p.hasAcked && c.assigneeId == null) const SizedBox(width: 8),
            if (c.assigneeId == null)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: brandDark),
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
    final ok = await confirm(context, '아직 평소보다 높아요', '마지막 체온 ${formatTemp(latest.value)}℃예요. 그래도 종료할까요?', '종료하기');
    if (!ok || !context.mounted) return;
  }
  repo.close(c.id, p.me, repo.now(), res.joined);
  toast(context, '${c.kindLabel} 건을 종료했어요. 모두에게 알렸어요');
}

// ── 대응하기 버튼들 (권한 없는 버튼은 흐리게 + 누르면 이유)
class _Actions extends ConsumerWidget {
  const _Actions({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final guideline = _Btn('투약 지침 보기', Icons.menu_book_outlined, () => showGuideline(context, ref, c.residentId));

    if (p.isOffice) {
      return _Section(title: '대응하기', children: [
        const Text('사무국은 보기만 할 수 있어요. 확인·담당·단계는 생활관·간호사·원장님이 기록해요.',
            style: TextStyle(color: inkSub, fontSize: 14)),
        const SizedBox(height: 8),
        _BtnGrid([guideline]),
      ]);
    }
    if (!c.isOpen) {
      return _Section(title: '대응하기', children: [
        const Text('종료된 건이에요. 기록은 그대로 남아 있어요.', style: TextStyle(color: inkSub, fontSize: 14)),
        const SizedBox(height: 8),
        _BtnGrid([guideline]),
      ]);
    }

    DateTime now() => repo.now();
    final buttons = <_Btn>[
      _Btn('재측정 입력', Icons.thermostat, () {
        Navigator.of(context).popUntil((r) => r.isFirst);
        ref.read(quickTempProvider.notifier).openFor(c.residentId);
      }, denied: p.remeasureDenied, primary: true),
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
    return _Section(title: '대응하기', children: [
      if (c.assigneeId != null && c.assigneeId != p.me)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('${withSubject(staffName(repo, c.assigneeId!))} 맡고 있어요', style: const TextStyle(fontSize: 14)),
        ),
      _BtnGrid(buttons),
    ]);
  }

  Future<void> _recordMedication(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repoProvider);
    final res = await showNoteSheet(context,
        title: '투약 기록',
        subtitle: '지침과 지시대로 한 일을 그대로 적어 주세요. 앱은 용량을 계산하거나 추천하지 않아요.',
        textRequired: true,
        hint: '예: 지침대로 해열제 줌, 원장님 지시 (선택)',
        submitLabel: '기록하기');
    if (res == null || !context.mounted) return;
    repo.addNote(c.id, 'medication', p.me, repo.now(), res.joined);
    if (repo.caseById(c.id).stage == 1) {
      final up = await confirm(context, '② 원내 조제로 올릴까요?', '투약을 기록했어요. 대응 단계를 ② 원내 조제로 올릴 수 있어요.', '올리기');
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
    final ok = await confirm(context, '병원으로 보낼까요?', '대응 단계가 ④ 인근 병원으로 올라가고 모두에게 알림이 가요.', '보내기');
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
        subtitle: '[지켜보세요]는 1시간 뒤 재측정을 예약해요.',
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

class _BtnGrid extends StatelessWidget {
  const _BtnGrid(this.buttons);
  final List<_Btn> buttons;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - 8) / 2;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final b in buttons)
            SizedBox(
              width: w,
              child: Semantics(
                hint: b.denied,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    alignment: Alignment.centerLeft,
                    foregroundColor: b.denied != null
                        ? const Color(0xFF9AA19C)
                        : (b.danger ? stageColors[Stage.danger]!.ink : (b.primary ? Colors.white : brandDark)),
                    backgroundColor: b.denied == null && b.primary ? brandDark : Colors.white,
                    side: BorderSide(
                        color: b.denied != null
                            ? const Color(0xFFD5DAD6)
                            : (b.danger ? stageColors[Stage.danger]!.line : brandDark.withValues(alpha: 0.4))),
                  ),
                  icon: Icon(b.denied != null ? Icons.lock_outline : b.icon, size: 20),
                  label: Text(b.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  onPressed: () => b.denied != null ? toast(context, b.denied!) : b.onTap(),
                ),
              ),
            ),
        ]);
      });
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...children,
      ]);
}

// ── 이 건의 체온 기록
class _MeasurementList extends ConsumerWidget {
  const _MeasurementList({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final list = repo.measurementsOfCase(c.id);
    return _Section(title: '체온 기록', children: [
      if (list.isEmpty) const Text('체온 기록이 없어요', style: TextStyle(color: inkSub)),
      for (final m in list)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: stageColors[m.judgment.stage]!.line, width: 4)),
          ),
          child: Row(children: [
            SizedBox(width: 46, child: Text(hm(m.measuredAt), style: const TextStyle(color: inkSub, fontSize: 13))),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${formatTemp(m.value)}℃ ', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  TextSpan(text: '(${formatDiff(m.judgment.diff)}) ', style: const TextStyle(fontSize: 13, color: inkSub)),
                  TextSpan(
                      text: '${m.judgment.stage.symbol} ${m.judgment.stage.label}',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: stageColors[m.judgment.stage]!.ink)),
                  if (m.isVoided) const TextSpan(text: '  · 잘못 잰 값', style: TextStyle(fontSize: 13, color: inkSub)),
                ]),
                style: m.isVoided ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(staffName(repo, m.recordedBy).split(' ').first, style: const TextStyle(fontSize: 12.5, color: inkSub)),
          ]),
        ),
    ]);
  }
}

// ── 대응 기록 타임라인 (취소된 줄은 취소선)
class _Timeline extends ConsumerWidget {
  const _Timeline({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final events = repo.eventsOf(c.id);
    return _Section(title: '대응 기록', children: [
      if (events.isEmpty) const Text('아직 기록이 없어요', style: TextStyle(color: inkSub)),
      for (final e in events)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    eventText(repo, e),
                    style: TextStyle(
                      fontSize: 14.5,
                      decoration: e.voidedBy != null ? TextDecoration.lineThrough : null,
                      color: e.voidedBy != null ? inkSub : inkMain,
                    ),
                  ),
                  Text(
                    '${hm(e.at)} · ${staffName(repo, e.actorId)}'
                    '${e.voidedBy != null ? ' · 취소됨 (${staffName(repo, e.voidedBy!)})' : ''}',
                    style: const TextStyle(fontSize: 12, color: inkSub),
                  ),
                ]),
              ),
            ),
            if (p.canVoid(e))
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                onPressed: () async {
                  final ok = await confirm(context, '이 기록을 취소할까요?', "기록은 지워지지 않고 '취소됨'으로 표시돼요.", '취소 표시');
                  if (ok) repo.voidEvent(e.id, p.me);
                },
                child: const Text('기록 취소'),
              ),
          ]),
        ),
    ]);
  }
}
