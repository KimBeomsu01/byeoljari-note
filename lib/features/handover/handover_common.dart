// 인수인계 화면들이 같이 쓰는 작은 도구: 시각 표시, 토스트, 아바타, 칩, 화면 상태.
// 색·글자 크기는 docs/design.md와 lib/core/theme.dart의 토큰만 쓴다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';

/// 할 일 상자 색 (판정 '주의' 색을 빌려 쓴다: 노랑 계열, 글자는 진하게).
final StageColors hoTask = stageColors[Stage.caution]!;

/// 완료·확인함 색 (판정 '평소' 초록 계열).
final StageColors hoDone = stageColors[Stage.normal]!;

/// 전체 공지 카드 바탕 (아주 옅은 남색).
final Color hoNoticeBg = Color.alphaBlend(brandDark.withValues(alpha: 0.05), surface);

String two(int n) => n.toString().padLeft(2, '0');
String hm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

/// "09:20" (오늘) · "어제 15:20" · "10월 26일 09:30"
String whenLabel(DateTime t, DateTime now) {
  final d0 = DateTime(now.year, now.month, now.day);
  final d = DateTime(t.year, t.month, t.day);
  final days = d0.difference(d).inDays;
  if (days == 0) return hm(t);
  if (days == 1) return '어제 ${hm(t)}';
  if (t.year != now.year) return '${t.year}년 ${t.month}월 ${t.day}일 ${hm(t)}';
  return '${t.month}월 ${t.day}일 ${hm(t)}';
}

/// 할 일 기한 표시: 프리셋이 있으면 프리셋, 없으면 "10:00까지".
String dueLabel(Task t, DateTime now) {
  if (t.duePreset != null) return t.duePreset!;
  if (t.dueAt != null) return '${whenLabel(t.dueAt!, now)}까지';
  return '기한 없음';
}

/// 토스트: 화면 아래쪽에 3초 (통합 명세 5-9). 모양은 테마(snackBarTheme)를 따른다.
void showToast(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
}

/// 선생님(직원) 이름 첫 글자 동그라미. 별님은 core의 ResidentAvatar를 쓴다.
class NameAvatar extends StatelessWidget {
  const NameAvatar({super.key, required this.name, this.size = 32, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? paper,
            shape: BoxShape.circle,
            border: Border.all(color: line, width: 1.5),
          ),
          child: Text(
            name.isEmpty ? '?' : name.characters.first,
            textScaler: TextScaler.noScaling, // 동그라미 안 글자는 크기 고정 (동그라미가 커지지 않으므로)
            style: TextStyle(
              fontSize: size * 0.45 < T.caption ? T.caption : size * 0.45,
              fontWeight: FontWeight.w700,
              color: inkMain,
              height: 1,
            ),
          ),
        ),
      );
}

/// '새 기록' 표시: 노란 점 + 글자 (색만으로 뜻을 전하지 않는다).
class NewMark extends StatelessWidget {
  const NewMark({super.key, this.text = '새 기록'});
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const YellowDot(),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: inkMain)),
        ),
      ]);
}

/// 노란 점 ('새 기록'에만 쓴다).
class YellowDot extends StatelessWidget {
  const YellowDot({super.key, this.size = 12});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: starYellow, shape: BoxShape.circle, border: Border.all(color: inkMain, width: 1)),
      );
}

/// 하나 고르기 칩. 글자 길이에 맞춰 늘어나고 잘리지 않는다 (높이 52 이상).
class HoChip extends StatelessWidget {
  const HoChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.trailing,
    this.semanticsLabel,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 반 색 점.
  final Color? dot;
  final Widget? trailing;
  final String? semanticsLabel;

  /// 고르기 칩이 아닌 "누르면 넣기" 칩일 때의 앞 아이콘 (선택 표시 ✓ 대신).
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: icon == null ? selected : null,
        label: semanticsLabel ?? label,
        excludeSemantics: true,
        child: Material(
          color: selected ? brandDark : surface,
          shape: StadiumBorder(side: BorderSide(color: selected ? brandDark : line, width: 1.5)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 56),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (dot != null) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? Colors.white : inkMain, width: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (icon != null) ...[
                  Icon(icon, size: 20, color: selected ? Colors.white : brandDark),
                  const SizedBox(width: 4),
                ] else if (selected) ...[
                  const Icon(Icons.check, size: 20, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: T.body,
                        color: selected ? Colors.white : inkMain,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      )),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ]),
            ),
          ),
        ),
      );
}

/// 작은 숫자 배지 (안 본 기록 수). 노란 바탕 + 진한 글자.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 26),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: starYellow,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: inkMain, width: 1),
        ),
        child: Text('$count',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: inkMain)),
      );
}

/// 별님별 기록에서 고른 반. 작성 시트의 기본 반으로도 쓴다 (인수인계 3.4).
class HandoverClassController extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String classId) => state = classId;
}

final handoverClassProvider = NotifierProvider<HandoverClassController, String?>(HandoverClassController.new);

/// 이번 세션에서 새로 쓴 기록 (테두리 강조, 인수인계 3.1).
class SessionWrittenController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void add(String entryId) => state = {...state, entryId};
}

final sessionWrittenProvider = NotifierProvider<SessionWrittenController, Set<String>>(SessionWrittenController.new);
