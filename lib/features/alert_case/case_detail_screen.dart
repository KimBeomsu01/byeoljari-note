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
          child: Text(
            '이 이상 건을 찾지 못했어요.\n앱을 다시 열어 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: T.body, color: inkSub),
          ),
        ),
      );
    }
    final c = found;
    final now = repo.now();
    final p = CasePerms(repo, me, c, now);
    final r = repo.resident(c.residentId);

    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: Text('${r.name} · ${c.kindLabel}')),
      // 내용이 짧으니 한 번에 다 그려 둔다 (화면 밖 기록도 바로 찾을 수 있게).
      // 순서는 시제품 S3: 알약·제목 → 체온 카드 → 단계 칩 → 누가 → 할 수 있는 일 → 기록.
      body: ListView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, Gap.xl * 2),
        children: [
          _Header(c: c, now: now),
          const SizedBox(height: Gap.m),
          _StageStepper(stage: c.stage, closed: !c.isOpen),
          const SizedBox(height: Gap.m),
          _InfoRows(c: c),
          if (c.isOpen && c.recoveredAt != null) ...[const SizedBox(height: Gap.m), _RecoveredCard(c: c, p: p)],
          _Actions(c: c, p: p),
          _MeasurementList(c: c),
          _Timeline(c: c, p: p),
          const SizedBox(height: Gap.xl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: inkMain),
            icon: const Icon(Icons.badge_outlined, color: inkSub),
            label: const Text('별님 카드로'),
            onPressed: () => openResidentCard(context, c.residentId),
          ),
        ],
      ),
      bottomNavigationBar: p.readOnly || (p.hasAcked && c.assigneeId != null) ? null : _PrimaryBar(c: c, p: p),
    );
  }
}

/// 작은 구역 제목 (시제품: 굵은 본문 크기 + 옆에 옅은 설명).
class _SmallTitle extends StatelessWidget {
  const _SmallTitle(this.text, {this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, Gap.xl, 0, Gap.s),
    child: Wrap(
      spacing: Gap.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain),
        ),
        if (note != null)
          Text(
            note!,
            style: const TextStyle(fontSize: T.caption, color: inkSub),
          ),
      ],
    ),
  );
}

