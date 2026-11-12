// 퀵 체온 (QT). 퀵 체온 명세 3~8장 + 통합 명세 6-1.
// 화면 기준: docs/design.md — 팀 시제품(퀵체온입력_화면시제품) 배치 그대로, 글자만 한 단계 크게.
// 위에서부터: 반 캡슐 → 별님 얼굴 줄 → 이름·체온(같은 크기) → 다이얼 → ± 조절 → 쓸기 안내.
// 뒤에는 고른 별님 얼굴을 아주 옅게 깐다. 작은 폰에서는 글자가 아니라 다이얼을 먼저 줄인다.
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

/// 시제품의 진한 초록 (선택 테두리·기록 완료 글자). 흰 바탕·연초록 바탕 모두 대비 충분.
final Color _green = stageColors[Stage.normal]!.ink;

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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _swipe = Offset.zero,
      onPanUpdate: (d) => _swipe += d.delta,
      onPanEnd: (_) => _onSwipeEnd(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        // 기록 완료면 화면 전체가 연초록으로 바뀐다 (시제품 .sheet.saved).
        color: saved ? recordedGreen : paper,
        child: LayoutBuilder(
          builder: (context, outer) {
            return Stack(
              children: [
                // 고른 별님 얼굴을 크게, 아주 옅게 (시제품 .backdrop). 글자 읽기를 방해하지 않게 10% 안팎.
                Positioned(
                  top: 150,
                  left: -outer.maxWidth * 0.15,
                  right: -outer.maxWidth * 0.15,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: saved ? 0.06 : 0.08,
                      child: Center(child: FaceAvatar.resident(r.id, size: outer.maxWidth * 1.3)),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // 작은 화면: 위 안내 줄·쓸기 그림을 빼고 간격을 줄인다. 글자 크기는 그대로.
                      // 큰 글자 설정이면 같은 화면도 '작은 화면'처럼 다룬다.
                      final compact = box.maxHeight / scaler.scale(1) < 640;
                      final gap = compact ? Gap.xs : Gap.s;
                      return Column(
                        children: [
                          if (!compact) const _TopLine() else const SizedBox(height: Gap.s),
                          _ClassTabs(state: st),
                          SizedBox(height: compact ? Gap.xs : Gap.m),
                          _ResidentRow(state: st, face: compact ? 40 : 46),
                          SizedBox(height: gap),
                          Text(
                            '${cls.name} · ${idx + 1} / ${residents.length}',
                            style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub),
                          ),
                          Semantics(
                            label: '${r.name} ${formatTemp(st.value)}도 ${saved ? '기록 완료' : '입력 중'}',
                            child: ExcludeSemantics(
                              child: _NameAndTemp(name: r.name, value: st.value, compact: compact),
                            ),
                          ),
                          const SizedBox(height: Gap.xs),
                          _StatusLine(saved: saved),
                          SizedBox(height: gap),
                          // 다이얼은 남은 높이만큼만 (작은 화면에서 가장 먼저 줄어든다).
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, area) {
                                // 작은 화면: 높이가 모자라면 ± 를 다이얼 양옆에 두어 높이를 아낀다.
                                // (큰 글자로 compact가 됐지만 높이가 남으면 시제품처럼 아래에 둔다.)
                                const fineH = tapHeight + Gap.s;
                                final fullW = math.min(area.maxWidth - Gap.page * 2, 250.0);
                                final besides = compact && area.maxHeight < fullW + fineH;
                                final below = compact && !besides;
                                final side = besides ? 52.0 * 2 + Gap.s * 2 : 0.0;
                                final maxByWidth = area.maxWidth - Gap.page * 2 - side;
                                final maxByHeight = area.maxHeight - (below ? fineH : 0);
                                final dial = math.max(0.0, math.min(math.min(maxByHeight, maxByWidth), 250.0));
                                final dialW = _Dial(
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
                                );
                                if (!compact) return Center(child: dialW);
                                if (below) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      dialW,
                                      const SizedBox(height: Gap.s),
                                      _FineRow(onMinus: () => ctrl.nudge(-1), onPlus: () => ctrl.nudge(1)),
                                    ],
                                  );
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _RoundBtn(label: '−', semantic: '0.1도 내리기', onTap: () => ctrl.nudge(-1)),
                                    const SizedBox(width: Gap.s),
                                    dialW,
                                    const SizedBox(width: Gap.s),
                                    _RoundBtn(label: '+', semantic: '0.1도 올리기', onTap: () => ctrl.nudge(1)),
                                  ],
                                );
                              },
                            ),
                          ),
                          SizedBox(height: gap),
                          if (!compact) ...[
                            _FineRow(onMinus: () => ctrl.nudge(-1), onPlus: () => ctrl.nudge(1)),
                            // 기록 완료 한 줄 (자리는 늘 잡아 둬서 다이얼 크기가 흔들리지 않게).
                            SizedBox(
                              height: scaler.scale(T.body) * 1.45,
                              child: saved
                                  ? Text(
                                      '${r.name} · ${formatTemp(st.value)}℃ 기록 완료',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: _green),
                                    )
                                  : null,
                            ),
                          ],
                          _GestureGuide(
                            mode: st.mode,
                            compact: compact,
                            onUp: () => ctrl.setMode(QtMode.classSelect),
                            onDown: () => ctrl.setMode(QtMode.resident),
                          ),
                          SizedBox(height: compact ? Gap.s : Gap.m),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── 맨 위 한 줄: ✳ 퀵 체온 · ● 오늘의 건강 기록 (시제품 .topline)
