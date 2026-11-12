// 퀵 체온 (QT). 퀵 체온 명세 3~8장 + 통합 명세 6-1.
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
import '../alert_case/alert_sheet.dart';
import 'quick_temp_controller.dart';

const double _swipeThreshold = 48;

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
        content: Text('평소보다 조금 높아요 (${formatDiff(result.measurement.judgment.diff)}). 30분 뒤 다시 재 주세요'),
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _swipe = Offset.zero,
      onPanUpdate: (d) => _swipe += d.delta,
      onPanEnd: (_) => _onSwipeEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: saved
                ? [recordedGreen, const Color(0xFFE3F1E1)]
                : [Color.alphaBlend(Color(cls.color).withValues(alpha: 0.22), paper), paper],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(builder: (context, box) {
            final compact = box.maxHeight < 720;
            // 작은 화면에서는 다이얼을 줄인다 (퀵 체온 명세: 작은 화면·safe area 지원)
            final dialSize = (box.maxHeight * 0.27).clamp(140.0, 210.0);
            return Column(
              children: [
                const SizedBox(height: 8),
                _ClassTabs(state: st),
                SizedBox(height: compact ? 4 : 10),
                _ResidentRow(state: st),
                SizedBox(height: compact ? 2 : 10),
                Text('${cls.name} · ${idx + 1} / ${residents.length}',
                    style: const TextStyle(fontSize: 13, color: inkSub)),
                Semantics(
                  label: '${r.name} ${formatTemp(st.value)}도 ${saved ? '기록 완료' : '입력 중'}',
                  child: Column(children: [
                    Text(r.name, style: TextStyle(fontSize: compact ? 32 : 40, fontWeight: FontWeight.w500, height: 1.15)),
                    _DigitalTemp(value: st.value, size: compact ? 38 : 46),
                  ]),
                ),
                Text(saved ? '체온 기록 완료' : '체온을 입력해 주세요',
                    style: TextStyle(fontSize: 13, color: saved ? brandDark : inkSub)),
                const Spacer(),
                _Dial(
                  value: st.value,
                  saved: saved,
                  enabled: ctrl.canMeasure(st.classId),
                  diameter: dialSize,
                  onNudge: (d) {
                    if (ref.read(quickTempProvider).mode == QtMode.classSelect) ctrl.setMode(QtMode.resident);
                    ctrl.nudge(d);
                  },
                  onHoldComplete: _save,
                ),
                SizedBox(height: compact ? 4 : 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _RoundBtn(label: '−', semantic: '0.1도 내리기', onTap: () => ctrl.nudge(-1)),
                  const SizedBox(width: 16),
                  const Text('돌려서 조절 · 0.1℃', style: TextStyle(fontSize: 13, color: inkSub)),
                  const SizedBox(width: 16),
                  _RoundBtn(label: '+', semantic: '0.1도 올리기', onTap: () => ctrl.nudge(1)),
                ]),
                SizedBox(
                  height: 22,
                  child: saved
                      ? Text('${r.name} · ${formatTemp(st.value)}℃ 기록 완료',
                          style: const TextStyle(fontSize: 13, color: brandDark, fontWeight: FontWeight.w600))
                      : null,
                ),
                const Spacer(),
                _GestureGuide(compact: compact, mode: st.mode, onUp: () => ctrl.setMode(QtMode.classSelect), onDown: () => ctrl.setMode(QtMode.resident)),
                SizedBox(height: compact ? 8 : 12),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ClassTabs extends ConsumerWidget {
  const _ClassTabs({required this.state});
  final QuickTempState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final ctrl = ref.read(quickTempProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          for (final c in repo.classes)
            _ClassTab(
              cls: c,
              selected: c.id == state.classId,
              ring: c.id == state.classId && state.mode == QtMode.classSelect,
              locked: !ctrl.canMeasure(c.id),
              onTap: () => ctrl.selectClass(c.id, keepMode: state.mode == QtMode.classSelect),
            ),
        ]),
      ),
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
    return Semantics(
      button: true,
      enabled: !locked,
      label: '${cls.name}${locked ? ', 측정 권한 없음' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: locked ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ring ? brandDark : Colors.transparent, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(cls.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: locked ? inkSub.withValues(alpha: 0.6) : inkMain,
                )),
            if (locked) const Padding(padding: EdgeInsets.only(left: 3), child: Icon(Icons.lock, size: 12, color: inkSub)),
          ]),
        ),
      ),
    );
  }
}

