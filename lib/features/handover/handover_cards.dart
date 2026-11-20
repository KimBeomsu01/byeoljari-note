// 01 인수인계 카드 모양 (Main.dc.html의 ShiftSummaryCard · UrgentVitalCard · TodoRow · FeedCard 4종 · Fab).
// 모두 글자·숫자만 받아 그린다. 실제 자료와 개발 DB 예시 카드가 같은 모양을 쓴다.
import 'package:flutter/material.dart';

import '../../core/ds.dart';
import '../../core/theme.dart';

// ── 작은 부품

/// 누르면 살짝 줄어드는 버튼 (ds-press). [onTap]이 없으면 누를 수 없다.
class HoButton extends StatefulWidget {
  const HoButton(
    this.label, {
    super.key,
    required this.onTap,
    required this.bg,
    required this.fg,
    this.height = 44,
    this.hPad = 16,
    this.radius = 12,
    this.fontSize = T.body,
    this.weight = FontWeight.w600,
    this.icon,
    this.iconSize = 18,
    this.gap = 4,
    this.shadow,
    this.pressScale = 0.98,
  });
  final String label;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final double height;
  final double hPad;
  final double radius;
  final double fontSize;
  final FontWeight weight;
  final IconData? icon;
  final double iconSize;
  final double gap;
  final List<BoxShadow>? shadow;
  final double pressScale;

  @override
  State<HoButton> createState() => _HoButtonState();
}

class _HoButtonState extends State<HoButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final r = BorderRadius.circular(w.radius);
    return Semantics(
      button: true,
      enabled: w.onTap != null,
      child: AnimatedScale(
        scale: _down ? w.pressScale : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: r, boxShadow: w.shadow),
          child: Material(
            color: w.bg,
            borderRadius: r,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: w.onTap,
              onHighlightChanged: (v) => setState(() => _down = v),
              // 넓이가 정해진 자리(Expanded)에선 꽉 채우고, 아니면 글자 크기만큼.
              child: Container(
                height: w.height,
                padding: EdgeInsets.symmetric(horizontal: w.hPad),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (w.icon != null) ...[Icon(w.icon, size: w.iconSize, color: w.fg), SizedBox(width: w.gap)],
                  Flexible(
                    child: Text(w.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: w.fontSize, height: 1.43, fontWeight: w.weight, color: w.fg)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 이름 글자를 누를 수 있게 (별님카드로).
class _NameLink extends StatelessWidget {
  const _NameLink(this.text, {required this.style, this.onTap, this.leading});
  final String text;
  final TextStyle style;
  final VoidCallback? onTap;

  /// 이름 앞 프로필 사진 (함께 누를 수 있다).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final t = leading == null
        ? label
        : Row(mainAxisSize: MainAxisSize.min, children: [leading!, const SizedBox(width: 6), Flexible(child: label)]);
    if (onTap == null) return t;
    return Semantics(
      button: true,
      label: '$text 별님카드 열기',
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: t),
    );
  }
}

/// 시각 + (안 읽었으면) 파란 점.
class _TimeText extends StatelessWidget {
  const _TimeText(this.text, {this.unread = false});
  final String text;
  final bool unread;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (unread) ...[
          Semantics(
            label: '미확인',
            child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Ds.blue500, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 6),
        ],
        Text(text, style: const TextStyle(fontSize: T.caption, height: 1.33, color: Ds.gray500, fontFeatures: tabular)),
      ]);
}

/// 반 이름 꼬리표는 글자 크기만큼 (아주 긴 이름만 줄인다).
Widget _tagBox(Widget tag) => ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: tag);

/// 반 이름 꼬리표 (TodoRow: 11px, gray-600 / gray-100, radius 4).
class _SmallTag extends StatelessWidget {
  const _SmallTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Ds.gray100, borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w600, color: Ds.gray600)),
      );
}

