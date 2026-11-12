// S3 위에 올라오는 시트들: 글 남기기(투약·조치·원장 지시·병원 결과), S5 단계 올리기, S7 대응 종료.
// 투약은 간호사가 쓴 글을 그대로 남긴다. 앱이 용량을 계산하거나 추천하지 않는다.
import 'package:flutter/material.dart';

import '../../core/repository.dart';
import '../../core/theme.dart';
import 'case_ui.dart';

/// 시트 결과: 고른 칩 + 쓴 글.
class NoteResult {
  const NoteResult(this.chip, this.text);
  final String? chip;
  final String text;

  /// 칩 · 글 (빈 것은 빼고).
  String get joined => [?chip, if (text.trim().isNotEmpty) text.trim()].join(' · ');
}

/// 칩 고르기 + 글 쓰기 시트 하나로 여러 기록을 받는다.
Future<NoteResult?> showNoteSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<String> chips = const [],
  bool chipRequired = false,
  bool textRequired = false,
  Set<String> textRequiredFor = const {},
  String hint = '메모 (선택)',
  required String submitLabel,
  String? initialChip,
  Color? submitColor,
}) => showModalBottomSheet<NoteResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _NoteSheet(
    title: title,
    subtitle: subtitle,
    chips: chips,
    chipRequired: chipRequired,
    textRequired: textRequired,
    textRequiredFor: textRequiredFor,
    hint: hint,
    submitLabel: submitLabel,
    initialChip: initialChip,
    submitColor: submitColor,
  ),
);

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.chipRequired,
    required this.textRequired,
    required this.textRequiredFor,
    required this.hint,
    required this.submitLabel,
    required this.initialChip,
    required this.submitColor,
  });
  final String title;
  final String? subtitle;
  final List<String> chips;
  final bool chipRequired;
  final bool textRequired;
  final Set<String> textRequiredFor;
  final String hint;
  final String submitLabel;
  final String? initialChip;
  final Color? submitColor;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _ctrl = TextEditingController();
  String? _chip;

  @override
  void initState() {
    super.initState();
    _chip = widget.initialChip;
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _needText => widget.textRequired || (_chip != null && widget.textRequiredFor.contains(_chip));
  bool get _ready => (!widget.chipRequired || _chip != null) && (!_needText || _ctrl.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(fontSize: T.body, color: inkSub),
                ),
              ],
              if (widget.chips.isNotEmpty) ...[
                const SizedBox(height: Gap.l),
                const Text(
                  '하나 골라 주세요',
                  style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub),
                ),
                const SizedBox(height: Gap.s),
                Wrap(
                  spacing: Gap.s,
                  runSpacing: Gap.s,
                  children: [
                    for (final c in widget.chips)
                      ChoiceChip(
                        label: Text(c),
                        selected: _chip == c,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (on) => setState(() => _chip = on ? c : null),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Gap.l),
              TextField(
                controller: _ctrl,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(fontSize: T.body, color: inkMain),
                decoration: InputDecoration(
                  hintText: _needText ? widget.hint.replaceAll('(선택)', '(꼭 써 주세요)') : widget.hint,
                ),
              ),
              const SizedBox(height: Gap.l),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(tapHeight),
                        backgroundColor: widget.submitColor ?? brandDark,
                      ),
                      onPressed: _ready ? () => Navigator.pop(context, NoteResult(_chip, _ctrl.text)) : null,
                      child: Text(widget.submitLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// S5 단계 고르기: 지금보다 높은 단계만. 권한 없는 단계는 자물쇠 + 이유 글자.
Future<int?> pickStage(BuildContext context, CasePerms p) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '단계 올리기',
            style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            '지금은 ${circledStage[p.c.stage - 1]} ${InMemoryRepository.stageLabel(p.c.stage)}',
            style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
          ),
          const Text(
            '건너뛰고 올릴 수도 있어요',
            style: TextStyle(fontSize: T.body, color: inkSub),
          ),
          const SizedBox(height: Gap.l),
          for (var s = p.c.stage + 1; s <= 4; s++) ...[
            Builder(
              builder: (_) {
                final denied = p.stageDenied(s);
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    foregroundColor: denied == null ? brandDark : inkSub,
                    backgroundColor: denied == null ? surface : paper,
                    side: BorderSide(color: denied == null ? brandDark : line, width: 1.5),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
                  ),
                  onPressed: () {
                    if (denied != null) {
                      toast(sheet, denied);
                      return;
                    }
                    Navigator.pop(sheet, s);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.stageAction(s),
                              style: TextStyle(
                                fontSize: T.body,
                                fontWeight: FontWeight.w800,
                                color: denied == null ? inkMain : inkSub,
                              ),
                            ),
                            if (denied != null)
                              Text(
                                denied,
                                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w500, color: inkSub),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        denied == null ? Icons.chevron_right : Icons.lock_outline,
                        size: 26,
                        semanticLabel: denied == null ? null : '권한 없음',
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: Gap.s),
          ],
        ],
      ),
    ),
  ),
);

/// 단계마다 받는 입력 (S5 표). 결과 글은 단계 기록의 메모가 된다.
Future<NoteResult?> stageInputSheet(BuildContext context, int stage, CasePerms p) => switch (stage) {
  2 => showNoteSheet(
    context,
    title: '원내 조제로 대응할까요?',
    subtitle: '간호사·원장님 지시대로 한 일을 적어 주세요.\n앱은 용량을 정하지 않아요.',
    hint: '무엇을 했는지 (선택)',
    submitLabel: '단계 올리기',
  ),
  3 => showNoteSheet(
    context,
    title: p.isDirector ? '원장 처방으로 올릴까요?' : '원장님 처방을 요청할까요?',
    subtitle: '원장님께 중요 알림이 가요.',
    chips: const ['열이 안 내림', '증상 악화', '합병증 의심', '기타'],
    chipRequired: true,
    textRequiredFor: const {'기타'},
    submitLabel: p.isDirector ? '단계 올리기' : '원장 처방 요청',
  ),
  _ => showNoteSheet(
    context,
    title: '병원으로 이동할까요?',
    subtitle: '원장님·간호사·사무국·담임에게 알림이 가요.',
    chips: const ['시설 차량', '구급차', '보호자'],
    hint: '병원 이름·동행자 (선택)',
    submitLabel: '병원으로 이동',
  ),
};

/// S7 대응 종료.
Future<NoteResult?> closeSheet(BuildContext context, CasePerms p, {String? initial}) => showNoteSheet(
  context,
  title: '대응을 종료할까요?',
  subtitle: p.fullClose ? '종료하면 다시 재기 알림도 멈춰요.\n모두에게 종료 알림이 가요.' : '처음 잰 선생님은 잘못 잰 값일 때만 종료할 수 있어요.',
  chips: p.allowedCloseReasons,
  chipRequired: true,
  textRequiredFor: const {'기타'},
  initialChip: initial,
  submitLabel: '종료하기',
);

/// 예/아니오 확인창. 두 버튼은 같은 폭.
Future<bool> confirm(BuildContext context, String title, String body, String yes) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actionsPadding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(d, false), child: const Text('아니요')),
            ),
            const SizedBox(width: Gap.s),
            Expanded(
              child: FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(yes)),
            ),
          ],
        ),
      ],
    ),
  );
  return ok == true;
}