class _ResidentRow extends ConsumerWidget {
  const _ResidentRow({required this.state});
  final QuickTempState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final cls = repo.classOf(state.classId);
    final list = repo.residentsOf(state.classId);
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final r in list)
            Semantics(
              button: true,
              selected: r.id == state.residentId,
              label: r.name,
              child: InkWell(
                onTap: () => ref.read(quickTempProvider.notifier).selectResident(r.id),
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: r.id == state.residentId && state.mode == QtMode.resident ? brandDark : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(cls.color).withValues(alpha: 0.35),
                        child: Text(r.name.substring(1, 2), style: const TextStyle(fontSize: 14, color: inkMain)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.name.substring(1)}${state.saved.containsKey(r.id) ? ' ✓' : ''}',
                      style: TextStyle(fontSize: 12, fontWeight: r.id == state.residentId ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DigitalTemp extends StatelessWidget {
  const _DigitalTemp({required this.value, this.size = 46});
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
          fontWeight: FontWeight.w300,
          letterSpacing: 2,
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      const Padding(padding: EdgeInsets.only(top: 8, left: 2), child: Text('℃', style: TextStyle(fontSize: 16))),
    ]);
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
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.saved ? Icons.check : Icons.north, color: brandDark, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      !widget.enabled ? '측정 권한 없음' : (widget.saved ? '기록 완료' : '눌러서 기록'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.saved ? '다음 별님으로 넘겨 주세요' : '0.5초간 꾹 눌러 주세요',
                        style: const TextStyle(fontSize: 11, color: inkSub)),
                  ]),
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
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.9));
    canvas.drawCircle(
        c, r, Paint()..color = const Color(0x22000000)..style = PaintingStyle.stroke..strokeWidth = 1);
    canvas.drawCircle(c, r * 0.62, Paint()..color = const Color(0xFFF7F7F2));

    final tick = Paint()..color = inkSub.withValues(alpha: 0.5)..strokeWidth = 1.4;
    for (var i = 0; i < 60; i++) {
      final a = (i * 6 + rotation - 90) * math.pi / 180;
      final major = i % 5 == 0;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r - 8);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r - (major ? 20 : 14));
      canvas.drawLine(p1, p2, tick..strokeWidth = major ? 2 : 1.2);
    }
    final dotA = (rotation - 90) * math.pi / 180;
    canvas.drawCircle(c + Offset(math.cos(dotA), math.sin(dotA)) * (r - 14), 5, Paint()..color = brandDark);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 3),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = brandDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.rotation != rotation || old.progress != progress || old.saved != saved;
}

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
          width: 44,
          height: 44,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero, backgroundColor: Colors.white),
            child: Text(label, style: const TextStyle(fontSize: 20, color: inkMain)),
          ),
        ),
      );
}

class _GestureGuide extends StatelessWidget {
  const _GestureGuide({required this.compact, required this.mode, required this.onUp, required this.onDown});
  final bool compact;
  final QtMode mode;
  final VoidCallback onUp, onDown;

  @override
  Widget build(BuildContext context) {
    final residentMode = mode == QtMode.resident;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        if (!compact) ...[
          Text(residentMode ? '별님 선택 중' : '반 선택 중', style: const TextStyle(fontSize: 11, color: inkSub)),
          Text(residentMode ? '별님 바꾸기' : '반 바꾸기', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Text('화면을 좌우로 쓸어 주세요', style: TextStyle(fontSize: 11, color: inkSub)),
          const SizedBox(height: 8),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(residentMode ? '좌우로 쓸어 별님 바꾸기' : '좌우로 쓸어 반 바꾸기',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        Row(children: [
          Expanded(child: _GuideBtn(icon: Icons.swipe_up, text: '위로 쓸어\n반 바꾸기', strong: residentMode, onTap: onUp)),
          const SizedBox(width: 8),
          Expanded(child: _GuideBtn(icon: Icons.swipe_down, text: '아래로 쓸어\n별님 선택', strong: !residentMode, onTap: onDown)),
        ]),
      ]),
    );
  }
}

class _GuideBtn extends StatelessWidget {
  const _GuideBtn({required this.icon, required this.text, required this.strong, required this.onTap});
  final IconData icon;
  final String text;
  final bool strong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: strong ? const Color(0xFFE2ECDD) : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: strong ? brandDark.withValues(alpha: 0.5) : const Color(0x22000000)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: strong ? brandDark : inkSub),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 12, color: strong ? inkMain : inkSub)),
          ]),
        ),
      );
}
