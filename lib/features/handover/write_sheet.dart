// "기록하기" 시트: 전체 공지 · 반 공지 · 별님 기록 고르기 → 내용 → 저장 (addEntry).
// 별님카드 등 다른 화면도 showWriteSheet를 쓴다. 함수 이름·인자는 바꾸지 않는다.
// 체온 숫자는 여기서 받지 않는다. 체온 입력은 퀵 체온 하나뿐이다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

Future<void> showWriteSheet(BuildContext context, WidgetRef ref, {String? classId, String? residentId}) {
  final repo = ref.read(repoProvider);
  final me = ref.read(currentUserProvider);
  final visible = repo.myClasses(me);
  final initialClass = [
    classId,
    if (residentId != null) repo.resident(residentId).classId,
    repo.homeClassOf(me),
  ].whereType<String>().where(visible.contains).firstOrNull ??
      repo.classes.firstWhere((c) => visible.contains(c.id), orElse: () => repo.classes.first).id;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WriteSheet(classId: initialClass, residentId: residentId),
  );
}

/// 빠른 문구: 누르면 완성된 문장이 내용 끝에 새 줄로 붙는다.
const quickPhrases = <(String chip, String sentence)>[
  ('다 드심', '식사를 다 드셨어요.'),
  ('절반 드심', '식사를 절반만 드셨어요.'),
  ('기분 좋음', '기분이 좋아 보여요.'),
  ('피곤해 보임', '피곤해 보여요.'),
  ('재측정 필요', '체온을 한 번 더 재 주세요.'),
  ('물 자주 드림', '물을 자주 드렸어요.'),
];

/// 할 일 기한 프리셋. 시각은 [가정]: 일정과 연결되면 별님 일정에서 가져온다.
const taskPresets = ['점심 전', '13:00 목욕 전', '저녁 전', '다음 근무조'];

DateTime? presetDueAt(List<Shift> shifts, String preset, DateTime now) {
  DateTime today(int h, int m) {
    final t = DateTime(now.year, now.month, now.day, h, m);
    return t.isBefore(now) ? t.add(const Duration(days: 1)) : t;
  }

  switch (preset) {
    case '점심 전':
      return today(11, 30);
    case '13:00 목욕 전':
      return today(13, 0);
    case '저녁 전':
      return today(17, 30);
    case '다음 근무조':
      final next = shifts.where((s) => s.startAt.isAfter(now)).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
      return next.isEmpty ? null : next.first.startAt;
  }
  return null;
}

class WriteSheet extends ConsumerStatefulWidget {
  const WriteSheet({super.key, required this.classId, this.residentId});
  final String classId;
  final String? residentId;

  @override
  ConsumerState<WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends ConsumerState<WriteSheet> {
  EntryScope _scope = EntryScope.resident;
  late String _classId = widget.classId;
  late String? _residentId = widget.residentId;
  final _body = TextEditingController();
  final _title = TextEditingController();
  bool _asTask = false;
  TaskKind _taskKind = TaskKind.memo;
  String _preset = taskPresets.last;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _body.dispose();
    _title.dispose();
    super.dispose();
  }

  void _setScope(EntryScope s) => setState(() {
        _scope = s;
        _error = null;
        if (s != EntryScope.resident) _taskKind = TaskKind.memo;
        if (s == EntryScope.facility) _asTask = false;
      });

  void _addPhrase(String s) {
    final t = _body.text.trimRight();
    _body.text = t.isEmpty ? s : '$t\n$s';
    _body.selection = TextSelection.collapsed(offset: _body.text.length);
    setState(() => _error = null);
  }

