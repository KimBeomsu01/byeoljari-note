// 퀵 체온 (QT). 퀵 체온 명세 3~8장 + 통합 명세 6-1.
// 화면 기준: docs/design.md — 40~60대 선생님이 한 손으로, 돋보기 없이 본다.
// 위에서부터: 반 고르기 → 별님 고르기 → 이름·체온(크게) → 다이얼(± 옆) → 쓸기 안내.
// 작은 폰에서는 글자가 아니라 다이얼을 먼저 줄인다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../alert_case/alert_sheet.dart';
import 'quick_temp_controller.dart';

const double _swipeThreshold = 48;

/// "기록 완료" 표시의 진한 초록 (흰 글자 대비 충분). 판정 '평소' 글자색과 같은 계열.
final Color _doneGreen = stageColors[Stage.normal]!.ink;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('! ${plainDiff(result.measurement.judgment.diff)}\n30분 뒤 다시 재 주세요'),
      ));
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _swipe = Offset.zero,
      onPanUpdate: (d) => _swipe += d.delta,
      onPanEnd: (_) => _onSwipeEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        // 기록 완료면 화면 전체가 초록으로 바뀐다 (한눈에 알 수 있게).
        color: saved ? recordedGreen : Color.alphaBlend(Color(cls.color).withValues(alpha: 0.14), paper),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(builder: (context, box) {
            // 작은 화면: 이름과 체온을 한 줄에, 간격을 줄인다. 글자 크기는 그대로.
            final compact = box.maxHeight < 700;
            final gap = compact ? Gap.xs : Gap.m;
            return Column(
              children: [
                SizedBox(height: compact ? Gap.xs : Gap.s),
                _ClassTabs(state: st),
                SizedBox(height: gap),
                _ResidentRow(state: st),
                Text('${cls.name} · ${idx + 1} / ${residents.length}',
                    style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
                SizedBox(height: compact ? 0 : Gap.xs),
                Semantics(
                  label: '${r.name} ${formatTemp(st.value)}도 ${saved ? '기록 완료' : '입력 중'}',
                  child: ExcludeSemantics(child: _NameAndTemp(name: r.name, value: st.value, compact: compact)),
                ),
                SizedBox(height: compact ? Gap.xs : Gap.s),
                _StatusLine(saved: saved),
                SizedBox(height: gap),
                // 다이얼은 남은 높이만큼만 (작은 화면에서 가장 먼저 줄어든다).
                Expanded(
                  child: LayoutBuilder(builder: (context, area) {
                    const btn = 60.0;
                    final maxByWidth = area.maxWidth - Gap.page * 2 - btn * 2 - Gap.m * 2;
                    final dial = math.max(0.0, math.min(math.min(area.maxHeight, maxByWidth), 260.0));
                    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _RoundBtn(label: '−', semantic: '0.1도 내리기', onTap: () => ctrl.nudge(-1)),
                      const SizedBox(width: Gap.m),
                      _Dial(
                        value: st.value,
                        saved: saved,
                        enabled: canMeasure,
                        diameter: dial,
                        onNudge: (d) {
                          if (ref.read(quickTempProvider).mode == QtMode.classSelect) ctrl.setMode(QtMode.resident);
                          ctrl.nudge(d);
                        },
                        onHoldComplete: _save,
                      ),
                      const SizedBox(width: Gap.m),
                      _RoundBtn(label: '+', semantic: '0.1도 올리기', onTap: () => ctrl.nudge(1)),
                    ]);
                  }),
                ),
                const SizedBox(height: Gap.xs),
                const Text('돌려서 0.1도씩', style: TextStyle(fontSize: T.body, color: inkSub, fontWeight: FontWeight.w600)),
                SizedBox(height: gap),
                _GestureGuide(
                  mode: st.mode,
                  onUp: () => ctrl.setMode(QtMode.classSelect),
                  onDown: () => ctrl.setMode(QtMode.resident),
                ),
                SizedBox(height: compact ? Gap.s : Gap.l),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ── 반 고르기: 높이 52 칩. 잠긴 반은 자물쇠 + '잠김' 글자.
class _ClassTabs extends ConsumerWidget {
  const _ClassTabs({required this.state});
  final QuickTempState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final ctrl = ref.read(quickTempProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      // 잴 수 있는 반을 앞에, 잠긴 반은 뒤에 둔다 (내 반이 첫 화면에 보이게).
      child: Row(children: [
        for (final c in [
          ...repo.classes.where((c) => ctrl.canMeasure(c.id)),
          ...repo.classes.where((c) => !ctrl.canMeasure(c.id)),
        ])
          Padding(
            padding: const EdgeInsets.only(right: Gap.s),
            child: _ClassTab(
              cls: c,
              selected: c.id == state.classId,
              ring: c.id == state.classId && state.mode == QtMode.classSelect,
              locked: !ctrl.canMeasure(c.id),
              onTap: () => ctrl.selectClass(c.id, keepMode: state.mode == QtMode.classSelect),
            ),
          ),
      ]),
    );
  }
}

class _ClassTab extends StatelessWidget {
  const _ClassTab({required this.cls, required this.selected, required this.ring, required this.locked, required this.onTap});
  final Class cls;
  final bool selected, ring, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : (locked ? inkSub : inkMain);
    return Semantics(
      button: true,
      enabled: !locked,
      selected: selected,
      label: '${cls.name}${locked ? ', 측정 권한 없음' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? brandDark : (locked ? paper : surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
          // 반 고르기 중이면 선택된 칩에 굵은 테두리 (위아래로 쓸어 바꾸는 상태)
          side: BorderSide(
            color: ring ? inkMain : (selected ? brandDark : line),
            width: ring ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: locked ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: Gap.l),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(cls.color),
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? Colors.white : inkSub, width: 1.5),
                ),
              ),
              const SizedBox(width: Gap.s),
              Text(cls.name, style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: fg)),
              if (locked) ...[
                const SizedBox(width: Gap.s),
                Icon(Icons.lock, size: 18, color: fg),
                const SizedBox(width: 2),
                Text('잠김', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: fg)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ── 별님 고르기: 동그라미 52 + 이름. 고른 별님은 굵은 남색 테두리, 잰 별님은 ✓.
class _ResidentRow extends ConsumerWidget {
  const _ResidentRow({required this.state});
  final QuickTempState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final cls = repo.classOf(state.classId);
    final list = repo.residentsOf(state.classId);
    final nameH = MediaQuery.textScalerOf(context).scale(T.caption) * 1.45;
    return SizedBox(
      height: 52 + 8 + 2 + nameH + 4,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.page - 4),
        children: [
          for (final r in list) _residentItem(ref, r, cls, list),
        ],
      ),
    );
  }

  Widget _residentItem(WidgetRef ref, Resident r, Class cls, List<Resident> list) {
    final selected = r.id == state.residentId;
    final done = state.saved.containsKey(r.id);
    return Semantics(
      button: true,
      selected: selected,
      label: '${r.name}${done ? ', 기록함' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => ref.read(quickTempProvider.notifier).selectResident(r.id),
        borderRadius: BorderRadius.circular(Radii.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? (state.mode == QtMode.resident ? brandDark : inkSub) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ResidentAvatar(name: r.name, classColor: cls.color, size: 52),
              ),
              if (done)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _doneGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
            ]),
            const SizedBox(height: 2),
            Text(
              r.name.substring(1),
              style: TextStyle(
                fontSize: T.caption,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? brandDark : inkMain,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 이름과 체온: 같은 크기로 크게 (퀵 체온 명세). 작은 화면에서는 한 줄에 나란히.
class _NameAndTemp extends StatelessWidget {
  const _NameAndTemp({required this.name, required this.value, required this.compact});
  final String name;
  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 44.0;
    final nameText = Text(name, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1.15, color: inkMain));
    final temp = _DigitalTemp(value: value, size: size);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: compact
            ? Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
                nameText,
                const SizedBox(width: Gap.l),
                temp,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [nameText, temp]),
      ),
    );
  }
}

