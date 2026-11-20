// PC 03 의료 호출함(간호사) · 04 의료진 협진 포털(의사)이 함께 쓰는 것:
// 목록 정렬 · 지금 보는 호출 · 판(패널) · 꼬리표 · 버튼 · 체온 문구 · 처방약 한 줄.
// 수치는 Claude Design PcMedicalCalls / PcDoctorPortal 의 px 그대로.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'pc_shell.dart';

// ── 원본 hex (tokens 에 없는 Tailwind 색)
/// 고온 기준선 (체온 추이 그래프).
const int hotTemp = 380;

const mcRed50 = Color(0xFFFEF2F2);
const mcRed100 = Color(0xFFFEE2E2);
const mcRed200 = Color(0xFFFECACA);
const mcAmber50 = Color(0xFFFFFBEB);
const mcAmber200 = Color(0xFFFDE68A);
const mcAmber800 = Color(0xFF92400E);
const mcBlue100 = Color(0xFFDBEAFE);
const mcBlue200 = Color(0xFFBFDBFE);
const mcGreen100 = Color(0xFFD1FAE5);
const mcGray200a60 = Color(0x99E5E8EB);
const mcGray200a70 = Color(0xB3E5E8EB);
const mcBlueLine = Color(0x333182F6);
const mcHint = Color(0xFF6B7280);

/// 판 그림자 `0 2px 8px rgba(0,0,0,.03)`.
const mcPanelShadow = [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))];

/// 파란 버튼 그림자 `0 4px 12px rgba(49,130,246,.3)`.
const mcBlueShadow = [BoxShadow(color: Color(0x4D3182F6), blurRadius: 12, offset: Offset(0, 4))];

/// 글자 모양. [mono]는 숫자 고정폭 (원본 font-mono).
TextStyle mcText(double size,
        {FontWeight weight = FontWeight.w400, Color color = Ds.gray900, double? height = 1.5, bool mono = false}) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color, height: height, fontFeatures: mono ? tabular : null);

// ── 고른 호출 · 펼친 채팅방

/// 지금 보는 호출: 고른 호출, 없으면 목록의 첫 열린 호출 (그것도 없으면 가장 최근 호출).
/// 의사는 자기에게 온 호출만 고를 수 있다.
MedicalCall? shownCall(WidgetRef ref) {
  final repo = ref.watch(repoProvider);
  final id = ref.watch(selectedCallProvider);
  final me = ref.watch(currentUserProvider);
  final doctor = ref.watch(screenKindProvider) == 'doctor' || repo.staff(me).role == Role.doctor;
  final all = doctor ? repo.callsForDoctor(me) : repo.calls;
  if (id != null) {
    for (final c in all) {
      if (c.id == id) return c;
    }
  }
  return all.where((c) => c.isOpen).firstOrNull ?? all.firstOrNull;
}

// ── 글

/// '(남 · 만 19세)' / '(남, 만 19세)'. 둘 다 없으면 빈 글.
String sexAge(Resident r, {String sep = ' · '}) {
  final parts = [if (r.sex != null) r.sex!, if (r.age != null) '만 ${r.age}세'];
  return parts.isEmpty ? '' : '(${parts.join(sep)})';
}

/// '이서준 별님' (이름이 이미 '별님'으로 끝나면 그대로).
String starName(String name) => name.endsWith('별님') ? name : '$name 별님';

/// 금기 글의 첫 줄 (나머지 줄은 [cautionRest]).
String? cautionHead(Resident r) {
  final c = r.cautions?.trim();
  if (c == null || c.isEmpty) return null;
  return c.split('\n').first.trim();
}

String? cautionRest(Resident r) {
  final c = r.cautions?.trim();
  if (c == null || !c.contains('\n')) return null;
  final rest = c.split('\n').skip(1).join(' ').trim();
  return rest.isEmpty ? null : rest;
}

/// 측정에 저장된 판정 이름 → [Stage] (없거나 모르면 null).
Stage? stageNamed(Object? name) {
  for (final s in Stage.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// 저장된 판정을 말로 (새로 판정하지 않는다). [short]는 '경보'를 뺀다.
String vitalWord(Stage? stage, int diff, {bool short = false}) => switch (stage) {
      Stage.danger || Stage.abnormal => diff > 0 ? (short ? '급상승' : '급상승 경보') : stage!.label,
      Stage.low => short ? '저온' : '저온 경보',
      Stage.caution => '주의',
      Stage.normal => '평소 범위',
      null => '',
    };

/// '▲ +1.3°C' / '▼ −0.6°C' / '+0.0°C'
String arrowDiff(int diff) => '${diff > 0 ? '▲ ' : diff < 0 ? '▼ ' : ''}${formatDiff(diff)}°C';

/// 저장된 판정의 색: 이상·위험 = 빨강, 저온 = 파랑, 그 밖에는 평소 차이 색.
Color vitalColor(Stage? stage, int diff) => switch (stage) {
      Stage.abnormal || Stage.danger => Ds.red500,
      Stage.low => Ds.blue500,
      _ => diffColor(diff),
    };

// ── 부품

/// 흰 판 (radius 16, gray-200 테두리).
class McPanel extends StatelessWidget {
  const McPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Ds.gray200),
          boxShadow: mcPanelShadow,
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(15), child: child),
      );
}

/// 판 안의 흰 카드 (radius 24, 그림자 sm).
class McCard extends StatelessWidget {
  const McCard({super.key, required this.children, this.padding = 14, this.gap = 10});
  final List<Widget> children;
  final double padding;
  final double gap;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Ds.gray200),
          boxShadow: Ds.shadowSm,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
        ]),
      );
}