/// 빨간 점이 천천히 깜빡인다 (ds-pulse). 처음 몇 번만 깜빡이고 멈춘다 (움직임 줄이기 설정이면 안 깜빡임).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.size = 10, this.color = Ds.red500});
  final double size;
  final Color color;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  static const _cycles = 5;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && ++_done < _cycles && mounted) _c.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done == 0 && !_c.isAnimating && !MediaQuery.disableAnimationsOf(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          // 0% · 100% 불투명, 50%에서 0.5.
          final t = const Cubic(0.4, 0, 0.6, 1).transform(_c.value);
          final o = 1 - 0.5 * (1 - (2 * t - 1).abs());
          return Opacity(opacity: o, child: child);
        },
        child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
}

// ── ShiftSummaryCard

class ShiftSummaryCard extends StatelessWidget {
  const ShiftSummaryCard({
    super.key,
    required this.timeText,
    required this.scopeText,
    required this.title,
    required this.urgent,
    required this.todo,
    required this.unread,
    required this.missed,
    required this.onTap,
  });

  /// '09:41 기준'
  final String timeText;

  /// '6개 반 36명'
  final String scopeText;

  /// '오전 근무조 인계'
  final String title;
  final int urgent;
  final int todo;
  final int unread;
  final int missed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const caption = TextStyle(fontSize: T.caption, height: 1.33, color: Ds.gray500, fontWeight: FontWeight.w500);
    return Semantics(
      button: true,
      label: '$title 요약 열기',
      child: DsCard(
        shadow: Ds.shadowCard,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ds.gray100))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: timeText),
                        const TextSpan(text: '  ·  '),
                        TextSpan(text: scopeText),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption.copyWith(fontFeatures: tabular),
                    ),
                  ),
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: T.title, height: 1.4, fontWeight: FontWeight.w700, color: Ds.gray900, letterSpacing: -0.5)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, size: 24, color: Ds.gray300),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(children: [
              Expanded(child: _Stat(label: '긴급', value: urgent, color: Ds.red500, labelColor: Ds.red500, dot: true)),
              const SizedBox(width: 8),
              Expanded(child: _Stat(label: '할 일', value: todo, color: Ds.gray900)),
              const SizedBox(width: 8),
              Expanded(child: _Stat(label: '미확인', value: unread, color: Ds.blue500)),
              const SizedBox(width: 8),
              Expanded(child: _Stat(label: '체온 미기록', value: missed, color: Ds.gray800)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color, this.labelColor = Ds.gray600, this.dot = false});
  final String label;
  final int value;
  final Color color;
  final Color labelColor;
  final bool dot;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (dot) ...[
                Container(width: 6, height: 6, decoration: BoxDecoration(color: labelColor, shape: BoxShape.circle)),
                const SizedBox(width: 2),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: T.caption, height: 1.33, fontWeight: dot ? FontWeight.w600 : FontWeight.w500, color: labelColor)),
            ]),
          ),
          const SizedBox(height: 2),
          Text('$value',
              style: TextStyle(fontSize: T.headline, height: 1.33, fontWeight: FontWeight.w700, color: color, fontFeatures: tabular)),
        ]),
      );
}

// ── FilterChips

class HoFilterBar extends StatelessWidget {
  const HoFilterBar({super.key, required this.chips});

  /// (이름, 고름, 숫자, 숫자 색, 누름)
  final List<(String, bool, int?, Color?, VoidCallback)> chips;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        child: Row(children: [
          for (final (i, (label, selected, count, color, onTap)) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            DsChip(label: label, selected: selected, onTap: onTap, count: count, countColor: color),
          ],
        ]),
      );
}

// ── UrgentVitalCard

class UrgentVitalCard extends StatelessWidget {
  const UrgentVitalCard({
    super.key,
    required this.classTag,
    required this.name,
    required this.tempText,
    required this.diffText,
    required this.tempColor,
    required this.scheduleText,
    required this.scheduleRight,
    required this.acknowledged,
    required this.onAcknowledge,
    required this.onRemeasure,
    this.onTap,
    this.avatar,
  });
  final String classTag;
  final String name;

  /// 이름 앞 동그란 프로필 사진 (ResidentCircle).
  final Widget? avatar;

  /// '38.2°C'
  final String tempText;

