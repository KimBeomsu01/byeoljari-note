// 별님카드에서 여는 시트: 기록 남기기 · 투약 지침 · 기록 거르기.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'resident_timeline.dart';

const _sheetTitle = TextStyle(fontSize: T.heading, height: 1.4, fontWeight: FontWeight.w700, color: Ds.gray900);
const _sheetSub = TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500);
const _sectionLabel = TextStyle(fontSize: T.label, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray600);

// ── 기록 남기기

/// 이 별님 기록 작성 시트. 관찰 기록 / 감각 메모를 골라 별님 기록(scope: resident)으로 남긴다.
Future<void> showResidentWriteSheet(BuildContext context, String residentId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WriteSheet(residentId: residentId),
    );

class _WriteSheet extends ConsumerStatefulWidget {
  const _WriteSheet({required this.residentId});
  final String residentId;

  @override
  ConsumerState<_WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends ConsumerState<_WriteSheet> {
  static const _kinds = ['관찰 기록', '감각 메모'];
  String _kind = _kinds.first;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    final r = repo.resident(widget.residentId);
    repo.addEntry(Entry(
      id: '',
      scope: EntryScope.resident,
      authorId: me,
      kindLabel: _kind,
      createdAt: repo.now(),
      classId: r.classId,
      residentId: r.id,
      body: _text.text.trim(),
    ));
    showDsToast(context, '기록을 남겼어요');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final r = repo.resident(widget.residentId);
    final cls = repo.classOf(r.classId);
    final canSave = _text.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${r.name} 기록 남기기', style: _sheetTitle),
            const SizedBox(height: 2),
            Text('${cls.name} · 내 이름으로 남겨요', style: _sheetSub),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in _kinds) DsChip(label: k, selected: _kind == k, onTap: () => setState(() => _kind = k)),
            ]),
            const SizedBox(height: 12),
            TextField(
              key: const Key('rc-write-field'),
              controller: _text,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: T.body, height: 1.6, color: Ds.gray900),
              decoration: InputDecoration(
                hintText: _kind == '감각 메모' ? '소리·빛·촉감 같은 자극에 보인 반응을 적어 주세요' : '식사, 잠, 기분, 행동에서 본 것을 적어 주세요',
              ),
            ),
            const SizedBox(height: 8),
            DsButton('기록 남기기',
                key: const Key('rc-write-save'),
                icon: Icons.edit_rounded,
                expand: true,
                height: 52,
                onPressed: canSave ? _save : null),
          ]),
        ),
      ),
    );
  }
}

// ── 투약 지침

/// 투약 지침 · 의료 정보 시트. 의료진이 쓴 글을 그대로 보여주기만 한다 (앱은 계산·추천하지 않는다).
Future<void> showGuideSheet(BuildContext context, InMemoryRepository repo, Resident r) {
  final g = repo.guidelineOf(r.id);
  final info = <(String, String)>[
    if (r.diagnosis != null) ('주진단', r.diagnosis!),
    if (r.cautions != null) ('금기 · 주의', r.cautions!),
    if (r.regularMeds != null) ('상시 복약', r.regularMeds!),
    if (r.prnNote != null) ('필요시 투약 지시', r.prnNote!),
  ];
  String date(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Ds.blue50, shape: BoxShape.circle),
                child: const Icon(Icons.medication_rounded, size: 20, color: Ds.blue500),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('${r.name} 투약 지침', style: _sheetTitle)),
            ]),
            const SizedBox(height: 6),
            const Text('의료진이 쓴 글을 그대로 보여드려요', style: _sheetSub),
            const SizedBox(height: 16),
            if (g != null) ...[
              DsInset(
                child: Text(g.body, style: const TextStyle(fontSize: T.body, height: 1.6, fontWeight: FontWeight.w500, color: Ds.gray800)),
              ),
              const SizedBox(height: 8),
              Text('${repo.staff(g.writtenBy).displayName} · ${date(g.updatedAt)} 고침', style: _sheetSub),
            ] else
              const DsInset(
                child: Text('등록된 투약 지침이 없어요. 간호 선생님에게 문의해 주세요.',
                    style: TextStyle(fontSize: T.body, height: 1.6, color: Ds.gray700)),
              ),
            if (info.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('의료 정보', style: _sectionLabel),
              const SizedBox(height: 8),
              for (final (label, value) in info)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(fontSize: T.caption, height: 1.5, fontWeight: FontWeight.w600, color: Ds.gray500)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: TextStyle(
                            fontSize: T.body,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                            color: label == '금기 · 주의' ? Ds.red500 : Ds.gray900)),
                  ]),
                ),
            ],
            const SizedBox(height: 12),
            DsButton('닫기', kind: DsButtonKind.gray, expand: true, height: 48, onPressed: () => Navigator.of(sheet).pop()),
          ],
        ),
      ),
    ),
  );
}

// ── 기록 거르기 (FilterChips의 [전체] · ActionBar 필터 버튼)

Future<void> showFilterSheet(
  BuildContext context, {
  required KindFilter kind,
  required PeriodFilter period,
  required void Function(KindFilter kind, PeriodFilter period) onChanged,
}) {
  var k = kind;
  var p = period;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, setSheet) {
        void set(KindFilter nk, PeriodFilter np) {
          setSheet(() {
            k = nk;
            p = np;
          });
          onChanged(nk, np);
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('기록 거르기', style: _sheetTitle),
              const SizedBox(height: 16),
              const Text('종류', style: _sectionLabel),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final x in KindFilter.values) DsChip(label: x.label, selected: k == x, onTap: () => set(x, p)),
              ]),
              const SizedBox(height: 16),
              const Text('기간', style: _sectionLabel),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final x in PeriodFilter.values) DsChip(label: x.label, selected: p == x, onTap: () => set(k, x)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: DsButton('처음으로',
                      kind: DsButtonKind.outline,
                      expand: true,
                      height: 48,
                      onPressed: k == KindFilter.all && p == PeriodFilter.all ? null : () => set(KindFilter.all, PeriodFilter.all)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DsButton('닫기', kind: DsButtonKind.dark, expand: true, height: 48, onPressed: () => Navigator.of(sheet).pop()),
                ),
              ]),
            ]),
          ),
        );
      },
    ),
  );
}