// ── 머리 (시제품 S3): 알약들 + 시작 시각 → "반 이름 별님" 제목 → 흰 카드(큰 체온 | 평소와 차이)
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
    final low = stageColors[Stage.low]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: Gap.s,
                runSpacing: Gap.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CaseBadge(c),
                  StatusPill(
                    status,
                    color: unacked ? stageColors[Stage.danger]!.ink : (c.isOpen ? low.ink : inkSub),
                    background: unacked ? stageColors[Stage.danger]!.soft : (c.isOpen ? low.soft : surface),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.s),
            Text(
              '${hm(c.createdAt)} 시작',
              style: const TextStyle(fontSize: T.caption, color: inkSub),
            ),
          ],
        ),
        const SizedBox(height: Gap.m),
        Text(
          '${cls.name} ${r.name} 별님',
          style: const TextStyle(fontSize: T.headline, fontWeight: FontWeight.w600, height: 1.3, color: inkMain),
        ),
        const SizedBox(height: Gap.m),
        InfoCard(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: formatTemp(latest?.value ?? c.firstTemp)),
                    const TextSpan(
                      text: '℃',
                      style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w500, color: inkSub),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: T.display - 4,
                  fontWeight: FontWeight.w500,
                  color: inkMain,
                  height: 1.1,
                  fontFeatures: _tabular,
                ),
              ),
              const SizedBox(width: Gap.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (latest != null)
                      Text(
                        plainDiff(latest.judgment.diff),
                        style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: col.ink),
                      ),
                    if (latest != null)
                      Text(
                        '평소 체온 ${formatTemp(latest.judgment.baseline)}℃',
                        style: const TextStyle(fontSize: T.caption, color: inkSub),
                      ),
                    if (changed)
                      Text(
                        '처음 ${formatTemp(c.firstTemp)}℃ → 최근 ${formatTemp(latest.value)}℃',
                        style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkMain),
                      ),
                    Text(
                      agoText(now, c.createdAt) == '방금' ? '방금 시작' : '${agoText(now, c.createdAt)} 시작',
                      style: const TextStyle(fontSize: T.caption, color: inkSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 대응 단계 ①~④ (시제품: 가로 칩, 지금 단계는 짙은 초록으로 채움). 큰 글자에 맞춰 2칸 × 2줄.
class _StageStepper extends StatelessWidget {
  const _StageStepper({required this.stage, required this.closed});
  final int stage;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    Widget row(int a) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _chip(a)),
          const SizedBox(width: Gap.s),
          Expanded(child: _chip(a + 1)),
        ],
      ),
    );
    return Semantics(
      label: '대응 단계 $stage, ${InMemoryRepository.stageLabel(stage)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row(1),
            const SizedBox(height: Gap.s),
            row(3),
          ],
        ),
      ),
    );
  }

  Widget _chip(int s) {
    final current = s == stage;
    final past = s < stage;
    final normal = stageColors[Stage.normal]!;
    final fg = current ? Colors.white : (past ? normal.ink : inkSub);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 6),
      decoration: BoxDecoration(
        color: current ? brandDark : (past ? normal.soft : surface),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: current ? brandDark : (past ? normal.line : line), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '${circledStage[s - 1]} ${InMemoryRepository.stageLabel(s)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: T.caption, fontWeight: current ? FontWeight.w800 : FontWeight.w600, color: fg),
            ),
          ),
          if (current) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(Radii.pill)),
              child: Text(
                closed ? '마지막' : '지금',
                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: brandDark),
              ),
            ),
          ] else if (past) ...[
            const SizedBox(width: 4),
            Icon(Icons.check, size: 16, color: normal.ink),
          ],
        ],
      ),
    );
  }
}

// ── 확인한 사람 · 담당자 · 재측정 · 종료 (시제품: 흰 카드 안 줄 목록)
class _InfoRows extends ConsumerWidget {
  const _InfoRows({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final acks = acksOf(repo, c.id);
    Widget row(String k, List<String> values) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w500, color: inkSub, height: 1.6),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final v in values)
                  Text(
                    v,
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return InfoCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
      child: Column(
        children: [
          row(
            '확인한 사람',
            acks.isEmpty ? ['아직 아무도 확인 안 했어요'] : [for (final e in acks) '${staffName(repo, e.actorId)} ${hm(e.at)}'],
          ),
          const Divider(),
          row('담당자', [c.assigneeId == null ? '아직 없어요' : staffName(repo, c.assigneeId!)]),
          const Divider(),
          if (c.isOpen)
            row('재측정', [
              c.remeasureAt != null && c.status == CaseStatus.waitingRemeasure
                  ? '${hm(c.remeasureAt!)} 예정'
                  : '정해진 시각 없음',
            ]),
          if (!c.isOpen) row('종료', [c.closeReason ?? '', if (c.closedAt != null) '${hm(c.closedAt!)}에 종료']),
        ],
      ),
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '✓ 평소 체온으로 돌아왔어요',
            style: TextStyle(color: col.ink, fontWeight: FontWeight.w800, fontSize: T.title),
          ),
          if (latest != null)
            Text(
              plainDiff(latest.judgment.diff),
              style: TextStyle(color: col.ink, fontWeight: FontWeight.w600, fontSize: T.body),
            ),
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
        ],
      ),
    );
  }
}