  /// '+1.4°C 급상승'
  final String diffText;
  final Color tempColor;

  /// '09:51 재측정 예정'
  final String scheduleText;

  /// '10분 후'
  final String scheduleRight;

  /// 내가 이미 확인했으면 [확인함] (누를 수 없음).
  final bool acknowledged;
  final VoidCallback onAcknowledge;
  final VoidCallback onRemeasure;

  /// 카드 본문 (이상 건 상세).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DsCard(
      borderColor: Ds.borderDanger,
      shadow: Ds.shadowDanger,
      topStripe: Ds.red500,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Row(children: [
              const PulseDot(),
              const SizedBox(width: 8),
              _tagBox(DsTag(classTag, tone: TagTone.red)),
              const SizedBox(width: 8),
              if (avatar != null) ...[avatar!, const SizedBox(width: 8)],
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: T.heading, height: 1.56, fontWeight: FontWeight.w700, color: Ds.gray900)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(tempText,
                style: TextStyle(fontSize: T.title, height: 1.4, fontWeight: FontWeight.w700, color: tempColor, fontFeatures: tabular)),
            Text(diffText,
                style: TextStyle(fontSize: T.micro, height: 1.5, fontWeight: FontWeight.w500, color: tempColor, fontFeatures: tabular)),
          ]),
        ]),
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Ds.gray50, borderRadius: BorderRadius.circular(Radii.inner)),
          child: Row(children: [
            const Icon(Icons.schedule_rounded, size: 17, color: Ds.blue500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(scheduleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w600, color: Ds.gray900, fontFeatures: tabular)),
            ),
            const SizedBox(width: 8),
            Text(scheduleRight, style: const TextStyle(fontSize: T.micro, height: 1.45, color: Ds.gray500, fontFeatures: tabular)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: acknowledged
                ? const HoButton('확인함', onTap: null, bg: Ds.gray100, fg: Ds.gray500, icon: Icons.check_rounded, iconSize: 16)
                : HoButton('확인했어요', onTap: onAcknowledge, bg: Ds.gray100, fg: Ds.gray800),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: HoButton('재측정하기',
                onTap: onRemeasure, bg: Ds.violet500, fg: Colors.white, icon: Icons.thermostat_rounded, shadow: Ds.shadowSm),
          ),
        ]),
      ]),
    );
  }
}

// ── TodoRow

class TodoRow extends StatelessWidget {
  const TodoRow({
    super.key,
    required this.classTag,
    required this.name,
    required this.timeText,
    required this.line,
    required this.onDone,
    this.onName,
    this.onTap,
    this.unread = false,
    this.avatar,
  });
  final String classTag;
  final String name;
  final Widget? avatar;

  /// '어제 15:20'
  final String timeText;

  /// '재측정 필요 (37.5°C 주의)'
  final String line;
  final VoidCallback onDone;
  final VoidCallback? onName;
  final VoidCallback? onTap;
  final bool unread;

  @override
  Widget build(BuildContext context) => DsCard(
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _tagBox(_SmallTag(classTag)),
                const SizedBox(width: 6),
                Flexible(
                  child: _NameLink(name,
                      leading: avatar,
                      onTap: onName,
                      style: const TextStyle(fontSize: T.body, height: 1.43, fontWeight: FontWeight.w700, color: Ds.gray900)),
                ),
                const SizedBox(width: 6),
                if (unread) ...[
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Ds.blue500, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                ],
                Text(timeText, style: const TextStyle(fontSize: T.micro, height: 1.5, color: Ds.gray500, fontFeatures: tabular)),
              ]),
              const SizedBox(height: 4),
              Text(line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w500, color: Ds.gray600)),
            ]),
          ),
          const SizedBox(width: 12),
          HoButton('완료',
              onTap: onDone,
              bg: Ds.blue50,
              fg: Ds.blue500,
              height: 36,
              hPad: 14,
              fontSize: T.caption,
              weight: FontWeight.w700),
        ]),
      );
}

// ── FeedCard

