// 근무조 인계 요약 시트 (ShiftSummaryCard의 › 를 누르면). 근무조 사람 · 서명 여부 · [인계 확인 서명].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'handover_data.dart';

Future<void> showShiftSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ShiftSheet(),
    );

class ShiftSheet extends ConsumerWidget {
  const ShiftSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final now = repo.now();
    final d = HandoverData(repo, me, now);
    final shift = d.shift;
    final signs = shift == null ? const <HandoverSign>[] : repo.signsOf(shift.id);
    HandoverSign? signOf(String id) => signs.where((s) => s.staffId == id).firstOrNull;
    final mine = shift == null ? null : signOf(me);
    final inShift = shift != null && shift.staffIds.contains(me);

    final caseNames = [for (final c in d.cases) repo.resident(c.residentId).name];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(d.shiftTitle,
              style: const TextStyle(fontSize: T.title, height: 1.4, fontWeight: FontWeight.w700, color: Ds.gray900, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(
            shift == null
                ? '${hhmm(now)} 기준 · 근무 시간 정보가 없어요'
                : '${hhmm(now)} 기준 · 근무 ${hhmm(shift.startAt)}–${hhmm(shift.endAt)}',
            style: const TextStyle(fontSize: T.caption, height: 1.33, color: Ds.gray500, fontFeatures: tabular),
          ),
          const SizedBox(height: 16),
          DsInset(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              _SumLine(label: '긴급', value: '${d.caseCount}건', color: Ds.red500, sub: caseNames.join(', ')),
              _SumLine(label: '할 일', value: '${d.taskCount}개', color: Ds.gray900),
              _SumLine(label: '미확인 기록', value: '${d.unreadCount}개', color: Ds.blue500),
              _SumLine(label: '체온 미기록', value: '${d.missed.length}명', color: Ds.gray800, last: true),
            ]),
          ),
          if (d.missed.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('체온을 아직 안 잰 별님 · 누르면 바로 재요',
                style: TextStyle(fontSize: T.caption, height: 1.33, fontWeight: FontWeight.w600, color: Ds.gray600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in d.missed)
                _Chip(
                  label: '${repo.classOf(r.classId).name} ${r.name}',
                  selected: false,
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(quickTempProvider.notifier).openFor(r.id);
                  },
                ),
            ]),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: Text(shift == null ? '근무조' : '근무조 ${shift.staffIds.length}명',
                  style: const TextStyle(fontSize: T.bodyLg, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900)),
            ),
            if (shift != null)
              Text('서명 ${signs.where((s) => shift.staffIds.contains(s.staffId)).length}/${shift.staffIds.length}',
                  style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: Ds.gray500, fontFeatures: tabular)),
          ]),
          const SizedBox(height: 8),
          if (shift == null) ...[
            const Text('근무조가 아직 정해지지 않았어요',
                style: TextStyle(fontSize: T.body, height: 1.43, color: Ds.gray500)),
            if (repo.isDev) ...[
              const SizedBox(height: 10),
              const ExampleWrap(child: _StaffRow(initial: '예', name: '예시 선생님', signedAt: '07:07')),
            ],
          ] else
            for (final id in shift.staffIds)
              _StaffRow(
                initial: repo.staff(id).name.characters.first,
                name: '${repo.staff(id).displayName}${id == me ? ' (나)' : ''}',
                signedAt: signOf(id) == null ? null : hhmm(signOf(id)!.signedAt),
              ),
          const SizedBox(height: 20),
          if (shift != null && inShift)
            mine != null
                ? DsButton('서명했어요 · ${hhmm(mine.signedAt)}', kind: DsButtonKind.gray, height: 52, expand: true, icon: Icons.check_rounded, onPressed: null)
                : DsButton('인계 확인 서명', kind: DsButtonKind.violet, height: 52, expand: true, icon: Icons.draw_outlined, onPressed: () {
                    repo.signHandover(shift.id, me);
                    showDsToast(context, '인계 서명을 남겼어요');
                  })
          else if (shift != null)
            const Text('지금 근무조 선생님만 서명할 수 있어요',
                textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: Ds.gray500)),
        ],
      ),
    );
  }
}

class _SumLine extends StatelessWidget {
  const _SumLine({required this.label, required this.value, required this.color, this.sub, this.last = false});
  final String label;
  final String value;
  final Color color;
  final String? sub;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Ds.gray100))),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: T.body, height: 1.43, fontWeight: FontWeight.w500, color: Ds.gray700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(sub ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: T.caption, color: Ds.gray500)),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(fontSize: T.bodyLg, height: 1.5, fontWeight: FontWeight.w700, color: color, fontFeatures: tabular)),
        ]),
      );
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.initial, required this.name, this.signedAt});
  final String initial;
  final String name;

  /// 서명 시각. 없으면 서명 전.
  final String? signedAt;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          InitialAvatar(initial, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: T.body, height: 1.43, fontWeight: FontWeight.w600, color: Ds.gray900)),
          ),
          if (signedAt != null) ...[
            const Icon(Icons.check_circle_rounded, size: 16, color: Ds.green500),
            const SizedBox(width: 4),
            Text('서명 $signedAt',
                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: Ds.green500, fontFeatures: tabular)),
          ] else
            const Text('서명 전', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w500, color: Ds.gray500)),
        ]),
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
