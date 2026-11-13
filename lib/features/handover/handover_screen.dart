// 인수인계 첫 화면 (개선 시안 1 "지금 아픈 별님이 있나? 내가 이어받은 할 일은?").
// 순서: ① 한 문장 요약 → ② 이상 대응 카드 (긴급 먼저) → ③ 이어받은 할 일 (한 줄 = 한 별님 = 한 버튼) → 안 본 기록 n개 ›.
// 최신 기록·별님별 기록·보기 칩·[기록 남기기]는 "안 본 기록" 줄 안(HandoverRecordsScreen)으로 옮겼다.
// 체온 미기록은 일정 탭 "먼저 챙길 별님"과 전체 기록 머리말의 작은 링크에 있다.
// 상단 제목줄(누구·근무·반 + 인수인계 + 🔔)은 app.dart의 공통 머리가 그린다.
// 이 화면은 메모리 저장소를 바로 읽으므로 "불러오는 중·실패" 상태가 생기지 않는다. 서버 저장소로 바꿀 때 5-5 상태를 붙인다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatar.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import 'handover_common.dart';
import 'handover_view.dart';
import 'records_screen.dart';
import 'response_card.dart';
import 'task_actions.dart';

class HandoverScreen extends ConsumerWidget {
  const HandoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final v = HandoverView(repo, me, ref.read(clockProvider)());
    final rows = v.taskRows;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
      children: [
        SummarySentence(urgent: v.urgentCount, abnormal: v.abnormalCount, tasks: rows.length),
        for (final c in v.activeCases) ...[
          const SizedBox(height: Gap.m),
          ResponseCard(key: ValueKey('case-${c.id}'), caseItem: c),
        ],
        if (rows.isNotEmpty) ...[
          const SizedBox(height: Gap.m),
          _TaskList(view: v, rows: rows),
        ],
        const SizedBox(height: Gap.m),
        _UnreadRow(unread: v.unread.length, notices: v.unreadNotices),
      ],
    );
  }
}

/// ① 한 문장 요약. 0인 숫자는 말하지 않는다. 숫자는 색 + 글자 (색만으로 뜻을 전하지 않는다).
class SummarySentence extends StatelessWidget {
  const SummarySentence({super.key, required this.urgent, required this.abnormal, required this.tasks});
  final int urgent;
  final int abnormal;
  final int tasks;

  /// 화면에 그리는 문장 그대로 (테스트·읽어 주기용).
  String get plain => _spans().map((s) => s.$1).join();

  List<(String, Color?)> _spans() {
    final danger = stageColors[Stage.danger]!.ink;
    final abn = stageColors[Stage.abnormal]!.ink;
    final out = <(String, Color?)>[];
    final hasCase = urgent > 0 || abnormal > 0;
    if (urgent > 0) out.addAll([('긴급 ', null), ('$urgent건', danger)]);
    if (urgent > 0 && abnormal > 0) out.add(('과 ', null));
    if (abnormal > 0) out.addAll([('이상 대응 ', null), ('$abnormal건', abn)]);
    if (hasCase) out.add((tasks > 0 ? '이 있고,\n' : '이 있어요.', null));
    if (tasks > 0) out.addAll([('이어받은 할 일이 ', null), ('$tasks개', brandDark), (' 있어요.', null)]);
    if (!hasCase && tasks == 0) out.add(('지금 아픈 별님도,\n이어받은 할 일도 없어요.', null));
    return out;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text.rich(
      TextSpan(children: [for (final (t, c) in _spans()) TextSpan(text: t, style: c == null ? null : TextStyle(color: c))]),
      semanticsLabel: plain.replaceAll('\n', ' '),
      style: const TextStyle(fontFamily: fontBig, fontSize: 19, fontWeight: FontWeight.w700, height: 1.4, color: inkMain),
    ),
  );
}

/// ③ 이어받은 할 일 N · 급한 순.
class _TaskList extends StatelessWidget {
  const _TaskList({required this.view, required this.rows});
  final HandoverView view;
  final List<TaskRow> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                '이어받은 할 일 ${rows.length}',
                style: const TextStyle(fontFamily: fontBig, fontSize: 19, fontWeight: FontWeight.w700, color: inkMain),
              ),
            ),
            const Text('급한 순', style: TextStyle(fontSize: T.caption, color: inkSub)),
          ],
        ),
      ),
      Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: const BorderSide(color: line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, r) in rows.indexed) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: lineSoft),
              _TaskRowTile(view: view, row: r),
            ],
          ],
        ),
      ),
    ],
  );
}

