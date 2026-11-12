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
      toast = '할 일로 넘겼어요 · 완료할 때까지 지금 챙길 일에 남아요';
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
      ..showSnackBar(SnackBar(content: Text(toast), duration: const Duration(seconds: 3)));
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
      EntryScope.facility => '모든 선생님의 최신 기록에 보여요',
      EntryScope.classScope => '인수인계와 ${cls.name} 별님 ${residents.length}명의 아카이브에 남아요',
      EntryScope.resident => '인수인계와 ${resName ?? '별님'} 별님 아카이브에 남아요',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 머리
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.s, Gap.xs),
          child: Row(children: [
            const Expanded(
              child: Text('기록 남기기', style: TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain)),
            ),
            IconButton(
              tooltip: '닫기 (쓴 내용은 버려요)',
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: tapHeight, minHeight: tapHeight),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: inkMain),
            ),
          ]),
        ),
        const Divider(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.l, Gap.page, Gap.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 1. 종류
              const _Label('무엇을 남길까요?'),
              Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
                HoChip(
                    label: '별님 기록',
                    selected: _scope == EntryScope.resident,
                    onTap: () => setState(() {
                          _scope = EntryScope.resident;
                          _error = null;
                        })),
                HoChip(
                    label: '반 공지',
                    selected: _scope == EntryScope.classScope,
                    onTap: () => setState(() {
                          _scope = EntryScope.classScope;
                          _error = null;
                          _taskKind = TaskKind.memo;
                        })),
                if (canFacility)
                  HoChip(
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
                  padding: EdgeInsets.only(top: Gap.s),
                  child: Text('전체 공지는 사무국에서 올려요.', style: TextStyle(fontSize: T.caption, color: inkSub)),
                ),

              // 2. 반
              if (_scope != EntryScope.facility) ...[
                const SizedBox(height: Gap.xl),
                const _Label('어느 반인가요?'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(children: [
                    for (final c in repo.classes)
                      Padding(
                        padding: const EdgeInsets.only(right: Gap.s),
                        child: HoChip(
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

              // 3. 별님
              if (_scope == EntryScope.resident) ...[
                const SizedBox(height: Gap.xl),
                const _Label('어떤 별님인가요?'),
                Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
                  for (final r in residents)
                    HoChip(
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
                const SizedBox(height: Gap.xl),
                const _Label('제목 (안 써도 돼요)'),
                TextField(controller: _title, style: const TextStyle(fontSize: T.body, color: inkMain)),
                const SizedBox(height: Gap.s),
                _CheckRow(
                  label: '최신 기록 맨 위에 고정',
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                ),
              ],

              // 4. 메모
              const SizedBox(height: Gap.xl),
              _Label(bodyLabel),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 8,
                style: const TextStyle(fontSize: T.body, height: 1.5, color: inkMain),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: const InputDecoration(
                  hintText: '오늘 본 작은 변화나 다음 선생님이 알아야 할 일을 적어주세요.',
                  hintMaxLines: 3,
                ),
              ),

              if (_scope != EntryScope.facility) ...[
                const SizedBox(height: Gap.l),
                const _Label('누르면 메모에 들어가요'),
                for (final (group, items) in quickPhrases) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xs, bottom: Gap.xs),
                    child: Text(group,
                        style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w700, color: inkSub)),
                  ),
                  Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
                    for (final (chip, sentence) in items)
                      Tooltip(
                        message: sentence,
                        child: HoChip(
                          label: chip,
                          selected: false,
                          icon: Icons.add,
                          semanticsLabel: '$chip 넣기',
                          onTap: () => _addPhrase(sentence),
                        ),
                      ),
                  ]),
                  const SizedBox(height: Gap.s),
                ],
              ],

              // 5. 사진 (시연: 자리 표시만, 1장)
              const SizedBox(height: Gap.m),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _photos = _photos == 0 ? 1 : 0),
                    icon: Icon(_photos == 0 ? Icons.add_a_photo_outlined : Icons.remove_circle_outline),
                    label: Text(_photos == 0 ? '사진 넣기' : '사진 빼기'),
                  ),
                ),
                if (_photos > 0) ...[
                  const SizedBox(width: Gap.m),
                  Semantics(
                    label: '사진 1장 (시연용 자리 표시)',
                    excludeSemantics: true,
                    child: Container(
                      width: 72,
                      height: tapHeight,
                      decoration: BoxDecoration(
                        color: paper,
                        borderRadius: BorderRadius.circular(Radii.button),
                        border: Border.all(color: line),
                      ),
                      child: const Icon(Icons.photo_outlined, color: inkSub),
                    ),
                  ),
                ],
              ]),

              // 6. 할 일
              if (_scope != EntryScope.facility) ...[
                const SizedBox(height: Gap.m),
                _CheckRow(
                  label: '할 일로 넘기기',
                  value: _asTask,
                  onChanged: (v) => setState(() => _asTask = v),
                ),
                if (_asTask) ...[
                  if (_scope == EntryScope.resident) ...[
                    const SizedBox(height: Gap.s),
                    const _Label('무슨 할 일인가요?'),
                    Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
                      HoChip(
                          label: '부탁·확인',
                          selected: _taskKind == TaskKind.memo,
                          onTap: () => setState(() => _taskKind = TaskKind.memo)),
                      HoChip(
                          label: '체온 재기',
                          selected: _taskKind == TaskKind.temp,
                          onTap: () => setState(() => _taskKind = TaskKind.temp)),
                    ]),
                  ],
                  const SizedBox(height: Gap.l),
                  const _Label('언제까지 할까요?'),
                  Wrap(spacing: Gap.s, runSpacing: Gap.s, children: [
                    for (final p in taskPresets)
                      HoChip(label: p, selected: _preset == p, onTap: () => setState(() => _preset = p)),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.s),
                    child: Text('[완료하기] 버튼이 붙고, 끝날 때까지 지금 챙길 일에 남아요.',
                        style: TextStyle(fontSize: T.caption, color: hoTask.ink, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],

              const SizedBox(height: Gap.l),
              Text(whereText, style: const TextStyle(fontSize: T.caption, color: inkSub)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.s),
                  child: Text('⚠ $_error',
                      style: TextStyle(fontSize: T.body, color: stageColors[Stage.danger]!.ink, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
        const Divider(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.page, Gap.m),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
                // 대상을 고르기 전에는 비활성 (인수인계 3.4)
                onPressed: _targetChosen && !_saving ? _save : null,
                child: const Text('기록 남기기', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800)),
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
        padding: const EdgeInsets.only(bottom: Gap.s),
        child: Text(text, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
      );
}

/// 큰 체크 줄: 높이 56, 글자 크게, 줄 전체를 눌러도 된다.
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: value,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.button),
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: tapHeight),
            child: Row(children: [
              Transform.scale(
                scale: 1.3,
                child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              ),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
              ),
            ]),
          ),
        ),
      );
}
