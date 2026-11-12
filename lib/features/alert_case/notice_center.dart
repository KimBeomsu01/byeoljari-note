// S2 알림: 🔔 목록과 위에서 내려오는 배너 (이상 대응 S2, 통합 명세 9장).
// 금요일 시연은 실제 푸시 대신 앱 안 배너 + 🔔 목록으로 보여준다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'case_ui.dart';

Case? _caseOrNull(InMemoryRepository repo, String id) {
  try {
    return repo.caseById(id);
  } catch (_) {
    return null;
  }
}

/// 알림 한 줄 위에 붙는 "반 별님 · 긴급/이상 대응".
String _noticeContext(InMemoryRepository repo, AppNotice n) {
  final c = _caseOrNull(repo, n.caseId);
  if (c == null) return '';
  return '${repo.classOf(c.classId).name} ${repo.resident(c.residentId).name} · ${caseBadge(c)}';
}

/// 알림 한 줄의 "누구": "은하수자리 이서준".
String _noticeWho(InMemoryRepository repo, AppNotice n) {
  final c = _caseOrNull(repo, n.caseId);
  if (c == null) return '';
  return '${repo.classOf(c.classId).name} ${repo.resident(c.residentId).name}';
}

/// 🔔 목록 시트. 진행 중인 건 위, 끝난 건 아래 (따로 묶음).
Future<void> showNoticeCenter(BuildContext context, WidgetRef ref) {
  final repo = ref.read(repoProvider);
  final me = ref.read(currentUserProvider);
  final all = repo.noticesFor(me);
  bool open(AppNotice n) => _caseOrNull(repo, n.caseId)?.isOpen ?? false;
  final active = all.where(open).toList();
  final done = all.where((n) => !open(n)).toList();
  repo.markNoticesSeen(me, ref.read(clockProvider)());
  Widget row(BuildContext sheet, AppNotice n, bool isOpen) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.s),
        child: _NoticeRow(
          notice: n,
          who: _noticeWho(repo, n),
          caseItem: _caseOrNull(repo, n.caseId),
          closed: !isOpen,
          onTap: () {
            Navigator.pop(sheet);
            openCaseDetail(context, n.caseId);
          },
        ),
      );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: paper,
    builder: (sheet) => FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl), children: [
          const Text('알림', style: TextStyle(fontSize: T.headline, fontWeight: FontWeight.w800)),
          if (all.isEmpty) const EmptyNote('받은 알림이 없어요'),
          if (active.isNotEmpty) ...[
            SectionTitle('진행 중', count: active.length),
            for (final n in active) row(sheet, n, true),
          ],
          if (done.isNotEmpty) ...[
            SectionTitle('끝난 건', count: done.length),
            for (final n in done) row(sheet, n, false),
          ],
        ]),
      ),
    ),
  );
}

/// 알림 한 줄 (높이 72 이상): [중요] 제목 / 누구 + 긴급·이상 대응 / 내용 / 시각.
class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.who, required this.caseItem, required this.closed, required this.onTap});
  final AppNotice notice;
  final String who;
  final Case? caseItem;
  final bool closed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final danger = stageColors[Stage.danger]!;
    final c = caseItem;
    return Semantics(
      button: true,
      child: InfoCard(
        accent: n.important && !closed ? danger.ink : null,
        background: closed ? paper : surface,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.m, Gap.m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72 - Gap.m * 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (n.important) StatusPill('중요', color: danger.ink, filled: true),
                  if (closed) const StatusPill('끝난 건', color: inkSub),
                  Text(n.title, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
                ]),
                if (who.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(who, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
                ],
                if (c != null)
                  Text(caseBadge(c), style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: caseColors(c).ink)),
                Text(n.body, style: const TextStyle(fontSize: T.body, color: inkMain)),
                Text(hm(n.at), style: const TextStyle(fontSize: T.caption, color: inkSub)),
              ]),
            ),
            const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.chevron_right, size: 28, color: inkSub)),
          ]),
        ),
      ),
    );
  }
}

/// 새 알림이 오면 화면 위에서 배너를 내린다 (약 5초 뒤 사라짐). 누르면 S3.
/// 내가 한 행동으로 생긴 알림(내가 잰 체온, 내가 누른 확인 등)은 배너로 띄우지 않는다.
/// 역할을 바꾸면 그 사람이 아직 안 본 알림 중 가장 최근 것을 띄운다 (시연 5단계).
class NoticeBannerHost extends ConsumerStatefulWidget {
  const NoticeBannerHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<NoticeBannerHost> createState() => _NoticeBannerHostState();
}