class _DigitalTemp extends StatelessWidget {
  const _DigitalTemp({required this.value, this.size = 44});
  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        formatTemp(value),
        style: TextStyle(
          fontSize: size,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: inkMain,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4, left: 2),
        child: Text('℃', style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w700, color: inkSub)),
      ),
    ]);
  }
}

// ── 지금 상태 한 줄: 입력 중(조용히) / 기록 완료(진한 초록 띠 + ✓).
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.saved});
  final bool saved;

  @override
  Widget build(BuildContext context) {
    if (!saved) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('체온을 입력해 주세요',
            textAlign: TextAlign.center, style: TextStyle(fontSize: T.body, color: inkSub, fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 6),
      decoration: BoxDecoration(color: _doneGreen, borderRadius: BorderRadius.circular(Radii.pill)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, color: Colors.white, size: 24),
        SizedBox(width: 6),
        Text('체온 기록 완료', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    );
  }
}

/// 원형 다이얼: 돌리면 6°당 0.1℃, 가만히 0.5초 누르면 기록 (퀵 체온 명세 6·7장).
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
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
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
    final title = !widget.enabled ? '측정 권한 없음' : (widget.saved ? '기록 완료' : '눌러서 기록');
    final sub = !widget.enabled ? '다른 반이에요' : (widget.saved ? '다음 별님으로' : '0.5초 꾹');
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
          if (widget.enabled) {
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
                painter: _DialPainter(rotation: _rotation, progress: _hold.value, saved: widget.saved),
                child: Center(
                  // 아주 작은 화면에서만 안쪽 글씨를 다이얼에 맞춘다.
                  child: SizedBox(
                    width: d * 0.62,
                    height: d * 0.62,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(widget.saved ? Icons.check_circle : Icons.touch_app,
                            color: widget.saved ? _doneGreen : brandDark, size: 32),
                        Text(title,
                            style: TextStyle(
                                fontSize: T.body,
                                fontWeight: FontWeight.w800,
                                color: widget.saved ? _doneGreen : inkMain)),
                        Text(sub, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub)),
                      ]),
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
  _DialPainter({required this.rotation, required this.progress, required this.saved});
  final double rotation, progress;
  final bool saved;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    if (r <= 0) return;
    canvas.drawCircle(c, r, Paint()..color = surface);
    canvas.drawCircle(
        c,
        r - 1,
        Paint()
          ..color = saved ? _doneGreen : line
          ..style = PaintingStyle.stroke
          ..strokeWidth = saved ? 3 : 2);
    canvas.drawCircle(c, r * 0.62, Paint()..color = saved ? recordedGreen : paper);

    final tick = Paint()..color = inkSub;
    for (var i = 0; i < 60; i++) {
      final a = (i * 6 + rotation - 90) * math.pi / 180;
      final major = i % 5 == 0;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r - 8);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r - (major ? 20 : 14));
      canvas.drawLine(p1, p2, tick..strokeWidth = major ? 2.4 : 1.2);
    }
    final dotA = (rotation - 90) * math.pi / 180;
    canvas.drawCircle(c + Offset(math.cos(dotA), math.sin(dotA)) * (r - 14), 6, Paint()..color = brandDark);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 4),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = brandDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.rotation != rotation || old.progress != progress || old.saved != saved;
}

