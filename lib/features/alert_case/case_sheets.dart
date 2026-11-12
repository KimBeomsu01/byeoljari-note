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
}) =>
    showModalBottomSheet<NoteResult>(
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: const TextStyle(fontSize: 13, color: inkSub)),
            ],
            if (widget.chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in widget.chips)
                  ChoiceChip(
                    label: Text(c),
                    selected: _chip == c,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (on) => setState(() => _chip = on ? c : null),
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _needText ? widget.hint.replaceAll('(선택)', '(꼭 써 주세요)') : widget.hint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48), backgroundColor: widget.submitColor ?? brandDark),
                  onPressed: _ready ? () => Navigator.pop(context, NoteResult(_chip, _ctrl.text)) : null,
                  child: Text(widget.submitLabel),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// S5 단계 고르기: 지금보다 높은 단계만. 권한 없는 단계는 흐리게 + 이유.
Future<int?> pickStage(BuildContext context, CasePerms p) => showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('단계 올리기', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text('지금 ${circledStage[p.c.stage - 1]} ${InMemoryRepository.stageLabel(p.c.stage)} · 단계를 건너뛸 수 있어요',
                style: const TextStyle(fontSize: 13, color: inkSub)),
            const SizedBox(height: 12),
            for (var s = p.c.stage + 1; s <= 4; s++) ...[
              Builder(builder: (_) {
                final denied = p.stageDenied(s);
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: denied == null ? brandDark : inkSub,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () {
                    if (denied != null) {
                      toast(sheet, denied);
                      return;
                    }
                    Navigator.pop(sheet, s);
                  },
                  child: Row(children: [
                    Expanded(child: Text(p.stageAction(s), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    if (denied != null) const Icon(Icons.lock_outline, size: 18, semanticLabel: '권한 없음'),
                  ]),
                );
              }),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      ),
    );

/// 단계마다 받는 입력 (S5 표). 결과 글은 단계 기록의 메모가 된다.
Future<NoteResult?> stageInputSheet(BuildContext context, int stage, CasePerms p) => switch (stage) {
      2 => showNoteSheet(context,
          title: '원내 조제로 대응할까요?',
          subtitle: '간호사·원장님 지시대로 한 일을 적어 주세요. 앱은 용량을 정하지 않아요.',
          hint: '무엇을 했는지 (선택)',
          submitLabel: '단계 올리기'),
      3 => showNoteSheet(context,
          title: p.isDirector ? '원장 처방으로 올릴까요?' : '원장님 처방을 요청할까요?',
          subtitle: '원장님께 중요 알림이 가요.',
          chips: const ['열이 안 내림', '증상 악화', '합병증 의심', '기타'],
          chipRequired: true,
          textRequiredFor: const {'기타'},
          submitLabel: p.isDirector ? '단계 올리기' : '원장 처방 요청'),
      _ => showNoteSheet(context,
          title: '병원으로 이동할까요?',
          subtitle: '원장님·간호사·사무국·담임에게 알림이 가요.',
          chips: const ['시설 차량', '구급차', '보호자'],
          hint: '병원 이름·동행자 (선택)',
          submitLabel: '병원으로 이동'),
    };

/// S7 대응 종료.
Future<NoteResult?> closeSheet(BuildContext context, CasePerms p, {String? initial}) => showNoteSheet(
      context,
      title: '대응을 종료할까요?',
      subtitle: p.fullClose ? '종료하면 남은 재측정 예약도 멈추고 모두에게 종료 알림이 가요.' : '입력한 선생님은 잘못 잰 값일 때만 종료할 수 있어요.',
      chips: p.allowedCloseReasons,
      chipRequired: true,
      textRequiredFor: const {'기타'},
      initialChip: initial,
      submitLabel: '종료하기',
    );

/// 예/아니오 확인창.
Future<bool> confirm(BuildContext context, String title, String body, String yes) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('아니요')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(yes)),
      ],
    ),
  );
  return ok == true;
}