class _NoticeBannerHostState extends ConsumerState<NoticeBannerHost> {
  /// 사람마다 이미 배너로 띄웠거나 건너뛴 알림.
  final Map<String, Set<String>> _handled = {};
  OverlayEntry? _entry;
  bool _checkQueued = false;

  @override
  void initState() {
    super.initState();
    // 앱을 켤 때 이미 있던 알림은 배너로 띄우지 않는다.
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    _handled[me] = {for (final n in repo.noticesFor(me)) n.id};
    ref.listenManual(repoProvider, (_, _) => _queueCheck());
    ref.listenManual(currentUserProvider, (_, _) => _queueCheck());
  }

  @override
  void dispose() {
    _removeBanner();
    super.dispose();
  }

  void _queueCheck() {
    if (_checkQueued) return;
    _checkQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (mounted) _check();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// 이 알림이 [me]의 행동으로 생겼나: 같은 시각에 내가 남긴 기록이나 내가 잰 체온이 있으면 그렇다.
  bool _selfCaused(InMemoryRepository repo, AppNotice n, String me) {
    if (repo.eventsOf(n.caseId).any((e) => e.at == n.at && e.actorId == me)) return true;
    return repo.measurementsOfCase(n.caseId).any((m) => m.measuredAt == n.at && m.recordedBy == me);
  }

  void _check() {
    final repo = ref.read(repoProvider);
    final me = ref.read(currentUserProvider);
    final handled = _handled.putIfAbsent(me, () => {});
    final list = repo.noticesFor(me); // 최신 먼저
    final unseen = repo.unseenNoticeCount(me);
    final fresh = [
      for (var i = 0; i < list.length && i < unseen; i++)
        if (!handled.contains(list[i].id)) list[i]
    ];
    // 이미 본(🔔 열어 본) 알림도 다시 띄우지 않도록 표시
    handled.addAll(list.map((n) => n.id));
    final candidates = fresh.where((n) => !_selfCaused(repo, n, me)).toList();
    if (candidates.isEmpty) return;
    final pick = candidates.firstWhere((n) => n.important, orElse: () => candidates.first);
    _showBanner(pick);
  }

  void _removeBanner() {
    final e = _entry;
    _entry = null;
    if (e == null) return;
    e.remove();
    e.dispose();
  }

  void _showBanner(AppNotice n) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _removeBanner();
    final repo = ref.read(repoProvider);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NoticeBanner(
        notice: n,
        contextLine: _noticeContext(repo, n),
        onOpen: () {
          if (_entry == entry) _removeBanner();
          if (mounted) openCaseDetail(context, n.caseId);
        },
        onDismissed: () {
          if (_entry == entry) _removeBanner();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NoticeBanner extends StatefulWidget {
  const _NoticeBanner({
    required this.notice,
    required this.contextLine,
    required this.onOpen,
    required this.onDismissed,
  });
  final AppNotice notice;
  final String contextLine;
  final VoidCallback onOpen;
  final VoidCallback onDismissed;

  @override
  State<_NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<_NoticeBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), _hide);
  }

  Future<void> _hide() async {
    _timer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final important = n.important;
    final danger = stageColors[Stage.danger]!;
    // 중요 알림: 빨간 바탕 + 흰 글자 + '중요' 표. 보통 알림: 흰 바탕 + 남색 테두리.
    final bg = important ? danger.ink : surface;
    final fg = important ? Colors.white : inkMain;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -1.2), end: Offset.zero)
              .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, 0),
            child: Semantics(
              liveRegion: true,
              button: true,
              label: '${important ? '중요 알림, ' : '알림, '}${n.title}, ${widget.contextLine}, ${n.body}. 누르면 자세히 봐요',
              child: Material(
                color: bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.card),
                  side: BorderSide(color: important ? danger.ink : brandDark, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onOpen,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 72),
                    padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.xs, Gap.m),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: ExcludeSemantics(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              if (important)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration:
                                      BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Radii.pill)),
                                  child: Text('중요',
                                      style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: danger.ink)),
                                )
                              else
                                const Icon(Icons.notifications_active, color: brandDark, size: 24),
                              Text(n.title, style: TextStyle(fontWeight: FontWeight.w800, color: fg, fontSize: T.title)),
                            ]),
                            if (widget.contextLine.isNotEmpty)
                              Text(widget.contextLine,
                                  style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: fg)),
                            Text(n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: T.body, color: fg)),
                          ]),
                        ),
                      ),
                      IconButton(
                        tooltip: '알림 닫기',
                        iconSize: 26,
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        color: fg,
                        icon: const Icon(Icons.close),
                        onPressed: _hide,
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
