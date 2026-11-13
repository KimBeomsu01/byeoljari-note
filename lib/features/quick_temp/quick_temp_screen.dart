// 퀵 체온 (QT). 퀵 체온 명세 3~8장 + 통합 명세 6-1.
// 화면 기준: 클로드 디자인 개선 시안 "2 퀵 체온 입력" — "누구 차례고, 몇 도로 넣을까?"
// 위에서부터: [● 반 ▾] + 기록 수 → 별님 얼굴 줄(잰 별님 흐리게 + ✓) → (할 일) → 이름 40 · 체온 96
// → 평소 체온 한 줄 → [−] 링 다이얼(가운데 초록 원 '꾹 눌러 기록') [+] → 안내 한 줄.
// 작은 화면에서는 글자가 아니라 다이얼을 먼저 줄인다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../alert_case/alert_sheet.dart';
import 'quick_temp_controller.dart';

const double _swipeThreshold = 48;

/// 잰 별님 ✓ 표 (시안 #4c7d62 = 판정 '평소' 진한 초록).
final Color _doneGreen = stageColors[Stage.normal]!.ink;

/// 링 눈금 색 (시안 repeating-conic-gradient #d8c4bb).
const Color _tick = Color(0xFFD8C4BB);

class QuickTempScreen extends ConsumerStatefulWidget {
  const QuickTempScreen({super.key});

  @override
  ConsumerState<QuickTempScreen> createState() => _QuickTempScreenState();
}