/// ── 하단 고정 (시제품: 폭 전체 짙은 초록 주 버튼). 둘 다 필요하면 [확인했어요] 테두리 + [제가 맡을게요] 채움.
class _PrimaryBar extends ConsumerWidget {
  const _PrimaryBar({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final showAck = !p.hasAcked;
    final showTake = c.assigneeId == null;
    final ack = showTake
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: inkMain),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('확인했어요'),
            onPressed: () => repo.acknowledge(c.id, p.me, repo.now()),
          )
        : FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: brandDark),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('확인했어요'),
            onPressed: () => repo.acknowledge(c.id, p.me, repo.now()),
          );
    return Material(
      color: paper,
      shape: const Border(top: BorderSide(color: line)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.page, Gap.m),
          child: Row(
            children: [
              if (showAck) Expanded(child: ack),
              if (showAck && showTake) const SizedBox(width: Gap.s),
              if (showTake)
                Expanded(
                  flex: showAck ? 1 : 2,
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
            ],
          ),
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
      return _Section(
        title: '할 수 있는 일',
        children: [
          const Text(
            '사무국은 보기만 할 수 있어요.\n확인·담당·단계는 생활관·간호사·원장님이 기록해요.',
            style: TextStyle(color: inkSub, fontSize: T.body),
          ),
          const SizedBox(height: Gap.m),
          _WideBtn(guideline),
        ],
      );
    }
    if (!c.isOpen) {
      return _Section(
        title: '할 수 있는 일',
        children: [
          const Text(
            '종료된 건이에요. 기록은 그대로 남아 있어요.',
            style: TextStyle(color: inkSub, fontSize: T.body),
          ),
          const SizedBox(height: Gap.m),
          _WideBtn(guideline),
        ],
      );
    }

    DateTime now() => repo.now();
    final primary = _Btn(
      '재측정 입력',
      Icons.thermostat,
      () {
        Navigator.of(context).popUntil((r) => r.isFirst);
        ref.read(quickTempProvider.notifier).openFor(c.residentId);
      },
      denied: p.remeasureDenied,
      primary: true,
    );
    final buttons = <_Btn>[
      _Btn('30분 뒤 다시 재기', Icons.alarm, () {
        final t = now();
        repo.scheduleRemeasure(c.id, p.me, t, const Duration(minutes: 30));
        toast(context, '${hm(t.add(const Duration(minutes: 30)))}에 다시 알려 드릴게요');
      }),
      guideline,
      _Btn('투약 기록', Icons.medication_outlined, () => _recordMedication(context, ref), denied: p.medicationDenied),
      _Btn('조치 기록', Icons.edit_note, () async {
        final res = await showNoteSheet(
          context,
          title: '조치 기록',
          chips: const ['💧 수분 섭취', '👕 옷·이불 조절', '🧊 미온수 마사지', '🌡 실내 온도 조절', '👀 상태 관찰', '✏️ 직접 쓰기'],
          chipRequired: true,
          textRequiredFor: const {'✏️ 직접 쓰기'},
          submitLabel: '기록하기',
        );
        if (res != null) repo.addNote(c.id, 'note', p.me, now(), res.joined);
      }),
      if (c.stage < 4) _Btn('단계 올리기', Icons.trending_up, () => _raise(context, ref), denied: p.raiseDenied),
      if (p.isDirector && c.stage < 4)
        _Btn('병원으로 보내세요', Icons.local_hospital_outlined, () => _sendHospital(context, ref), danger: true),
      if (p.isDirector) _Btn('원장 지시', Icons.assignment_outlined, () => _directorOrder(context, ref)),
      if (c.stage == 4)
        _Btn('병원 결과 기록', Icons.local_hospital_outlined, () async {
          final res = await showNoteSheet(
            context,
            title: '병원 결과 기록',
            chips: const ['병원 도착', '진료 후 귀원', '입원'],
            chipRequired: true,
            hint: '진단·처방 메모 (선택)',
            submitLabel: '기록하기',
          );
          if (res != null) repo.addNote(c.id, 'hospital_result', p.me, now(), res.joined);
        }),
      _Btn('대응 종료', Icons.check_circle_outline, () => runClose(context, ref, c, p), denied: p.closeDenied),
    ];
    return _Section(
      title: '할 수 있는 일',
      children: [
        if (c.assigneeId != null && c.assigneeId != p.me)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.m),
            child: IconLine(
              icon: Icons.front_hand_outlined,
              text: '${withSubject(staffName(repo, c.assigneeId!))} 맡고 있어요',
              strong: true,
            ),
          ),
        _BtnGrid([primary, ...buttons]),
      ],
    );
  }

  Future<void> _recordMedication(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repoProvider);
    final res = await showNoteSheet(
      context,
      title: '투약 기록',
      subtitle: '지침과 지시대로 한 일을 그대로 적어 주세요.\n앱은 용량을 계산하거나 추천하지 않아요.',
      textRequired: true,
      hint: '예: 지침대로 해열제 줌, 원장님 지시 (선택)',
      submitLabel: '기록하기',
    );
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
    final res = await showNoteSheet(
      context,
      title: '원장 지시',
      subtitle: '[지켜보세요]를 고르면 1시간 뒤에 다시 재도록 알려요.',
      chips: const ['처방했어요', '지켜보세요'],
      chipRequired: true,
      textRequiredFor: const {'처방했어요'},
      hint: '지시·처방 내용 (선택)',
      submitLabel: '지시 남기기',
    );
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