class _TopLine extends StatelessWidget {
  const _TopLine();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Gap.page + 4, Gap.m, Gap.page + 4, Gap.s),
    child: Row(
      children: [
        Icon(Icons.flare, size: 18, color: _green),
        const SizedBox(width: 6),
        const Text(
          '퀵 체온',
          style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
        ),
        const Spacer(),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        const Text(
          '오늘의 건강 기록',
          style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub),
        ),
      ],
    ),
  );
}

// ── 반 고르기: 반투명 캡슐 안에 반 이름. 고른 반은 흰 바탕 + 굵게, 잠긴 반은 자물쇠.
class _ClassTabs extends ConsumerWidget {
  const _ClassTabs({required this.state});
  final QuickTempState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final ctrl = ref.read(quickTempProvider.notifier);
    final classMode = state.mode == QtMode.classSelect;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gap.l),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.pill),
        // 반 고르기 중이면 캡슐 테두리를 진하게 (위아래로 쓸어 바꾸는 상태)
        border: Border.all(color: classMode ? _green : Colors.white, width: classMode ? 2 : 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // 잴 수 있는 반을 앞에, 잠긴 반은 뒤에 둔다 (내 반이 첫 화면에 보이게).
          child: Row(
            children: [
              for (final c in [
                ...repo.classes.where((c) => ctrl.canMeasure(c.id)),
                ...repo.classes.where((c) => !ctrl.canMeasure(c.id)),
              ])
                _ClassTab(
                  cls: c,
                  selected: c.id == state.classId,
                  ring: c.id == state.classId && classMode,
                  locked: !ctrl.canMeasure(c.id),
                  onTap: () => ctrl.selectClass(c.id, keepMode: classMode),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassTab extends StatelessWidget {
  const _ClassTab({
    required this.cls,
    required this.selected,
    required this.ring,
    required this.locked,
    required this.onTap,
  });
  final Class cls;
  final bool selected, ring, locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? inkMain : inkSub;
    return Semantics(
      button: true,
      enabled: !locked,
      selected: selected,
      label: '${cls.name}${locked ? ', 측정 권한 없음' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? surface : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: ring ? _green : Colors.transparent, width: 2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: locked ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: tapHeight),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: Color(cls.color), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  cls.name,
                  style: TextStyle(
                    fontSize: T.body,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (locked) ...[const SizedBox(width: 4), const Icon(Icons.lock, size: 16, color: starYellow)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 별님 고르기: 얼굴 그림 + 이름. 고른 별님은 초록 테두리, 잰 별님은 이름 뒤 ✓.
class _ResidentRow extends ConsumerWidget {
  const _ResidentRow({required this.state, required this.face});
  final QuickTempState state;
  final double face;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final list = repo.residentsOf(state.classId);
    final nameH = MediaQuery.textScalerOf(context).scale(T.caption) * 1.45;
    final faceBox = face + 10; // 테두리 자리 (2.5 + 2.5) × 2
    return LayoutBuilder(
      builder: (context, box) {
        final avail = box.maxWidth - Gap.l * 2;
        final itemW = math.max(faceBox + 8, avail / list.length);
        return SizedBox(
          height: faceBox + 4 + nameH + 2,
          child: ListView(
            scrollDirection: Axis.horizontal,
            itemExtent: itemW,
            padding: const EdgeInsets.symmetric(horizontal: Gap.l),
            children: [for (final r in list) _item(ref, r)],
          ),
        );
      },
    );
  }

  Widget _item(WidgetRef ref, Resident r) {
    final selected = r.id == state.residentId;
    final done = state.saved.containsKey(r.id);
    final ring = selected ? (state.mode == QtMode.resident ? _green : inkSub) : Colors.transparent;
    return Semantics(
      button: true,
      selected: selected,
      label: '${r.name}${done ? ', 기록함' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => ref.read(quickTempProvider.notifier).selectResident(r.id),
        borderRadius: BorderRadius.circular(Radii.button),
        child: Column(
          children: [
            FaceAvatar.resident(r.id, size: face, ring: ring),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: r.name.substring(1)),
                  if (done)
                    // 시제품 '하윤 ✓' (✓ 글자가 없는 글꼴도 있어 아이콘으로 그린다)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(Icons.check, size: 16, color: _green),
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: T.caption,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? inkMain : inkSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 이름과 체온: 같은 높이로 크게 (퀵 체온 명세). 체온은 시제품처럼 디지털 숫자.
// 작은 화면에서는 한 줄에 나란히.
class _NameAndTemp extends StatelessWidget {
  const _NameAndTemp({required this.name, required this.value, required this.compact});
  final String name;
  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : T.display;
    final nameText = Text(
      name,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w500, height: 1.2, color: inkMain, letterSpacing: -1),
    );
    final temp = _DigitalTemp(value: value, height: size * 0.92);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: compact
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  nameText,
                  const SizedBox(width: Gap.l),
                  temp,
                ],
              )
            : Column(mainAxisSize: MainAxisSize.min, children: [nameText, const SizedBox(height: 4), temp]),
      ),
    );
  }
}

/// 7칸 디지털 숫자 (시제품 .digital). 뒤에 옅은 '8'을 깔아 계기판처럼 보이게 한다.
class _DigitalTemp extends StatelessWidget {
  const _DigitalTemp({required this.value, required this.height});
  final int value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = formatTemp(value);
    final digitW = height * 0.56;
    final gap = height * 0.12;
    final dotW = height * 0.22;
    var w = 0.0;
    for (final ch in text.split('')) {
      w += (ch == '.' ? dotW : digitW) + gap;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          size: Size(w - gap, height),
          painter: _SevenSegPainter(text: text, digitW: digitW, dotW: dotW, gap: gap, color: inkMain),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            '℃',
            style: TextStyle(fontSize: height * 0.42, fontWeight: FontWeight.w400, color: inkSub, height: 1),
          ),
        ),
      ],
    );
  }
}

class _SevenSegPainter extends CustomPainter {
  _SevenSegPainter({
    required this.text,
    required this.digitW,
    required this.dotW,
    required this.gap,
    required this.color,
  });
  final String text;
  final double digitW, dotW, gap;
  final Color color;

  // 칸 이름: a 위, b 오른쪽 위, c 오른쪽 아래, d 아래, e 왼쪽 아래, f 왼쪽 위, g 가운데
  static const _map = {
    '0': 'abcdef',
    '1': 'bc',
    '2': 'abged',
    '3': 'abgcd',
    '4': 'fgbc',
    '5': 'afgcd',
    '6': 'afgedc',
    '7': 'abc',
    '8': 'abcdefg',
    '9': 'abcdfg',
    '-': 'g',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final on = Paint()..color = color;
    final ghost = Paint()..color = color.withValues(alpha: 0.07);
    final h = size.height;
    final t = h * 0.12; // 획 두께
    var x = 0.0;
    for (final ch in text.split('')) {
      if (ch == '.') {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x + (dotW - t) / 2, h - t, t, t), Radius.circular(t * 0.2)),
          on,
        );
        x += dotW + gap;
        continue;
      }
      final segs = _map[ch] ?? '';
      for (final s in 'abcdefg'.split('')) {
        canvas.drawPath(_seg(s, x, digitW, h, t), segs.contains(s) ? on : ghost);
      }
      x += digitW + gap;
    }
  }

  /// 끝이 비스듬한 막대 하나.
  Path _seg(String s, double x, double w, double h, double t) {
    final m = h / 2;
    final g = t * 0.18; // 칸 사이 틈
    Path horiz(double y) => Path()
      ..moveTo(x + g + t / 2, y)
      ..lineTo(x + g + t, y - t / 2)
      ..lineTo(x + w - g - t, y - t / 2)
      ..lineTo(x + w - g - t / 2, y)
      ..lineTo(x + w - g - t, y + t / 2)
      ..lineTo(x + g + t, y + t / 2)
      ..close();
    Path vert(double cx, double y1, double y2) => Path()
      ..moveTo(cx, y1 + g)
      ..lineTo(cx + t / 2, y1 + g + t / 2)
      ..lineTo(cx + t / 2, y2 - g - t / 2)
      ..lineTo(cx, y2 - g)
      ..lineTo(cx - t / 2, y2 - g - t / 2)
      ..lineTo(cx - t / 2, y1 + g + t / 2)
      ..close();
    final l = x + t / 2, r = x + w - t / 2;
    final top = t / 2, bot = h - t / 2;
    return switch (s) {
      'a' => horiz(top),
      'g' => horiz(m),
      'd' => horiz(bot),
      'f' => vert(l, top, m),
      'b' => vert(r, top, m),
      'e' => vert(l, m, bot),
      _ => vert(r, m, bot), // c
    };
  }

  @override
  bool shouldRepaint(_SevenSegPainter old) => old.text != text || old.color != color;
}

