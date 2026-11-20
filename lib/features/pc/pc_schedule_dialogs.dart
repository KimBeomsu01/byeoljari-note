// PC 02 대화상자: "+ 일정 등록" 모달 (신규 일정 등록) · 일정 상세.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'pc_dashboard_ui.dart';
import 'pc_schedule_calendar.dart';

/// 모달 분류 버튼 글자 (디자인: 시설 점검/행사 · 특수교육 · 촉탁의 진료 + 나머지 두 분류).
String categoryButton(CalendarCategory c) => switch (c) {
  CalendarCategory.facility => '시설 점검/행사',
  CalendarCategory.education => '특수교육',
  CalendarCategory.therapy => '재활치료',
  CalendarCategory.care => '생활 케어',
  CalendarCategory.medical => '촉탁의 진료',
};

/// 등록하면 만든 일정을 돌려준다.
Future<CalendarEvent?> showCreateEvent(BuildContext context, {required DateTime initialDate, String? classId}) =>
    showPcDialog<CalendarEvent>(
      context,
      maxWidth: 512,
      builder: (_) => _CreateEvent(initialDate: initialDate, classId: classId),
    );

class _CreateEvent extends ConsumerStatefulWidget {
  const _CreateEvent({required this.initialDate, this.classId});
  final DateTime initialDate;
  final String? classId;

  @override
  ConsumerState<_CreateEvent> createState() => _CreateEventState();
}

class _CreateEventState extends ConsumerState<_CreateEvent> {
  CalendarCategory _cat = CalendarCategory.facility;
  final _title = TextEditingController();
  final _owner = TextEditingController();
  late DateTime _date = dayOf(widget.initialDate);
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  late String? _classId = widget.classId;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(repoProvider).now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (d != null) setState(() => _date = dayOf(d));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '일정명을 적어 주세요');
      return;
    }
    final owner = _owner.text.trim();
    final e = ref
        .read(repoProvider)
        .addCalendarEvent(
          date: _date,
          title: title,
          category: _cat,
          by: ref.read(currentUserProvider),
          time: '${two(_time.hour)}:${two(_time.minute)}',
          classId: _classId,
          owner: owner.isEmpty ? null : owner,
        );
    Navigator.of(context).pop(e);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final classes = repo.classes;
    if (_classId != null && !classes.any((c) => c.id == _classId)) _classId = null;

    Widget field(String text, IconData icon, VoidCallback onTap, String label) => PcHover(
      onTap: onTap,
      semanticsLabel: label,
      builder: (hover) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: hover ? Colors.white : Ds.gray100,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: hover ? Ds.blue500 : Ds.gray200),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: pcText(15, mono: true))),
            Icon(icon, size: 18, color: Ds.gray500),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PcDialogHeader('신규 일정 등록'),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PcLabel('일정 구분'),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = (c.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cat in CalendarCategory.values)
                          SizedBox(
                            width: w,
                            child: PcChoice(label: categoryButton(cat), selected: _cat == cat, onTap: () => setState(() => _cat = cat)),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                const PcLabel('일정명'),
                TextField(
                  key: const ValueKey('event-title'),
                  controller: _title,
                  maxLength: 40,
                  style: pcText(15),
                  decoration: pcInput('예: 3층 소화 설비 정기 점검', error: _error).copyWith(counterText: ''),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PcLabel('일자'),
                          field('${_date.year}-${two(_date.month)}-${two(_date.day)}', Icons.calendar_today_outlined, _pickDate, '일자 고르기'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PcLabel('시작 시간'),
                          field('${two(_time.hour)}:${two(_time.minute)}', Icons.schedule_rounded, _pickTime, '시작 시간 고르기'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const PcLabel('대상 생활관 & 담당자'),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Ds.gray100,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Ds.gray200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            key: const ValueKey('event-class'),
                            value: _classId,
                            isExpanded: true,
                            style: DefaultTextStyle.of(context).style.merge(pcText(15)),
                            borderRadius: BorderRadius.circular(16),
                            items: [
                              DropdownMenuItem<String?>(value: null, child: Text('시설 전체', style: pcText(15))),
                              for (final c in classes)
                                DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (v) => setState(() => _classId = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('event-owner'),
                        controller: _owner,
                        maxLength: 30,
                        style: pcText(15),
                        decoration: pcInput('담당: 박소연 간호사').copyWith(counterText: ''),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Ds.gray100)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PcButton(
                label: '취소',
                onTap: () => Navigator.of(context).pop(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                bg: Ds.gray100,
                fg: Ds.gray700,
                hoverBg: Ds.gray200,
              ),
              const SizedBox(width: 8),
              PcButton(
                key: const ValueKey('event-submit'),
                label: '등록 완료',
                onTap: _submit,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                bg: Ds.blue500,
                fg: Colors.white,
                hoverBg: Ds.blue600,
                weight: FontWeight.w700,
                shadow: const [BoxShadow(color: Color(0x4D3182F6), blurRadius: 12, offset: Offset(0, 4))],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── 일정 상세

Future<void> showEventDetail(BuildContext context, CalendarEvent e) =>
    showPcDialog(context, maxWidth: 480, builder: (_) => _EventDetail(e: e));

class _EventDetail extends ConsumerWidget {
  const _EventDetail({required this.e});
  final CalendarEvent e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final (soft, ink, strong) = categoryColors(e.category);
    final hol = holidayName(e.date);
    String? cls;
    if (e.classId != null) {
      try {
        cls = repo.classOf(e.classId!).name;
      } catch (_) {}
    }
    Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(k, style: pcText(13, color: Ds.gray500)),
          ),
          Expanded(
            child: Text(v, style: pcText(14, weight: FontWeight.w500)),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PcDialogHeader('일정 상세', dot: strong),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(6)),
              child: Text(
                e.category.tag,
                style: pcText(13, weight: FontWeight.w700, color: ink),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(e.title, style: pcText(18, weight: FontWeight.w700, height: 1.4)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        kv('날짜', '${e.date.year}년 ${e.date.month}월 ${e.date.day}일 (${weekdayKo[e.date.weekday - 1]})${hol == null ? '' : ' · $hol'}'),
        kv('시각', e.time ?? '종일'),
        kv('분류', e.category.label),
        kv('대상', cls ?? '시설 전체'),
        if ((e.owner ?? '').isNotEmpty) kv('담당', e.owner!),
        if ((e.detail ?? '').isNotEmpty) kv('내용', e.detail!),
        kv('등록', '${repo.staff(e.createdBy).displayName} · ${relTime(e.createdAt, now)}'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: PcButton(
            label: '닫기',
            onTap: () => Navigator.of(context).pop(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            bg: Ds.gray100,
            fg: Ds.gray700,
            hoverBg: Ds.gray200,
          ),
        ),
      ],
    );
  }
}
