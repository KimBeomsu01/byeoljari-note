// 03 체온 측정 (Claude Design QuickVital.dc.html, data-screen="quick-vital-dial").
// 탭 바 가운데 버튼으로 여는 전체 화면 레이어. 상단 바 없음 — 맨 위가 담당 반 다이얼.
// 위에서부터: ClassDial → ResidentDial → VitalDisplay (여기까지 SelectionGestureArea)
// → VitalDial(링 · −/+ · 길게 눌러 기록) → PresetChips → (주의 이상이면) AlertActionSheet.
// 아래 탭 바(가운데 X)는 app.dart가 그린다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/photo.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import '../alert_case/alert_sheet.dart';
import 'nurse_call_sheet.dart';
import 'quick_temp_controller.dart';

/// 다이얼 이동 (240ms cubic-bezier(0.2, 0.8, 0.2, 1)).
const _slide = Cubic(0.2, 0.8, 0.2, 1);
const _slideTime = Duration(milliseconds: 240);

/// 반 칸 116, 별님 칸 68 (디자인 CW · RW).
const double _classCell = 116;
const double _residentCell = 68;

/// 프리셋 칩 값 (×10).
const _presets = [365, 371, 378, 384, 390];

/// 탭 바 가운데 동그라미가 위로 솟은 만큼 비워 둔다 (디자인 main padding-bottom 96 = 탭 바 64 + 32).
const double _bottomGap = 32;

/// 다이얼을 뺀 나머지 높이 (반 56 + 별님 93.5 + 체온 표시 141.5 + 다이얼 위아래 24 + 프리셋 48).
const double _fixedHeight = 363 + 16 + 44; // + 간호쌤 호출 버튼

enum _Kind { idle, normal, high, low }

/// 평소와의 차이에 따른 색 (디자인 tones).
class _Tone {
  const _Tone(this.num, this.badgeBg, this.badgeFg, this.arc);
  final Color num, badgeBg, badgeFg, arc;

  static _Tone of(_Kind k) => switch (k) {
        _Kind.idle => const _Tone(Ds.gray300, Ds.gray100, Ds.gray600, Ds.gray300),
        _Kind.normal => const _Tone(Ds.gray900, Ds.gray100, Ds.gray700, Ds.blue500),
        _Kind.high => const _Tone(Ds.red500, Ds.red50, Ds.red500, Ds.red500),
        _Kind.low => const _Tone(Ds.blue500, Ds.blue50, Ds.blue500, Ds.blue500),
      };
}

class QuickTempScreen extends ConsumerStatefulWidget {
  const QuickTempScreen({super.key});

  @override
  ConsumerState<QuickTempScreen> createState() => _QuickTempScreenState();
}

