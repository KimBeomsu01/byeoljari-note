// PC 01 현황판 · 02 일정이 같이 쓰는 작은 부품 (Claude Design pc.css의 색 · hover · 선택 상태).
// 디자인 inline 값(px)을 그대로 옮겼다. 글자 크기가 없는 요소는 PC 화면 기본 16px를 쓴다.
import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 디자인에 hex로 들어 있는 Tailwind 기본 팔레트 (amber · emerald · red).
class Tw {
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber200 = Color(0xFFFDE68A);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const amber800 = Color(0xFF92400E);
  static const amber900 = Color(0xFF78350F);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const emerald800 = Color(0xFF065F46);
  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red200 = Color(0xFFFECACA);
  static const red600 = Color(0xFFDC2626);

  /// 일정 분류 색 (PC 02 범례).
  static const greenSoft = Color(0xFFE6F9F1);
  static const greenInk = Color(0xFF028A54);
  static const cyanInk = Color(0xFF008DA6);
}

/// PC 기본 글자 크기 (디자인 .pc-root font-size 16px).
const double pcBase = 16;

/// 글자 모양. [mono]는 디자인 font-mono 자리 (숫자 고정폭).
TextStyle pcText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = Ds.gray900,
  double? height = 1.5,
  double? spacing,
  bool mono = false,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: spacing,
  fontFeatures: mono ? tabular : null,
);

/// 카드 그림자 (0 2 12 rgba(0,0,0,.03)).
const pcCardShadow = [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))];

/// 요약 카드 그림자 (0 2 8 rgba(0,0,0,.03)).
const pcTileShadow = [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))];

/// 일정 카드 그림자 (0 1 4 rgba(0,0,0,.04)).
const pcSoftShadow = [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))];

/// 디자인 시각 표기 '2026.10.28 수 10:15'.
const weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

String two(int v) => v.toString().padLeft(2, '0');
String dotDate(DateTime t) => '${t.year}.${two(t.month)}.${two(t.day)} ${weekdayKo[t.weekday - 1]}';
String hm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// 체온 '38.2℃' (디자인 PC 표기).
String degC(int v) => '${(v / 10).toStringAsFixed(1)}℃';

/// 마우스를 올리면 모양이 바뀌는 누르는 자리 (pc.css :hover 규칙).
class PcHover extends StatefulWidget {
  const PcHover({super.key, required this.builder, this.onTap, this.semanticsLabel});
  final Widget Function(bool hover) builder;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  State<PcHover> createState() => _PcHoverState();
}

class _PcHoverState extends State<PcHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      label: widget.semanticsLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: widget.builder(enabled && _hover)),
      ),
    );
  }
}

/// 둥근 알약 버튼. 색 · 테두리 · hover 색을 디자인 값 그대로 받는다.
class PcButton extends StatelessWidget {
  const PcButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.iconSize = 18,
    this.bg = Colors.white,
    this.fg = Ds.gray700,
    this.border,
    this.hoverBg,
    this.hoverFg,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.radius = 999,
    this.size = pcBase,
    this.weight = FontWeight.w600,
    this.shadow,
    this.gap = 6,
    this.trailing,
    this.iconAfter = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;
  final Color bg;
  final Color fg;
  final Color? border;
  final Color? hoverBg;
  final Color? hoverFg;
  final double? height;
  final EdgeInsets padding;
  final double radius;
  final double size;
  final FontWeight weight;
  final List<BoxShadow>? shadow;
  final double gap;
  final Widget? trailing;
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    final iconW = icon == null ? null : Icon(icon, size: iconSize, color: iconColor ?? fg);
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: PcHover(
        onTap: onTap,
        builder: (hover) {
          final color = hover ? (hoverFg ?? fg) : fg;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: hover ? (hoverBg ?? bg) : bg,
              borderRadius: BorderRadius.circular(radius),
              border: border == null ? null : Border.all(color: border!),
              boxShadow: shadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconW != null && !iconAfter) ...[iconW, SizedBox(width: gap)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pcText(size, weight: weight, color: color),
                  ),
                ),
                if (iconW != null && iconAfter) ...[SizedBox(width: gap), iconW],
                if (trailing != null) ...[SizedBox(width: gap), trailing!],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 테두리 있는 알약 꼬리표 (상태 판정 · 대응 현황 · 건수).
class PcPill extends StatelessWidget {
  const PcPill(
    this.text, {
    super.key,
    required this.bg,
    required this.fg,
    this.border,
    this.icon,
    this.iconColor,
    this.iconSize = 14,
    this.size = pcBase,
    this.weight = FontWeight.w700,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.radius = 999,
    this.dot,
    this.mono = false,
    this.shadow,
  });
  final String text;
  final Color bg;
  final Color fg;
  final Color? border;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;
  final double size;
  final FontWeight weight;
  final EdgeInsets padding;
  final double radius;

