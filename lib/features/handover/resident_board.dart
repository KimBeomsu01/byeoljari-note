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

    // 시제품 .grid: 3칸. 아주 좁은 화면이나 큰 글자에서는 2칸으로.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final width = MediaQuery.sizeOf(context).width;
    final cols = (width < 340 || scale > 1.15) ? 2 : 3;
    final rows = <Widget>[];
    for (var i = 0; i < residents.length; i += cols) {
      final chunk = residents.skip(i).take(cols).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.s),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: Gap.s),
                  Expanded(
                    child: j < chunk.length ? _ResidentTile(resident: chunk[j], view: v) : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, Gap.xl),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          child: Row(
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
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.m, Gap.page, Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: Gap.s,
                children: [
                  Text(
                    '${cls.name} 별님 ${residents.length}명',
                    style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '담임 ${repo.staff(cls.homeroomId).displayName}',
                      style: const TextStyle(fontSize: T.caption, color: inkSub),
                    ),
                  ),
                ],
              ),
              const Text(
                '별님을 누르면 그동안 쌓인 관찰·체온 기록을 처음부터 볼 수 있어요.',
                style: TextStyle(fontSize: T.caption, color: inkSub),
              ),
            ],
          ),
        ),
        if (residents.isEmpty)
          const EmptyNote('이 반에는 별님이 없어요')
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Column(children: rows),
          ),
      ],
    );
  }
}

/// 반 탭 (시제품 .ctab): 반 색 점 + 이름 + 안 본 수. 고르면 반 색 20% 바탕 + 반 색 테두리.
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
        color: selected ? Color.alphaBlend(color.withValues(alpha: 0.2), surface) : surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? color : line, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => ref.read(handoverClassProvider.notifier).select(cls.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: tapHeight),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  cls.name,
                  style: TextStyle(
                    fontSize: T.body,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: inkMain,
                  ),
                ),
                if (unread > 0) ...[const SizedBox(width: 7), CountBadge(unread)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 별님 카드 (시제품 .gcard): 가운데 얼굴 · 이름 · 기록 수 · 최근 체온, 상태 알약. 순서는 바꾸지 않는다.
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

    // 상태 표시: 긴급·이상 대응 > 할 일 (시제품: 빨간/주황 테두리 + 작은 알약)
    Color border = line;
    double borderW = 1;
    Color bg = surface;
    String? status;
    Color statusInk = inkMain;
    Color statusBg = surface;
    if (c != null) {
      final sc = stageColors[c.isUrgent ? Stage.danger : c.severity]!;
      border = sc.line;
      borderW = 1.5;
      bg = Color.alphaBlend(sc.soft.withValues(alpha: 0.4), surface);
      status = '${c.isUrgent ? Stage.danger.symbol : c.severity.symbol} ${c.kindLabel}';
      statusInk = sc.ink;
      statusBg = sc.soft;
    } else if (tasks.isNotEmpty) {
      border = starYellow;
      borderW = 1.5;
      bg = const Color(0xFFFFFBF6);
      status = '할 일 ${dueLabel(tasks.first.task!, view.now)}';
      statusInk = hoTaskInk;
      statusBg = hoTaskBg;
    }

    final semantics = [
      '${r.name} 별님',
      last == null ? '체온 기록 없음' : '최근 ${(last.value / 10).toStringAsFixed(1)}도 ${last.judgment.stage.label}',
      ?status,
      if (newCount > 0) '새 기록 $newCount',
    ].join(', ');

    Widget fit(Widget w) => FittedBox(fit: BoxFit.scaleDown, child: w);

    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: border, width: borderW),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openArchive(context, r.id),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ResidentAvatar(name: r.name, classColor: cls.color, size: 54, residentId: r.id),
                    const SizedBox(height: 6),
                    fit(
                      Text(
                        r.name,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: T.body,
                          fontWeight: FontWeight.w800,
                          color: inkMain,
                          height: 1.3,
                        ),
                      ),
                    ),
                    fit(
                      Text(
                        '기록 $recordCount건',
                        maxLines: 1,
                        style: const TextStyle(fontSize: T.caption, color: inkSub),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (last == null)
                      fit(
                        const Text(
                          '체온 기록 없음',
                          maxLines: 1,
                          style: TextStyle(fontSize: T.caption, color: inkSub),
                        ),
                      )
                    else
                      fit(_TempPill(stage: last.judgment.stage, value: last.value)),
                    if (status != null) ...[
                      const SizedBox(height: 4),
                      fit(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(7)),
                          child: Text(
                            status,
                            maxLines: 1,
                            style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: statusInk),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                  ],
                ),
              ),
              if (newCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: starYellow, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text(
                      '새 $newCount',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: inkMain),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 최근 체온 알약: "✓ 36.4° 평소" (기호 + 숫자 + 판정 글자).
class _TempPill extends StatelessWidget {
  const _TempPill({required this.stage, required this.value});
  final Stage stage;
  final int value;

  @override
  Widget build(BuildContext context) {
    final c = stageColors[stage]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.line),
      ),
      child: Text(
        '${stage.symbol} ${(value / 10).toStringAsFixed(1)}° ${stage.label}',
        maxLines: 1,
        style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: c.ink),
      ),
    );
  }
}
