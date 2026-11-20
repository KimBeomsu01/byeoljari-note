// PC 의료 호출함 · 협진 포털의 대화 조각: 메시지(체온 첨부 · 말풍선 · 안내 줄) · 입력 상자 · 예시 대화.
// 실제 통화·화상·파일 올리기는 없다. 할 수 없는 일은 토스트로 알리고 거짓 결과를 말하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'pc_calls_common.dart';

/// 회색 입력 상자 (focus: 흰 바탕 + 파란 테).
class McField extends StatelessWidget {
  const McField({
    super.key,
    required this.controller,
    required this.hint,
    required this.height,
    required this.fontSize,
    this.focusNode,
    this.padH = 14,
    this.action,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.prefix,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final double height;
  final double fontSize;
  final double padH;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final IconData? prefix;

  @override
  Widget build(BuildContext context) {
    final lineH = fontSize * 1.5;
    OutlineInputBorder line(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: action,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: mcText(fontSize),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintMaxLines: 1,
        hintStyle: mcText(fontSize, color: mcHint),
        filled: true,
        fillColor: Ds.gray100,
        hoverColor: Colors.transparent,
        prefixIcon: prefix == null ? null : Icon(prefix, size: 16, color: Ds.gray500),
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 16),
        contentPadding: EdgeInsets.symmetric(horizontal: padH, vertical: ((height - lineH) / 2).clamp(4, 20)),
        border: line(Ds.gray200, 1),
        enabledBorder: line(Ds.gray200, 1),
        focusedBorder: line(const Color(0x663182F6), 2),
      ),
    );
  }
}

/// 메시지 한 개: 체온 첨부 · 말풍선 · 안내 줄.
class CareMessageView extends ConsumerWidget {
  const CareMessageView({required this.message, required this.resident, required this.me, required this.doctor});
  final CareMessage message;
  final Resident resident;
  final String me;
  final bool doctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final m = message;
    switch (m.kind) {
      case 'vital':
        final data = m.data;
        final value = data['value'] as int?;
        if (value == null) return _SystemLine(text: m.body, doctor: doctor);
        final diff = data['diff'] as int? ?? 0;
        final base = data['baseline'] as int?;
        final by = data['by'] as String?;
        final measuredAt = DateTime.tryParse(data['measuredAt'] as String? ?? '') ?? m.at;
        final auto = m.authorId == 'system';
        return VitalView(
          label: auto ? '시스템 자동 첨부 · 실시간 활력징후' : '${repo.staff(m.authorId).displayName} 첨부 · 최근 체온 기록',
          time: '${hhmm(m.at)} 전송',
          resident: '거주인: ${resident.name}${sexAge(resident, sep: ', ').isEmpty ? '' : ' ${sexAge(resident, sep: ', ')}'}',
          baseline: base,
          value: value,
          diff: diff,
          stage: stageNamed(data['stage']),
          footer: '측정 ${hhmm(measuredAt)}${by == null ? '' : ' · 기록 ${repo.staff(by).displayName}'}',
          doctor: doctor,
        );
      case 'system':
        return _SystemLine(text: m.body, doctor: doctor);
      default:
        final author = repo.staff(m.authorId);
        return TextBubble(
          mine: m.authorId == me,
          name: author.displayName,
          initial: author.role == Role.doctor ? '의' : (author.name.isEmpty ? '?' : author.name.substring(0, 1)),
          isDoctor: author.role == Role.doctor,
          time: hhmm(m.at),
          body: m.body,
          doctor: doctor,
        );
    }
  }
}

/// "시스템 자동 첨부 · 실시간 활력징후" 카드. 자료에 없는 값(SpO2·맥박)은 쓰지 않는다.
class VitalView extends StatelessWidget {
  const VitalView({
    super.key,
    required this.label,
    required this.time,
    required this.resident,
    required this.baseline,
    required this.value,
    required this.diff,
    required this.stage,
    required this.footer,
    this.doctor = false,
  });
  final String label;
  final String time;
  final String resident;
  final int? baseline;
  final int value;
  final int diff;
  final Stage? stage;
  final String footer;
  final bool doctor;

  @override
  Widget build(BuildContext context) {
    final color = vitalColor(stage, diff);
    final hot = color == Ds.red500;
    final d = doctor;
    return Container(
      padding: EdgeInsets.all(d ? 16 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ds.gray200),
        boxShadow: Ds.shadowSm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.sensors, size: 16, color: Ds.blue500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(11.5, weight: FontWeight.w700, color: Ds.blue500)),
          ),
          Text(time, style: mcText(11, color: Ds.gray500, mono: true)),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hot ? const Color(0xB3FEF2F2) : Ds.gray50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: hot ? mcRed100 : Ds.gray200),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(resident, style: mcText(d ? 13.5 : 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '평소 기저체온: '),
                    TextSpan(
                      text: baseline == null ? '기록 없음' : fmtC(baseline!),
                      style: const TextStyle(color: Ds.gray900, fontWeight: FontWeight.w700, fontFeatures: tabular),
                    ),
                  ]),
                  style: mcText(d ? 12 : 11.5, color: Ds.gray600),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtC(value), style: mcText(d ? 28 : 26, weight: FontWeight.w900, color: color, height: 1, mono: true)),
              const SizedBox(height: 2),
              Text('${arrowDiff(diff)} ${vitalWord(stage, diff)}'.trim(),
                  style: mcText(d ? 11 : 10.5, weight: FontWeight.w700, color: color)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Text(footer, textAlign: TextAlign.right, style: mcText(d ? 11 : 10.5, color: Ds.gray500)),
      ]),
    );
  }
}

