// PC 01 현황판 오른쪽 (aside span 4): 실시간 응급·의료 타임라인 + 교대 근무조 인계 및 공지 · 결재 대기 업무.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_dashboard_ui.dart';
import 'pc_shell.dart';

// ─────────────────────────── 실시간 응급·의료 타임라인

enum _FeedTone { urgent, consult, normal, caution, alert, notice, call, done }

class _Feed {
  _Feed({
    required this.at,
    required this.tone,
    required this.header,
    required this.title,
    this.badge,
    this.side,
    this.body,
    this.footLeft,
    this.footRight,
    this.call,
  });
  final DateTime at;
  final _FeedTone tone;
  final String header;
  final String title;
  final String? badge;

  /// 오른쪽 위 글자 (꼬리표 대신, 예: '정상').
  final String? side;
  final String? body;
  final String? footLeft;
  final String? footRight;

  /// 이 줄에서 열 수 있는 의료 호출.
  final MedicalCall? call;
}

/// 최근 호출 · 비대면 협진 · 알림 · 측정을 섞어 최신순 6개.
List<_Feed> _buildFeed(InMemoryRepository repo, DateTime now) {
  String who(String residentId) {
    final r = repo.resident(residentId);
    return '[${repo.classOf(r.classId).name}] ${r.name}';
  }

  final items = <_Feed>[];
  final calls = repo.calls.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // 의료 호출 (최근 3건)
  for (final c in calls.take(3)) {
    final msgs = repo.messagesOf(c.id).where((m) => m.kind == 'text').toList();
    final temp = c.temp == null ? '' : ' (${degC(c.temp!)}${c.level == CallLevel.urgent ? ' 고온 감지' : ''})';
    items.add(
      _Feed(
        at: c.createdAt,
        tone: !c.isOpen ? _FeedTone.done : (c.level == CallLevel.urgent ? _FeedTone.urgent : _FeedTone.call),
        header:
            '${hm(c.createdAt)} · ${switch (c.level) {
              CallLevel.urgent => '긴급 발열 호출',
              CallLevel.observe => '관찰 의료 호출',
              CallLevel.general => '일반 의료 의뢰',
            }}',
        badge: !c.isOpen ? '완료' : (c.videoAt != null ? '화상 ${hm(c.videoAt!)} 예약' : '응답 대기'),
        title: '${who(c.residentId)}$temp',
        body: msgs.isEmpty ? c.summary : msgs.last.body,
        call: c,
      ),
    );
  }

  // 비대면 협진 (화상 예약된 호출, 최근 2건)
  final video = repo.calls.where((c) => c.videoAt != null).toList()..sort((a, b) => b.videoAt!.compareTo(a.videoAt!));
  for (final c in video.take(2)) {
    final rx = repo.prescriptionOf(c.id);
    final issued = rx != null && rx.issued;
    final doctor = rx == null ? null : repo.staff(rx.doctorId);
    items.add(
      _Feed(
        at: c.videoAt!,
        tone: _FeedTone.consult,
        header: '${hm(c.videoAt!)} · 비대면 협진 ${issued ? '완료' : (now.isBefore(c.videoAt!) ? '예정' : '진행')}',
        badge: issued ? '처방전 수신' : (rx != null ? '처방전 작성 중' : '화상 예약'),
        title: '${who(c.residentId)}${c.temp == null ? '' : ' (${degC(c.temp!)})'}',
        body: issued
            ? '${doctor!.displayName} 원격 진료. ${rx.codeName}(${rx.code}) 진단 후 전자처방전 발행.'
            : (rx != null ? '${doctor!.displayName} 원격 진료 중. 진단서 · 처방전을 작성하고 있어요.' : '비대면 화상 진료가 ${hm(c.videoAt!)}에 예약되어 있어요.'),
        footLeft: issued ? '발행 ${hm(rx.issuedAt ?? rx.updatedAt)}' : (rx != null ? '초안 저장 ${hm(rx.updatedAt)}' : null),
        footRight: issued ? rx.number : null,
        call: c,
      ),
    );
  }

  // 알림 (새 이상 건 알림은 호출 줄과 겹쳐서 뺀다, 최근 2건)
  final notices = repo.allNotices.where((n) => !n.title.startsWith('새 ')).take(2);
  for (final n in notices) {
    items.add(_Feed(at: n.at, tone: n.important ? _FeedTone.alert : _FeedTone.notice, header: '${hm(n.at)} · ${n.title}', title: n.body));
  }

  // 체온 측정 (최근 2건)
  for (final m in repo.allMeasurements.where((m) => !m.isVoided).take(2)) {
    final r = repo.resident(m.residentId);
    final cls = repo.classOf(r.classId);
    final st = m.judgment.stage;
    items.add(
      _Feed(
        at: m.measuredAt,
        tone: st == Stage.normal ? _FeedTone.normal : (st == Stage.caution ? _FeedTone.caution : _FeedTone.alert),
        header: '${hm(m.measuredAt)} · ${st == Stage.normal ? '정기 바이탈 기록' : '체온 ${st.label} 감지'}',
        side: st == Stage.normal ? '정상' : st.label,
        title: st == Stage.normal
            ? '[${cls.name}] ${r.name} (${degC(m.value)}) 활력징후 기록 완료'
            : '[${cls.name}] ${r.name} (${degC(m.value)}) 평소보다 ${formatDiff(m.judgment.diff)}℃',
      ),
    );
  }

  items.sort((a, b) => b.at.compareTo(a.at));
  return items.take(6).toList();
}