// ── 지금 상태 한 줄: 입력 중(조용히) / 기록 완료(초록 ✓).
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.saved});
  final bool saved;

  @override
  Widget build(BuildContext context) {
    if (!saved) {
      return const Text(
        '체온을 입력해 주세요',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: T.caption, color: inkSub, fontWeight: FontWeight.w600),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: _green, size: 18),
        const SizedBox(width: 4),
        Text(
          '체온 기록 완료',
          style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: _green),
        ),
      ],
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
    final sub = !widget.enabled ? '다른 반이에요' : (widget.saved ? '다음 별님으로 넘겨요' : '0.5초 꾹 눌러 주세요');
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
                    width: d * 0.58,
                    height: d * 0.58,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.saved ? Icons.check : Icons.north,
                            color: widget.saved ? _green : brandDark,
                            size: widget.saved ? 34 : 26,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: T.title,
                              fontWeight: FontWeight.w600,
                              color: widget.saved ? _green : inkMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w500, color: inkSub),
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
  _DialPainter({required this.rotation, required this.progress, required this.saved});
  final double rotation, progress;
  final bool saved;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    if (r <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    // 바깥 원판: 흰색 → 옅은 미색 (시제품 .dial 그라데이션)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF3DF)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..color = saved ? stageColors[Stage.normal]!.line : line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 눈금 60개 (돌리면 함께 돈다)
    for (var i = 0; i < 60; i++) {
      final a = (i * 6 + rotation - 90) * math.pi / 180;
      final major = i % 5 == 0;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (r * 0.90),
        c + dir * (r * (major ? 0.80 : 0.85)),
        Paint()
          ..color = major ? inkSub : inkSub.withValues(alpha: 0.45)
          ..strokeWidth = major ? 2 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
    // 위쪽 바늘 (돌린 만큼 따라 돈다)
    final pa = (rotation - 90) * math.pi / 180;
    canvas.save();
    canvas.translate(c.dx + math.cos(pa) * r * 0.86, c.dy + math.sin(pa) * r * 0.86);
    canvas.rotate(pa + math.pi / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 7, height: 13), const Radius.circular(4)),
      Paint()..color = _green,
    );
    canvas.restore();

    // 안쪽 원 (얇은 테두리)
    final core = r * 0.64;
    canvas.drawCircle(c, core, Paint()..color = saved ? const Color(0xFFF0F8E9) : const Color(0xFFFFFBF9));
    canvas.drawCircle(
      c,
      core,
      Paint()
        ..color = const Color(0xFFCCD6C3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 4),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = _green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.rotation != rotation || old.progress != progress || old.saved != saved;
}