  void _save() {
    if (_saving) return;
    if (_scope == EntryScope.resident && _residentId == null) {
      setState(() => _error = '어떤 별님의 기록인지 골라 주세요');
      return;
    }
    final body = _body.text.trim();
    if (body.isEmpty) {
      setState(() => _error = '내용을 한 줄이라도 적어 주세요');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    final now = repo.now();
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
    repo.addEntry(Entry(
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
      task: task,
    ));
    final toast = task != null
        ? '할 일로 넘겼어요'
        : switch (_scope) {
            EntryScope.resident => '${repo.resident(_residentId!).name} 별님 기록을 남겼어요',
            EntryScope.classScope => '${repo.classOf(_classId).name} 반 공지를 올렸어요',
            EntryScope.facility => '전체 공지를 올렸어요',
          };
    // 토스트는 앱 맨 위 겹(root overlay)에 붙어서 시트가 닫혀도 남는다.
    showDsToast(context, toast);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final cls = repo.classOf(_classId);
    final residents = repo.residentsOf(_classId);
    final resName = _residentId == null ? null : repo.resident(_residentId!).name;

    final bodyLabel = switch (_scope) {
      EntryScope.facility => '공지 내용',
      EntryScope.classScope => '${cls.name} 반 공지 내용',
      EntryScope.resident => resName == null ? '기록 내용' : '$resName 별님 기록 내용',
    };
    final hint = switch (_scope) {
      EntryScope.facility => '모든 선생님이 알아야 할 내용을 적어 주세요',
      EntryScope.classScope => '${cls.name} 선생님들이 알아야 할 내용을 적어 주세요',
      EntryScope.resident => '오늘 본 작은 변화나 다음 선생님이 알아야 할 일을 적어 주세요',
    };
    final whereText = switch (_scope) {
      EntryScope.facility => '모든 선생님의 최신 기록에 보여요',
      EntryScope.classScope => '최신 기록과 ${cls.name} 별님 ${residents.length}명의 별님카드에 남아요',
      EntryScope.resident => '최신 기록과 ${resName ?? '별님'} 별님카드에 남아요',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(children: [
            const Expanded(
              child: Text('기록하기',
                  style: TextStyle(fontSize: T.title, height: 1.4, fontWeight: FontWeight.w700, color: Ds.gray900, letterSpacing: -0.5)),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Ds.gray700),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('무엇을 남길까요?'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Chip(label: '별님 기록', selected: _scope == EntryScope.resident, onTap: () => _setScope(EntryScope.resident)),
                _Chip(label: '반 공지', selected: _scope == EntryScope.classScope, onTap: () => _setScope(EntryScope.classScope)),
                _Chip(label: '전체 공지', selected: _scope == EntryScope.facility, onTap: () => _setScope(EntryScope.facility)),
              ]),
              if (_scope != EntryScope.facility) ...[
                const SizedBox(height: 20),
                const _Label('어느 반인가요?'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(children: [
                    for (final c in repo.classes.where((c) => repo.myClasses(ref.read(currentUserProvider)).contains(c.id)))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Chip(
                          label: c.name,
                          selected: c.id == _classId,
                          onTap: () => setState(() {
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
                const SizedBox(height: 20),
                const _Label('어떤 별님인가요?'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final r in residents)
                    _Chip(
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
                const SizedBox(height: 20),
                const _Label('제목 (안 써도 돼요)'),
                TextField(
                  controller: _title,
                  style: const TextStyle(fontSize: T.body, color: Ds.gray900),
                  decoration: const InputDecoration(hintText: '예: 오늘 10:00 목욕실 온수 보일러 점검 안내'),
                ),
              ],
              const SizedBox(height: 20),
              _Label(bodyLabel),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(fontSize: T.body, height: 1.5, color: Ds.gray900),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(hintText: hint, hintMaxLines: 2),
              ),
              if (_scope == EntryScope.resident) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (chip, sentence) in quickPhrases) _PhraseChip(chip, onTap: () => _addPhrase(sentence)),
                ]),
              ],
              if (_scope != EntryScope.facility) ...[
                const SizedBox(height: 12),
                _CheckRow(label: '할 일로 넘기기', value: _asTask, onChanged: (v) => setState(() => _asTask = v)),
                if (_asTask) ...[
                  if (_scope == EntryScope.resident) ...[
                    const SizedBox(height: 8),
                    const _Label('무슨 할 일인가요?'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _Chip(label: '부탁·확인', selected: _taskKind == TaskKind.memo, onTap: () => setState(() => _taskKind = TaskKind.memo)),
                      _Chip(label: '체온 재기', selected: _taskKind == TaskKind.temp, onTap: () => setState(() => _taskKind = TaskKind.temp)),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  const _Label('언제까지 할까요?'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in taskPresets) _Chip(label: p, selected: _preset == p, onTap: () => setState(() => _preset = p)),
                  ]),
                ],
              ],
              const SizedBox(height: 16),
              Text(whereText, style: const TextStyle(fontSize: T.caption, height: 1.4, color: Ds.gray500)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Ds.red500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(fontSize: T.label, fontWeight: FontWeight.w600, color: Ds.red500)),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ds.gray100))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: DsButton('저장하기', kind: DsButtonKind.violet, height: 52, expand: true, onPressed: _saving ? null : _save),
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
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: T.body, height: 1.43, fontWeight: FontWeight.w700, color: Ds.gray900)),
      );
}

/// 빠른 문구 칩 (+ 아이콘, gray-100).
class _PhraseChip extends StatelessWidget {
  const _PhraseChip(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label 넣기',
        excludeSemantics: true,
        child: Material(
          color: Ds.gray100,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, size: 14, color: Ds.gray600),
                const SizedBox(width: 2),
                Text(label, style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: Ds.gray700)),
              ]),
            ),
          ),
        ),
      );
}

/// 체크 줄: 줄 전체를 눌러도 된다.
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
          child: SizedBox(
            height: tapHeight,
            child: Row(children: [
              Checkbox(
                value: value,
                activeColor: Ds.violet500,
                side: const BorderSide(color: Ds.gray300, width: 1.5),
                onChanged: (v) => onChanged(v ?? false),
              ),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: Ds.gray900)),
              ),
            ]),
          ),
        ),
      );
}

/// DsChip은 Wrap 안에서 줄 끝까지 늘어나므로 글자 크기만큼으로 묶는다.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IntrinsicWidth(child: DsChip(label: label, selected: selected, onTap: onTap));
}