class LiveFeedCard extends ConsumerWidget {
  const LiveFeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final feed = _buildFeed(repo, now);
    final me = ref.watch(currentUserProvider);

    void openCall(MedicalCall c) {
      ref.read(selectedCallProvider.notifier).select(c.id);
      ref.read(pcPageProvider.notifier).go(PcPage.calls);
    }

    void askOnSite(MedicalCall c) {
      repo.sendMessage(c.id, me, '현장 확인 부탁드립니다. (현황판에서 요청)');
      showDsToast(context, '케어팀 대화에 현장 확인 요청을 남겼어요');
    }

    Widget list;
    if (feed.isEmpty) {
      list = repo.isDev
          ? ExampleWrap(
              child: _FeedTile(
                item: _Feed(
                  at: now,
                  tone: _FeedTone.urgent,
                  header: '10:11 · 긴급 발열 호출',
                  badge: '응답 대기',
                  title: '[예시반] 예시 별님 (38.2℃ 고온 감지)',
                  body: '체온 이상이 생기면 호출 · 협진 · 측정 기록이 여기에 시간순으로 올라와요.',
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '아직 올라온 소식이 없어요',
                textAlign: TextAlign.center,
                style: pcText(14, color: Ds.gray500),
              ),
            );
    } else {
      list = Stack(
        children: [
          const Positioned(
            left: 17,
            top: 8,
            bottom: 8,
            child: SizedBox(width: 2, child: ColoredBox(color: Ds.gray200)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < feed.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _FeedTile(
                  item: feed[i],
                  onOpen: feed[i].call == null ? null : () => openCall(feed[i].call!),
                  onAsk: feed[i].call != null && feed[i].call!.isOpen && feed[i].tone != _FeedTone.consult
                      ? () => askOnSite(feed[i].call!)
                      : null,
                ),
              ],
            ],
          ),
        ],
      );
    }

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PcDot(10, Ds.red500),
              const SizedBox(width: 8),
              Expanded(
                child: Text('실시간 응급·의료 타임라인', style: pcText(pcBase, weight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Ds.blue50, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'LIVE FEED',
                  style: pcText(pcBase, weight: FontWeight.w700, color: Ds.blue500, mono: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          list,
        ],
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.item, this.onOpen, this.onAsk});
  final _Feed item;
  final VoidCallback? onOpen;
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    final t = item.tone;
    // (원 바탕, 원 아이콘 색, 원 테두리, 아이콘, 카드 바탕, 카드 테두리, 머리 글자 색)
    final (Color cBg, Color cFg, Color? cBorder, IconData icon, Color cardBg, Color cardBorder, Color headColor) = switch (t) {
      _FeedTone.urgent => (
        Ds.red500,
        Colors.white,
        null,
        Icons.medical_services_rounded,
        const Color(0x99FEF2F2),
        const Color(0xCCFECACA),
        Ds.red500,
      ),
      _FeedTone.alert => (
        Ds.red500,
        Colors.white,
        null,
        Icons.warning_amber_rounded,
        const Color(0x99FEF2F2),
        const Color(0xCCFECACA),
        Ds.red500,
      ),
      _FeedTone.consult => (Ds.blue500, Colors.white, null, Icons.videocam_rounded, const Color(0x80E8F3FF), Ds.borderInfo, Ds.blue500),
      _FeedTone.call => (
        Tw.amber50,
        Tw.amber700,
        Tw.amber200,
        Icons.medical_services_outlined,
        const Color(0x99FFFBEB),
        Tw.amber200,
        Tw.amber700,
      ),
      _FeedTone.caution => (
        Tw.amber50,
        Tw.amber700,
        Tw.amber200,
        Icons.priority_high_rounded,
        const Color(0x99FFFBEB),
        Tw.amber200,
        Tw.amber700,
      ),
      _FeedTone.normal => (Tw.emerald50, Tw.emerald700, Tw.emerald200, Icons.check_rounded, Ds.gray50, const Color(0xCCE5E8EB), Ds.gray500),
      _FeedTone.notice => (
        Colors.white,
        Tw.amber600,
        Ds.gray200,
        Icons.notifications_active_outlined,
        Ds.gray50,
        const Color(0xCCE5E8EB),
        Ds.gray500,
      ),
      _FeedTone.done => (Ds.gray100, Ds.gray600, Ds.gray200, Icons.task_alt_rounded, Ds.gray50, const Color(0xCCE5E8EB), Ds.gray500),
    };
    final strong = t == _FeedTone.urgent || t == _FeedTone.consult || t == _FeedTone.alert || t == _FeedTone.call;

    Widget? badge;
    if (item.badge != null) {
      final (Color bg, Color fg, Color border) = switch (item.badge!) {
        '처방전 수신' || '완료' => (Tw.emerald100, Tw.emerald800, Tw.emerald200),
        '처방전 작성 중' || '화상 예약' => (Colors.white, Ds.blue500, Ds.borderInfo),
        _ when t == _FeedTone.urgent => (Tw.red100, Ds.red500, Tw.red200),
        _ => (Tw.amber100, Tw.amber800, Tw.amber200),
      };
      badge = PcPill(
        item.badge!,
        bg: bg,
        fg: fg,
        border: border,
        size: pcBase,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      );
    } else if (item.side != null) {
      badge = Text(
        item.side!,
        style: pcText(
          pcBase,
          weight: FontWeight.w700,
          color: t == _FeedTone.normal ? Tw.emerald700 : (t == _FeedTone.caution ? Tw.amber700 : Ds.red500),
        ),
      );
    }

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                item.header,
                style: pcText(pcBase, weight: strong ? FontWeight.w700 : FontWeight.w400, color: headColor),
              ),
              ?badge,
            ],
          ),
          const SizedBox(height: 4),
          Text(item.title, style: pcText(pcBase, weight: strong ? FontWeight.w700 : FontWeight.w500)),
          if (item.body != null) ...[
            const SizedBox(height: 4),
            Text(
              item.body!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: pcText(12, color: Ds.gray600, height: 1.625),
            ),
          ],
          if (item.footLeft != null || item.footRight != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x263182F6))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.footLeft ?? '', style: pcText(11, color: Ds.gray500)),
                  ),
                  if (item.footRight != null)
                    Text(
                      item.footRight!,
                      style: pcText(11, weight: FontWeight.w700, color: Ds.blue500, mono: true),
                    ),
                ],
              ),
            ),
          if (onOpen != null && t != _FeedTone.consult && t != _FeedTone.done) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                PcButton(
                  label: '호출 열기',
                  onTap: onOpen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  bg: t == _FeedTone.urgent ? Ds.red500 : Ds.blue500,
                  fg: Colors.white,
                  hoverBg: t == _FeedTone.urgent ? Tw.red600 : Ds.blue600,
                  weight: FontWeight.w700,
                  shadow: Ds.shadowSm,
                ),
                if (onAsk != null)
                  PcButton(
                    label: '현장 확인 요청',
                    onTap: onAsk,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    bg: Colors.white,
                    fg: Ds.gray700,
                    border: Ds.gray200,
                    hoverBg: Ds.gray50,
                    shadow: Ds.shadowSm,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cBg,
            shape: BoxShape.circle,
            border: cBorder == null ? null : Border.all(color: cBorder),
            boxShadow: cBorder == null ? Ds.shadowSm : null,
          ),
          child: Icon(icon, size: 18, color: cFg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: (t == _FeedTone.consult || t == _FeedTone.done) && onOpen != null
              ? PcHover(onTap: onOpen, semanticsLabel: '호출 열기', builder: (_) => card)
              : card,
        ),
      ],
    );
  }
}

