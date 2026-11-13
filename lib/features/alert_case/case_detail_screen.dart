// S3 이상 건 상세 (이상 대응 명세 6장 S3, 통합 명세 6-2).
// 화면 기준: 클로드 디자인 개선 시안 "3 이상 대응 · 03b" — "누가 알고 있고, 다음엔 뭘 하지?"
// 위에서부터: ‹ 이상 대응 · 시작 시각 → 얼굴·이름 → 체온 카드(평소와 차이) → 누가 알고 있나 한 줄
// → 얇은 단계 막대 → 다음에 할 일 1개 → [투약 지침 보기 ›] [다른 일 · 대응 기록 ›] → 하단 [확인했어요][제가 맡을게요].
// 나머지 할 일(잠긴 것은 이유와 함께)·단계 올리기·종료·체온 기록·대응 기록은 [다른 일] 화면으로 옮겼다.
// 버튼 한 번 = 기록 한 줄. 기록은 지우지 않고 취소 표시만 한다.
// 투약은 의료진이 쓴 지침을 보여주고, 간호사가 한 일을 글로 남길 뿐이다. 용량 계산·추천 없음.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
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

/// 진행 막대의 빈 칸 · 지난 칸이 아닌 단계 글자 색 (시안).
const Color _barEmpty = Color(0xFFEAD9D2);
const Color _labelSub = Color(0xFF7A6458);

Case? _findCase(InMemoryRepository repo, String id) {
  try {
    return repo.caseById(id);
  } catch (_) {
    return null;
  }
}

Widget _notFound() => Scaffold(
  appBar: AppBar(title: const Text('이상 건 상세')),
  body: const Center(
    child: Text(
      '이 이상 건을 찾지 못했어요.\n앱을 다시 열어 주세요.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: T.body, color: inkSub),
    ),
  ),
);

