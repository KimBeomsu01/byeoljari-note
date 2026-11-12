// HO-W 관찰 기록 작성 시트 (인수인계 명세 3.4).
// 아카이브의 "○○ 별님 기록 남기기"도 이 함수를 쓴다. 함수 이름·인자는 바꾸지 않는다.
// 체온 숫자는 여기서 받지 않는다. 체온 입력은 퀵 체온 하나뿐이다 (CLAUDE.md).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'entry_card.dart' show taskPresets, presetDueAt;
import 'handover_common.dart';

Future<void> showWriteSheet(BuildContext context, WidgetRef ref, {String? classId, String? residentId}) {
  final repo = ref.read(repoProvider);
  final me = ref.read(currentUserProvider);
  final initialClass = classId ??
      (residentId != null ? repo.resident(residentId).classId : null) ??
      ref.read(handoverClassProvider) ??
      repo.homeClassOf(me) ??
      repo.classes.first.id;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => WriteSheet(classId: initialClass, residentId: residentId),
  );
}

/// 빠른 문구: 누르면 완성된 문장이 메모 끝에 새 줄로 붙는다.
const quickPhrases = <(String group, List<(String chip, String sentence)>)>[
  ('식사', [('다 드심', '식사를 다 드셨어요.'), ('절반', '식사를 절반만 드셨어요.'), ('거의 안 드심', '식사를 거의 안 드셨어요.')]),
  ('컨디션', [('기분 좋음', '기분이 좋아 보여요.'), ('피곤해 보임', '피곤해 보여요.'), ('일찍 쉼', '일찍 쉬었어요.')]),
  ('체온', [('재측정 필요', '체온을 한 번 더 재 주세요.'), ('물 자주 드림', '물을 자주 드렸어요.')]),
];

class WriteSheet extends ConsumerStatefulWidget {
  const WriteSheet({super.key, required this.classId, this.residentId});
  final String classId;
  final String? residentId;

  @override
  ConsumerState<WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends ConsumerState<WriteSheet> {
  late EntryScope _scope = EntryScope.resident;
  late String _classId = widget.classId;
  late String? _residentId = widget.residentId;
  final _body = TextEditingController();
  final _title = TextEditingController();
  int _photos = 0;
  bool _pinned = true;
  bool _asTask = false;
  TaskKind _taskKind = TaskKind.memo;
  String _preset = '13:00 목욕 전';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _body.dispose();
    _title.dispose();
    super.dispose();
  }

  bool get _targetChosen => switch (_scope) {
        EntryScope.resident => _residentId != null,
        _ => true,
      };

  void _addPhrase(String s) {
    final t = _body.text.trimRight();
    _body.text = t.isEmpty ? s : '$t\n$s';
    _body.selection = TextSelection.collapsed(offset: _body.text.length);
    setState(() => _error = null);
  }