class _QuickTempScreenState extends ConsumerState<QuickTempScreen> with SingleTickerProviderStateMixin {
  /// 가운데 버튼 0.5초 누르기.
  late final AnimationController _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _press.reset();
        setState(() => _pressing = false);
        _record();
      }
    });
  bool _pressing = false;
  bool _flash = false;

  final _scroll = ScrollController();
  final _sheetKey = GlobalKey();

  String _toast = '';
  int _toastSeq = 0;
  Timer? _toastTimer;
  Timer? _flashTimer;

  // SelectionGestureArea: 누른 곳 · 좌우 누적 · 위아래 누적
  QtZone _zone = QtZone.screen;
  double _hAcc = 0;
  double _vAcc = 0;
  bool _vDone = false;

  // VitalDial: 링 돌리기
  Offset? _dDown;
  bool _rotating = false;
  double _lastAngle = 0;
  double _angleAcc = 0;

  QuickTempController get _ctrl => ref.read(quickTempProvider.notifier);

  @override
  void dispose() {
    _press.dispose();
    _scroll.dispose();
    _toastTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() {
      _toast = text;
      _toastSeq++;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = '');
    });
  }

  /// 지금 기록할 수 없으면 그 이유 (null = 기록 가능).
  String? _blockReason(QtView v) {
    if (v.cls == null) return '측정할 수 있는 반이 없어요';
    if (!v.canMeasure) return '${v.cls!.name} 체온 측정 권한이 없어요';
    if (v.residents.isEmpty) return '이 반에 별님이 없어요';
    if (v.selected == null) return '별님을 먼저 선택해 주세요.';
    return null;
  }

  // ── 길게 눌러 기록
  void _startPress() {
    final reason = _blockReason(_ctrl.view());
    if (reason != null) {
      _showToast(reason);
      return;
    }
    setState(() => _pressing = true);
    _press.forward(from: 0);
  }

  void _cancelPress() {
    if (!_pressing && !_press.isAnimating) return;
    _press.reset();
    setState(() => _pressing = false);
  }

  void _record() {
    final SaveResult? res;
    try {
      res = _ctrl.record();
    } catch (_) {
      _showToast('저장하지 못했어요. 다시 눌러 주세요');
      return;
    }
    if (res == null) return;
    HapticFeedback.mediumImpact();
    _flashTimer?.cancel();
    setState(() => _flash = true);
    _flashTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _flash = false);
    });
    _showToast('체온 ${formatTemp(res.measurement.value)}° 기록이 완료되었습니다.');
    if (res.measurement.judgment.stage != Stage.normal) {
      // 다이얼 아래에 붙은 알림 시트가 다 보이게 내린다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _sheetKey.currentContext;
        if (c != null && c.mounted) {
          Scrollable.ensureVisible(c,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
        }
      });
    }
  }

  // ── SelectionGestureArea: 좌우 = 지금 단계 다이얼 한 칸, 아래 = 별님 단계, 위 = 반 단계
  void _hUpdate(DragUpdateDetails d) {
    _hAcc += d.delta.dx;
    if (_hAcc.abs() >= 44) {
      _ctrl.step(_zone, _hAcc < 0 ? 1 : -1);
      _hAcc = 0;
    }
  }

  void _vUpdate(DragUpdateDetails d) {
    _vAcc += d.delta.dy;
    if (!_vDone && _vAcc.abs() >= 32) {
      _vDone = true;
      _ctrl.setLevel(_vAcc > 0 ? QtLevel.resident : QtLevel.classes);
    }
  }

  // ── VitalDial: 링을 돌리면 9°마다 0.1° (시계 방향 = 올림), 가운데를 0.5초 누르면 기록
  void _dialDown(PointerDownEvent e, double size) {
    final c = Offset(size / 2, size / 2);
    _dDown = e.localPosition;
    _rotating = false;
    _angleAcc = 0;
    _lastAngle = math.atan2(e.localPosition.dy - c.dy, e.localPosition.dx - c.dx);
    if ((e.localPosition - c).distance <= 74 * size / 240) _startPress();
  }

  void _dialMove(PointerMoveEvent e, double size) {
    final down = _dDown;
    if (down == null) return;
    if (!_rotating) {
      if ((e.localPosition - down).distance < 8) return;
      _rotating = true;
      _cancelPress();
    }
    final c = Offset(size / 2, size / 2);
    if ((e.localPosition - c).distance < 24 * size / 240) return;
    final a = math.atan2(e.localPosition.dy - c.dy, e.localPosition.dx - c.dx);
    var da = (a - _lastAngle) * 180 / math.pi;
    if (da > 180) da -= 360;
    if (da < -180) da += 360;
    _lastAngle = a;
    _angleAcc += da;
    final steps = (_angleAcc / 9).truncate();
    if (steps != 0) {
      _angleAcc -= steps * 9;
      _ctrl.nudge(steps);
      HapticFeedback.selectionClick();
    }
  }

  void _dialUp() {
    _dDown = null;
    _cancelPress();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(quickTempProvider);
    final repo = ref.watch(repoProvider);
    ref.listen(quickTempProvider.select((s) => s.open), (prev, open) {
      if (open && _scroll.hasClients) _scroll.jumpTo(0);
    });
    final v = _ctrl.view();
    final now = repo.now();
    final sel = v.selected;
    final base = sel == null ? null : repo.baselineOf(sel.id, now).value;
    final diff = base == null ? 0 : st.value - base;
    final kind = sel == null ? _Kind.idle : (diff >= 5 ? _Kind.high : (diff <= -5 ? _Kind.low : _Kind.normal));
    final tone = _Tone.of(kind);

    // 방금 기록이 주의 이상이면 알림 시트 (값·별님을 바꾸면 컨트롤러가 지운다)
    final rec = st.recorded;
    final recNow = rec == null
        ? null
        : repo.measurementsOf(rec.measurement.residentId).where((m) => m.id == rec.measurement.id).firstOrNull;
    final showSheet = rec != null &&
        sel != null &&
        rec.measurement.residentId == sel.id &&
        recNow != null &&
        !recNow.isVoided &&
        rec.measurement.judgment.stage != Stage.normal;

    final focus = sel ?? (v.ri >= 0 ? v.residents[v.ri] : null);
    final example = (focus?.example ?? false) || (v.cls?.example ?? false);
    final bottomPad = MediaQuery.paddingOf(context).bottom + _bottomGap;

    return Semantics(
      container: true,
      label: '체온 측정',
      explicitChildNodes: true,
      child: ColoredBox(
        color: Ds.surface,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              LayoutBuilder(builder: (context, box) {
                final dial = (box.maxHeight - _fixedHeight - bottomPad).clamp(176.0, 240.0);
                return SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _selectionArea(v, st, tone, base, diff, now),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(children: [
                          _vitalDial(v, st, tone, dial),
                          const SizedBox(height: 12),
                          _presetChips(st.value),
                          const SizedBox(height: 16),
                          _nurseCallButton(sel),
                        ]),
                      ),
                      if (showSheet)
                        Padding(
                          key: _sheetKey,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _Appear(
                            child: AlertActionSheet(
                              result: rec,
                              onToast: _showToast,
                              onUndone: () => _ctrl.clearRecorded(),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              if (example) const Positioned(top: 8, right: 16, child: ExampleTag()),
              if (_toast.isNotEmpty)
                Positioned(
                  top: 16,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(child: Center(child: _Toast(key: ValueKey(_toastSeq), text: _toast))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SelectionGestureArea (ClassDial · ResidentDial · VitalDisplay)
  Widget _selectionArea(QtView v, QuickTempState st, _Tone tone, int? base, int diff, DateTime now) {
    Widget zone(QtZone z, Widget child) =>
        Listener(behavior: HitTestBehavior.opaque, onPointerDown: (_) => _zone = z, child: child);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: (_) => _hAcc = 0,
      onHorizontalDragUpdate: _hUpdate,
      onVerticalDragStart: (_) {
        _vAcc = 0;
        _vDone = false;
      },
      onVerticalDragUpdate: _vUpdate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          zone(QtZone.classes, _classDial(v, st.level)),
          zone(QtZone.resident, _residentDial(v)),
          zone(QtZone.screen, _vitalDisplay(v, st.value, tone, base, diff, now)),
        ],
      ),
    );
  }

  /// 다이얼 줄을 [left]로 옮긴다 (240ms). 폭은 바로 바뀌고 위치만 움직인다.
  Widget _slideTo({required double left, required double top, required double width, double? height, required Widget child}) =>
      TweenAnimationBuilder<double>(
        tween: Tween(end: left),
        duration: _slideTime,
        curve: _slide,
        builder: (context, x, child) => Positioned(left: x, top: top, width: width, height: height, child: child!),
        child: child,
      );

  /// ClassDial: 2개 이하면 나란히, 3개 이상이면 선택한 반이 가운데.
  Widget _classDial(QtView v, QtLevel level) {
    final n = v.classes.length;
    final classX = n <= 2 ? n * _classCell / 2 : v.ci * _classCell + _classCell / 2;
    return Semantics(
      label: '담당 반',
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: SizedBox(
          height: 40,
          child: n == 0
              ? const Center(child: Text('측정할 수 있는 반이 없어요', style: TextStyle(fontSize: T.body, color: Ds.gray500)))
              : LayoutBuilder(
                  builder: (context, c) => ClipRect(
                    child: Stack(children: [
                      _slideTo(
                        left: c.maxWidth / 2 - classX,
                        top: 0,
                        width: n * _classCell,
                        height: 40,
                        child: Row(children: [
                          for (var i = 0; i < n; i++)
                            SizedBox(
                              width: _classCell,
                              child: Center(
                                child: _ClassButton(
                                  name: v.classes[i].name,
                                  on: i == v.ci,
                                  focus: i == v.ci && level == QtLevel.classes,
                                  onTap: () => _ctrl.selectClassAt(i),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                ),
        ),
      ),
    );
  }

  /// ResidentDial: 선택한 별님이 항상 가운데. 사진 대신 이름 두 글자.
  Widget _residentDial(QtView v) {
    final n = v.residents.length;
    final residentX = math.max(0, v.ri) * _residentCell + _residentCell / 2;
    final h = (52 + 6 + MediaQuery.textScalerOf(context).scale(T.label) * 1.5).ceilToDouble();
    // 위아래 여백 8까지 잘라 그린다 (선택 테두리 4가 밖으로 나온다).
    return Semantics(
      label: '별님',
      child: SizedBox(
          height: h + 16,
          child: n == 0
              ? const Center(child: Text('이 반에 별님이 없어요', style: TextStyle(fontSize: T.body, color: Ds.gray500)))
              : LayoutBuilder(
                  builder: (context, c) => ClipRect(
                    child: Stack(children: [
                      _slideTo(
                        left: c.maxWidth / 2 - residentX,
                        top: 8,
                        width: n * _residentCell,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (var i = 0; i < n; i++)
                            _ResidentItem(
                              resident: v.residents[i],
                              on: v.selected != null && i == v.ri,
                              anySelected: v.selected != null,
                              photoUrl: ref.read(repoProvider).profilePhotoOf(v.residents[i].id)?.url,
                              onTap: () => _ctrl.selectResidentAt(i),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                ),
      ),
    );
  }

  /// VitalDisplay: 큰 체온 → 평소와 차이 | 평소 체온 → 최근 기록.
  Widget _vitalDisplay(QtView v, int value, _Tone tone, int? base, int diff, DateTime now) {
    final sel = v.selected;
    final deltaLabel = diff == 0 ? '± 0.0°' : '${diff > 0 ? '▲' : '▼'} ${(diff.abs() / 10).toStringAsFixed(1)}°';
    final latest = sel == null ? null : ref.read(repoProvider).latestOf(sel.id);
    final lastLine = sel == null
        ? ''
        : latest == null
            ? '최근 기록 없음'
            : '최근 기록 ${relTime(latest.measuredAt, now)} · ${formatTemp(latest.value)}°';
    const ms200 = Duration(milliseconds: 200);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(children: [
        Semantics(
          liveRegion: true,
          label: sel == null ? '체온 ${formatTemp(value)}도' : '${sel.name} 체온 ${formatTemp(value)}도',
          excludeSemantics: true,
          // 큰 글자 설정에서도 한 줄 (폭이 모자라면 줄여 그린다)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedDefaultTextStyle(
                  duration: ms200,
                  style: TextStyle(
                    fontFamily: fontBig,
                    fontSize: T.display,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.6,
                    color: tone.num,
                    fontFeatures: tabular,
                  ),
                  child: Text(formatTemp(value)),
                ),
                const SizedBox(width: 2),
                AnimatedDefaultTextStyle(
                  duration: ms200,
                  style: TextStyle(fontFamily: fontBig, fontSize: 36, height: 1, fontWeight: FontWeight.w700, color: tone.num),
                  child: const Text('°'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedContainer(
            duration: ms200,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: tone.badgeBg, borderRadius: BorderRadius.circular(Radii.pill)),
            child: AnimatedDefaultTextStyle(
              duration: ms200,
              style: TextStyle(fontFamily: fontSmall, fontSize: T.label, height: 1.5, fontWeight: FontWeight.w600, color: tone.badgeFg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: sel == null || base == null
                    ? const [Text('별님을 선택해 주세요')]
                    : [
                        Text(deltaLabel, style: const TextStyle(fontFeatures: tabular)),
                        const SizedBox(width: 6),
                        const Opacity(opacity: 0.6, child: Text('|', style: TextStyle(fontWeight: FontWeight.w400))),
                        const SizedBox(width: 6),
                        Text('평소 ${formatTemp(base)}°', style: const TextStyle(fontFeatures: tabular)),
                      ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(T.caption) * 1.5,
          child: Text(lastLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500, fontFeatures: tabular)),
        ),
      ]),
    );
  }

  /// VitalDial + LongPressRecordButton + −/+ (지름 [size], 디자인 240).
  Widget _vitalDial(QtView v, QuickTempState st, _Tone tone, double size) {
    final k = size / 240;
    final frac = ((st.value - 340) / 70).clamp(0.0, 1.0);
    final blocked = _blockReason(v);
    final noPermission = v.cls != null && !v.canMeasure;
    final rec = size * 148 / 240;

    final dial = Semantics(
      container: true,
      slider: true,
      label: '체온 다이얼. 링을 돌려 조절',
      value: '${formatTemp(st.value)}도',
      increasedValue: '${formatTemp(math.min(maxTemp, st.value + 1))}도',
      decreasedValue: '${formatTemp(math.max(minTemp, st.value - 1))}도',
      onIncrease: () => _ctrl.nudge(1),
      onDecrease: () => _ctrl.nudge(-1),
      child: Listener(
        onPointerDown: (e) => _dialDown(e, size),
        onPointerMove: (e) => _dialMove(e, size),
        onPointerUp: (_) => _dialUp(),
        onPointerCancel: (_) => _dialUp(),
        // 다이얼 위에서 끄는 손가락이 화면 스크롤로 잡히지 않게 막는다 (touch-action: none).
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (_) {},
          onHorizontalDragUpdate: (_) {},
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: frac),
                  duration: const Duration(milliseconds: 300),
                  curve: const Cubic(0.4, 0, 0.2, 1),
                  builder: (context, f, _) => TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: tone.arc),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, color, _) => CustomPaint(painter: _ArcPainter(frac: f, color: color ?? tone.arc)),
                  ),
                ),
              ),
              Semantics(
                container: true,
                button: true,
                enabled: blocked == null,
                label: blocked == null ? '길게 눌러서 체온 기록' : '체온 기록. $blocked',
                onLongPress: () => blocked == null ? _record() : _showToast(blocked),
                excludeSemantics: true,
                child: AnimatedScale(
                  scale: _pressing ? 0.95 : 1,
                  duration: const Duration(milliseconds: 150),
                  curve: const Cubic(0.4, 0, 0.2, 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: rec,
                    height: rec,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _flash ? Ds.blue50 : Ds.surface,
                      border: Border.all(color: Ds.gray100),
                      boxShadow: Ds.shadowDial,
                    ),
                    child: Stack(children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _press,
                          builder: (context, _) => CustomPaint(
                            painter: _PressRingPainter(progress: _pressing ? _press.value : 0, k: rec / 148),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12 * k),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(noPermission ? Icons.lock_outline : Icons.touch_app_outlined,
                                  size: 28, color: noPermission ? Ds.gray500 : Ds.gray900),
                              const SizedBox(height: 4),
                              Text(noPermission ? '측정 권한 없음' : '길게 눌러서',
                                  style: TextStyle(
                                      fontSize: T.bodyMd,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                      color: noPermission ? Ds.gray500 : Ds.gray900)),
                              const SizedBox(height: 2),
                              Text(noPermission ? '담당 반이 아니에요' : '체온 기록',
                                  style: const TextStyle(
                                      fontSize: T.label, height: 1.5, fontWeight: FontWeight.w500, color: Ds.gray500)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    // −/+ 는 다이얼 위에 겹쳐 둔다 (누르면 링 돌리기·길게 누르기로 잡히지 않는다).
    return SizedBox(
      width: size + 8,
      height: size,
      child: Stack(children: [
        Positioned(left: 4, top: 0, width: size, height: size, child: dial),
        Positioned(
          left: 0,
          top: size / 2 - 22,
          child: _Stepper(label: '-', semantics: '체온 감소', onTap: () => _ctrl.nudge(-1)),
        ),
        Positioned(
          right: 0,
          top: size / 2 - 22,
          child: _Stepper(label: '+', semantics: '체온 증가', onTap: () => _ctrl.nudge(1)),
        ),
      ]),
    );
  }

  /// PresetChips: 누르면 그 값으로. 지금 값과 같은 칩이 선택 표시.
  /// [간호쌤 호출]: 의료 호출함(간호사)으로 호출 + 별님카드에 기록. 별님을 골라야 누를 수 있다.
  Widget _nurseCallButton(Resident? sel) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Semantics(
            button: true,
            enabled: sel != null,
            label: sel == null ? '간호쌤 호출 (별님을 먼저 고르세요)' : '${sel.name} 별님 간호쌤 호출',
            excludeSemantics: true,
            child: OutlinedButton.icon(
              key: const Key('qt-nurse-call'),
              onPressed: sel == null
                  ? null
                  : () async {
                      final sent = await showNurseCallSheet(context, sel.id);
                      if (sent && mounted) _showToast('간호 선생님께 호출했어요 · 별님카드에 남겼어요');
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                foregroundColor: Ds.red500,
                disabledForegroundColor: Ds.gray400,
                side: BorderSide(color: sel == null ? Ds.gray200 : Ds.borderDanger),
                backgroundColor: sel == null ? Colors.transparent : Ds.red50,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.medical_services_rounded, size: 18),
              label: Text(sel == null ? '별님을 고르면 간호쌤을 부를 수 있어요' : '간호쌤 호출'),
            ),
          ),
        ),
      );

  Widget _presetChips(int value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < _presets.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _PresetChip(value: _presets[i], on: value == _presets[i], onTap: () => _ctrl.setValue(_presets[i])),
            ],
          ]),
        ),
      );
}

/// 반 칩: 선택+활성(진한 칩) / 선택(연한 칩) / 비선택(글자만).
class _ClassButton extends StatelessWidget {
  const _ClassButton({required this.name, required this.on, required this.focus, required this.onTap});
  final String name;
  final bool on, focus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        label: name,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: focus ? Ds.gray900 : (on ? Ds.gray100 : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              name,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: T.bodyLg,
                height: 1.5,
                letterSpacing: -0.4,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: focus ? Colors.white : (on ? Ds.gray900 : Ds.gray500),
              ),
            ),
          ),
        ),
      );
}

/// 별님 한 칸 (68): 이름 두 글자 동그라미 52 + 이름.
class _ResidentItem extends StatelessWidget {
  const _ResidentItem({required this.resident, required this.on, required this.anySelected, required this.onTap, this.photoUrl});
  final Resident resident;
  final bool on, anySelected;

  /// 프로필 사진 (있으면 동그라미 안에 사진, 없으면 이름 두 글자).
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        label: resident.name,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: on ? 1 : (anySelected ? 0.4 : 0.75),
            child: SizedBox(
              width: _residentCell,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? Ds.gray900 : Ds.gray100,
                    // 0 0 0 2px #FFF, 0 0 0 4px #191F28, shadow-sm (아래부터 그린다)
                    boxShadow: on
                        ? const [
                            BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
                            BoxShadow(color: Ds.gray900, spreadRadius: 4),
                            BoxShadow(color: Colors.white, spreadRadius: 2),
                          ]
                        : const [],
                  ),
                  child: photoUrl != null
                      ? ResidentCircle(label: resident.shortName, url: photoUrl, size: 52)
                      : Text(
                          resident.shortName,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: T.bodyMd,
                            height: 1.5,
                            fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                            color: on ? Colors.white : Ds.gray700,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  on ? resident.name : resident.shortName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: T.label,
                    height: 1.5,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? Ds.gray900 : Ds.gray700,
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// − / + (44, 흰 바탕 · 테두리 · shadow-float, 누르면 0.95).
class _Stepper extends StatefulWidget {
  const _Stepper({required this.label, required this.semantics, required this.onTap});
  final String label;
  final String semantics;
  final VoidCallback onTap;

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.semantics,
        excludeSemantics: true,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 150),
          child: DecoratedBox(
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: Ds.shadowFloat),
            child: Material(
              color: Ds.surface,
              shape: const CircleBorder(side: BorderSide(color: Ds.gray200)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: (v) => setState(() => _down = v),
                hoverColor: Ds.gray100,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Text(widget.label,
                        style: const TextStyle(fontSize: 22, height: 1.5, fontWeight: FontWeight.w600, color: Ds.gray700)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// 프리셋 칩 (36, gray-100 / 선택 gray-900).
class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.value, required this.on, required this.onTap});
  final int value;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        label: '${formatTemp(value)}도',
        excludeSemantics: true,
        child: Material(
          color: on ? Ds.gray900 : Ds.gray100,
          shape: const StadiumBorder(),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: on ? null : Ds.gray200,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(
                '${formatTemp(value)}°',
                style: TextStyle(
                  fontSize: T.label,
                  height: 1.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? Colors.white : Ds.gray700,
                  fontFeatures: tabular,
                ),
              ),
            ),
          ),
        ),
      );
}

/// 위에서 내려오는 토스트 (gray-900, radius 12, 14/20 w600).
class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: _Appear(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Ds.gray900,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: T.body, height: 20 / 14, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      );
}

/// ds-toast: 180ms 동안 위에서 8 내려오며 나타남.
class _Appear extends StatelessWidget {
  const _Appear({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: const Cubic(0.4, 0, 0.2, 1),
        builder: (context, t, child) =>
            Opacity(opacity: t, child: Transform.translate(offset: Offset(0, -8 * (1 - t)), child: child)),
        child: child,
      );
}

/// 다이얼 링: 회색 바탕 링 + 34–41° 구간을 한 바퀴로 그리는 호 (r 102, 굵기 12, 위에서 시계 방향).
class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.frac, required this.color});
  final double frac;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 240;
    final c = size.center(Offset.zero);
    final r = 102 * k;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12 * k;
    canvas.drawCircle(c, r, stroke..color = Ds.gray100);
    if (frac <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * frac.clamp(0.0, 1.0),
      false,
      stroke
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.frac != frac || old.color != color;
}

/// 길게 누르는 동안 가운데 버튼 가장자리를 따라 차오르는 파란 링 (r 70, 굵기 4).
class _PressRingPainter extends CustomPainter {
  _PressRingPainter({required this.progress, required this.k});
  final double progress;
  final double k;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: 70 * k),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Ds.blue500,
    );
  }

  @override
  bool shouldRepaint(_PressRingPainter old) => old.progress != progress || old.k != k;
}
