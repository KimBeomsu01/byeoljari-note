// 인수인계 화면들이 같이 쓰는 작은 도구: 시각 표시, 토스트, 아바타, 화면 상태.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme.dart';

/// 인수인계 디자인 토큰 (인수인계 명세 13장).
const Color hoCardLine = Color(0xFFE7EBEF);
const Color hoSummaryBg = Color(0xFF2F3A34);
const Color hoNoticeBg = Color(0xFFFBF6EA);
const Color hoNoticeLine = Color(0xFFE3CF9F);
const Color hoTaskBg = Color(0xFFFBF1DD);
const Color hoTaskLine = Color(0xFFF0DCB4);
const Color hoTaskInk = Color(0xFF7F5510);
const Color hoDoneBg = Color(0xFFE9F3ED);
const Color hoDoneLine = Color(0xFFCFE3D6);
const Color hoDoneInk = Color(0xFF3F6C53);
const Color hoUnreadBadge = Color(0xFFD9A44E);

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

/// 토스트: 화면 아래쪽에 3초 (통합 명세 5-9).
void showToast(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
}

/// 이름 첫 글자 원형 아바타.
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
          decoration: BoxDecoration(color: color ?? const Color(0xFFDCE5DF), shape: BoxShape.circle),
          child: Text(
            name.isEmpty ? '?' : name.characters.first,
            style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: inkMain),
          ),
        ),
      );
}

/// 판정 기호 + 글자 + 색 (색만으로 뜻을 전하지 않는다, 5-7).
class StageTag extends StatelessWidget {
  const StageTag({super.key, required this.stage, this.text});
  final Stage stage;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final c = stageColors[stage]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(99), border: Border.all(color: c.line)),
      child: Text('${stage.symbol} ${text ?? stage.label}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.ink)),
    );
  }
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