/// FeedCard · vital: 체온 기록.
class VitalFeedCard extends StatelessWidget {
  const VitalFeedCard({
    super.key,
    required this.classTag,
    required this.name,
    required this.timeText,
    required this.tempText,
    required this.judgeText,
    required this.judgeColor,
    required this.sideText,
    required this.checked,
    this.voided = false,
    this.doneText,
    this.onRemeasure,
    this.onName,
    this.onTap,
    this.unread = false,
    this.avatar,
  });
  final String classTag;
  final String name;
  final Widget? avatar;
  final String timeText;

  /// '37.6°C'
  final String tempText;

  /// '(+0.5°) 주의'
  final String judgeText;
  final Color judgeColor;

  /// '기한 30분' · '평소 37.1°C'
  final String sideText;

  /// 담당 확인완료
  final bool checked;

  /// 잘못 잰 값 (무효)
  final bool voided;

  /// 할 일을 끝냈으면 '10:11 재측정 38.4°C'.
  final String? doneText;

  /// 열린 재측정 할 일이 있으면 [재측정 완료].
  final VoidCallback? onRemeasure;
  final VoidCallback? onName;
  final VoidCallback? onTap;
  final bool unread;

  @override
  Widget build(BuildContext context) => DsCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _tagBox(DsTag(classTag)),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _NameLink(name,
                    leading: avatar,
                    onTap: onName,
                    style: const TextStyle(fontSize: T.bodyLg, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900)),
              ),
            ),
            _TimeText(timeText, unread: unread),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Ds.gray50, borderRadius: BorderRadius.circular(Radii.inner)),
            child: Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(tempText,
                          style: TextStyle(
                            fontSize: T.headline,
                            height: 1.33,
                            fontWeight: FontWeight.w700,
                            color: voided ? Ds.gray400 : Ds.gray900,
                            letterSpacing: -0.6,
                            fontFeatures: tabular,
                            decoration: voided ? TextDecoration.lineThrough : null,
                          )),
                      const SizedBox(width: 6),
                      Text(judgeText,
                          style: TextStyle(
                              fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w600, color: judgeColor, fontFeatures: tabular)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(sideText,
                  style: const TextStyle(
                      fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w500, color: Ds.gray600, fontFeatures: tabular)),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Icon(checked ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16, color: checked ? Ds.blue500 : Ds.gray400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(checked ? '담당 확인완료' : '담당 미확인',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w500, color: Ds.gray500)),
              ),
              if (onRemeasure != null)
                HoButton('재측정 완료',
                    onTap: onRemeasure, bg: Ds.gray900, fg: Colors.white, height: 36, hPad: 16, fontSize: T.caption)
              else if (doneText != null)
                Text(doneText!,
                    style: const TextStyle(
                        fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w500, color: Ds.gray600, fontFeatures: tabular)),
            ]),
          ),
        ]),
      );
}

/// FeedCard · notice-all: 전체 공지.
class NoticeAllFeedCard extends StatelessWidget {
  const NoticeAllFeedCard({super.key, required this.timeText, this.title, required this.body, this.pinned = false, this.onTap, this.unread = false});
  final String timeText;
  final String? title;
  final String body;
  final bool pinned;
  final VoidCallback? onTap;
  final bool unread;

  @override
  Widget build(BuildContext context) => DsCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.campaign_outlined, size: 15, color: Ds.blue500),
            const SizedBox(width: 4),
            const Text('전체 공지', style: TextStyle(fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w600, color: Ds.blue500)),
            if (pinned) ...[
              const SizedBox(width: 6),
              const Icon(Icons.push_pin_rounded, size: 13, color: Ds.gray400, semanticLabel: '고정'),
            ],
            const Spacer(),
            _TimeText(timeText, unread: unread),
          ]),
          if (title != null && title!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(title!, style: const TextStyle(fontSize: T.body, height: 1.375, fontWeight: FontWeight.w700, color: Ds.gray900)),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: T.caption, height: 1.625, color: Ds.gray600)),
          ],
        ]),
      );
}