//// 폭 전체 버튼 (사무국·종료된 건의 투약 지침).
class _WideBtn extends StatelessWidget {
  const _WideBtn(this.b);
  final _Btn b;

  @override
  Widget build(BuildContext context) => _GridBtn(b, wide: true);
}

/// 2칸 격자 (시제품 '할 수 있는 일'). 한 줄의 두 버튼은 같은 폭·같은 높이.
class _BtnGrid extends StatelessWidget {
  const _BtnGrid(this.buttons);
  final List<_Btn> buttons;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // 글자 자리 = 칸 폭 − 안쪽 여백·테두리 − 아이콘·간격
      final labelW = (box.maxWidth - Gap.s) / 2 - 10 * 2 - 3 - 18 - 6;
      final rows = <Widget>[];
      for (var i = 0; i < buttons.length; i += 2) {
        final a = buttons[i];
        final b = i + 1 < buttons.length ? buttons[i + 1] : null;
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _GridBtn(a, labelW: labelW)),
                const SizedBox(width: Gap.s),
                Expanded(child: b == null ? const SizedBox() : _GridBtn(b, labelW: labelW)),
              ],
            ),
          ),
        );
        if (i + 2 < buttons.length) rows.add(const SizedBox(height: Gap.s));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    },
  );
}

/// 시제품 버튼: 흰 바탕 + 옅은 테두리, 왼쪽에 작은 색 아이콘 + 글자.
/// 주 행동(재측정 입력)은 연초록, 권한 없는 버튼은 자물쇠 + 흐린 바탕(누르면 이유).
class _GridBtn extends StatelessWidget {
  const _GridBtn(this.b, {this.wide = false, this.labelW});
  final _Btn b;
  final bool wide;
  final double? labelW;