class _TaskRowTile extends ConsumerWidget {
  const _TaskRowTile({required this.view, required this.row});
  final HandoverView view;
  final TaskRow row;

  /// 할 일 이름을 쉬운 말로 ('재측정' → '다시 재기').
  static String plainLabel(String label) => label == '재측정' ? '다시 재기' : label;

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// 둘째 줄: 왜·언제까지. 판정이 있으면 판정 색 + 기호.
  static (String, Color) subline(InMemoryRepository repo, Entry e, DateTime now) {
    final t = e.task!;
    final due = t.dueAt != null ? '${whenLabel(t.dueAt!, now)}까지' : dueLabel(t, now);
    if (e.measurementId != null) {
      final m = repo.measurement(e.measurementId!);
      final st = m.judgment.stage;
      if (st != Stage.normal) {
        return ('${st.symbol} ${st.label} ${formatTemp(m.value)}℃ · $due', stageColors[st]!.ink);
      }
    }
    final where = e.classId != null ? repo.classOf(e.classId!).name : '전체';
    if (!_sameDay(e.createdAt, now)) return ('$where · ${whenLabel(e.createdAt, now)}부터', inkSub);
    if (t.kind == TaskKind.temp) {
      return ('아직 안 쟀어요 · ${t.duePreset != null ? '${t.duePreset}까지' : due}', inkSub);
    }
    return ('$where · ${t.duePreset != null ? '${t.duePreset}까지' : due}', inkSub);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = view.repo;
    final e = row.first;
    final rid = row.residentId;
    final who = rid != null ? repo.resident(rid).name : (e.classId != null ? repo.classOf(e.classId!).name : '전체');
    final more = row.entries.length > 1 ? ' 외 ${row.entries.length - 1}' : '';
    final title = '$who · ${plainLabel(e.task!.label)}$more';
    final (sub, subColor) = subline(repo, e, view.now);

    final Widget action = row.isTemp
        ? _SoftButton(
            text: '재기',
            semantics: '$who 체온 재기',
            bg: actionSoft,
            ink: actionInk,
            onTap: () => openQuickTempFor(context, ref, rid!),
          )
        : _SoftButton(
            text: '완료',
            semantics: '${e.task!.label} 완료',
            bg: sage,
            ink: brandDark,
            onTap: () => confirmCompleteTask(context, ref, e),
          );

    return InkWell(
      onTap: rid == null ? null : () => openArchive(context, rid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            if (rid != null) FaceAvatar.resident(rid, size: 44) else FaceAvatar.staff(e.authorId, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain, height: 1.35),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: T.caption, color: subColor, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            action,
          ],
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({required this.text, required this.semantics, required this.bg, required this.ink, required this.onTap});
  final String text;
  final String semantics;
  final Color bg;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: semantics,
    excludeSemantics: true,
    child: Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        ),
      ),
    ),
  );
}

/// "안 본 기록 8개 · 공지 2 ›" — 누르면 전체 기록 (최신 기록·별님별 기록·기록 남기기).
class _UnreadRow extends StatelessWidget {
  const _UnreadRow({required this.unread, required this.notices});
  final int unread;
  final int notices;

  @override
  Widget build(BuildContext context) {
    final main = unread > 0 ? '안 본 기록 $unread개' : '안 본 기록 없어요';
    final tail = unread == 0 ? ' · 전체 기록 보기' : (notices > 0 ? ' · 공지 $notices' : '');
    return Semantics(
      button: true,
      label: '$main$tail, 전체 기록 열기',
      excludeSemantics: true,
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openHandoverRecords(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: tapHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                if (unread > 0) ...[const YellowDot(size: 12), const SizedBox(width: 12)],
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: main),
                        TextSpan(text: tail, style: const TextStyle(fontWeight: FontWeight.w400, color: inkSub)),
                      ],
                    ),
                    style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('›', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: inkSub)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