  void _save() {
    if (_saving) return;
    if (!_targetChosen) {
      setState(() => _error = '먼저 어떤 별님의 기록인지 골라주세요.');
      return;
    }
    final body = _body.text.trim();
    if (body.isEmpty) {
      setState(() => _error = '메모를 한 줄이라도 적어주세요.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    final now = ref.read(clockProvider)();
    Task? task;
    if (_asTask && _scope != EntryScope.facility) {
      final first = body.split('\n').first;
      final kind = _scope == EntryScope.resident ? _taskKind : TaskKind.memo;
      task = Task(
        id: '',
        label: kind == TaskKind.temp ? '체온 재기' : (first.length > 14 ? '${first.substring(0, 14)}…' : first),
        kind: kind,
        duePreset: _preset,
        dueAt: presetDueAt(repo.shifts, _preset, now),
      );
    }
    final title = _title.text.trim();
    final saved = repo.addEntry(Entry(
      id: '',
      scope: _scope,
      authorId: me,
      kindLabel: switch (_scope) {
        EntryScope.facility => '전체 공지',
        EntryScope.classScope => '반 공지',
        EntryScope.resident => '관찰 기록',
      },
      createdAt: now,
      classId: _scope == EntryScope.facility ? null : _classId,
      residentId: _scope == EntryScope.resident ? _residentId : null,
      title: _scope == EntryScope.facility && title.isNotEmpty ? title : null,
      body: body,
      photoCount: _photos,
      task: task,
      pinned: _scope == EntryScope.facility && _pinned,
    ));
    ref.read(sessionWrittenProvider.notifier).add(saved.id);

    final String toast;
    if (task != null) {
      toast = '할 일로 넘겼어요 · 완료할 때까지 교대 요약에 남아요';
    } else {
      toast = switch (_scope) {
        EntryScope.resident => '${repo.resident(_residentId!).name} 별님 아카이브에 함께 담겼어요',
        EntryScope.classScope =>
          '반 공지로 ${repo.classOf(_classId).name} ${repo.residentsOf(_classId).length}명 아카이브에 함께 담겼어요',
        EntryScope.facility => '전체 공지를 올렸어요',
      };
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(toast), duration: const Duration(seconds: 3), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final role = repo.staff(me).role;
    final canFacility = role == Role.office || role == Role.director || role == Role.admin;
    final cls = repo.classOf(_classId);
    final residents = repo.residentsOf(_classId);
    final resName = _residentId == null ? null : repo.resident(_residentId!).name;

    final bodyLabel = switch (_scope) {
      EntryScope.facility => '전체 공지 내용',
      EntryScope.classScope => '${cls.name} 반 공지',
      EntryScope.resident => resName == null ? '메모' : '$resName 별님에 대한 메모',
    };
    final whereText = switch (_scope) {
      EntryScope.facility => '전체 공지 · 모든 선생님의 최신 기록에 보여요',
      EntryScope.classScope => '반 공지 + ${cls.name} ${residents.length}명 아카이브',
      EntryScope.resident => '인수인계 + ${resName ?? '별님'} 별님 아카이브',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 머리
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
          child: Row(children: [
            const Expanded(child: Text('기록 남기기', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            IconButton(
              tooltip: '닫기 (쓴 내용은 버려요)',
              iconSize: 26,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 종류
              const _Label('무엇을 남길까요?'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _Pick(
                    label: '별님 기록',
                    selected: _scope == EntryScope.resident,
                    onTap: () => setState(() {
                          _scope = EntryScope.resident;
                          _error = null;
                        })),
                _Pick(
                    label: '반 공지',
                    selected: _scope == EntryScope.classScope,
                    onTap: () => setState(() {
                          _scope = EntryScope.classScope;
                          _error = null;
                          _taskKind = TaskKind.memo;
                        })),
                if (canFacility)
                  _Pick(
                      label: '전체 공지',
                      selected: _scope == EntryScope.facility,
                      onTap: () => setState(() {
                            _scope = EntryScope.facility;
                            _error = null;
                            _asTask = false;
                          })),
              ]),
              if (!canFacility)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('전체 공지는 사무국에서 올려요.', style: TextStyle(fontSize: 12, color: inkSub)),
                ),

              if (_scope != EntryScope.facility) ...[
                const SizedBox(height: 12),
                const _Label('반'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final c in repo.classes)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Pick(
                          label: c.name,
                          dot: Color(c.color),
                          selected: c.id == _classId,
                          onTap: () => setState(() {
                            // 반을 바꾸면 고른 별님과 오류 문구를 지운다.
                            if (_classId != c.id) _residentId = null;
                            _classId = c.id;
                            _error = null;
                          }),
                        ),
                      ),
                  ]),
                ),
              ],

              if (_scope == EntryScope.resident) ...[
                const SizedBox(height: 12),
                const _Label('어떤 별님인가요?'),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final r in residents)
                    _Pick(
                      label: r.name,
                      selected: r.id == _residentId,
                      onTap: () => setState(() {
                        _residentId = r.id;
                        _error = null;
                      }),
                    ),
                ]),
              ],

              if (_scope == EntryScope.facility) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: '제목 (선택)', border: OutlineInputBorder()),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v ?? false),
                  title: const Text('최신 기록 맨 위에 고정'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],

              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 8,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  labelText: bodyLabel,
                  hintText: '오늘 본 작은 변화나 다음 선생님이 알아야 할 일을 적어주세요.',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: const OutlineInputBorder(),
                ),
              ),

              if (_scope != EntryScope.facility) ...[
                const SizedBox(height: 10),
                const _Label('빠른 문구'),
                for (final (group, items) in quickPhrases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 52,
                        height: 44,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(group, style: const TextStyle(fontSize: 12.5, color: inkSub)),
                        ),
                      ),
                      Expanded(
                        child: Wrap(spacing: 6, runSpacing: 4, children: [
                          for (final (chip, sentence) in items)
                            ActionChip(
                              materialTapTargetSize: MaterialTapTargetSize.padded,
                              label: Text(chip),
                              tooltip: sentence,
                              onPressed: () => _addPhrase(sentence),
                            ),
                        ]),
                      ),
                    ]),
                  ),
              ],

              const SizedBox(height: 8),
              // 사진 (시연: 자리 표시만, 1장)
              Row(children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: () => setState(() => _photos = _photos == 0 ? 1 : 0),
                  icon: Icon(_photos == 0 ? Icons.add_a_photo_outlined : Icons.remove_circle_outline),
                  label: Text(_photos == 0 ? '사진 넣기' : '사진 1장 · 빼기'),
                ),
                if (_photos > 0) ...[
                  const SizedBox(width: 10),
                  Semantics(
                    label: '사진 1장 (시연용 자리 표시)',
                    excludeSemantics: true,
                    child: Container(
                      width: 52,
                      height: 44,
                      decoration: BoxDecoration(color: const Color(0xFFE6E8E3), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.photo_outlined, color: inkSub),
                    ),
                  ),
                ],
              ]),

              if (_scope != EntryScope.facility) ...[
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _asTask,
                  onChanged: (v) => setState(() => _asTask = v ?? false),
                  title: const Text('할 일로 넘기기'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_asTask) ...[
                  if (_scope == EntryScope.resident)
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _Pick(
                          label: '부탁·확인',
                          selected: _taskKind == TaskKind.memo,
                          onTap: () => setState(() => _taskKind = TaskKind.memo)),
                      _Pick(
                          label: '체온 재기',
                          selected: _taskKind == TaskKind.temp,
                          onTap: () => setState(() => _taskKind = TaskKind.temp)),
                    ]),
                  const SizedBox(height: 6),
                  const _Label('언제까지'),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in taskPresets)
                      _Pick(label: p, selected: _preset == p, onTap: () => setState(() => _preset = p)),
                  ]),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('인수인계에 [완료하기] 버튼이 붙고, 끝날 때까지 교대 요약에 남아요.',
                        style: TextStyle(fontSize: 12.5, color: hoTaskInk)),
                  ),
                ],
              ],

              const SizedBox(height: 10),
              Text('저장 위치 · $whereText', style: const TextStyle(fontSize: 12.5, color: inkSub)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('⚠ $_error',
                      style: TextStyle(color: stageColors[Stage.danger]!.ink, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(44, 52), backgroundColor: hoSummaryBg),
                // 대상을 고르기 전에는 비활성 (인수인계 3.4)
                onPressed: _targetChosen && !_saving ? _save : null,
                child: const Text('기록 남기기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: inkSub)),
      );
}

/// 하나 고르기 칩 (44 높이).
class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.selected, required this.onTap, this.dot});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? hoSummaryBg : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: selected ? hoSummaryBg : hoCardLine)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (dot != null) ...[
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                ],
                if (selected) const Text('✓ ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : inkMain, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}
