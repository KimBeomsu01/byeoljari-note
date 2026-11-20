// 체온 측정 화면의 AlertActionSheet (Claude Design QuickVital.dc.html) · 투약 지침 보기.
// 기록한 체온이 평소보다 높으면(주의 이상) 다이얼 아래에 붙어 나온다.
// 투약 지침은 의료진이 쓴 글을 그대로 보여주기만 한다. 용량 계산·추천은 하지 않는다.
// 실제 전화는 걸 수 없다: 간호 선생님 의료 호출함에 "통화 요청"을 남기고 그렇게 알린다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';

/// 잘못 잰 값으로 끝낸 이상 건의 종료 사유 (이상 대응 화면과 같은 문구).
const _misMeasureReason = '잘못 잰 값 (오측정)';

/// 통화 요청 문구 (의료 호출 대화에 남는다).
const callRequestText = '현장에서 바로 통화 요청';

/// AlertActionSheet: 알림 머리 → [간호 선생님 바로 통화] → [투약 지침 확인] → 30분 뒤 다시 측정 알림 · 잘못 쟀어요.
class AlertActionSheet extends ConsumerWidget {
  const AlertActionSheet({super.key, required this.result, required this.onToast, required this.onUndone});

  /// 방금 기록한 결과 (판정은 저장할 때 측정에 함께 저장된 것).
  final SaveResult result;

  /// 화면 위 토스트로 결과를 알린다.
  final ValueChanged<String> onToast;