// ─────────────────────────── 교대 근무조 인계 및 공지 · 결재 대기 업무

class HandoverApprovalCard extends ConsumerWidget {
  const HandoverApprovalCard({super.key});

  static String shiftEnglish(ShiftType t) => switch (t) {
    ShiftType.am => 'Day Shift',
    ShiftType.pm => 'Evening Shift',
    ShiftType.night => 'Night Shift',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final now = repo.now();
    final shift = repo.shiftAt(now);
    final pending = repo.pendingApprovals;
    final allDone = repo.approvals.isNotEmpty && pending.isEmpty;

    final batch = PcButton(
      label: allDone ? '승인 완료' : '일괄 확인 (${pending.length}건)',
      icon: allDone ? Icons.check_rounded : Icons.done_all_rounded,
      iconSize: 14,
      gap: 4,
      onTap: pending.isEmpty
          ? null
          : () {
              final n = pending.length;
              repo.approveAll(me);
              showDsToast(context, '결재 $n건을 모두 승인했어요');
            },
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      bg: allDone ? Ds.green500 : Ds.blue500,
      fg: Colors.white,
      hoverBg: allDone ? Ds.green500 : Ds.blue600,
      weight: FontWeight.w700,
      shadow: Ds.shadowSm,
    );

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('교대 근무조 인계 및 공지', style: pcText(pcBase, weight: FontWeight.w700)),
              ),
              // 완료 상태에서는 흐리게 하지 않는다 (디자인: 초록 "승인 완료").
              allDone ? _doneBadge() : batch,
            ],
          ),
          const SizedBox(height: 16),
          _Signs(shift: shift),
          const SizedBox(height: 16),
          const _NoticeBox(),
          const SizedBox(height: 16),
          _Approvals(pending: pending, allDone: allDone),
        ],
      ),
    );
  }

  /// [PcButton]은 누를 수 없으면 반투명이 되므로, 완료 표시는 따로 진하게 그린다.
  Widget _doneBadge() => Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: Ds.green500, borderRadius: BorderRadius.circular(999), boxShadow: Ds.shadowSm),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          '승인 완료',
          style: pcText(pcBase, weight: FontWeight.w700, color: Colors.white),
        ),
      ],
    ),
  );
}