class CaseDetailScreen extends ConsumerWidget {
  const CaseDetailScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final found = _findCase(repo, caseId);
    if (found == null) return _notFound();
    final c = found;
    final now = repo.now();
    final p = CasePerms(repo, me, c, now);
    final r = repo.resident(c.residentId);
    final cls = repo.classOf(c.classId);
    final events = repo.eventsOf(c.id);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ‹ 이상 대응                09:20 시작
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xs, 0, Gap.page, 0),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '뒤로',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.chevron_left, size: 32, color: inkMain),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        c.kindLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: fontBig,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: inkMain,
                        ),
                      ),
                    ),
                    Text(
                      '${hm(c.createdAt)} 시작',
                      style: const TextStyle(fontSize: T.caption, color: inkSub),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, Gap.xl),
                children: [
                  // 얼굴 · 이름 · 반·담임
                  Row(
                    children: [
                      FaceAvatar.resident(r.id, size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.name} 별님',
                              style: const TextStyle(
                                fontFamily: fontBig,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: inkMain,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cls.name} · 담임 ${staffName(repo, cls.homeroomId).split(' ').first}',
                              style: const TextStyle(fontSize: 16, color: inkSub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.l),
                  _TempCard(c: c),
                  const SizedBox(height: Gap.l),
                  _WhoKnows(c: c),
                  const SizedBox(height: 10),
                  _StageBar(stage: c.stage),
                  const SizedBox(height: Gap.l),
                  _NextCard(c: c, p: p),
                  const SizedBox(height: Gap.l),
                  _LinkRows(
                    rows: [
                      ('투약 지침 보기', () => showGuideline(context, ref, c.residentId)),
                      (
                        '다른 일 · 대응 기록 ${events.length}줄',
                        () =>
                            Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => _CaseMoreScreen(caseId: c.id))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: p.readOnly || (p.hasAcked && c.assigneeId != null) ? null : _PrimaryBar(c: c, p: p),
    );
  }
}

// ── 체온 카드: 큰 체온 | 판정 알약 · 평소와 차이 · 평소 체온. 긴급이면 빨강 + '⚠ 긴급'.
class _TempCard extends ConsumerWidget {
  const _TempCard({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final col = caseColors(c);
    final latest = latestOfCase(repo, c.id);
    final changed = latest != null && latest.id != c.firstMeasurementId;
    final danger = stageColors[Stage.danger]!;
    final pill = c.isUrgent
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: danger.soft,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: danger.line, width: 1.5),
            ),
            child: Text(
              '⚠ 긴급',
              style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: danger.ink),
            ),
          )
        : StageTag(latest?.judgment.stage ?? c.severity);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: col.line, width: 2),
      ),
      // 좁은 화면·큰 글자에서는 설명이 체온 아래로 내려간다.
      child: Wrap(
        spacing: Gap.l,
        runSpacing: Gap.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: formatTemp(latest?.value ?? c.firstTemp)),
                const TextSpan(text: '℃', style: TextStyle(fontSize: 20)),
              ],
            ),
            style: TextStyle(
              fontFamily: fontBig,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: col.ink,
              height: 1,
              fontFeatures: _tabular,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pill,
              if (latest != null) ...[
                const SizedBox(height: 4),
                Text(
                  plainDiff(latest.judgment.diff),
                  style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: col.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '평소 ${formatTemp(latest.judgment.baseline)}℃',
                  style: const TextStyle(fontSize: T.caption, color: inkSub),
                ),
              ],
              if (changed)
                Text(
                  '처음 ${formatTemp(c.firstTemp)}℃ → 최근 ${formatTemp(latest.value)}℃',
                  style: const TextStyle(fontSize: T.caption, color: inkSub),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 누가 알고 있나 (3칸 표 대신 한 줄): 아무도 안 봄(빨강 점) → 확인함 → 맡음.
class _WhoKnows extends ConsumerWidget {
  const _WhoKnows({required this.c});
  final Case c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final acks = acksOf(repo, c.id);
    final danger = stageColors[Stage.danger]!;
    final normal = stageColors[Stage.normal]!;
    final String text;
    final Color color;
    final Widget mark;
    if (!c.isOpen) {
      text = '종료했어요${c.closeReason == null ? '' : ' · ${c.closeReason}'}';
      color = inkSub;
      mark = const Icon(Icons.check_circle_outline, size: 20, color: inkSub);
    } else if (c.assigneeId != null) {
      text = '${withSubject(staffName(repo, c.assigneeId!))} 맡았어요';
      color = normal.ink;
      mark = Icon(Icons.front_hand_outlined, size: 20, color: normal.ink);
    } else if (acks.isNotEmpty) {
      text =
          '${withSubject(staffName(repo, acks.first.actorId))} 확인했어요${acks.length > 1 ? ' 외 ${acks.length - 1}명' : ''}';
      color = normal.ink;
      mark = Icon(Icons.check_circle, size: 20, color: normal.ink);
    } else {
      text = '아직 아무도 확인 안 했어요';
      color = danger.ink;
      mark = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: danger.ink, shape: BoxShape.circle),
      );
    }
    return Row(
      children: [
        SizedBox(width: 20, child: Center(child: mark)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

// ── 대응 단계: 얇은 4칸 막대 + ① 관찰 ② 조제 ③ 처방 ④ 병원 (지금 단계는 굵은 초록 글자).
class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage});
  final int stage;

  static const _short = ['관찰', '조제', '처방', '병원'];

  @override
  Widget build(BuildContext context) => Semantics(
    label: '대응 단계 $stage, ${InMemoryRepository.stageLabel(stage)}',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var s = 1; s <= 4; s++) ...[
                if (s > 1) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: s <= stage ? brandDark : _barEmpty,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var s = 1; s <= 4; s++) ...[
                if (s > 1) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${circledStage[s - 1]} ${_short[s - 1]}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: s == stage ? FontWeight.w700 : FontWeight.w400,
                      color: s == stage ? brandDark : _labelSub,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

// ── 다음에 할 일: 지금 단계·역할에서 할 것 하나만 크게.
class _NextCard extends ConsumerWidget {
  const _NextCard({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final latest = latestOfCase(repo, c.id);
    String sentence;
    String? sub;
    final buttons = <Widget>[];

    if (p.isOffice) {
      sentence = '사무국은 보기만 할 수 있어요.\n확인·담당·단계는 생활관·간호사·원장님이 기록해요.';
    } else if (!c.isOpen) {
      sentence = '종료된 건이에요. 기록은 그대로 남아 있어요.';
      sub = [?c.closeReason, if (c.closedAt != null) '${hm(c.closedAt!)}에 종료'].join(' · ');
    } else if (c.recoveredAt != null) {
      // 종료 대기 (C3): 평소로 내려옴 → [지금 종료하기] / [한 번 더 재고 종료하기]
      final denied = p.closeDenied != null;
      sentence = '✓ 평소 체온으로 돌아왔어요';
      sub = latest == null ? null : plainDiff(latest.judgment.diff);
      buttons
        ..add(
          _ActionButton(
            label: '지금 종료하기',
            kind: _Kind.green,
            denied: p.closeDenied,
            icon: denied ? Icons.lock_outline : null,
            onTap: () => runClose(context, ref, c, p, initial: p.fullClose ? closeReasons.first : null),
          ),
        )
        ..add(
          _ActionButton(
            label: '한 번 더 재고 종료하기',
            kind: _Kind.outlined,
            onTap: () {
              final now = repo.now();
              repo.scheduleRemeasure(c.id, p.me, now, const Duration(minutes: 30));
              toast(context, '${hm(now.add(const Duration(minutes: 30)))}에 한 번 더 재고 종료해요');
            },
          ),
        );
    } else if (c.stage == 4) {
      sentence = '병원에 다녀온 결과를 기록해 주세요';
      buttons.add(
        _ActionButton(label: '병원 결과 기록', kind: _Kind.action, onTap: () => _recordHospital(context, ref, c, p)),
      );
    } else if (p.isDirector && c.isUrgent) {
      sentence = '긴급이에요. 병원으로 보낼지 정해 주세요';
      buttons.add(
        _ActionButton(label: '병원으로 보내세요', kind: _Kind.danger, onTap: () => _sendHospital(context, ref, c, p)),
      );
    } else {
      final due = c.status == CaseStatus.waitingRemeasure && c.remeasureAt != null
          ? c.remeasureAt!
          : (latest?.measuredAt ?? c.createdAt).add(const Duration(hours: 1));
      sentence = '${hm(due)}까지 다시 재 주세요';
      buttons.add(
        _ActionButton(
          label: '재측정 입력',
          kind: _Kind.action,
          denied: p.remeasureDenied,
          onTap: () => _openRemeasure(context, ref, c),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '다음에 할 일',
            style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub),
          ),
          const SizedBox(height: Gap.m),
          Text(
            sentence,
            style: TextStyle(
              fontFamily: p.isOffice || !c.isOpen ? fontSmall : fontBig,
              fontSize: p.isOffice || !c.isOpen ? T.body : 19,
              fontWeight: p.isOffice || !c.isOpen ? FontWeight.w400 : FontWeight.w700,
              color: c.recoveredAt != null && c.isOpen ? stageColors[Stage.normal]!.ink : inkMain,
              height: 1.4,
            ),
          ),
          if (sub != null && sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: const TextStyle(fontSize: T.caption, color: inkSub),
            ),
          ],
          for (final b in buttons) ...[const SizedBox(height: Gap.m), b],
        ],
      ),
    );
  }
}

enum _Kind { green, action, outlined, danger }

/// 다음에 할 일 버튼 (52). 권한이 없으면 자물쇠 + 흐린 바탕, 누르면 이유.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.kind, required this.onTap, this.denied, this.icon});
  final String label;
  final _Kind kind;
  final VoidCallback onTap;
  final String? denied;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final locked = denied != null;
    final danger = stageColors[Stage.danger]!;
    final (bg, fg, side) = locked
        ? (paper, inkSub, const BorderSide(color: line, width: 1.5))
        : switch (kind) {
            _Kind.green => (brandDark, Colors.white, BorderSide.none),
            _Kind.action => (actionSoft, actionInk, BorderSide.none),
            _Kind.danger => (danger.ink, Colors.white, BorderSide.none),
            _Kind.outlined => (surface, inkMain, const BorderSide(color: lineStrong, width: 1.5)),
          };
    return Semantics(
      hint: denied,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: bg,
          foregroundColor: fg,
          side: side,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
          textStyle: const TextStyle(fontFamily: fontSmall, fontSize: T.body, fontWeight: FontWeight.w700),
        ),
        onPressed: () => locked ? toast(context, denied!) : onTap(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked || icon != null) ...[
              Icon(locked ? Icons.lock_outline : icon, size: 18),
              const SizedBox(width: 6),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

/// 흰 카드 안 줄 목록 (56 높이, 오른쪽 ›).
class _LinkRows extends StatelessWidget {
  const _LinkRows({required this.rows});
  final List<(String, VoidCallback)> rows;

  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.card),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: lineSoft),
          InkWell(
            onTap: rows[i].$2,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.s),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: inkSub),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// ── 하단 고정: [확인했어요](테두리) [제가 맡을게요](초록). 하나만 남으면 폭 전체 초록.
