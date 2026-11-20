// Claude Design 공통 컴포넌트 (Components.dc.html). 화면마다 새로 만들지 말고 이걸 쓴다.
// 이름은 디자인 파일의 data-component 이름과 맞췄다.
import 'package:flutter/material.dart';

import 'judgment.dart';
import 'theme.dart';

/// '37.6°C'
String fmtC(int value) => '${formatTemp(value)}°C';

/// '+0.5°' / '−1.2°'
String fmtDiffDeg(int diff) => '${formatDiff(diff)}°';

/// 시각 '09:41'
String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// '어제 15:20' / '09:15' / '10/26 09:30'
String relTime(DateTime t, DateTime now) {
  final d0 = DateTime(now.year, now.month, now.day);
  final d1 = DateTime(t.year, t.month, t.day);
  final days = d0.difference(d1).inDays;
  if (days == 0) return hhmm(t);
  if (days == 1) return '어제 ${hhmm(t)}';
  return '${t.month}/${t.day} ${hhmm(t)}';
}

/// 흰 카드 (radius 24, 얇은 테두리, 그림자 card).
class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = Radii.card,
    this.borderColor = Ds.borderCard,
    this.shadow = Ds.shadowSm,
    this.color = Ds.surface,
    this.onTap,
    this.topStripe,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final List<BoxShadow> shadow;
  final Color color;
  final VoidCallback? onTap;

  /// 카드 맨 위 4px 띠 (UrgentVitalCard).
  final Color? topStripe;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget body = Padding(padding: padding, child: child);
    if (topStripe != null) {
      body = Stack(children: [
        body,
        Positioned(top: 0, left: 0, right: 0, child: Container(height: 4, color: topStripe)),
      ]);
    }
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: r, border: Border.all(color: borderColor), boxShadow: shadow),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// 회색 안쪽 상자 (radius 20, gray-50).
class DsInset extends StatelessWidget {
  const DsInset({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = Ds.gray50});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.inner)),
        child: child,
      );
}

/// 반 이름 같은 작은 꼬리표 (radius 6).
enum TagTone { gray, blue, red, green, orange, violet, cyan }

class DsTag extends StatelessWidget {
  const DsTag(this.text, {super.key, this.tone = TagTone.gray, this.small = false});
  final String text;
  final TagTone tone;
  final bool small;

  static (Color, Color) colors(TagTone t) => switch (t) {
        TagTone.gray => (Ds.gray100, Ds.gray700),
        TagTone.blue => (Ds.blue50, Ds.blue500),
        TagTone.red => (Ds.red50, Ds.red500),
        TagTone.green => (Ds.green50, Ds.green500),
        TagTone.orange => (Ds.orange50, const Color(0xFFE07A00)),
        TagTone.violet => (Ds.violet50, Ds.violet500),
        TagTone.cyan => (Ds.cyan50, const Color(0xFF0095B0)),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(small ? 4 : Radii.tag)),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: small ? T.micro : T.caption, height: small ? 1.5 : 1.33, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// 필터 칩 (36px, 선택 = gray-900). [count]가 있으면 옆에 숫자.
class DsChip extends StatelessWidget {
  const DsChip({super.key, required this.label, required this.selected, required this.onTap, this.count, this.countColor});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? countColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Ds.gray900 : Ds.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : Ds.borderChip)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: selected ? 15 : 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: T.caption,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.white : Ds.gray700)),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text('$count',
                    style: TextStyle(
                        fontSize: T.caption,
                        fontFeatures: tabular,
                        fontWeight: selected ? FontWeight.w400 : (countColor == null ? FontWeight.w500 : FontWeight.w700),
                        color: selected ? Colors.white.withValues(alpha: 0.8) : (countColor ?? Ds.gray500))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// 버튼 종류 (Components: primary violet · info blue · tonal blue-50 · dark gray-900 · gray gray-100).
enum DsButtonKind { violet, blue, tonal, dark, gray, outline, danger }

class DsButton extends StatelessWidget {
  const DsButton(this.label, {super.key, required this.onPressed, this.kind = DsButtonKind.violet, this.icon, this.height = 44, this.expand = false, this.small = false});
  final String label;
  final VoidCallback? onPressed;
  final DsButtonKind kind;
  final IconData? icon;
  final double height;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = switch (kind) {
      DsButtonKind.violet => (Ds.violet500, Colors.white, null),
      DsButtonKind.blue => (Ds.blue500, Colors.white, null),
      DsButtonKind.tonal => (Ds.blue50, Ds.blue500, null),
      DsButtonKind.dark => (Ds.gray900, Colors.white, null),
      DsButtonKind.gray => (Ds.gray100, Ds.gray800, null),
      DsButtonKind.outline => (Ds.surface, Ds.gray700, Ds.gray200),
      DsButtonKind.danger => (Ds.red500, Colors.white, null),
    };
    final disabled = onPressed == null;
    final child = Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: small ? 16 : 18, color: fg), const SizedBox(width: 4)],
      Flexible(
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: small ? T.caption : T.body, fontWeight: small && kind == DsButtonKind.tonal ? FontWeight.w700 : FontWeight.w600, color: fg)),
      ),
    ]);
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button), side: side == null ? BorderSide.none : BorderSide(color: side)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: small ? 14 : 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 개발 DB 예시 표시. 실제 기록이 생기면 예시 카드는 사라진다.
class ExampleTag extends StatelessWidget {
  const ExampleTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: Ds.orange50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x66FF8A00)),
        ),
        child: const Text('예시', style: TextStyle(fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w700, color: Color(0xFFE07A00))),
      );
}

/// 예시 카드 감싸기: 살짝 흐리게 + 오른쪽 위 "예시" 꼬리표 + 아래 안내 한 줄.
class ExampleWrap extends StatelessWidget {
  const ExampleWrap({super.key, required this.child, this.note = '실제 기록이 생기면 이 예시는 사라져요'});
  final Widget child;
  final String note;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '예시',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            Opacity(opacity: 0.6, child: IgnorePointer(child: child)),
            const Positioned(top: 10, right: 12, child: ExampleTag()),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(note, style: const TextStyle(fontSize: T.micro, color: Ds.gray500)),
          ),
        ]),
      );
}

/// 위에서 내려오는 토스트 (Toast). 잠깐 보였다가 사라진다.
void showDsToast(BuildContext context, String text, {IconData icon = Icons.check_circle, Color iconColor = Ds.green500}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.paddingOf(ctx).top + 16,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, -8 * (1 - v)), child: child)),
            child: Material(
              color: Ds.gray900,
              borderRadius: BorderRadius.circular(16),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: T.body, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2400), () {
    if (entry.mounted) entry.remove();
  });
}

/// 동그란 이름 두 글자 (사진이 없을 때 ResidentDial · 아바타).
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.text, {super.key, this.size = 40, this.background = Ds.gray100, this.foreground = Ds.gray700, this.ring});
  final String text;
  final double size;
  final Color background;
  final Color foreground;
  final Color? ring;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: ring == null ? null : Border.all(color: ring!, width: 2),
        ),
        child: Text(text,
            maxLines: 1,
            style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w700, color: foreground, letterSpacing: -0.3)),
      );
}

/// 구역 제목 (16px bold) + 오른쪽 부품.
class DsSectionTitle extends StatelessWidget {
  const DsSectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: T.bodyLg, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900))),
          if (trailing != null) trailing!,
        ]),
      );
}