/// 카드 제목 줄: 파란 아이콘 + 굵은 글 + 오른쪽 부품.
class McCardTitle extends StatelessWidget {
  const McCardTitle(this.text, {super.key, required this.icon, this.trailing, this.size = 12.5, this.gap = 6});
  final String text;
  final IconData icon;
  final Widget? trailing;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 17, color: Ds.blue500),
        SizedBox(width: gap),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(size, weight: FontWeight.w700))),
        ?trailing,
      ]);
}

/// 작은 꼬리표.
class McPill extends StatelessWidget {
  const McPill(
    this.text, {
    super.key,
    required this.bg,
    required this.fg,
    this.border,
    this.size = 9.5,
    this.weight = FontWeight.w700,
    this.padding = const EdgeInsets.symmetric(horizontal: 6),
    this.radius = 999,
    this.mono = false,
    this.icon,
  });
  final String text;
  final Color bg;
  final Color fg;
  final Color? border;
  final double size;
  final FontWeight weight;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool mono;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: size + 3, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(size, weight: weight, color: fg, mono: mono)),
          ),
        ]),
      );
}

/// 마우스를 올렸는지 알려 주는 감싸개 (pc.css hover 규칙).
class McHover extends StatefulWidget {
  const McHover({super.key, required this.builder});
  final Widget Function(bool hovered) builder;

  @override
  State<McHover> createState() => _McHoverState();
}

class _McHoverState extends State<McHover> {
  bool _on = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _on = true),
        onExit: (_) => setState(() => _on = false),
        child: widget.builder(_on),
      );
}

/// 둥근 아이콘 버튼 (hover gray-100).
class McIconButton extends StatelessWidget {
  const McIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 32,
    this.iconSize = 18,
    this.color = Ds.gray500,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            hoverColor: Ds.gray100,
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Icon(icon, size: iconSize, color: color)),
          ),
        ),
      );
}

/// 입력 아래 작은 회색 단추 (+ 바이탈 첨부 · 사진 · 청진 파일 · 투약 이력).
class McChipButton extends StatelessWidget {
  const McChipButton({super.key, required this.icon, required this.label, required this.onTap, this.iconColor = Ds.gray500, this.big = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final bool big;

  @override
  Widget build(BuildContext context) => Material(
        color: Ds.gray100,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: Ds.gray200,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: big ? 12 : 10, vertical: big ? 4 : 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: big ? 15 : 14, color: iconColor),
              const SizedBox(width: 4),
              Text(label, style: mcText(big ? 11.5 : 11, weight: FontWeight.w600, color: Ds.gray700)),
            ]),
          ),
        ),
      );
}

/// 파란 주요 버튼 (hover blue-600, 그림자).
class McBlueButton extends StatelessWidget {
  const McBlueButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.height = 36,
    this.fontSize = 12,
    this.iconSize = 16,
    this.padH = 16,
    this.gap = 6,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final double height;
  final double fontSize;
  final double iconSize;
  final double padH;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: on ? mcBlueShadow : null),
      child: Material(
        color: on ? Ds.blue500 : Ds.gray300,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: Ds.blue600,
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: padH),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: iconSize, color: Colors.white), SizedBox(width: gap)],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mcText(fontSize, weight: FontWeight.w700, color: Colors.white, height: 1.2)),
              ),
              if (trailingIcon != null) ...[SizedBox(width: gap), Icon(trailingIcon, size: iconSize, color: Colors.white)],
            ]),
          ),
        ),
      ),
    );
  }
}

/// 회색 보조 버튼 (gray-100, 테두리 gray-200, hover gray-200).
class McGrayButton extends StatelessWidget {
  const McGrayButton({super.key, required this.label, required this.onTap, this.icon, this.height = 36, this.tooltip});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final b = Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Ds.gray100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Ds.gray200)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: Ds.gray200,
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 16, color: Ds.gray700), const SizedBox(width: 4)],
              Text(label, style: mcText(12, weight: FontWeight.w700, color: Ds.gray700, height: 1.2)),
            ]),
          ),
        ),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// 둥근 점 (살아 있음 표시).
class McDot extends StatelessWidget {
  const McDot({super.key, required this.color, this.size = 6, this.ring});
  final Color color;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: ring == null ? null : [BoxShadow(color: ring!, spreadRadius: 2)],
        ),
      );
}

/// 처방약 한 줄 (의사가 쓴 이름 · 용법 · 양 그대로).
class RxItemView extends StatelessWidget {
  const RxItemView(this.item, {super.key, this.highlight = false});
  final RxItem item;

  /// 양 꼬리표를 파랑으로.
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Ds.gray100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: mcGray200a70),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name.isEmpty ? '(이름 없음)' : item.name, style: mcText(12, weight: FontWeight.w700)),
              if (item.usage.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(item.usage, style: mcText(11, color: Ds.gray600)),
              ],
            ]),
          ),
          if (item.amount.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Ds.gray200),
              ),
              child: Text(item.amount,
                  style: mcText(11, weight: FontWeight.w700, color: highlight ? Ds.blue500 : Ds.gray700, mono: true)),
            ),
          ],
        ]),
      );
}

/// 처방 상태 꼬리표: 진료 대기 · 처방 작성 중 · 발행됨.
class RxStatusPill extends StatelessWidget {
  const RxStatusPill(this.p, {super.key});
  final Prescription? p;

  @override
  Widget build(BuildContext context) {
    final (text, bg, fg, line) = p == null
        ? ('진료 대기', Ds.blue50, Ds.blue500, mcBlueLine)
        : p!.issued
            ? ('발행됨', Ds.green50, Ds.green500, const Color(0x4D03B26C))
            : ('처방 작성 중', Ds.orange50, const Color(0xFFE07A00), const Color(0x66FF8A00));
    return McPill(text,
        bg: bg, fg: fg, border: line, size: 10.5, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2));
  }
}