class _PrimaryBar extends ConsumerWidget {
  const _PrimaryBar({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final showAck = !p.hasAcked;
    final showTake = c.assigneeId == null;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    const text = TextStyle(fontFamily: fontSmall, fontSize: 18, fontWeight: FontWeight.w700);
    final filled = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      backgroundColor: brandDark,
      foregroundColor: Colors.white,
      shape: shape,
      textStyle: text,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    void ack() => repo.acknowledge(c.id, p.me, repo.now());
    final ackBtn = showTake
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: inkMain,
              backgroundColor: surface,
              side: const BorderSide(color: lineStrong, width: 1.5),
              shape: shape,
              textStyle: text,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: ack,
            child: const Text('확인했어요', textAlign: TextAlign.center),
          )
        : FilledButton(
            style: filled,
            onPressed: ack,
            child: const Text('확인했어요', textAlign: TextAlign.center),
          );
    return Material(
      color: surface,
      shape: const Border(top: BorderSide(color: Color(0xFFF1DFD9))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 14, Gap.page, 14),
          child: Row(
            children: [
              if (showAck) Expanded(child: ackBtn),
              if (showAck && showTake) const SizedBox(width: 10),
              if (showTake)
                Expanded(
                  child: FilledButton(
                    style: filled,
                    onPressed: () {
                      final now = repo.now();
                      if (!p.hasAcked) repo.acknowledge(c.id, p.me, now);
                      repo.assign(c.id, p.me, now);
                      toast(context, '이 건을 맡았어요. 모두에게 알렸어요');
                    },
                    child: const Text('제가 맡을게요', textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── [다른 일 · 대응 기록]: 할 수 있는 일 전부(잠긴 것은 이유) · 누가/담당/재측정 · 체온 기록 · 대응 기록 · 별님 카드.
class _CaseMoreScreen extends ConsumerWidget {
  const _CaseMoreScreen({required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final c = _findCase(repo, caseId);
    if (c == null) return _notFound();
    final p = CasePerms(repo, me, c, repo.now());
    final r = repo.resident(c.residentId);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 60,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${r.name} · ${c.kindLabel}',
              style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w400, color: inkSub),
            ),
            const Text(
              '다른 일 · 대응 기록',
              style: TextStyle(fontFamily: fontBig, fontSize: T.title, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: ListView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl * 2),
        children: [
          _Actions(c: c, p: p),
          _Section(
            title: '누가 알고 있나',
            children: [_InfoRows(c: c)],
          ),
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
    );
  }
}

// ── 할 일 버튼들 (2칸 격자). 권한 없는 버튼은 자물쇠 + 누르면 이유.
class _Actions extends ConsumerWidget {
  const _Actions({required this.c, required this.p});
  final Case c;
  final CasePerms p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    if (p.isOffice) {
      return const _Section(
        title: '할 수 있는 일',
        children: [
          Text(
            '사무국은 보기만 할 수 있어요.\n확인·담당·단계는 생활관·간호사·원장님이 기록해요.',
            style: TextStyle(color: inkSub, fontSize: T.body),
          ),
        ],
      );
    }
    if (!c.isOpen) {
      return const _Section(
        title: '할 수 있는 일',
        children: [
          Text(
            '종료된 건이라 더 할 일이 없어요.',
            style: TextStyle(color: inkSub, fontSize: T.body),
          ),
        ],
      );
    }

    DateTime now() => repo.now();
    final buttons = <_Btn>[
      _Btn('재측정 입력', Icons.thermostat, () => _openRemeasure(context, ref, c), denied: p.remeasureDenied, primary: true),
      _Btn('30분 뒤 다시 재기', Icons.alarm, () {
        final t = now();
        repo.scheduleRemeasure(c.id, p.me, t, const Duration(minutes: 30));
        toast(context, '${hm(t.add(const Duration(minutes: 30)))}에 다시 알려 드릴게요');
      }),
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
        _Btn('병원으로 보내세요', Icons.local_hospital_outlined, () => _sendHospital(context, ref, c, p), danger: true),
      if (p.isDirector) _Btn('원장 지시', Icons.assignment_outlined, () => _directorOrder(context, ref)),
      if (c.stage == 4) _Btn('병원 결과 기록', Icons.local_hospital_outlined, () => _recordHospital(context, ref, c, p)),
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
        _BtnGrid(buttons),
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

/// [재측정 입력]: 퀵 체온을 그 별님으로 연다 (체온 입력은 퀵 체온 한 곳뿐).
void _openRemeasure(BuildContext context, WidgetRef ref, Case c) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  ref.read(quickTempProvider.notifier).openFor(c.residentId);
}

Future<void> _recordHospital(BuildContext context, WidgetRef ref, Case c, CasePerms p) async {
  final repo = ref.read(repoProvider);
  final res = await showNoteSheet(
    context,
    title: '병원 결과 기록',
    chips: const ['병원 도착', '진료 후 귀원', '입원'],
    chipRequired: true,
    hint: '진단·처방 메모 (선택)',
    submitLabel: '기록하기',
  );
  if (res != null) repo.addNote(c.id, 'hospital_result', p.me, repo.now(), res.joined);
}

Future<void> _sendHospital(BuildContext context, WidgetRef ref, Case c, CasePerms p) async {
  final repo = ref.read(repoProvider);
  final ok = await confirm(context, '병원으로 보낼까요?', '대응 단계가 ④ 인근 병원으로 올라가요.\n모두에게 알림이 가요.', '보내기');
  if (!ok) return;
  final now = repo.now();
  repo.addNote(c.id, 'director_order', p.me, now, '병원으로 보내세요');
  repo.setStage(c.id, 4, p.me, now, note: '원장님 지시');
  if (context.mounted) toast(context, '④ 인근 병원으로 올렸어요');
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

class _Btn {
  const _Btn(this.label, this.icon, this.onTap, {this.denied, this.primary = false, this.danger = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? denied;
  final bool primary;
  final bool danger;
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
/// 주 행동(재측정 입력)은 연주황(체온 행동), 권한 없는 버튼은 자물쇠 + 흐린 바탕(누르면 이유).
class _GridBtn extends StatelessWidget {
  const _GridBtn(this.b, {this.labelW});
  final _Btn b;
  final double? labelW;

  @override
  Widget build(BuildContext context) {
    final denied = b.denied != null;
    final danger = stageColors[Stage.danger]!;
    final iconColor = denied ? inkSub : (b.danger ? danger.ink : (b.primary ? actionInk : brandDark));
    final bg = denied ? paper : (b.danger ? danger.soft : (b.primary ? actionSoft : surface));
    final border = denied ? line : (b.danger ? danger.line : (b.primary ? actionSoft : lineStrong));
    return Semantics(
      hint: b.denied,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Gap.s),
          alignment: Alignment.centerLeft,
          foregroundColor: iconColor,
          backgroundColor: bg,
          side: BorderSide(color: border, width: 1.5),
        ),
        onPressed: () => denied ? toast(context, b.denied!) : b.onTap(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
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