// ── 다이얼 아래: [−] 돌려서 조절 · 0.1℃ [+] (시제품 .fine)
class _FineRow extends StatelessWidget {
  const _FineRow({required this.onMinus, required this.onPlus});
  final VoidCallback onMinus, onPlus;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _RoundBtn(label: '−', semantic: '0.1도 내리기', onTap: onMinus),
      const SizedBox(width: Gap.m),
      const Flexible(
        child: Text(
          '돌려서 조절 · 0.1℃',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: inkSub),
        ),
      ),
      const SizedBox(width: Gap.m),
      _RoundBtn(label: '+', semantic: '0.1도 올리기', onTap: onPlus),
    ],
  );
}

/// − / + 알약 버튼 (누르는 자리 52×48).
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
      width: 52,
      height: tapHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: EdgeInsets.zero,
          minimumSize: const Size(52, tapHeight),
          backgroundColor: Colors.white.withValues(alpha: 0.7),
          side: const BorderSide(color: Color(0xFFB9C8B9), width: 1.2),
        ),
        // 글꼴마다 '−' 기호가 없을 수 있어 아이콘으로 그린다.
        child: Icon(label == '+' ? Icons.add : Icons.remove, size: 24, color: inkMain),
      ),
    ),
  );
}

// ── 쓸기 안내 (시제품 .gesture): 좌우로 쓸면 무엇이 바뀌는지 + 위/아래 쓸기 버튼 2개.
class _GestureGuide extends StatelessWidget {
  const _GestureGuide({required this.mode, required this.compact, required this.onUp, required this.onDown});
  final QtMode mode;
  final bool compact;
  final VoidCallback onUp, onDown;