/// 말풍선. 내 것은 오른쪽 파랑, 다른 사람은 왼쪽 흰색 (촉탁의는 파란 테 + "진료의").
class TextBubble extends StatelessWidget {
  const TextBubble({
    super.key,
    required this.mine,
    required this.name,
    required this.initial,
    required this.isDoctor,
    required this.time,
    required this.body,
    this.doctor = false,
  });
  final bool mine;
  final String name;
  final String initial;
  final bool isDoctor;
  final String time;
  final String body;
  final bool doctor;

  @override
  Widget build(BuildContext context) {
    final d = doctor;
    final side = d ? 48.0 : 40.0;
    final textStyle = mcText(d ? 13 : 12.5, height: 1.625, color: mine ? Colors.white : Ds.gray900);
    if (mine) {
      return Padding(
        padding: EdgeInsets.only(left: side),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(time, style: mcText(11, color: Ds.gray500, mono: true)),
            const SizedBox(width: 8),
            Text(name, style: mcText(11, weight: FontWeight.w700, color: Ds.blue500)),
          ]),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 512),
            padding: EdgeInsets.all(d ? 14 : 12),
            decoration: BoxDecoration(color: Ds.blue500, borderRadius: BorderRadius.circular(16), boxShadow: Ds.shadowSm),
            child: Text(body, style: textStyle),
          ),
        ]),
      );
    }
    return Padding(
      padding: EdgeInsets.only(right: side),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: isDoctor ? Ds.blue500 : Ds.gray200, shape: BoxShape.circle),
          child: Text(initial, style: mcText(12, weight: FontWeight.w700, color: isDoctor ? Colors.white : Ds.gray800, height: 1.2)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mcText(11, weight: FontWeight.w700, color: isDoctor ? Ds.gray900 : Ds.gray800)),
              ),
              if (isDoctor) ...[
                const SizedBox(width: 8),
                const McPill('진료의', bg: Ds.blue50, fg: Ds.blue500, size: 10, radius: 12),
              ],
              const SizedBox(width: 8),
              Text(time, style: mcText(11, color: Ds.gray500, mono: true)),
            ]),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxWidth: 512),
              padding: EdgeInsets.all(d ? 14 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDoctor ? mcBlue200 : Ds.gray200),
                boxShadow: isDoctor ? const [BoxShadow(color: mcBlue100, spreadRadius: 1), ...Ds.shadowSm] : Ds.shadowSm,
              ),
              child: Text(body, style: textStyle),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// 가운데 안내 줄 (입장 · 예약 · 완료 · 처방전 발행).
class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text, required this.doctor});
  final String text;
  final bool doctor;

  @override
  Widget build(BuildContext context) {
    final icon = text.contains('처방전')
        ? Icons.receipt_long_outlined
        : text.contains('화상')
            ? Icons.videocam_outlined
            : text.contains('완료')
                ? Icons.check_circle_outline
                : text.contains('입장')
                    ? Icons.meeting_room_outlined
                    : Icons.info_outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(alignment: Alignment.center, children: [
        Container(height: 1, color: Ds.gray200),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: doctor ? 4 : 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Ds.gray200),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: doctor ? 14 : 13, color: Ds.blue500),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: mcText(doctor ? 11 : 10.5, weight: FontWeight.w500, color: Ds.gray600)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// 개발 DB 예시 대화.
class ExampleCareMessages extends StatelessWidget {
  const ExampleCareMessages({required this.doctor});
  final bool doctor;

  @override
  Widget build(BuildContext context) => ExampleWrap(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          VitalView(
            label: '시스템 자동 첨부 · 실시간 활력징후',
            time: '09:30 전송',
            resident: '거주인: 예시 별님 (남, 만 20세)',
            baseline: 365,
            value: 379,
            diff: 14,
            stage: Stage.abnormal,
            footer: '측정 09:30 · 기록 예시 선생님',
            doctor: doctor,
          ),
          SizedBox(height: doctor ? 16 : 14),
          TextBubble(
            mine: false,
            name: '예시 선생님',
            initial: '예',
            isDoctor: false,
            time: '09:31',
            body: '체온이 올라서 간호 선생님께 알려요. 물을 마시게 하고 겉옷을 벗겼어요.',
            doctor: doctor,
          ),
        ]),
      );
}