/// FeedCard · notice-class: 반 공지. [highlight] 글자는 파랑 굵게.
class NoticeClassFeedCard extends StatelessWidget {
  const NoticeClassFeedCard({
    super.key,
    required this.classTag,
    required this.author,
    required this.timeText,
    required this.body,
    this.highlight,
    this.onTap,
    this.unread = false,
  });
  final String classTag;

  /// '박지은 담임'
  final String author;
  final String timeText;
  final String body;
  final Pattern? highlight;
  final VoidCallback? onTap;
  final bool unread;

  List<TextSpan> _spans() {
    final h = highlight;
    if (h == null) return [TextSpan(text: body)];
    final out = <TextSpan>[];
    var i = 0;
    for (final m in h.allMatches(body)) {
      if (m.start > i) out.add(TextSpan(text: body.substring(i, m.start)));
      out.add(TextSpan(text: m.group(0), style: const TextStyle(fontWeight: FontWeight.w700, color: Ds.blue500)));
      i = m.end;
    }
    if (i < body.length) out.add(TextSpan(text: body.substring(i)));
    return out;
  }

  @override
  Widget build(BuildContext context) => DsCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _tagBox(DsTag(classTag, tone: TagTone.blue)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w500, color: Ds.gray600)),
            ),
            _TimeText(timeText, unread: unread),
          ]),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: _spans()),
              style: const TextStyle(fontSize: T.caption, height: 1.625, fontWeight: FontWeight.w500, color: Ds.gray800)),
        ]),
      );
}

/// FeedCard · observation: 관찰 기록 · 감각 메모.
class ObservationFeedCard extends StatelessWidget {
  const ObservationFeedCard({
    super.key,
    required this.classTag,
    required this.name,
    required this.author,
    required this.timeText,
    required this.body,
    required this.likes,
    required this.liked,
    required this.onLike,
    this.onName,
    this.onTap,
    this.unread = false,
    this.avatar,
  });
  final String classTag;
  final String name;
  final Widget? avatar;

  /// 쓴 사람 이름. 예: '최민호'
  final String author;
  final String timeText;
  final String body;
  final int likes;

  /// 내가 이미 눌렀으면 파랑 (다시 누를 수 없음).
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback? onName;
  final VoidCallback? onTap;
  final bool unread;

  @override
  Widget build(BuildContext context) => DsCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _tagBox(DsTag(classTag)),
            const SizedBox(width: 6),
            Flexible(
              child: _NameLink(name,
                  leading: avatar,
                  onTap: onName,
                  style: const TextStyle(fontSize: T.body, height: 1.43, fontWeight: FontWeight.w700, color: Ds.gray900)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: T.caption, height: 1.33, color: Ds.gray500)),
            ),
            _TimeText(timeText, unread: unread),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Ds.gray50, borderRadius: BorderRadius.circular(Radii.inner)),
            child: Text('"$body"', style: const TextStyle(fontSize: T.caption, height: 1.625, color: Ds.gray700)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              label: liked ? '좋아요 $likes명, 눌렀어요' : '좋아요 $likes명',
              child: HoButton('$likes명',
                  onTap: liked ? null : onLike,
                  bg: liked ? Ds.blue50 : Ds.gray100,
                  fg: liked ? Ds.blue500 : Ds.gray700,
                  height: 32,
                  hPad: 12,
                  radius: Radii.pill,
                  fontSize: T.caption,
                  icon: Icons.thumb_up_rounded,
                  iconSize: 15),
            ),
          ),
        ]),
      );
}

// ── Fab

class WriteFab extends StatelessWidget {
  const WriteFab({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HoButton('기록하기',
      onTap: onTap,
      bg: Ds.violet500,
      fg: Colors.white,
      height: 48,
      hPad: 20,
      radius: Radii.pill,
      fontSize: T.body,
      weight: FontWeight.w700,
      icon: Icons.edit_outlined,
      iconSize: 19,
      gap: 6,
      shadow: Ds.shadowPrimary,
      pressScale: 0.95);
}

/// 거른 결과가 비었을 때.
class HoEmpty extends StatelessWidget {
  const HoEmpty(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(text, style: const TextStyle(fontSize: T.body, color: Ds.gray500))),
      );
}