class _QuickTempScreenState extends ConsumerState<QuickTempScreen> {
  Offset _swipe = Offset.zero;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return; // 한 번 누름 = 한 번 요청
    final st = ref.read(quickTempProvider);
    final ctrl = ref.read(quickTempProvider.notifier);
    if (!ctrl.canMeasure(st.classId)) return;
    setState(() => _saving = true);
    final repo = ref.read(repoProvider);
    final now = ref.read(clockProvider)();
    final me = ref.read(currentUserProvider);
    final SaveResult result;
    try {
      result = repo.saveMeasurement(residentId: st.residentId, value: st.value, by: me, at: now);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장하지 못했어요. 다시 눌러 주세요 ($e)')));
      }
      return;
    }
    HapticFeedback.mediumImpact();
    ctrl.markSaved(st.residentId, st.value);
    setState(() => _saving = false);

    final stage = result.measurement.judgment.stage;
    if (result.caseCreated || result.escalated || (result.caseItem != null && stage.opensCase)) {
      // "기록 완료"를 먼저 보여주고 약 0.6초 뒤 S1 (통합 명세 6-1)
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) await showAlertSheet(context, ref, result);
    } else if (stage == Stage.caution && result.task != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('! ${plainDiff(result.measurement.judgment.diff)}\n30분 뒤 다시 재 주세요'),
        ),
      );
    }
  }

  void _onSwipeEnd() {
    final d = _swipe;
    _swipe = Offset.zero;
    final ctrl = ref.read(quickTempProvider.notifier);
    if (d.dx.abs() >= d.dy.abs()) {
      if (d.dx.abs() < _swipeThreshold) return;
      ctrl.step(d.dx < 0 ? 1 : -1);
    } else {
      if (d.dy.abs() < _swipeThreshold) return;
      ctrl.setMode(d.dy < 0 ? QtMode.classSelect : QtMode.resident);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(quickTempProvider);
    final ctrl = ref.read(quickTempProvider.notifier);
    final repo = ref.watch(repoProvider);
    final cls = repo.classOf(st.classId);
    final residents = repo.residentsOf(st.classId);
    final r = repo.resident(st.residentId);
    final idx = residents.indexWhere((x) => x.id == r.id);
    final saved = st.isSaved;
    final canMeasure = ctrl.canMeasure(st.classId);
    final scaler = MediaQuery.textScalerOf(context);
    final now = ref.read(clockProvider)();
    final done = {for (final x in residents) x.id: _isDone(repo, st, x.id, now)};
    final doneCount = done.values.where((v) => v).length;
    final classMode = st.mode == QtMode.classSelect;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _swipe = Offset.zero,
      onPanUpdate: (d) => _swipe += d.delta,
      onPanEnd: (_) => _onSwipeEnd(),
      child: ColoredBox(
        color: paper,
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) {
              // 작은 화면(또는 큰 글자): 얼굴·이름·체온을 한 단계 줄이고 간격을 좁힌다.
              final compact = box.maxHeight / scaler.scale(1) < 660;
              final gap = compact ? Gap.s : Gap.l;
              final hint = classMode ? '옆으로 밀면 다음 반 · 아래로 밀면 별님 고르기' : '링을 돌리면 0.1℃씩 · 옆으로 밀면 다음 별님';
              return Padding(
                padding: const EdgeInsets.fromLTRB(Gap.page, 6, Gap.page, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ① 반 고르기 + 기록 수
                    Row(
                      children: [
                        _ClassPill(cls: cls, classMode: classMode),
                        const SizedBox(width: Gap.s),
                        Expanded(
                          child: Text(
                            '${residents.length}명 중 $doneCount명${compact ? '' : ' 기록'}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: brandDark),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap),
                    // ② 얼굴 줄
                    _ResidentRow(state: st, list: residents, done: done, face: compact ? 44 : 50),
                    SizedBox(height: compact ? Gap.xs : Gap.l),
                    // ③ 지금 차례: (할 일) · 이름 · 체온 · 평소 체온
                    Semantics(
                      label: '${cls.name} ${idx + 1}번째, ${r.name} ${formatTemp(st.value)}도 ${saved ? '기록 완료' : '입력 중'}',
                      child: ExcludeSemantics(
                        child: _Current(
                          resident: r,
                          value: st.value,
                          saved: saved,
                          compact: compact,
                          task: _taskText(repo, r.id),
                          baseline: repo.baselineOf(r.id, now).value,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? Gap.xs : Gap.s),
                    // ④ [−] 다이얼 [+] → 안내 한 줄. 다이얼은 남은 높이만큼만 (작은 화면에서 가장 먼저 줄어든다)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, area) {
                          final btn = compact ? 52.0 : 60.0;
                          final side = compact ? Gap.s : Gap.l;
                          final hintGap = compact ? Gap.xs : Gap.m;
                          final hintH = scaler.scale(T.caption) * 1.35 * 2 + hintGap;
                          final byW = area.maxWidth - (btn + side) * 2;
                          final dial = math.max(0.0, math.min(220.0, math.min(byW, area.maxHeight - hintH)));
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _RoundBtn(plus: false, size: btn, onTap: () => ctrl.nudge(-1)),
                                  SizedBox(width: side),
                                  _Dial(
                                    value: st.value,
                                    saved: saved,
                                    enabled: canMeasure,
                                    diameter: dial,
                                    onNudge: (d) {
                                      if (ref.read(quickTempProvider).mode == QtMode.classSelect) {
                                        ctrl.setMode(QtMode.resident);
                                      }
                                      ctrl.nudge(d);
                                    },
                                    onHoldComplete: _save,
                                  ),
                                  SizedBox(width: side),
                                  _RoundBtn(plus: true, size: btn, onTap: () => ctrl.nudge(1)),
                                ],
                              ),
                              SizedBox(height: hintGap),
                              // ⑤ 안내 한 줄 (쓸기 안내 카드·손 그림 대신)
                              Text(
                                hint,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(fontSize: T.caption, color: inkSub, height: 1.35),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // 하단 가운데 [닫기] 동그라미가 위로 솟아 있어 그만큼 비워 둔다.
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 오늘 잰 별님 = 이번에 기록했거나, 오늘 잰 값이 있고 남은 체온 할 일·이상 대응이 없는 별님.
  bool _isDone(InMemoryRepository repo, QuickTempState st, String id, DateTime now) {
    if (st.saved.containsKey(id)) return true;
    final m = repo.latestOf(id);
    if (m == null) return false;
    final t = m.measuredAt;
    if (t.year != now.year || t.month != now.month || t.day != now.day) return false;
    return repo.openTempTasksOf(id).isEmpty && repo.openCaseOf(id) == null;
  }

  /// 열린 체온 할 일: "할 일 · 09:15 37.6℃ 다시 재기" / "할 일 · 점심 전 오전 체온".
  String? _taskText(InMemoryRepository repo, String residentId) {
    final tasks = repo.openTempTasksOf(residentId);
    if (tasks.isEmpty) return null;
    final e = tasks.first;
    final mid = e.measurementId;
    if (mid != null) {
      try {
        final m = repo.measurement(mid);
        return '할 일 · ${hhmm(m.measuredAt)} ${formatTemp(m.value)}℃ 다시 재기';
      } catch (_) {}
    }
    final when = e.task!.duePreset ?? (e.task!.dueAt == null ? null : '${hhmm(e.task!.dueAt!)}까지');
    return '할 일 · ${[?when, e.task!.label].join(' ')}';
  }
}

// ── [● 은하수자리 ▾]: 누르면 반 목록. 권한 없는 반은 흐리게 + '권한 없음'.
class _ClassPill extends ConsumerWidget {
  const _ClassPill({required this.cls, required this.classMode});
  final Class cls;
  final bool classMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final ctrl = ref.read(quickTempProvider.notifier);
    return Semantics(
      button: true,
      label: '반 고르기, 지금 ${cls.name}',
      excludeSemantics: true,
      child: PopupMenuButton<String>(
        tooltip: '반 바꾸기',
        initialValue: cls.id,
        position: PopupMenuPosition.under,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
        onSelected: (id) => ctrl.selectClass(id, keepMode: classMode),
        itemBuilder: (_) => [
          for (final c in repo.classes)
            PopupMenuItem<String>(
              value: c.id,
              enabled: ctrl.canMeasure(c.id),
              height: tapHeight,
              child: Opacity(
                opacity: ctrl.canMeasure(c.id) ? 1 : 0.5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dot(Color(c.color)),
                    const SizedBox(width: 8),
                    Text(
                      c.name,
                      style: TextStyle(
                        fontSize: T.body,
                        fontWeight: c.id == cls.id ? FontWeight.w700 : FontWeight.w400,
                        color: inkMain,
                      ),
                    ),
                    if (!ctrl.canMeasure(c.id)) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.lock_outline, size: 16, color: inkSub),
                      const Text(
                        ' 권한 없음',
                        style: TextStyle(fontSize: T.caption, color: inkSub),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            // 위로 쓸어 '반 바꾸기' 중이면 초록 테두리
            border: Border.all(color: classMode ? brandDark : lineStrong, width: classMode ? 2 : 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(Color(cls.color)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  cls.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: inkSub),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ── 얼굴 줄: 잰 별님은 흐리게(55%) + 초록 ✓, 지금 별님은 초록 테두리.
class _ResidentRow extends ConsumerWidget {
  const _ResidentRow({required this.state, required this.list, required this.done, required this.face});
  final QuickTempState state;
  final List<Resident> list;
  final Map<String, bool> done;
  final double face;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameH = MediaQuery.textScalerOf(context).scale(T.caption) * 1.4;
    final faceBox = face + 6; // 시안: 50 얼굴 + 선택 테두리 자리
    return LayoutBuilder(
      builder: (context, box) {
        final itemW = math.max(faceBox, box.maxWidth / list.length);
        return SizedBox(
          height: faceBox + 6 + nameH,
          child: ListView(
            scrollDirection: Axis.horizontal,
            itemExtent: itemW,
            padding: EdgeInsets.zero,
            children: [for (final r in list) _item(ref, r)],
          ),
        );
      },
    );
  }

  Widget _item(WidgetRef ref, Resident r) {
    final selected = r.id == state.residentId;
    final isDone = done[r.id] ?? false;
    final ring = state.mode == QtMode.resident ? brandDark : inkSub;
    // 선택: 3 테두리 + 3 틈 안에 얼굴 (시안 56 상자). 잰 별님: 55% 흐리게 + ✓.
    Widget avatar = selected
        ? Container(
            width: face + 6,
            height: face + 6,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 3),
            ),
            child: FaceAvatar.resident(r.id, size: face - 6),
          )
        : Opacity(
            opacity: isDone ? 0.55 : 1,
            child: FaceAvatar.resident(r.id, size: face),
          );
    if (isDone) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _doneGreen,
                shape: BoxShape.circle,
                border: Border.all(color: paper, width: 2),
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: '${r.name}${isDone ? ', 기록함' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => ref.read(quickTempProvider.notifier).selectResident(r.id),
        borderRadius: BorderRadius.circular(Radii.button),
        child: Column(
          children: [
            SizedBox(
              width: face + 6,
              height: face + 6,
              child: Center(child: avatar),
            ),
            const SizedBox(height: 6),
            Text(
              r.name.substring(1),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: T.caption,
                height: 1.3,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? brandDark : (isDone ? inkSub : inkMain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 지금 차례: 할 일 알약 → 이름(40) → 체온(96) → 평소 체온 / ✓ 기록 완료.
class _Current extends StatelessWidget {
  const _Current({
    required this.resident,
    required this.value,
    required this.saved,
    required this.compact,
    required this.task,
    required this.baseline,
  });
  final Resident resident;
  final int value;
  final bool saved, compact;
  final String? task;
  final int baseline;

  @override
  Widget build(BuildContext context) {
    final caution = stageColors[Stage.caution]!;
    final nameSize = compact ? 34.0 : 40.0;
    final tempSize = compact ? 60.0 : T.display;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task != null && !saved) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: caution.soft, borderRadius: BorderRadius.circular(Radii.pill)),
            child: Text(
              task!,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: caution.ink),
            ),
          ),
          const SizedBox(height: 6),
        ],
        FittedBox(
          fit: BoxFit.scaleDown,
          // 작은 화면: 이름과 체온을 한 줄에 나란히 (높이를 다이얼에 양보)
          child: Flex(
            direction: compact ? Axis.horizontal : Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: compact ? Gap.l : 0,
            children: [
              Text(
                resident.name,
                style: TextStyle(
                  fontFamily: fontBig,
                  fontSize: nameSize,
                  fontWeight: FontWeight.w800,
                  color: inkMain,
                  height: 1.25,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTemp(value),
                    style: TextStyle(
                      fontFamily: fontBig,
                      fontSize: tempSize,
                      fontWeight: FontWeight.w800,
                      color: inkMain,
                      height: 1,
                      letterSpacing: -2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: EdgeInsets.only(top: compact ? 6 : 10),
                    child: Text(
                      '℃',
                      style: TextStyle(
                        fontFamily: fontBig,
                        fontSize: compact ? 20 : 26,
                        fontWeight: FontWeight.w700,
                        color: inkMain,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (saved)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFDFF0E0), borderRadius: BorderRadius.circular(Radii.pill)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 18, color: Color(0xFF2F6A2A)),
                SizedBox(width: 4),
                Text(
                  '기록 완료',
                  style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: Color(0xFF2F6A2A)),
                ),
              ],
            ),
          )
        else
          Text(
            '이 별님 평소 체온 ${formatTemp(baseline)}℃',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: inkSub),
          ),
      ],
    );
  }
}

/// 링 다이얼: 링을 돌리면 6°당 0.1℃, 가운데 초록 원을 0.5초 꾹 누르면 기록 (퀵 체온 명세 6·7장).
class _Dial extends StatefulWidget {
  const _Dial({
    required this.value,
    required this.saved,
    required this.enabled,
    required this.diameter,
    required this.onNudge,
    required this.onHoldComplete,
  });
  final int value;
  final bool saved, enabled;
  final double diameter;
  final ValueChanged<int> onNudge;
  final VoidCallback onHoldComplete;

  @override
  State<_Dial> createState() => _DialState();
}

class _DialState extends State<_Dial> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _holding = false;
        widget.onHoldComplete();
        _hold.reset();
      }
    });
  Offset? _down;
  bool _holding = false;
  bool _rotating = false;
  double _lastAngle = 0;
  double _accum = 0; // 아직 0.1℃가 안 된 회전 각도
  double _rotation = 0; // 눈금 회전 (도)

  double get _k => widget.diameter / 220;
  double get _innerR => 84 * _k;
  Offset get _center => Offset(widget.diameter / 2, widget.diameter / 2);
  double _angle(Offset p) => math.atan2(p.dy - _center.dy, p.dx - _center.dx) * 180 / math.pi;

  void _cancelHold() {
    _holding = false;
    _hold.reset();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diameter;
    final title = !widget.enabled ? '측정 권한 없음' : (widget.saved ? '기록했어요' : '꾹 눌러 기록');
    final sub = !widget.enabled ? '다른 반이에요' : (widget.saved ? '옆으로 밀면 다음 별님' : '0.5초');
    final fg = widget.enabled ? Colors.white : inkMain;
    return Semantics(
      label: '체온 다이얼. 돌려서 조절하고 0.5초 눌러 기록',
      value: '${formatTemp(widget.value)}도',
      increasedValue: '${formatTemp(widget.value + 1)}도',
      decreasedValue: '${formatTemp(widget.value - 1)}도',
      onIncrease: () => widget.onNudge(1),
      onDecrease: () => widget.onNudge(-1),
      child: Listener(
        onPointerDown: (e) {
          _down = e.localPosition;
          _rotating = false;
          _lastAngle = _angle(e.localPosition);
          _accum = 0;
          // 꾹 누르기는 가운데 초록 원에서만 (링은 돌리기만)
          if (widget.enabled && (e.localPosition - _center).distance <= _innerR) {
            _holding = true;
            _hold.forward(from: 0);
          }
        },
        onPointerMove: (e) {
          if (_down == null) return;
          if (!_rotating && (e.localPosition - _down!).distance >= 8) {
            _rotating = true;
            _cancelHold(); // 8px 넘게 움직이면 누름 취소
          }
          if (!_rotating) return;
          final a = _angle(e.localPosition);
          var delta = a - _lastAngle;
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          _lastAngle = a;
          _accum += delta;
          setState(() => _rotation += delta);
          final steps = (_accum / 6).truncate();
          if (steps != 0) {
            _accum -= steps * 6;
            widget.onNudge(steps);
            HapticFeedback.selectionClick();
          }
        },
        onPointerUp: (_) {
          _down = null;
          if (_holding) _cancelHold(); // 0.5초 전에 손 떼면 저장 안 함
        },
        onPointerCancel: (_) {
          _down = null;
          _cancelHold();
        },
        // 다이얼 위 드래그가 바깥 쓸기로 잡히지 않게 막는다.
        child: GestureDetector(
          onPanStart: (_) {},
          onPanUpdate: (_) {},
          child: SizedBox(
            width: d,
            height: d,
            child: AnimatedBuilder(
              animation: _hold,
              builder: (context, _) => CustomPaint(
                painter: _DialPainter(
                  rotation: _rotation,
                  progress: _hold.value,
                  enabled: widget.enabled,
                  saved: widget.saved,
                ),
                child: Center(
                  child: SizedBox(
                    width: _innerR * 1.6,
                    height: _innerR * 1.4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.saved && widget.enabled) Icon(Icons.check, color: fg, size: 26),
                          Text(
                            title,
                            style: TextStyle(fontFamily: fontBig, fontSize: 24, fontWeight: FontWeight.w800, color: fg),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sub,
                            style: TextStyle(fontSize: T.caption, color: fg.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.rotation, required this.progress, required this.enabled, required this.saved});
  final double rotation, progress;
  final bool enabled, saved;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    if (r <= 0) return;
    final k = size.width / 220;
    final band = 16 * k;

    // 눈금 60개 (6°마다 1.2° 폭, 링을 돌리면 함께 돈다)
    final tick = Paint()..color = _tick;
    for (var i = 0; i < 60; i++) {
      final a0 = (i * 6 + rotation - 90) * math.pi / 180;
      final a1 = a0 + 1.2 * math.pi / 180;
      final path = Path()
        ..moveTo(c.dx + math.cos(a0) * (r - band), c.dy + math.sin(a0) * (r - band))
        ..lineTo(c.dx + math.cos(a0) * r, c.dy + math.sin(a0) * r)
        ..lineTo(c.dx + math.cos(a1) * r, c.dy + math.sin(a1) * r)
        ..lineTo(c.dx + math.cos(a1) * (r - band), c.dy + math.sin(a1) * (r - band))
        ..close();
      canvas.drawPath(path, tick);
    }

    // 0.5초 누르는 동안 링을 따라 차오르는 초록 띠
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - band / 2),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = brandDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = band * 0.7
          ..strokeCap = StrokeCap.round,
      );
    }

    // 맨 위 초록 표시 (8×22)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - 4 * k, -2 * k, 8 * k, 22 * k), Radius.circular(4 * k)),
      Paint()..color = brandDark,
    );

    // 가운데 168 초록 원 (그림자 0 10 24 rgba(61,117,53,.35))
    final inner = 84 * k;
    final fill = !enabled ? const Color(0xFFE6D9D3) : (saved ? stageColors[Stage.normal]!.ink : brandDark);
    if (enabled) {
      canvas.drawCircle(
        c + Offset(0, 10 * k),
        inner,
        Paint()
          ..color = brandDark.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * k),
      );
    }
    canvas.drawCircle(c, inner, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.rotation != rotation || old.progress != progress || old.saved != saved || old.enabled != enabled;
}

/// − / + 동그란 버튼 (시안 60, 흰 바탕 + 테두리).
class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.plus, required this.size, required this.onTap});
  final bool plus;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: plus ? '0.1도 올리기' : '0.1도 내리기',
    excludeSemantics: true,
    child: SizedBox(
      width: size,
      height: size,
      child: Material(
        color: surface,
        shape: const CircleBorder(side: BorderSide(color: lineStrong, width: 1.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          // 글꼴마다 '−' 기호가 없을 수 있어 아이콘으로 그린다.
          child: Icon(plus ? Icons.add : Icons.remove, size: 30, color: inkMain),
        ),
      ),
    ),
  );
}