/// − / + 버튼 60×60.
class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.label, required this.semantic, required this.onTap});
  final String label, semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantic,
        excludeSemantics: true,
        child: SizedBox(
          width: 60,
          height: 60,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size(60, 60),
              backgroundColor: surface,
              side: const BorderSide(color: brandDark, width: 2),
            ),
            // 글꼴마다 '−' 기호가 없을 수 있어 아이콘으로 그린다.
            child: Icon(label == '+' ? Icons.add : Icons.remove, size: 34, color: brandDark),
          ),
        ),
      );
}

// ── 쓸기 안내: 지금 좌우로 쓸면 무엇이 바뀌는지 한 줄 + 위/아래 버튼 2개 (높이 56).
class _GestureGuide extends StatelessWidget {
  const _GestureGuide({required this.mode, required this.onUp, required this.onDown});
  final QtMode mode;
  final VoidCallback onUp, onDown;

  @override
  Widget build(BuildContext context) {
    final residentMode = mode == QtMode.resident;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(children: [
        Text(
          residentMode ? '좌우로 쓸면 다음 별님' : '좌우로 쓸면 다음 반',
          style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain),
        ),
        const SizedBox(height: Gap.xs),
        Row(children: [
          Expanded(child: _GuideBtn(icon: Icons.swipe_up, text: '반 바꾸기', on: !residentMode, onTap: onUp)),
          const SizedBox(width: Gap.s),
          Expanded(child: _GuideBtn(icon: Icons.swipe_down, text: '별님 고르기', on: residentMode, onTap: onDown)),
        ]),
      ]),
    );
  }
}

class _GuideBtn extends StatelessWidget {
  const _GuideBtn({required this.icon, required this.text, required this.on, required this.onTap});
  final IconData icon;
  final String text;

  /// 지금 이 모드인가 (남색으로 채움).
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? brandDark : surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
            side: BorderSide(color: on ? brandDark : line, width: 1.5),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.button),
            child: Container(
              constraints: const BoxConstraints(minHeight: tapHeight),
              padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.xs),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 24, color: on ? Colors.white : brandDark),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(text,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: on ? Colors.white : inkMain)),
                ),
              ]),
            ),
          ),
        ),
      );
}