  /// 앞에 붙는 작은 점 색.
  final Color? dot;
  final bool mono;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: border == null ? null : Border.all(color: border!),
      boxShadow: shadow,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot != null) ...[PcDot(6, dot!), const SizedBox(width: 4)],
        if (icon != null) ...[Icon(icon, size: iconSize, color: iconColor ?? fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: pcText(size, weight: weight, color: fg, mono: mono, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

/// 동그란 점. [ring]이 있으면 바깥 고리 (box-shadow 0 0 0 4px).
class PcDot extends StatelessWidget {
  const PcDot(this.size, this.color, {super.key, this.ring, this.ringWidth = 4});
  final double size;
  final Color color;
  final Color? ring;
  final double ringWidth;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: ring == null ? null : [BoxShadow(color: ring!, spreadRadius: ringWidth)],
    ),
  );
}

/// 흰 카드 (padding 16, radius 16, 테두리 gray-200).
class PcCard extends StatelessWidget {
  const PcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.border = Ds.gray200,
    this.shadow = pcCardShadow,
    this.color = Colors.white,
    this.gradient,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color border;
  final List<BoxShadow> shadow;
  final Color color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: shadow,
    ),
    child: child,
  );
}

/// 동그란 아이콘 자리 (32px, 연한 바탕).
class PcIconCircle extends StatelessWidget {
  const PcIconCircle(this.icon, {super.key, required this.bg, required this.fg, this.size = 32, this.iconSize = 18, this.border});
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: bg,
      shape: BoxShape.circle,
      border: border == null ? null : Border.all(color: border!),
    ),
    child: Icon(icon, size: iconSize, color: fg),
  );
}

/// 대화상자 머리 (제목 + 닫기 32px 원).
class PcDialogHeader extends StatelessWidget {
  const PcDialogHeader(this.title, {super.key, this.dot = Ds.blue500, this.subtitle, this.trailing});
  final String title;
  final Color dot;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(bottom: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Ds.gray100)),
    ),
    child: Row(
      children: [
        PcDot(12, dot),
        const SizedBox(width: 6),
        Flexible(
          child: Text(title, style: pcText(pcBase, weight: FontWeight.w700)),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pcText(13, color: Ds.gray500),
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
        Tooltip(
          message: '닫기',
          child: PcHover(
            onTap: () => Navigator.of(context).pop(),
            semanticsLabel: '닫기',
            builder: (hover) => Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Ds.gray100, shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, size: 18, color: hover ? Ds.gray900 : Ds.gray600),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 입력 칸 (디자인 모달 input: 높이 44, radius 28, gray-100 바탕, 초점 blue-500 2px).
InputDecoration pcInput(String hint, {Widget? prefix, String? error}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(28),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: pcText(15, color: Ds.gray400),
    isDense: true,
    filled: true,
    fillColor: Ds.gray100,
    prefixIcon: prefix,
    errorText: error,
    errorStyle: pcText(12, color: Ds.red500, height: 1.3),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: b(Ds.gray200),
    enabledBorder: b(Ds.gray200),
    focusedBorder: b(Ds.blue500, 2),
    errorBorder: b(Ds.red500),
    focusedErrorBorder: b(Ds.red500, 2),
  );
}

/// 입력 칸 위 라벨 (gray-600 600).
class PcLabel extends StatelessWidget {
  const PcLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: pcText(pcBase, weight: FontWeight.w600, color: Ds.gray600),
    ),
  );
}

/// 둘 중 하나 고르기 (선택 = blue-500, 디자인 .pc-cat-btn).
class PcChoice extends StatelessWidget {
  const PcChoice({super.key, required this.label, required this.selected, required this.onTap, this.height = 40});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: PcHover(
      onTap: onTap,
      builder: (hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Ds.blue500 : (hover ? Ds.gray200 : Ds.gray100),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: pcText(pcBase, weight: selected ? FontWeight.w700 : FontWeight.w600, color: selected ? Colors.white : Ds.gray700),
        ),
      ),
    ),
  );
}

/// PC 대화상자 틀 (흰 바탕 radius 24, padding 24, 최대 폭 [maxWidth]).
Future<R?> showPcDialog<R>(BuildContext context, {required WidgetBuilder builder, double maxWidth = 512, double? height}) => showDialog<R>(
  context: context,
  barrierColor: const Color(0x66000000),
  builder: (ctx) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Ds.gray200),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        width: maxWidth,
        height: height,
        child: Padding(padding: const EdgeInsets.all(24), child: builder(ctx)),
      ),
    ),
  ),
);

/// 예시 카드 안의 짧은 한 줄: 오른쪽 위 "예시" 꼬리표가 내용을 가리지 않게 자리를 비운다.
Widget exampleRoom(Widget child) => Padding(
  padding: const EdgeInsets.only(right: 48),
  child: ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 32),
    child: Align(alignment: Alignment.centerLeft, child: child),
  ),
);
