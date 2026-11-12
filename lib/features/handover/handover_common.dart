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

/// 전체 공지 카드 (시제품 #fbf6ea 바탕 / #e3cf9f 테두리).
const Color hoNoticeBg = Color(0xFFFBF6EA);
const Color hoNoticeLine = Color(0xFFE3CF9F);

/// 할 일 상자 (시제품: 열림 #fbf1dd / #f0dcb4 / #7f5510).
const Color hoTaskBg = Color(0xFFFBF1DD);
const Color hoTaskLine = Color(0xFFF0DCB4);
const Color hoTaskInk = Color(0xFF7F5510);

/// 완료·확인함 (시제품 #e9f3ed / #cfe3d6 / #3f6c53).
const Color hoDoneBg = Color(0xFFE9F3ED);
const Color hoDoneLine = Color(0xFFCFE3D6);
const Color hoDoneInk = Color(0xFF3F6C53);

/// 카드 아래 칸 구분선 (시제품 #eef0ec).
const Color hoFootLine = Color(0xFFFBEAE5);

/// 세그먼트·답글 펼침 바탕 (시제품 #eceee6).
const Color hoSegBg = Color(0xFFFBE7E2);

/// 어두운 요약 카드 위 글자 (시제품 #d7ded9). 짙은 바탕 위라 대비가 충분하다.
const Color hoOnDarkSub = Color(0xFFD7DED9);

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

/// '새 기록' 표시: 시제품의 작은 알약 (노란 점 + 글자, 색만으로 뜻을 전하지 않는다).
class NewMark extends StatelessWidget {
  const NewMark({super.key, this.text = '새 기록'});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
    decoration: BoxDecoration(
      color: hoTaskBg,
      borderRadius: BorderRadius.circular(Radii.pill),
      border: Border.all(color: starYellow),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const YellowDot(size: 9),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: hoTaskInk, height: 1.3),
          ),
        ),
      ],
    ),
  );
}

/// 노란 점 ('새 기록'에만 쓴다).
class YellowDot extends StatelessWidget {
  const YellowDot({super.key, this.size = 12});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(color: starYellow, shape: BoxShape.circle),
  );
}

/// 하나 고르기 칩 (시제품 .chip: 흰 바탕 · 옅은 테두리, 고르면 짙은 녹회색). 높이 48 이상.
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
      shape: StadiumBorder(side: BorderSide(color: selected ? brandDark : line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: tapHeight, minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: Colors.white, width: 1.5) : null,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              if (icon != null) ...[
                Icon(icon, size: 20, color: selected ? Colors.white : brandDark),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: T.body,
                    color: selected ? Colors.white : inkMain,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 7), trailing!],
            ],
          ),
        ),
      ),
    ),
  );
}

/// 작은 숫자 배지 (안 본 기록 수). 시제품의 노란 배지 (#d9a44e), 글자는 읽기 쉽게 진하게.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 26),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(color: starYellow, borderRadius: BorderRadius.circular(Radii.pill)),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: inkMain),
    ),
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