  @override
  Widget build(BuildContext context) {
    final residentMode = mode == QtMode.resident;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SwipeArt(square: !residentMode),
                  const SizedBox(width: Gap.m),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          residentMode ? '별님 선택 중' : '반 선택 중',
                          style: const TextStyle(fontSize: T.caption, color: inkSub, height: 1.3),
                        ),
                        Text(
                          residentMode ? '별님 바꾸기' : '반 바꾸기',
                          style: const TextStyle(
                            fontSize: T.body,
                            fontWeight: FontWeight.w700,
                            color: inkMain,
                            height: 1.3,
                          ),
                        ),
                        const Text(
                          '화면을 좌우로 쓸어 주세요',
                          style: TextStyle(fontSize: T.caption, color: inkSub, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _GuideBtn(
                  icon: Icons.swipe_up,
                  hint: '위로 쓸어',
                  text: '반 바꾸기',
                  on: !residentMode,
                  compact: compact,
                  onTap: onUp,
                ),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: _GuideBtn(
                  icon: Icons.swipe_down,
                  hint: '아래로 쓸어',
                  text: '별님 선택',
                  on: residentMode,
                  compact: compact,
                  onTap: onDown,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 손가락 + 동그라미(별님)·네모(반) 세 개. 가운데가 지금 고른 것.
class _SwipeArt extends StatelessWidget {
  const _SwipeArt({required this.square});
  final bool square;

  @override
  Widget build(BuildContext context) {
    Widget mark(bool sel) => Container(
      width: sel ? 18 : 14,
      height: sel ? 18 : 14,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: sel ? _green : const Color(0xFFB4C9AC).withValues(alpha: 0.6),
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(4) : null,
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: 84,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [mark(false), mark(true), mark(false)],
              ),
            ),
            Positioned(top: 20, child: Icon(Icons.swipe, size: 28, color: _green)),
          ],
        ),
      ),
    );
  }
}

class _GuideBtn extends StatelessWidget {
  const _GuideBtn({
    required this.icon,
    required this.hint,
    required this.text,
    required this.on,
    required this.compact,
    required this.onTap,
  });
  final IconData icon;
  final bool compact;
  final String hint, text;

  /// 지금 이 모드인가 (연초록으로 채움).
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    label: '$hint $text',
    excludeSemantics: true,
    child: Material(
      color: on ? const Color(0xFFE3F0D8) : Colors.white.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: on ? const Color(0xFF86B56C) : const Color(0xFFCBD5C4), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? tapHeight : 56),
          padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 24 : 30, color: on ? _green : inkSub),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!compact)
                      Text(
                        hint,
                        style: const TextStyle(fontSize: T.caption, color: inkSub, height: 1.25),
                      ),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: T.body,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: inkMain,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
