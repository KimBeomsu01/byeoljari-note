// PC 02 오른쪽 (span 4): "선택 일과표" — 고른 날의 일정 (시각 · 태그 · 담당 · 제목 · 설명), 글자 검색, 다음 인수인계 · 인쇄.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'pc_dashboard_ui.dart';
import 'pc_schedule_calendar.dart';

class DayAgendaPanel extends ConsumerStatefulWidget {
  const DayAgendaPanel({
    super.key,
    required this.day,
    required this.events,
    required this.onEvent,
    required this.className,
    this.example = false,
  });
  final DateTime day;

  /// 그날 일정 (생활관 필터를 거친 것).
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEvent;
  final String? Function(String?) className;
  final bool example;

  @override
  ConsumerState<DayAgendaPanel> createState() => _DayAgendaPanelState();
}

class _DayAgendaPanelState extends ConsumerState<DayAgendaPanel> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _match(CalendarEvent e, String q) {
    if (q.isEmpty) return true;
    final hay = [
      e.time ?? '',
      e.title,
      e.owner ?? '',
      e.detail ?? '',
      e.category.tag,
      e.category.label,
      widget.className(e.classId) ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final d = widget.day;
    final q = _search.text.trim().toLowerCase();
    final shown = widget.events.where((e) => _match(e, q)).toList();
    final upcoming = repo.shiftsAround(now).where((s) => s.startAt.isAfter(now)).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
    final next = upcoming.firstOrNull;

    Widget list;
    if (widget.events.isEmpty && widget.example) {
      list = ExampleWrap(
        note: '일정을 등록하면 이 자리에 그날 일과가 시간순으로 보여요',
        child: _AgendaTile(
          time: '10:00',
          category: CalendarCategory.facility,
          owner: '',
          title: '예시 · 온수 보일러 정기 점검',
          detail: '관리팀 · 1~3층 전 생활관 순회 점검',
        ),
      );
    } else if (widget.events.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          '이 날은 등록된 일정이 없어요',
          textAlign: TextAlign.center,
          style: pcText(14, color: Ds.gray500),
        ),
      );
    } else if (shown.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          '"${_search.text.trim()}"에 맞는 일정이 없어요',
          textAlign: TextAlign.center,
          style: pcText(14, color: Ds.gray500),
        ),
      );
    } else {
      list = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 640),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.only(right: 4),
          itemCount: shown.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final e = shown[i];
            final who = e.owner ?? widget.className(e.classId) ?? '시설 전체';
            return _AgendaTile(
              time: e.time ?? '종일',
              category: e.category,
              owner: who,
              title: e.title,
              detail: e.detail ?? (e.classId == null ? '시설 전체' : widget.className(e.classId)),
              onTap: () => widget.onEvent(e),
            );
          },
        ),
      );
    }

    return PcCard(
      border: const Color(0xCCE5E8EB),
      shadow: pcSoftShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Ds.gray100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 16, color: Ds.blue500),
                          const SizedBox(width: 4),
                          Text(
                            '선택 일과표',
                            style: pcText(pcBase, weight: FontWeight.w700, color: Ds.blue500),
                          ),
                        ],
                      ),
                      Text(
                        '${d.year}년 ${d.month}월 ${d.day}일 (${weekdayKo[d.weekday - 1]})',
                        style: pcText(18, weight: FontWeight.w700, height: 28 / 18, spacing: -0.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PcPill(
                  '총 ${widget.events.length}건의 일정',
                  bg: Ds.blue50,
                  fg: Ds.blue500,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('agenda-search'),
            controller: _search,
            style: pcText(15, height: 1.3),
            decoration: pcInput(
              '일정명, 생활관, 담당자 검색 (예: 물리치료, 박소연)...',
              prefix: const Icon(Icons.search_rounded, size: 18, color: Ds.gray400),
            ).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
          const SizedBox(height: 16),
          list,
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            decoration: BoxDecoration(
              color: Ds.gray50,
              borderRadius: BorderRadius.circular(28),
              border: const Border(top: BorderSide(color: Ds.gray100)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_alt_rounded, size: 18, color: Ds.blue500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '다음 인수인계 예정: ',
                          style: pcText(pcBase, color: Ds.gray600),
                        ),
                        TextSpan(
                          text: next == null ? '정해지지 않음' : (sameDay(next.startAt, now) ? hm(next.startAt) : '내일 ${hm(next.startAt)}'),
                          style: pcText(pcBase, weight: FontWeight.w700, mono: true),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                PcButton(
                  label: '일과표 인쇄',
                  icon: Icons.print_outlined,
                  iconSize: 15,
                  iconAfter: true,
                  gap: 4,
                  onTap: () =>
                      showDsToast(context, '인쇄 기능은 아직 연결되지 않았어요. 화면의 일과표를 확인해 주세요', icon: Icons.print_outlined, iconColor: Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  bg: Colors.white,
                  fg: Ds.blue500,
                  border: Ds.gray200,
                  hoverBg: Ds.gray100,
                  weight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({required this.time, required this.category, required this.owner, required this.title, this.detail, this.onTap});
  final String time;
  final CalendarCategory category;
  final String owner;
  final String title;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (soft, ink, strong) = categoryColors(category);
    return PcHover(
      onTap: onTap,
      semanticsLabel: title,
      builder: (hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: hover ? Ds.blue500 : const Color(0xB3E5E8EB)),
          boxShadow: hover ? Ds.shadowSm : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 50),
              child: Column(
                children: [
                  Text(time, style: pcText(15, weight: FontWeight.w700, mono: true, height: 1)),
                  const SizedBox(height: 10),
                  PcDot(8, strong),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          category.tag,
                          style: pcText(pcBase, weight: FontWeight.w700, color: ink),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          owner,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pcText(pcBase, color: Ds.gray500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pcText(pcBase, weight: FontWeight.w700),
                  ),
                  if ((detail ?? '').isNotEmpty)
                    Text(
                      detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pcText(12, color: Ds.gray600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
