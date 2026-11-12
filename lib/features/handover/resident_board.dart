// HO-2 별님별 기록 (인수인계 명세 3.2): 반 탭 + 별님 그리드.
// 그리드 순서는 상태에 따라 바꾸지 않는다 (선생님들이 별님 위치를 기억한다).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
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

    final rows = <Widget>[];
    for (var i = 0; i < residents.length; i += 3) {
      final chunk = residents.skip(i).take(3).toList();
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = 0; j < 3; j++) ...[
              if (j > 0) const SizedBox(width: 8),
              Expanded(child: j < chunk.length ? _ResidentTile(resident: chunk[j], view: v) : const SizedBox()),
            ],
          ]),
        ),
      ));
    }

    return ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 120), children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final c in repo.classes)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _ClassTab(cls: c, selected: c.id == selected, unread: v.unreadInClass(c.id)),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text('${cls.name} · 담임 ${repo.staff(cls.homeroomId).displayName} · ${residents.length}명',
            style: const TextStyle(fontSize: 13, color: inkSub)),
      ),
      if (residents.isEmpty)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('이 반에 별님이 없어요.')))
      else
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: rows)),
    ]);
  }
}

class _ClassTab extends ConsumerWidget {
  const _ClassTab({required this.cls, required this.selected, required this.unread});
  final Class cls;
  final bool selected;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(cls.color);
    return Semantics(
      button: true,
      selected: selected,
      label: '${cls.name}${unread > 0 ? ', 안 본 기록 $unread' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? Color.alphaBlend(color.withValues(alpha: 0.2), Colors.white) : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? color : hoCardLine, width: selected ? 1.5 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => ref.read(handoverClassProvider.notifier).select(cls.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(cls.name, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              if (unread > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: hoUnreadBadge, borderRadius: BorderRadius.circular(99)),
                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
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
    Color border = hoCardLine;
    double borderW = 1;
    String? status;
    Color statusInk = inkSub;
    if (c != null) {
      final sc = stageColors[c.isUrgent ? Stage.danger : c.severity]!;
      border = sc.line;
      borderW = 2;
      status = '${c.isUrgent ? Stage.danger.symbol : c.severity.symbol} ${c.kindLabel}';
      statusInk = sc.ink;
    } else if (tasks.isNotEmpty) {
      border = hoTaskLine;
      borderW = 2;
      status = '☐ 할 일 ${dueLabel(tasks.first.task!, view.now)}';
      statusInk = hoTaskInk;
    }

    final tempText = last == null
        ? '체온 기록 없음'
        : '${last.judgment.stage.symbol} ${formatTemp(last.value)}℃ ${last.judgment.stage.label}';
    final semantics = [
      '${r.name} 별님',
      last == null ? '체온 기록 없음' : '최근 ${formatTemp(last.value)}도 ${last.judgment.stage.label}',
      ?status,
      if (newCount > 0) '새 기록 $newCount',
    ].join(', ');

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: border, width: borderW)),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => openArchive(context, r.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                NameAvatar(name: r.name, size: 38, color: Color(cls.color).withValues(alpha: 0.4)),
                if (newCount > 0)
                  Positioned(
                    right: -16,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: hoUnreadBadge, borderRadius: BorderRadius.circular(99)),
                      child: Text('새 $newCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(r.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(tempText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: last == null ? inkSub : stageColors[last.judgment.stage]!.ink)),
              if (status != null)
                Text(status,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusInk)),
              Text('기록 $recordCount건', style: const TextStyle(fontSize: 11, color: inkSub)),
            ]),
          ),
        ),
      ),
    );
  }
}