class _Signs extends ConsumerWidget {
  const _Signs({required this.shift});
  final Shift? shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    Widget tile({required String name, required String sub, required bool signed, required String initial}) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: signed ? Ds.gray50 : const Color(0x99FFFBEB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: signed ? Ds.gray200 : Tw.amber200),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: signed ? Ds.gray200 : Tw.amber100, shape: BoxShape.circle),
            child: Text(
              initial,
              style: pcText(pcBase, weight: FontWeight.w700, color: signed ? Ds.gray800 : Tw.amber900, height: 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pcText(pcBase, weight: FontWeight.w700),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pcText(10, color: Ds.gray500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (signed)
            const Icon(Icons.check_circle_outline_rounded, size: 18, color: Tw.emerald600)
          else
            PcPill(
              '미서명',
              bg: Tw.amber100,
              fg: Tw.amber800,
              border: Tw.amber200,
              size: 10,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
        ],
      ),
    );

    Widget grid(List<Widget> tiles) {
      final rows = <Widget>[];
      for (var i = 0; i < tiles.length; i += 2) {
        rows.add(
          Row(
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 8),
              Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
            ],
          ),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
        ],
      );
    }

    final s = shift;
    if (s == null) {
      final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '오전 근무조 (Day Shift) 인계 서명 상태',
            style: pcText(pcBase, weight: FontWeight.w500, color: Ds.gray500),
          ),
          const SizedBox(height: 8),
          grid([
            tile(name: '예시 선생님', sub: '예시반', signed: true, initial: '예'),
            tile(name: '예시 선생님', sub: '예시반', signed: false, initial: '예'),
          ]),
        ],
      );
      if (repo.isDev) return ExampleWrap(note: '근무조가 정해지면 서명 상태가 여기에 보여요', child: body);
      return Text('지금 근무 중인 근무조가 없어요', style: pcText(14, color: Ds.gray500));
    }
    final signs = repo.signsOf(s.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${s.label} 근무조 (${HandoverApprovalCard.shiftEnglish(s.type)}) 인계 서명 상태',
          style: pcText(pcBase, weight: FontWeight.w500, color: Ds.gray500),
        ),
        const SizedBox(height: 8),
        grid([
          for (final id in s.staffIds)
            () {
              final st = repo.staff(id);
              final home = repo.homeClassOf(id);
              return tile(
                name: st.displayName,
                sub: home == null ? (st.team ?? '생활관') : repo.classOf(home).name,
                signed: signs.any((x) => x.staffId == id),
                initial: st.name.isEmpty ? '?' : st.name.substring(0, 1),
              );
            }(),
        ]),
      ],
    );
  }
}