  /// "잘못 쟀어요"로 기록을 무효 표시한 뒤 (시트를 닫는다).
  final VoidCallback onUndone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final m = result.measurement;
    final now = repo.now();
    final caseNow = result.caseItem == null ? null : repo.allCases.where((c) => c.id == result.caseItem!.id).firstOrNull;
    final notified = result.call != null || (caseNow != null && repo.openCalls.any((c) => c.caseId == caseNow.id));
    final caution = m.judgment.stage == Stage.caution;
    final header = notified
        ? '간호 선생님에게 이상 알림이 전송됐어요'
        : caution
            ? '30분 뒤 다시 측정할 일이 생겼어요'
            : '이상 대응 기록에 이어서 남겼어요';
    final mins = now.difference(m.measuredAt).inMinutes;
    final ago = mins < 1 ? '방금' : (mins < 60 ? '$mins분 전' : hhmm(m.measuredAt));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Ds.gray50,
        border: Border.all(color: Ds.gray100),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 머리: ● 간호 선생님에게 이상 알림이 전송됐어요 · 방금
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ds.gray100))),
            child: Row(children: [
              _PulseDot(color: notified || !caution ? Ds.red500 : Ds.orange500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(header,
                    style: const TextStyle(fontSize: T.body, height: 1.5, fontWeight: FontWeight.w600, color: Ds.gray900)),
              ),
              const SizedBox(width: 8),
              Text(ago, style: const TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500)),
            ]),
          ),
          const SizedBox(height: 16),
          _SheetButton(
            label: '간호 선생님 바로 통화',
            icon: Icons.call_outlined,
            primary: true,
            onTap: () => _requestCall(ref),
          ),
          const SizedBox(height: 10),
          _SheetButton(
            label: '투약 지침 확인',
            icon: Icons.assignment_outlined,
            primary: false,
            onTap: () => showGuideline(context, ref, m.residentId),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TextLink(
                  label: '30분 뒤 다시 측정 알림',
                  icon: Icons.alarm,
                  color: Ds.gray700,
                  weight: FontWeight.w500,
                  onTap: () => _remindLater(ref),
                ),
                _TextLink(
                  label: '잘못 쟀어요',
                  color: Ds.gray500,
                  weight: FontWeight.w400,
                  underline: true,
                  onTap: () => _undo(ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [간호 선생님 바로 통화]: 열린 호출이 있으면 거기에 통화 요청을 남기고, 없으면 긴급 호출을 새로 보낸다.
  void _requestCall(WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    final rid = result.measurement.residentId;
    final caseId = result.caseItem?.id;
    final mine = result.call == null ? null : repo.calls.where((c) => c.id == result.call!.id && c.isOpen).firstOrNull;
    final open = mine ??
        repo.openCalls.where((c) => c.residentId == rid && caseId != null && c.caseId == caseId).firstOrNull ??
        repo.openCalls.where((c) => c.residentId == rid).firstOrNull;
    if (open == null) {
      repo.requestCall(residentId: rid, level: CallLevel.urgent, by: me, summary: callRequestText);
    } else {
      repo.sendMessage(open.id, me, callRequestText);
    }
    onToast('간호 선생님에게 통화 요청을 보냈어요');
  }

  /// [30분 뒤 다시 측정 알림]: 이상 건이 열려 있으면 재측정 예약. 주의(이상 건 없음)면 다시 잴 할 일이 이미 생겨 있다.
  void _remindLater(WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    final now = repo.now();
    final rid = result.measurement.residentId;
    final open = repo.openCaseOf(rid);
    if (open != null) {
      const after = Duration(minutes: 30);
      repo.scheduleRemeasure(open.id, me, now, after);
      onToast('${hhmm(now.add(after))}에 다시 측정하도록 남겼어요');
      return;
    }
    final due = result.task?.dueAt ??
        repo.openTempTasksOf(rid).map((e) => e.task!.dueAt).whereType<DateTime>().firstOrNull;
    onToast(due != null ? '${hhmm(due)}에 다시 측정할 일이 이미 생겼어요' : '다시 측정할 일이 이미 있어요');
  }

  /// [잘못 쟀어요]: 기록을 지우지 않고 무효 표시. 이 측정으로 새로 생긴 이상 건·호출은 오측정으로 끝낸다.
  void _undo(WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    final at = repo.now();
    final m = result.measurement;
    repo.voidMeasurement(m.id, by: me, at: at);
    if (result.caseCreated && result.caseItem != null) {
      final c = repo.allCases.where((x) => x.id == result.caseItem!.id).firstOrNull;
      if (c != null && c.isOpen) repo.close(c.id, me, at, _misMeasureReason);
    }
    final call = result.call == null ? null : repo.calls.where((c) => c.id == result.call!.id && c.isOpen).firstOrNull;
    if (call != null) {
      repo.sendMessage(call.id, me, '${formatTemp(m.value)}°C는 잘못 잰 값이라 기록을 취소했어요');
      repo.completeCall(call.id, me);
    }
    onToast('기록을 취소했어요.');
    onUndone();
  }
}

/// 빨간 점 (ds-pulse: 2초마다 흐려졌다 돌아옴). 움직임 줄이기 설정이면 멈춰 있다.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.5).animate(CurvedAnimation(parent: _c, curve: const Cubic(0.4, 0, 0.6, 1))),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
}

/// 시트 안 큰 버튼: 주 버튼(violet 52) / 흰 버튼(48, 테두리).
class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.label, required this.icon, required this.primary, required this.onTap});
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(16);
    final fg = primary ? Colors.white : Ds.gray900;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: r, boxShadow: primary ? Ds.shadowSm : null),
        child: Material(
          color: primary ? Ds.violet500 : Ds.surface,
          shape: RoundedRectangleBorder(borderRadius: r, side: primary ? BorderSide.none : const BorderSide(color: Ds.gray200)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: primary ? Ds.violet600 : Ds.gray100,
            child: SizedBox(
              height: primary ? 52 : 48,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: primary ? 20 : 19, color: primary ? Colors.white : Ds.gray700),
                SizedBox(width: primary ? 8 : 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: primary ? T.bodyLg : T.bodyMd,
                        height: 1.5,
                        fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      )),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 시트 아래 작은 글자 버튼 (누르는 자리는 44 높이).
class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.label,
    required this.color,
    required this.weight,
    required this.onTap,
    this.icon,
    this.underline = false,
  });
  final String label;
  final Color color;
  final FontWeight weight;
  final IconData? icon;
  final bool underline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: tapHeight),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 4)],
              Flexible(
                child: Text(label,
                    style: TextStyle(
                      fontSize: T.label,
                      height: 1.5,
                      fontWeight: weight,
                      color: color,
                      decoration: underline ? TextDecoration.underline : null,
                      decorationColor: color,
                    )),
              ),
            ]),
          ),
        ),
      );
}

