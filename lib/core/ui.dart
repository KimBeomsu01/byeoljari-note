// 공통 화면 부품 (docs/design.md). 화면마다 비슷한 것을 새로 만들지 말고 이걸 쓴다.
import 'package:flutter/material.dart';

import 'avatar.dart';
import 'models.dart';
import 'theme.dart';

/// 평소 체온과의 차이를 말로: "평소보다 1.4도 높아요" / "평소와 같아요".
String plainDiff(int diff) {
  if (diff.abs() < 1) return '평소와 같아요';
  final v = (diff.abs() / 10).toStringAsFixed(1);
  return diff > 0 ? '평소보다 $v도 높아요' : '평소보다 $v도 낮아요';
}

/// 시각 "09:41".
String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 구역 제목. 굵고 크게, 옆에 개수.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.count, this.trailing});
  final String text;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, Gap.xl, 0, Gap.m),
        child: Row(children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: text),
                if (count != null) TextSpan(text: '  $count', style: const TextStyle(color: inkSub)),
              ]),
              style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain),
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// 흰 카드. [accent]가 있으면 왼쪽에 굵은 색 띠 (상태를 색 + 글자로 함께 보여줄 때).
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.accent, this.background, this.onTap, this.padding});
  final Widget child;
  final Color? accent;
  final Color? background;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding ?? const EdgeInsets.all(Gap.l), child: child);
    return Material(
      color: background ?? surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: accent ?? line, width: accent == null ? 1 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: accent == null
            ? body
            : IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(width: 8, color: accent),
                  Expanded(child: body),
                ]),
              ),
      ),
    );
  }
}

/// 판정 표시: 기호 + 글자 + 색 (색만으로 구분하지 않는다).
class StageTag extends StatelessWidget {
  const StageTag(this.stage, {super.key, this.value, this.large = false});
  final Stage stage;
  final int? value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = stageColors[stage]!;
    final v = value == null ? '' : ' ${(value! / 10).toStringAsFixed(1)}℃';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 8 : 4),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Text('${stage.symbol} ${stage.label}$v',
          style: TextStyle(fontSize: large ? T.body : T.caption, fontWeight: FontWeight.w800, color: c.ink)),
    );
  }
}

/// 상태 알약 (예: "긴급", "이상 대응", "새 기록"). 글자 + 색.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.color, this.background, this.filled = false});
  final String text;
  final Color color;
  final Color? background;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? color : (background ?? surface),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(text, style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: filled ? Colors.white : color)),
      );
}

/// 별님 동그라미. [residentId]가 있으면 시제품 얼굴 그림, 없으면 반 색 + 이름 글자.
class ResidentAvatar extends StatelessWidget {
  const ResidentAvatar({super.key, required this.name, required this.classColor, this.size = 48, this.residentId, this.ring});
  final String name;
  final int classColor;
  final double size;
  final String? residentId;
  final Color? ring;

  @override
  Widget build(BuildContext context) => residentId != null
      ? FaceAvatar.resident(residentId!, size: size, ring: ring)
      : Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color.alphaBlend(Color(classColor).withValues(alpha: 0.35), surface),
          shape: BoxShape.circle,
          border: Border.all(color: Color(classColor), width: 2),
        ),
        child: Text(name.length > 1 ? name.substring(1, 2) : name,
            style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: inkMain)),
      );
}

/// 빈 상태: 무엇이 비었는지 + 할 수 있는 것.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xl),
        child: Column(children: [
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: T.body, color: inkSub)),
          if (action != null) ...[const SizedBox(height: Gap.m), action!],
        ]),
      );
}
