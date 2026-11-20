// 01 인수인계 (Claude Design Main.dc.html).
// 머리(고정) → 근무조 요약 → 필터 칩 → 긴급 카드 → 할 일 → 최신 기록, 오른쪽 아래 [기록하기].
// 숫자·이름·시각은 모두 저장소에서 계산한다 (handover_data.dart).
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart' show MobileAppBar, goResidentCard;
import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/photo.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'handover_cards.dart';
import 'handover_data.dart';
import 'shift_sheet.dart';
import 'write_sheet.dart';

class HandoverScreen extends ConsumerStatefulWidget {
  const HandoverScreen({super.key});

  @override
  ConsumerState<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends ConsumerState<HandoverScreen> {
  HoFilter _filter = HoFilter.all;

  InMemoryRepository get _repo => ref.read(repoProvider);
  String get _me => ref.read(currentUserProvider);

  // ── 동작
  void _read(Entry e) => _repo.markRead(e.id, _me, _repo.now());

  void _openResident(String residentId, [Entry? e]) {
    if (e != null) _read(e);
    goResidentCard(ref, residentId);
  }

  void _remeasure(String residentId, [Entry? e]) {
    if (e != null) _read(e);
    ref.read(quickTempProvider.notifier).openFor(residentId);
  }

  void _acknowledge(Case c) {
    _repo.acknowledge(c.id, _me, _repo.now());
    showDsToast(context, '확인했다고 알렸어요');
  }

  void _completeTodo(Entry e) {
    final t = e.task!;
    if (t.kind == TaskKind.temp && e.residentId != null) {
      _remeasure(e.residentId!, e);
      return;
    }
    _repo.completeTask(e.id, _me, _repo.now());
    showDsToast(context, '할 일을 완료했어요');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final now = repo.now();
    final d = HandoverData(repo, me, now);
    final view = d.viewFor(_filter);
    final pad = MediaQuery.paddingOf(context);

    // 개발 DB 예시: 그 자리의 실제 자료가 하나도 없을 때만.
    final exCase = repo.isDev && _filter == HoFilter.all && d.cases.isEmpty;
    final exTodo = repo.isDev && (_filter == HoFilter.all || _filter == HoFilter.todo) && d.todos.isEmpty;
    final exFeed = repo.isDev &&
        (_filter == HoFilter.all || _filter == HoFilter.notice || _filter == HoFilter.record) &&
        d.feed.isEmpty;

    Widget side(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: w);

    final items = <Widget>[
      side(ShiftSummaryCard(
        timeText: '${hhmm(now)} 기준',
        scopeText: _scopeText(repo, d.myClasses),
        title: d.shiftTitle,
        urgent: d.caseCount,
        todo: d.taskCount,
        unread: d.unreadCount,
        missed: d.missed.length,
        onTap: () => showShiftSheet(context),
      )),
      HoFilterBar(chips: [
        for (final f in HoFilter.values)
          (
            f.label,
            _filter == f,
            d.countFor(f),
            switch (f) { HoFilter.unread => Ds.red500, HoFilter.todo => Ds.blue500, _ => null },
            () => setState(() => _filter = f),
          ),
      ]),
      for (final c in view.cases) side(_caseCard(repo, me, now, c)),
      if (exCase) side(const ExampleWrap(child: _ExampleUrgent())),
      for (final e in view.todos) side(_todoRow(repo, d, now, e)),
      if (exTodo) side(const ExampleWrap(child: _ExampleTodo())),
      if (view.feed.isNotEmpty || exFeed) side(const DsSectionTitle('최신 기록')),
      for (final e in view.feed) side(_feedCard(repo, d, now, e)),
      if (exFeed) side(ExampleWrap(child: _filter == HoFilter.notice ? const _ExampleNotice() : const _ExampleObservation())),
      if (view.isEmpty && !exCase && !exTodo && !exFeed) side(HoEmpty(_filter.emptyText)),
    ];

    return ColoredBox(
      color: Ds.bg,
      child: Stack(children: [
        ListView.separated(
          padding: EdgeInsets.only(top: pad.top + 56 + 8, bottom: 112 + pad.bottom),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) => items[i],
        ),
        // 머리: 위에 고정, 아래 내용이 비쳐 보이게 흐림.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (pad.top > 0) Container(height: pad.top, color: const Color(0xE6F2F4F6)),
                const MobileAppBar(section: '인수인계'),
              ]),
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 16 + pad.bottom,
          child: WriteFab(onTap: () => showWriteSheet(context, ref)),
        ),
      ]),
    );
  }

  // ── 실제 자료 → 카드

  /// '은하수자리 6명' (담당 반 하나) · '6개 반 36명'
  static String _scopeText(InMemoryRepository repo, Set<String> mine) {
    final cls = repo.classes.where((c) => mine.contains(c.id)).toList();
    final n = repo.residents.where((r) => mine.contains(r.classId)).length;
    return cls.length == 1 ? '${cls.single.name} ${n}명' : '${cls.length}개 반 ${n}명';
  }

  /// 이름 앞 동그란 프로필 사진 (없으면 이름 두 글자).
  static Widget? _face(InMemoryRepository repo, String? rid, double size) {
    if (rid == null) return null;
    return ResidentCircle(label: repo.resident(rid).shortName, url: repo.profilePhotoOf(rid)?.url, size: size);
  }

  Widget _caseCard(InMemoryRepository repo, String me, DateTime now, Case c) {
    final r = repo.resident(c.residentId);
    final ms = repo.measurementsOfCase(c.id).where((m) => !m.isVoided).toList();
    final latest = ms.isEmpty ? null : ms.last;
    final value = latest?.value ?? c.firstTemp;
    final diff = latest?.judgment.diff ?? (c.firstTemp - c.baseline);
    final stage = latest?.judgment.stage ?? c.severity;
    final label = switch (stage) {
      Stage.danger || Stage.abnormal => diff >= 10 ? '급상승' : '상승',
      Stage.low => '저온',
      Stage.caution => '주의',
      Stage.normal => '회복',
    };
    final color = stage == Stage.low ? Ds.blue500 : (stage == Stage.normal ? Ds.gray900 : Ds.red500);
    final first = ms.isEmpty ? c.createdAt : ms.first.measuredAt;
    final (schedule, right) = c.remeasureAt != null
        ? ('${hhmm(c.remeasureAt!)} 재측정 예정', untilText(c.remeasureAt!, now))
        : ('${hhmm(first)} 첫 측정', '${spanText(now.difference(first).inMinutes)} 전');
    return UrgentVitalCard(
      key: ValueKey('case-${c.id}'),
      classTag: repo.classOf(c.classId).name,
      name: r.name,
      avatar: _face(repo, c.residentId, 32),
      tempText: fmtC(value),
      diffText: '${formatDiff(diff)}°C $label',
      tempColor: color,
      scheduleText: schedule,
      scheduleRight: right,
      acknowledged: repo.isAcknowledged(c.id, me),
      onAcknowledge: () => _acknowledge(c),
      onRemeasure: () => _remeasure(c.residentId),
      onTap: () => openCaseDetail(context, c.id),
    );
  }

  Widget _todoRow(InMemoryRepository repo, HandoverData d, DateTime now, Entry e) {
    final rid = e.residentId;
    final body = (e.body ?? '').replaceAll('\n', ' ').trim();
    return TodoRow(
      key: ValueKey('todo-${e.id}'),
      classTag: e.classId != null ? repo.classOf(e.classId!).name : '전체',
      name: rid != null ? repo.resident(rid).name : repo.staff(e.authorId).name,
      avatar: _face(repo, rid, 24),
      timeText: relTime(e.createdAt, now),
      line: body.isEmpty ? e.task!.label : body,
      unread: d.isUnread(e),
      onDone: () => _completeTodo(e),
      onName: rid == null ? null : () => _openResident(rid, e),
      onTap: () => _read(e),
    );
  }

  Widget _feedCard(InMemoryRepository repo, HandoverData d, DateTime now, Entry e) {
    final key = ValueKey('feed-${e.id}');
    final time = relTime(e.createdAt, now);
    final unread = d.isUnread(e);
    final rid = e.residentId;
    final cls = e.classId != null ? repo.classOf(e.classId!) : (rid != null ? repo.classOf(repo.resident(rid).classId) : null);
    final author = repo.staff(e.authorId);

    if (e.measurementId != null) {
      final m = _measurementOrNull(repo, e.measurementId!);
      final t = e.task;
      final open = t != null && !t.done;
      String side;
      if (open && t.dueAt != null) {
        final mins = t.dueAt!.difference(now).inMinutes;
        side = mins >= 0 ? '기한 ${spanText(mins)}' : '기한 ${spanText(mins)} 지남';
      } else if (open) {
        side = t.duePreset ?? '기한 없음';
      } else {
        side = m == null ? '' : '평소 ${fmtC(m.judgment.baseline)}';
      }
      String? doneText;
      if (t != null && t.done && t.doneAt != null) {
        final res = t.resultMeasurementId == null ? null : _measurementOrNull(repo, t.resultMeasurementId!);
        doneText = '${hhmm(t.doneAt!)} 재측정${res == null ? ' 완료' : ' ${fmtC(res.value)}'}';
      }
      final homeroom = cls?.homeroomId;
      final checked = homeroom != null && (e.authorId == homeroom || repo.isRead(e.id, homeroom));
      final diff = m?.judgment.diff ?? 0;
      return VitalFeedCard(
        key: key,
        classTag: cls?.name ?? '',
        name: rid != null ? repo.resident(rid).name : '',
        avatar: _face(repo, rid, 28),
        timeText: time,
        tempText: m == null ? '-' : fmtC(m.value),
        judgeText: m == null ? '' : (m.isVoided ? '무효' : '(${fmtDiffDeg(diff)}) ${m.judgment.stage.label}'),
        judgeColor: m == null || m.isVoided ? Ds.gray500 : diffColor(diff),
        voided: m?.isVoided ?? false,
        sideText: side,
        checked: checked,
        doneText: doneText,
        onRemeasure: open && rid != null ? () => _remeasure(rid, e) : null,
        onName: rid == null ? null : () => _openResident(rid, e),
        onTap: () => _read(e),
        unread: unread,
      );
    }

    if (e.scope == EntryScope.facility || (e.scope == EntryScope.classScope && cls == null)) {
      return NoticeAllFeedCard(
        key: key,
        timeText: time,
        title: e.title,
        body: e.body ?? '',
        pinned: e.pinned,
        onTap: () => _read(e),
        unread: unread,
      );
    }

    if (e.scope == EntryScope.classScope) {
      return NoticeClassFeedCard(
        key: key,
        classTag: cls!.name,
        author: repo.classes.any((c) => c.homeroomId == e.authorId) ? '${author.name} 담임' : author.displayName,
        timeText: time,
        body: e.body ?? '',
        highlight: RegExp('${RegExp.escape(cls.name)}(\\s?\\d+순위)?'),
        onTap: () => _read(e),
        unread: unread,
      );
    }

    final likes = repo.likesOf(e.id);
    return ObservationFeedCard(
      key: key,
      classTag: cls?.name ?? '',
      name: rid != null ? repo.resident(rid).name : '',
      avatar: _face(repo, rid, 24),
      author: author.name,
      timeText: time,
      body: e.body ?? '',
      likes: likes.length,
      liked: likes.contains(d.me),
      onLike: () => repo.like(e.id, d.me, repo.now()),
      onName: rid == null ? null : () => _openResident(rid, e),
      onTap: () => _read(e),
      unread: unread,
    );
  }

  static Measurement? _measurementOrNull(InMemoryRepository repo, String id) {
    try {
      return repo.measurement(id);
    } catch (_) {
      return null;
    }
  }
}