/// 공지 = 가장 최근 전체 공지.
class _NoticeBox extends ConsumerWidget {
  const _NoticeBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final notices = repo.entries.where((e) => e.scope == EntryScope.facility).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    Widget box(String title, String when, String body) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xB3FFFBEB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Tw.amber200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.campaign_rounded, size: 22, color: Tw.amber600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: pcText(pcBase, weight: FontWeight.w700)),
                    PcPill(
                      when,
                      bg: Tw.amber100,
                      fg: Tw.amber800,
                      border: Tw.amber200,
                      size: 10,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[const SizedBox(height: 2), Text(body, style: pcText(12, color: Ds.gray700, height: 1.625))],
              ],
            ),
          ),
        ],
      ),
    );
    if (notices.isEmpty) {
      if (repo.isDev) {
        return ExampleWrap(
          note: '전체 공지를 올리면 가장 최근 공지가 여기에 보여요',
          child: box('예시 공지 · 온수 보일러 점검', '오늘 10:00 - 11:30', '점검 시간에는 샤워 온수가 제한돼요. 목욕은 점검 뒤로 미뤄 주세요.'),
        );
      }
      return const SizedBox.shrink();
    }
    final e = notices.first;
    final title = (e.title ?? '').trim().isNotEmpty ? e.title!.trim() : e.kindLabel;
    final when = sameDay(e.createdAt, now) ? '오늘 ${hm(e.createdAt)} 게시' : '${relTime(e.createdAt, now)} 게시';
    return box(title, when, (e.body ?? '').trim());
  }
}

class _Approvals extends ConsumerWidget {
  const _Approvals({required this.pending, required this.allDone});
  final List<Approval> pending;
  final bool allDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = repo.staff(ref.watch(currentUserProvider));
    Widget row(String title, VoidCallback? onApprove, {bool first = true}) => Container(
      margin: EdgeInsets.only(top: first ? 0 : 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Ds.gray50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Ds.gray200),
      ),
      child: Row(
        children: [
          Icon(
            title.contains('투약') || title.contains('약') ? Icons.medication_outlined : Icons.description_outlined,
            size: 18,
            color: Ds.blue500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: pcText(pcBase, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          PcButton(
            label: '승인',
            onTap: onApprove,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            bg: Ds.blue500,
            fg: Colors.white,
            hoverBg: Ds.blue600,
            weight: FontWeight.w700,
            shadow: Ds.shadowSm,
          ),
        ],
      ),
    );

    Widget list;
    if (allDone) {
      list = Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Tw.emerald50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Tw.emerald200),
        ),
        child: Text(
          '대기 중인 결재 업무가 모두 완료되었습니다.',
          textAlign: TextAlign.center,
          style: pcText(pcBase, weight: FontWeight.w500, color: Tw.emerald800),
        ),
      );
    } else if (pending.isEmpty) {
      list = repo.isDev
          ? ExampleWrap(note: '결재 요청이 올라오면 여기서 승인해요', child: exampleRoom(row('예시 · 비상 해열제 선투약 품의', () {})))
          : Text('결재 대기 업무가 없어요', style: pcText(14, color: Ds.gray500));
    } else {
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < pending.length; i++)
            row(pending[i].title, () {
              repo.approve(pending[i].id, ref.read(currentUserProvider));
              showDsToast(context, '결재를 승인했어요');
            }, first: i == 0),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${me.title ?? '담당자'} 결재 대기 업무',
                  style: pcText(pcBase, weight: FontWeight.w500, color: Ds.gray600),
                ),
              ),
              Text(
                '${pending.length}건 대기',
                style: pcText(pcBase, weight: FontWeight.w700, color: Ds.blue500, mono: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          list,
        ],
      ),
    );
  }
}