/// 투약 지침 보기: 의료진이 쓴 글을 그대로 보여준다 (없으면 "등록된 지침이 없어요").
Future<void> showGuideline(BuildContext context, WidgetRef ref, String residentId) {
  final repo = ref.read(repoProvider);
  final g = repo.guidelineOf(residentId);
  final now = repo.now();
  final r = repo.resident(residentId);

  // 최근 투약 기록 (중복 투약을 막도록 보여만 준다)
  final meds = [
    for (final c in repo.casesOf(residentId))
      for (final e in repo.eventsOf(c.id))
        if (e.type == 'medication' && e.voidedBy == null) e,
  ]..sort((a, b) => b.at.compareTo(a.at));
  final oldDays = g == null ? 0 : now.difference(g.updatedAt).inDays;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.assignment_outlined, size: 20, color: Ds.gray700),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${r.name} 투약 지침',
                    style: const TextStyle(fontSize: T.heading, height: 1.4, fontWeight: FontWeight.w700, color: Ds.gray900)),
              ),
              if (r.example) const ExampleTag(),
            ]),
            if (g != null) ...[
              const SizedBox(height: 4),
              Text(
                '${repo.staff(g.writtenBy).displayName} 작성 · ${g.updatedAt.year}년 ${g.updatedAt.month}월 ${g.updatedAt.day}일 고침',
                style: const TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500),
              ),
            ],
            const SizedBox(height: 16),
            if (g == null)
              const DsInset(
                padding: EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('등록된 지침이 없어요',
                      style: TextStyle(fontSize: T.bodyMd, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900)),
                  SizedBox(height: 2),
                  Text('간호 선생님께 먼저 연락해 주세요.', style: TextStyle(fontSize: T.label, height: 1.5, color: Ds.gray600)),
                ]),
              )
            else ...[
              if (oldDays > 180) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Ds.orange50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x66FF8A00)),
                  ),
                  child: Text('$oldDays일 동안 고치지 않은 지침이에요. 간호 선생님께 확인해 주세요.',
                      style: const TextStyle(fontSize: T.label, height: 1.5, fontWeight: FontWeight.w600, color: Color(0xFFE07A00))),
                ),
                const SizedBox(height: 12),
              ],
              DsInset(
                padding: const EdgeInsets.all(16),
                child: Text(g.body, style: const TextStyle(fontSize: T.bodyMd, height: 1.6, color: Ds.gray900)),
              ),
            ],
            if (meds.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('최근 투약 기록',
                  style: TextStyle(fontSize: T.body, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900)),
              for (final e in meds.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e.data['text'] ?? ''}',
                        style: const TextStyle(fontSize: T.body, height: 1.5, fontWeight: FontWeight.w600, color: Ds.gray900)),
                    Text('${relTime(e.at, now)} · ${repo.staff(e.actorId).name}',
                        style: const TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500)),
                  ]),
                ),
            ],
            const SizedBox(height: 16),
            const Text(
              '의료진이 미리 쓴 글을 그대로 보여 줘요. 판단이 어려우면 간호 선생님께 먼저 연락해 주세요.',
              style: TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500),
            ),
            const SizedBox(height: 16),
            DsButton('닫기', kind: DsButtonKind.gray, expand: true, height: 52, onPressed: () => Navigator.pop(sheet)),
          ],
        ),
      ),
    ),
  );
}