// ── 개발 DB 예시 카드 (실제 자료가 생기면 사라진다). 이름은 예시 명단과 같은 가짜 이름.

class _ExampleUrgent extends StatelessWidget {
  const _ExampleUrgent();

  @override
  Widget build(BuildContext context) => UrgentVitalCard(
        classTag: '예시반',
        name: '예시 별님',
        avatar: const ResidentCircle(label: '예시', size: 32),
        tempText: '38.2°C',
        diffText: '+1.4°C 급상승',
        tempColor: Ds.red500,
        scheduleText: '09:51 재측정 예정',
        scheduleRight: '10분 후',
        acknowledged: false,
        onAcknowledge: () {},
        onRemeasure: () {},
      );
}

class _ExampleTodo extends StatelessWidget {
  const _ExampleTodo();

  @override
  Widget build(BuildContext context) => TodoRow(
        classTag: '예시반',
        name: '예시 별님',
        avatar: const ResidentCircle(label: '예시', size: 24),
        timeText: '어제 15:20',
        line: '재측정 필요 (37.5°C 주의)',
        onDone: () {},
      );
}

class _ExampleObservation extends StatelessWidget {
  const _ExampleObservation();

  @override
  Widget build(BuildContext context) => ObservationFeedCard(
        classTag: '예시반',
        name: '예시 별님',
        avatar: const ResidentCircle(label: '예시', size: 24),
        author: '예시 선생님',
        timeText: '07:50',
        body: '아침 식사 반찬 남김없이 잘 드시고 기분 좋게 노래 흥얼거리심. 컨디션 매우 양호합니다.',
        likes: 2,
        liked: false,
        onLike: () {},
      );
}

class _ExampleNotice extends StatelessWidget {
  const _ExampleNotice();

  @override
  Widget build(BuildContext context) => const NoticeAllFeedCard(
        timeText: '08:00',
        title: '오늘 10:00 목욕실 온수 보일러 점검 안내',
        body: '10:00~11:30 온수 사용 불가. 오전 목욕은 일정을 앞당겨 진행해주세요.',
      );
}