  @override
  Widget build(BuildContext context) {
    final denied = b.denied != null;
    final danger = stageColors[Stage.danger]!;
    final normal = stageColors[Stage.normal]!;
    final iconColor = denied ? inkSub : (b.danger ? danger.ink : (b.primary ? normal.ink : brandDark));
    final bg = denied ? paper : (b.danger ? danger.soft : (b.primary ? const Color(0xFFE3F0D8) : surface));
    final border = denied ? line : (b.danger ? danger.line : (b.primary ? const Color(0xFF86B56C) : line));
    return Semantics(
      hint: b.denied,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Gap.s),
          alignment: wide ? Alignment.center : Alignment.centerLeft,
          foregroundColor: iconColor,
          backgroundColor: bg,
          side: BorderSide(color: border, width: 1.5),
        ),
        onPressed: () => denied ? toast(context, b.denied!) : b.onTap(),
        child: Row(
          mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(denied ? Icons.lock_outline : b.icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: _FitLabel(
                b.label,
                maxWidth: labelW,
                style: TextStyle(
                  fontSize: T.body,
                  fontWeight: b.primary ? FontWeight.w800 : FontWeight.w600,
                  color: denied ? inkSub : inkMain,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 버튼 글자: 한 줄에 조금 넘치면 살짝 줄여 한 줄로 (14 아래로는 안 줄인다),
/// 많이 넘치면 두 줄로. "다시 재/기"처럼 글자 중간에서 끊기는 것을 막는다.
class _FitLabel extends StatelessWidget {
  const _FitLabel(this.text, {required this.style, this.maxWidth});
  final String text;
  final TextStyle style;

  /// 글자 자리 폭 (격자 안에서는 IntrinsicHeight 때문에 LayoutBuilder를 못 써서 밖에서 받는다).
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final max = maxWidth;
    if (max == null) return Text(text, style: style);
    final tp = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    if (w <= max || max / w < T.caption / T.body) return Text(text, style: style);
    // 살짝 넘치면 글자를 그만큼만 줄여 한 줄로 (14 아래로는 안 줄인다).
    return Text(text, style: style.copyWith(fontSize: T.body * max / w), maxLines: 1, softWrap: false);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.note});
  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SmallTitle(title, note: note),
      ...children,
    ],
  );
}

// ── 이 건의 체온 기록: 한 장의 흰 카드 안에 줄마다 체온(크게) + 판정 / 평소와 차이 / 시각·잰 사람
class _MeasurementList extends ConsumerWidget {
  const _MeasurementList({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final list = repo.measurementsOfCase(c.id);
    return _Section(
      title: '체온 기록',
      children: [
        if (list.isEmpty) const EmptyNote('체온 기록이 없어요'),
        if (list.isNotEmpty)
          InfoCard(
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < list.length; i++) ...[if (i > 0) const Divider(), _row(repo, list[i])],
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(InMemoryRepository repo, Measurement m) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Gap.m),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Gap.s,
          runSpacing: Gap.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${formatTemp(m.value)}℃',
              style: TextStyle(
                fontSize: T.title,
                fontWeight: FontWeight.w800,
                fontFeatures: _tabular,
                decoration: m.isVoided ? TextDecoration.lineThrough : null,
                color: m.isVoided ? inkSub : inkMain,
              ),
            ),
            if (m.isVoided) const StatusPill('잘못 잰 값', color: inkSub) else StageTag(m.judgment.stage),
          ],
        ),
        if (!m.isVoided)
          Text(
            plainDiff(m.judgment.diff),
            style: const TextStyle(fontSize: T.body, color: inkMain),
          ),
        Text(
          '${hm(m.measuredAt)} · ${staffName(repo, m.recordedBy).split(' ').first}',
          style: const TextStyle(fontSize: T.caption, color: inkSub),
        ),
      ],
    ),
  );
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
    return _Section(
      title: '대응 기록',
      note: '버튼 한 번 = 기록 한 줄 · 지우지 않아요',
      children: [
        if (events.isEmpty) const EmptyNote('아직 기록이 없어요'),
        if (events.isNotEmpty)
          InfoCard(
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < events.length; i++) ...[
                  if (i > 0) const Divider(),
                  _eventRow(context, repo, events[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _eventRow(BuildContext context, InMemoryRepository repo, CaseEvent e) {
    final voided = e.voidedBy != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Text(
            '${hm(e.at)} · ${eventActor(repo, e)}',
            style: const TextStyle(fontSize: T.caption, color: inkSub),
          ),
          if (voided)
            Text(
              '취소됨 (${staffName(repo, e.voidedBy!)})',
              style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub),
            ),
          if (p.canVoid(e))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, tapHeight),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                ),
                icon: const Icon(Icons.undo),
                onPressed: () async {
                  final ok = await confirm(context, '이 기록을 취소할까요?', "기록은 지워지지 않고\n'취소됨'으로 표시돼요.", '취소 표시');
                  if (ok) repo.voidEvent(e.id, p.me);
                },
                label: const Text('기록 취소'),
              ),
            ),
        ],
      ),
    );
  }
}
