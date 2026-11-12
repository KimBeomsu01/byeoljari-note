// HO-2 별님별 기록 (인수인계 명세 3.2): 반 칩 + 별님 카드 2칸.
// 카드 순서는 상태에 따라 바꾸지 않는다 (선생님들이 별님 위치를 기억한다).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'handover_common.dart';
import 'handover_view.dart';

class ResidentBoard extends ConsumerWidget {
  const ResidentBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final now = ref.read(clockProvider)();
    final v = HandoverView(repo, me, now);
    final selected = ref.watch(handoverClassProvider) ?? repo.homeClassOf(me) ?? repo.classes.first.id;
    final cls = repo.classOf(selected);
    final residents = repo.residentsOf(selected);

    const cols = 2;
    final rows = <Widget>[];
    for (var i = 0; i < residents.length; i += cols) {
      final chunk = residents.skip(i).take(cols).toList();
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: Gap.m),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) const SizedBox(width: Gap.m),
              Expanded(child: j < chunk.length ? _ResidentTile(resident: chunk[j], view: v) : const SizedBox()),
            ],
          ]),
        ),
      ));
    }

    return ListView(padding: const EdgeInsets.fromLTRB(0, Gap.s, 0, 120), children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.s),
        child: Text('반 고르기', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkSub)),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.page),
        child: Row(children: [
          for (final c in repo.classes)
            Padding(
              padding: const EdgeInsets.only(right: Gap.s),
              child: _ClassTab(cls: c, selected: c.id == selected, unread: v.unreadInClass(c.id)),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${cls.name} 별님 ${residents.length}명',
              style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
          Text('담임 ${repo.staff(cls.homeroomId).displayName}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
      ),
      if (residents.isEmpty)
        const EmptyNote('이 반에는 별님이 없어요')
      else
        Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.page), child: Column(children: rows)),
    ]);
  }
}

class _ClassTab extends ConsumerWidget {
  const _ClassTab({required this.cls, required this.selected, required this.unread});
  final Class cls;
  final bool selected;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) => HoChip(
        label: cls.name,
        selected: selected,
        dot: Color(cls.color),
        semanticsLabel: '${cls.name}${unread > 0 ? ', 안 본 기록 $unread' : ''}',
        trailing: unread > 0 ? CountBadge(unread) : null,
        onTap: () => ref.read(handoverClassProvider.notifier).select(cls.id),
      );
}

class _ResidentTile extends ConsumerWidget {
  const _ResidentTile({required this.resident, required this.view});
  final Resident resident;
  final HandoverView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final r = resident;
    final cls = repo.classOf(r.classId);
    final last = repo.latestOf(r.id);
    final c = view.activeCaseOf(r.id);
    final tasks = view.openTasks.where((e) => e.residentId == r.id).toList();
    final newCount = view.unreadOfResident(r.id);
    final recordCount = repo.archiveEntriesOf(r.id).where((e) => e.scope == EntryScope.resident).length;

    // 상태 표시: 긴급·이상 대응 > 할 일
    Color? accent;
    String? status;
    Color statusInk = inkMain;
    if (c != null) {
      final sc = stageColors[c.isUrgent ? Stage.danger : c.severity]!;
      accent = c.isUrgent ? sc.ink : sc.line;
      status = '${c.isUrgent ? Stage.danger.symbol : c.severity.symbol} ${c.kindLabel}';
      statusInk = sc.ink;
    } else if (tasks.isNotEmpty) {
      accent = hoTask.line;
      status = '☐ 할 일 ${dueLabel(tasks.first.task!, view.now)}';
      statusInk = hoTask.ink;
    }

    final semantics = [
      '${r.name} 별님',
      last == null ? '체온 기록 없음' : '최근 ${(last.value / 10).toStringAsFixed(1)}도 ${last.judgment.stage.label}',
      ?status,
      if (newCount > 0) '새 기록 $newCount',
    ].join(', ');

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: accent ?? line, width: accent == null ? 1 : 2.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openArchive(context, r.id),
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              ResidentAvatar(name: r.name, classColor: cls.color, size: 56),
              const SizedBox(height: Gap.s),
              Text(r.name, style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain, height: 1.3)),
              if (newCount > 0) NewMark(text: '새 기록 $newCount'),
              const SizedBox(height: Gap.xs),
              if (last == null)
                const Text('체온 기록 없음', style: TextStyle(fontSize: T.caption, color: inkSub))
              else
                StageTag(last.judgment.stage, value: last.value),
              if (status != null) ...[
                const SizedBox(height: Gap.xs),
                Text(status, style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: statusInk)),
              ],
              const Spacer(),
              const SizedBox(height: Gap.xs),
              Text('기록 $recordCount건', style: const TextStyle(fontSize: T.caption, color: inkSub)),
            ]),
          ),
        ),
      ),
    );
  }
}
