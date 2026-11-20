// 의료 호출 흐름: 생활관 선생님(앱 "간호쌤 호출") → 의료 호출함(간호사) → 간호사가 의료진 채팅으로 보냄 → 의료진 협진 포털.
// 3단: 왼쪽 호출함 · 가운데 채팅함(호출함보다 넓다) · 오른쪽.
// 채팅함은 목록 사이에서 아래로 펼쳐진다 (오른쪽에 따로 열리지 않음).
//   간호사: 채팅방 = 의료진(병원 · 의사) 한 명.  의사: 채팅방 = 별님 한 명 (혜진원).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_calls_chat.dart';
import 'pc_calls_common.dart';
import 'pc_calls_dialogs.dart';
import 'pc_dashboard_ui.dart' show showPcDialog;
import 'pc_shell.dart';

/// 펼친 채팅방: 간호사 'doc:<의사>' · 의사 'res:<별님>'. null 이면 모두 닫힘.
final openRoomProvider = NotifierProvider<OpenRoom, String?>(OpenRoom.new);

class OpenRoom extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String? key) => state = key;
  void toggle(String key) => state = state == key ? null : key;
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// '2026.11.19 (목)'
String dateLabel(DateTime t) =>
    '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')} (${_weekdays[t.weekday - 1]})';

/// 3단: 호출함(300) · 채팅함(남는 폭 전부) · 오른쪽(420). 칸마다 따로 스크롤한다.
class McLayout extends StatelessWidget {
  const McLayout({super.key, required this.inbox, required this.rooms, required this.side});
  final Widget inbox;
  final Widget rooms;
  final Widget side;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w400, height: 1.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 300, child: inbox),
            const SizedBox(width: 16),
            Expanded(child: rooms),
            const SizedBox(width: 16),
            SizedBox(width: 420, child: side),
          ]),
        ),
      );
}

void _info(BuildContext context, String text) => showDsToast(context, text, icon: Icons.info_outline, iconColor: Ds.gray400);

// ── 왼쪽 호출함

/// 패널 머리: 아이콘 · 제목 · 숫자 · 한 줄 설명.
class _PanelHead extends StatelessWidget {
  const _PanelHead({required this.icon, required this.title, required this.sub, this.badge = 0});
  final IconData icon;
  final String title;
  final String sub;
  final int badge;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Ds.gray200))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 20, color: Ds.blue500),
            const SizedBox(width: 8),
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(15, weight: FontWeight.w700))),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              McPill('새 $badge', bg: Ds.red500, fg: Colors.white, size: 11, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1)),
            ],
            const Spacer(),
          ]),
          const SizedBox(height: 2),
          Text(sub, style: mcText(11.5, color: Ds.gray500)),
        ]),
      );
}

/// 열린 · 끝낸 호출 나누기.
class _OpenDoneToggle extends StatelessWidget {
  const _OpenDoneToggle({required this.done, required this.openCount, required this.doneCount, required this.onChanged});
  final bool done;
  final int openCount;
  final int doneCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(bool value, String label) {
      final on = done == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: Container(
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: on ? Ds.shadowSm : null,
              ),
              child: Text(label,
                  style: mcText(12, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? Ds.gray900 : Ds.gray500)),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Ds.gray100, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [seg(false, '열린 호출 $openCount'), seg(true, '끝낸 호출 $doneCount')]),
    );
  }
}

Color _levelBg(CallLevel l) => switch (l) { CallLevel.urgent => Ds.red500, CallLevel.observe => mcAmber50, CallLevel.general => Ds.gray100 };
Color _levelFg(CallLevel l) => switch (l) { CallLevel.urgent => Colors.white, CallLevel.observe => mcAmber800, CallLevel.general => Ds.gray600 };

/// 의료 호출함(간호사) 왼쪽: 생활관 선생님이 보낸 호출.
class NurseInbox extends ConsumerStatefulWidget {
  const NurseInbox({super.key});

  @override
  ConsumerState<NurseInbox> createState() => _NurseInboxState();
}

class _NurseInboxState extends ConsumerState<NurseInbox> {
  bool _done = false;
  Set<String>? _known;

  Future<void> _forward(MedicalCall call) async {
    final repo = ref.read(repoProvider);
    final doctorId = await pickDoctor(context, repo, call);
    if (doctorId == null || !mounted) return;
    repo.forwardCall(call.id, doctorId, ref.read(currentUserProvider));
    ref.read(selectedCallProvider.notifier).select(call.id);
    ref.read(openRoomProvider.notifier).open('doc:$doctorId');
    showDsToast(context, '${repo.staff(doctorId).displayName}에게 보냈어요 · 의료진 협진 포털에 알림이 갔어요');
  }

  void _open(MedicalCall call) {
    final repo = ref.read(repoProvider);
    repo.markSeen(ref.read(currentUserProvider), 'call:${call.id}');
    ref.read(selectedCallProvider.notifier).select(call.id);
    if (call.doctorId != null) ref.read(openRoomProvider.notifier).open('doc:${call.doctorId}');
  }

  void _complete(MedicalCall call) {
    final repo = ref.read(repoProvider);
    repo.completeCall(call.id, ref.read(currentUserProvider));
    showDsToast(context, '호출을 완료했어요');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final selected = shownCall(ref);
    final all = repo.calls;
    final open = all.where((c) => c.isOpen).toList();
    final done = all.where((c) => !c.isOpen).toList()..sort((a, b) => (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));
    final fresh = {for (final c in open) if (repo.isNewCall(c, me)) c.id};

    // 새 호출이 들어오면 알림 (다른 화면 · 앱에서 보낸 호출이 동기화로 들어올 때)
    final known = _known;
    if (known != null) {
      final arrived = fresh.difference(known);
      if (arrived.isNotEmpty) {
        final c = repo.callById(arrived.first);
        final r = repo.resident(c.residentId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDsToast(context, '새 간호사 호출 · ${r.name} 별님 (${repo.classOf(r.classId).name})',
                icon: Icons.notifications_active_rounded, iconColor: Ds.red500);
          }
        });
      }
    }
    _known = fresh;

    final shown = _done ? done : open;
    return McPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHead(icon: Icons.inbox_rounded, title: '호출함', sub: '생활관 선생님이 앱에서 보낸 간호사 호출', badge: fresh.length),
        _OpenDoneToggle(done: _done, openCount: open.length, doneCount: done.length, onChanged: (v) => setState(() => _done = v)),
        Expanded(
          child: shown.isEmpty
              ? (repo.isDev && all.isEmpty
                  ? ListView(padding: const EdgeInsets.all(12), children: const [ExampleWrap(child: _ExampleCallCard(doctor: false))])
                  : Center(child: Text(_done ? '끝낸 호출이 없어요' : '열린 호출이 없어요', style: mcText(12.5, color: Ds.gray500))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = shown[i];
                    return _NurseCallCard(
                      key: ValueKey('nurse-call-${c.id}'),
                      call: c,
                      selected: selected?.id == c.id,
                      fresh: fresh.contains(c.id),
                      onTap: () => _open(c),
                      onForward: () => _forward(c),
                      onComplete: () => _complete(c),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _NurseCallCard extends ConsumerWidget {
  const _NurseCallCard({
    super.key,
    required this.call,
    required this.selected,
    required this.fresh,
    required this.onTap,
    required this.onForward,
    required this.onComplete,
  });
  final MedicalCall call;
  final bool selected;
  final bool fresh;
  final VoidCallback onTap;
  final VoidCallback onForward;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final now = repo.now();
    final r = repo.resident(call.residentId);
    final cls = repo.classOf(r.classId);
    final caller = call.createdBy == 'system' ? '자동 호출' : '${repo.staff(call.createdBy).displayName} 호출';
    final doctor = call.doctorId == null ? null : repo.staff(call.doctorId!);

    return Semantics(
      button: true,
      selected: selected,
      label: '${r.name} 호출',
      child: Material(
        color: selected ? Ds.blue50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? Ds.blue500 : (fresh ? mcRed200 : Ds.gray200), width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                if (fresh) ...[const McDot(color: Ds.red500, size: 8), const SizedBox(width: 6)],
                Flexible(
                  child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(14, weight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                McPill(cls.name, bg: Ds.gray100, fg: Ds.gray600, size: 10.5, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1)),
                const Spacer(),
                Text(relTime(call.createdAt, now), style: mcText(11, color: fresh ? Ds.red500 : Ds.gray500, mono: true)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                McPill(call.level.label,
                    bg: _levelBg(call.level), fg: _levelFg(call.level), size: 10.5, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1)),
                if (call.temp != null) ...[
                  const SizedBox(width: 6),
                  Text('${formatTemp(call.temp!)}°C', style: mcText(12.5, weight: FontWeight.w700, color: (call.diff ?? 0) >= 5 ? Ds.red500 : Ds.gray800, mono: true)),
                ],
                const SizedBox(width: 6),
                Expanded(child: Text(caller, maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(11.5, color: Ds.gray500))),
              ]),
              const SizedBox(height: 6),
              Text(call.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: mcText(12.5, color: Ds.gray800)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(doctor == null ? Icons.schedule_send_outlined : Icons.send_rounded, size: 14, color: doctor == null ? Ds.gray400 : Ds.blue500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    doctor == null ? '아직 의료진에게 보내지 않았어요' : '${doctor.displayName}에게 보냄 · ${hhmm(call.forwardedAt!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mcText(11.5, weight: doctor == null ? FontWeight.w400 : FontWeight.w600, color: doctor == null ? Ds.gray500 : Ds.blue500),
                  ),
                ),
              ]),
              if (call.isOpen) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: doctor == null
                        ? McBlueButton(key: ValueKey('forward-${call.id}'), label: '의료진에게 보내기', icon: Icons.send_rounded, height: 32, onTap: onForward)
                        : McGrayButton(label: '채팅 보기', icon: Icons.forum_outlined, height: 32, onTap: onTap),
                  ),
                  const SizedBox(width: 6),
                  McGrayButton(label: '완료', icon: Icons.check_rounded, height: 32, onTap: onComplete),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// 어느 의료진(병원 · 의사)에게 보낼지 고른다.
Future<String?> pickDoctor(BuildContext context, InMemoryRepository repo, MedicalCall call) => showPcDialog<String>(
      context,
      maxWidth: 480,
      builder: (ctx) => _DoctorPicker(repo: repo, call: call),
    );

class _DoctorPicker extends StatefulWidget {
  const _DoctorPicker({required this.repo, required this.call});
  final InMemoryRepository repo;
  final MedicalCall call;

  @override
  State<_DoctorPicker> createState() => _DoctorPickerState();
}

class _DoctorPickerState extends State<_DoctorPicker> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final r = repo.resident(widget.call.residentId);
    final doctors = repo.doctors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('어느 의료진에게 보낼까요?', style: mcText(18, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${r.name} 별님 · ${widget.call.summary}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mcText(12.5, color: Ds.gray500)),
        const SizedBox(height: 16),
        if (doctors.isEmpty)
          Text('등록된 의료진이 없어요', style: mcText(13, color: Ds.gray500))
        else
          for (final d in doctors) ...[
            Semantics(
              button: true,
              selected: _picked == d.id,
              child: Material(
                color: _picked == d.id ? Ds.blue50 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: _picked == d.id ? Ds.blue500 : Ds.gray200, width: _picked == d.id ? 1.5 : 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('pick-${d.id}'),
                  onTap: () => setState(() => _picked = d.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      _Initial(d.name, doctor: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d.displayName, style: mcText(13.5, weight: FontWeight.w700)),
                          if (d.team != null) Text(d.team!, style: mcText(11.5, color: Ds.gray500)),
                        ]),
                      ),
                      if (_picked == d.id) const Icon(Icons.check_circle_rounded, size: 20, color: Ds.blue500),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: McGrayButton(label: '취소', height: 44, onTap: () => Navigator.of(context).pop())),
          const SizedBox(width: 8),
          Expanded(
            child: McBlueButton(
              key: const ValueKey('pick-send'),
              label: '보내기',
              icon: Icons.send_rounded,
              height: 44,
              onTap: _picked == null ? null : () => Navigator.of(context).pop(_picked),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// 의료진 협진 포털 왼쪽: 나에게 온 호출 (보낸 기관 = 혜진원).
class DoctorInbox extends ConsumerStatefulWidget {
  const DoctorInbox({super.key});

  @override
  ConsumerState<DoctorInbox> createState() => _DoctorInboxState();
}

class _DoctorInboxState extends ConsumerState<DoctorInbox> {
  bool _done = false;
  Set<String>? _known;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final selected = shownCall(ref);
    final all = repo.callsForDoctor(me);
    final open = all.where((c) => c.isOpen).toList();
    final done = all.where((c) => !c.isOpen).toList();
    bool isFresh(MedicalCall c) {
      final read = repo.lastRead(me, 'res:${c.residentId}');
      return c.forwardedAt != null && (read == null || c.forwardedAt!.isAfter(read));
    }

    final fresh = {for (final c in open) if (isFresh(c)) c.id};
    final known = _known;
    if (known != null) {
      final arrived = fresh.difference(known);
      if (arrived.isNotEmpty) {
        final r = repo.resident(repo.callById(arrived.first).residentId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDsToast(context, '${InMemoryRepository.facilityName} 새 호출 · ${r.name} 별님',
                icon: Icons.notifications_active_rounded, iconColor: Ds.red500);
          }
        });
      }
    }
    _known = fresh;

    final shown = _done ? done : open;
    return McPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHead(icon: Icons.local_hospital_outlined, title: '호출함', sub: '협진 기관에서 보낸 호출', badge: fresh.length),
        _OpenDoneToggle(done: _done, openCount: open.length, doneCount: done.length, onChanged: (v) => setState(() => _done = v)),
        Expanded(
          child: shown.isEmpty
              ? (repo.isDev && all.isEmpty
                  ? ListView(padding: const EdgeInsets.all(12), children: const [ExampleWrap(child: _ExampleCallCard(doctor: true))])
                  : Center(child: Text(_done ? '끝낸 호출이 없어요' : '받은 호출이 없어요', style: mcText(12.5, color: Ds.gray500))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = shown[i];
                    return _DoctorCallCard(
                      key: ValueKey('doctor-call-${c.id}'),
                      call: c,
                      selected: selected?.id == c.id,
                      fresh: fresh.contains(c.id),
                      onTap: () {
                        ref.read(selectedCallProvider.notifier).select(c.id);
                        ref.read(openRoomProvider.notifier).open('res:${c.residentId}');
                      },
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _DoctorCallCard extends ConsumerWidget {
  const _DoctorCallCard({super.key, required this.call, required this.selected, required this.fresh, required this.onTap});
  final MedicalCall call;
  final bool selected;
  final bool fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final r = repo.resident(call.residentId);
    final cls = repo.classOf(r.classId);
    final sent = call.forwardedBy == null ? null : repo.staff(call.forwardedBy!);
    return Semantics(
      button: true,
      selected: selected,
      label: '${InMemoryRepository.facilityName} ${r.name} 호출',
      child: Material(
        color: selected ? Ds.blue50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? Ds.blue500 : (fresh ? mcRed200 : Ds.gray200), width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const McPill(InMemoryRepository.facilityName,
                    bg: Ds.gray900, fg: Colors.white, size: 11, icon: Icons.apartment_rounded, padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                const SizedBox(width: 6),
                if (fresh) const McDot(color: Ds.red500, size: 8),
                const Spacer(),
                Text(call.forwardedAt == null ? '' : '${dateLabel(call.forwardedAt!).substring(5)} ${hhmm(call.forwardedAt!)}',
                    style: mcText(11, color: fresh ? Ds.red500 : Ds.gray500, mono: true)),
              ]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(r.name, style: mcText(14, weight: FontWeight.w700)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${sexAge(r)} · ${cls.name}${cls.room == null ? '' : ' ${cls.room}'}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(11.5, color: Ds.gray500)),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                McPill(call.level.label,
                    bg: _levelBg(call.level), fg: _levelFg(call.level), size: 10.5, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1)),
                if (call.temp != null) ...[
                  const SizedBox(width: 6),
                  Text('${formatTemp(call.temp!)}°C', style: mcText(12.5, weight: FontWeight.w700, color: (call.diff ?? 0) >= 5 ? Ds.red500 : Ds.gray800, mono: true)),
                ],
              ]),
              const SizedBox(height: 6),
              Text(call.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: mcText(12.5, color: Ds.gray800)),
              if (sent != null) ...[
                const SizedBox(height: 6),
                Text('${sent.displayName} 보냄', style: mcText(11.5, color: Ds.gray500)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// 개발 DB 예시 호출 카드.
class _ExampleCallCard extends StatelessWidget {
  const _ExampleCallCard({required this.doctor});
  final bool doctor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Ds.gray200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (doctor) ...[
            const McPill(InMemoryRepository.facilityName, bg: Ds.gray900, fg: Colors.white, size: 11, padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
            const SizedBox(height: 8),
          ],
          Text('예시 별님', style: mcText(14, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('37.9°C · 열이 나요', style: mcText(12.5, color: Ds.gray800)),
          const SizedBox(height: 4),
          Text(doctor ? '예시 간호사 보냄' : '예시 선생님 호출 · 아직 의료진에게 보내지 않았어요', style: mcText(11.5, color: Ds.gray500)),
        ]),
      );
}

// ── 가운데 채팅함 (목록 사이에서 아래로 펼쳐진다)

class _Initial extends StatelessWidget {
  const _Initial(this.name, {this.doctor = false});
  final String name;
  final bool doctor;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: doctor ? Ds.blue50 : Ds.gray100, borderRadius: BorderRadius.circular(14)),
        child: Text(name.isEmpty ? '?' : name.characters.first,
            style: mcText(15, weight: FontWeight.w700, color: doctor ? Ds.blue500 : Ds.gray700)),
      );
}

/// 채팅함. 간호사 = 의료진별, 의사 = 별님별.
class ChatRooms extends ConsumerWidget {
  const ChatRooms({super.key, required this.doctor});
  final bool doctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final openKey = ref.watch(openRoomProvider);

    final rooms = <({String key, String title, String sub, CareMessage? last, int unread, bool doc})>[];
    if (doctor) {
      for (final rid in repo.patientsOf(me)) {
        final r = repo.resident(rid);
        final cls = repo.classOf(r.classId);
        final msgs = repo.patientRoomMessages(me, rid);
        rooms.add((
          key: 'res:$rid',
          title: '${r.name} 별님',
          sub: '${InMemoryRepository.facilityName} · ${cls.name}${cls.room == null ? '' : ' ${cls.room}'} · ${sexAge(r)}',
          last: msgs.lastOrNull,
          unread: repo.roomUnread(me, 'res:$rid'),
          doc: false,
        ));
      }
    } else {
      for (final d in repo.doctors) {
        final msgs = repo.doctorRoomMessages(d.id);
        rooms.add((
          key: 'doc:${d.id}',
          title: d.displayName,
          sub: d.team ?? '',
          last: msgs.lastOrNull,
          unread: repo.roomUnread(me, 'doc:${d.id}'),
          doc: true,
        ));
      }
      // 대화가 있는 방부터 최근 순
      rooms.sort((a, b) {
        if (a.last == null || b.last == null) return a.last == null ? (b.last == null ? 0 : 1) : -1;
        return b.last!.at.compareTo(a.last!.at);
      });
    }
    final unread = rooms.fold(0, (n, r) => n + r.unread);

    return McPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PanelHead(
          icon: Icons.forum_outlined,
          title: doctor ? '별님별 채팅' : '의료진 채팅',
          sub: doctor ? '${InMemoryRepository.facilityName} 별님마다 대화가 따로 있어요. 눌러서 펼쳐요.' : '병원 · 의료진을 누르면 대화가 아래로 펼쳐져요.',
          badge: unread,
        ),
        Expanded(
          child: rooms.isEmpty
              ? Center(
                  child: Text(doctor ? '아직 받은 호출이 없어요' : '등록된 의료진이 없어요', style: mcText(12.5, color: Ds.gray500)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                  children: [
                    for (final room in rooms) ...[
                      _RoomTile(
                        key: ValueKey('room-${room.key}'),
                        title: room.title,
                        sub: room.sub,
                        preview: room.last == null
                            ? '아직 대화가 없어요'
                            : (room.last!.kind == 'vital' ? '체온 기록 ${room.last!.body}' : room.last!.body),
                        time: room.last == null ? '' : relTime(room.last!.at, repo.now()),
                        unread: room.unread,
                        expanded: openKey == room.key,
                        doctorAvatar: room.doc,
                        onTap: () => ref.read(openRoomProvider.notifier).toggle(room.key),
                        body: openKey == room.key ? _RoomBody(key: ValueKey('body-${room.key}'), roomKey: room.key, doctor: doctor) : null,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    super.key,
    required this.title,
    required this.sub,
    required this.preview,
    required this.time,
    required this.unread,
    required this.expanded,
    required this.doctorAvatar,
    required this.onTap,
    this.body,
  });
  final String title;
  final String sub;
  final String preview;
  final String time;
  final int unread;
  final bool expanded;
  final bool doctorAvatar;
  final VoidCallback onTap;
  final Widget? body;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: expanded ? Ds.blue500 : (unread > 0 ? mcRed200 : Ds.gray200), width: expanded ? 1.5 : 1),
          boxShadow: expanded ? mcPanelShadow : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: '$title 채팅${unread > 0 ? ', 안 읽은 글 $unread' : ''}',
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  _Initial(title, doctor: doctorAvatar),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(14, weight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        Flexible(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(11.5, color: Ds.gray500))),
                      ]),
                      const SizedBox(height: 2),
                      Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mcText(12.5, color: unread > 0 ? Ds.gray900 : Ds.gray600, weight: unread > 0 ? FontWeight.w600 : FontWeight.w400)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(time, style: mcText(11, color: Ds.gray500, mono: true)),
                    const SizedBox(height: 4),
                    if (unread > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Ds.red500, borderRadius: BorderRadius.circular(10)),
                        child: Text('$unread', style: mcText(11, weight: FontWeight.w700, color: Colors.white, height: 1)),
                      )
                    else
                      Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: Ds.gray400),
                  ]),
                ]),
              ),
            ),
          ),
          if (body != null) ...[const Divider(height: 1, color: Ds.gray200), body!],
        ]),
      );
}

/// 펼친 채팅방: 도구 줄 · 대화 · 입력.
class _RoomBody extends ConsumerStatefulWidget {
  const _RoomBody({super.key, required this.roomKey, required this.doctor});
  final String roomKey;
  final bool doctor;

  @override
  ConsumerState<_RoomBody> createState() => _RoomBodyState();
}

class _RoomBodyState extends ConsumerState<_RoomBody> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  String? _target;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(MedicalCall? call) {
    if (call == null) return _info(context, widget.doctor ? '열린 호출이 없어요' : '이 의료진에게 보낸 열린 호출이 없어요. 왼쪽 호출함에서 먼저 보내 주세요');
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref.read(repoProvider).sendMessage(call.id, ref.read(currentUserProvider), text);
    _input.clear();
    _focus.requestFocus();
  }

  Future<void> _video(MedicalCall? call) async {
    if (call == null) return _info(context, '열린 호출이 없어요');
    final repo = ref.read(repoProvider);
    final at = await pickVideoTime(context, repo.now(), current: call.videoAt);
    if (at == null || !mounted) return;
    repo.scheduleVideo(call.id, at, ref.read(currentUserProvider));
    showDsToast(context, '화상 진료 예약 알림을 남겼어요 (${hhmm(at)})');
  }

  void _vital(MedicalCall? call) {
    if (call == null) return _info(context, '열린 호출이 없어요');
    final repo = ref.read(repoProvider);
    final m = repo.latestOf(call.residentId);
    if (m == null) return _info(context, '첨부할 체온 기록이 없어요');
    repo.sendMessage(call.id, ref.read(currentUserProvider), fmtC(m.value), kind: 'vital', data: {
      'value': m.value,
      'baseline': m.judgment.baseline,
      'diff': m.judgment.diff,
      'stage': m.judgment.stage.name,
      'by': m.recordedBy,
      'measuredAt': m.measuredAt.toIso8601String(),
      'measurementId': m.id,
    });
    showDsToast(context, '최근 체온 기록(${fmtC(m.value)})을 첨부했어요');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    final key = widget.roomKey;
    final id = key.substring(4);
    final docRoom = key.startsWith('doc:');
    final msgs = docRoom ? repo.doctorRoomMessages(id) : repo.patientRoomMessages(me, id);
    final calls = docRoom ? repo.callsWithDoctor(id) : repo.callsForDoctor(me).where((c) => c.residentId == id).toList();
    final open = calls.where((c) => c.isOpen).toList();
    final target = open.where((c) => c.id == _target).firstOrNull ?? open.firstOrNull;

    // 펼쳐 보면 읽음
    if (repo.roomUnread(me, key) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(repoProvider).markSeen(me, key);
      });
    }

    final items = <Widget>[];
    String? lastResident;
    for (final m in msgs) {
      final rid = repo.callById(m.callId).residentId;
      // 간호사 방에는 여러 별님 대화가 섞이므로 별님이 바뀌는 곳에 이름 줄
      if (docRoom && rid != lastResident) {
        items.add(_ResidentDivider(name: repo.resident(rid).name));
      }
      lastResident = rid;
      items.add(CareMessageView(message: m, resident: repo.resident(rid), me: me, doctor: widget.doctor));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 도구 줄
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: Ds.gray50,
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (docRoom && open.length > 1) ...[
            Text('보낼 별님', style: mcText(12, weight: FontWeight.w600, color: Ds.gray600)),
            for (final c in open)
              ChoiceChip(
                label: Text(repo.resident(c.residentId).name, style: mcText(12, weight: FontWeight.w600)),
                selected: c.id == target?.id,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _target = c.id),
              ),
          ],
          McChipButton(
            icon: Icons.videocam_outlined,
            iconColor: Ds.blue500,
            label: target?.videoAt == null ? '화상 진료 예약' : '화상 진료 ${relTime(target!.videoAt!, repo.now())}',
            onTap: () => _video(target),
          ),
          McChipButton(icon: Icons.add_chart, iconColor: Ds.blue500, label: '+ 바이탈 첨부', onTap: () => _vital(target)),
          McChipButton(
            icon: Icons.description_outlined,
            label: '투약 이력',
            onTap: () => target == null ? _info(context, '열린 호출이 없어요') : showMedicationHistory(context, repo, target.residentId),
          ),
        ]),
      ),
      // 대화
      SizedBox(
        height: 420,
        child: ColoredBox(
          color: const Color(0x66F2F4F6),
          child: items.isEmpty
              ? (repo.isDev
                  ? ListView(padding: const EdgeInsets.all(16), children: [ExampleCareMessages(doctor: widget.doctor)])
                  : Center(
                      child: Text(docRoom ? '아직 대화가 없어요. 왼쪽 호출함에서 이 의료진에게 호출을 보내 보세요.' : '아직 대화가 없어요',
                          style: mcText(12.5, color: Ds.gray500)),
                    ))
              : ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => items[items.length - 1 - i],
                ),
        ),
      ),
      // 입력
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Ds.gray200))),
        child: Row(children: [
          Expanded(
            child: McField(
              key: ValueKey('room-input-$key'),
              controller: _input,
              focusNode: _focus,
              hint: target == null
                  ? (docRoom ? '이 의료진에게 보낸 열린 호출이 없어요' : '열린 호출이 없어요')
                  : '${repo.resident(target.residentId).name} 별님 건으로 보낼 메시지',
              height: 40,
              fontSize: 12.5,
              action: TextInputAction.send,
              onSubmitted: (_) => _send(target),
            ),
          ),
          const SizedBox(width: 8),
          McBlueButton(label: '전송', trailingIcon: Icons.send, height: 40, fontSize: 12.5, onTap: () => _send(target)),
        ]),
      ),
    ]);
  }
}

class _ResidentDivider extends StatelessWidget {
  const _ResidentDivider({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Divider(color: Ds.gray200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: McPill('$name 별님', bg: Colors.white, fg: Ds.gray700, border: Ds.gray200, size: 11, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
        ),
        const Expanded(child: Divider(color: Ds.gray200)),
      ]);
}

// ── 오른쪽: 비대면 진단 · 처방 기록 (날짜순)

List<Widget> rxRecordCards(InMemoryRepository repo) {
  final list = repo.prescriptions;
  if (list.isEmpty) {
    return [
      if (repo.isDev)
        const ExampleWrap(child: _ExampleRxRecord())
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text('아직 비대면 진단·처방 기록이 없어요', textAlign: TextAlign.center, style: mcText(12.5, color: Ds.gray500)),
        ),
    ];
  }
  return [for (final p in list) RxRecordCard(key: ValueKey('rx-${p.id}'), p: p)];
}

class RxRecordCard extends ConsumerWidget {
  const RxRecordCard({super.key, required this.p});
  final Prescription p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final r = repo.resident(p.residentId);
    final d = repo.staff(p.doctorId);
    final at = p.issuedAt ?? p.updatedAt;
    return McCard(children: [
      Row(children: [
        const Icon(Icons.event_note_outlined, size: 16, color: Ds.blue500),
        const SizedBox(width: 6),
        Expanded(child: Text('${dateLabel(at)} ${hhmm(at)}', style: mcText(13.5, weight: FontWeight.w700, mono: true))),
        RxStatusPill(p),
      ]),
      Text('${r.name} 별님 · ${repo.classOf(r.classId).name}', style: mcText(13, weight: FontWeight.w600)),
      Text('${d.displayName}${d.team == null ? '' : ' · ${d.team}'}', style: mcText(11.5, color: Ds.gray500)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Ds.gray50, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(p.code, style: mcText(12.5, weight: FontWeight.w700, color: Ds.blue500, mono: true)),
          const SizedBox(width: 8),
          Expanded(child: Text(p.codeName, style: mcText(12.5, weight: FontWeight.w500))),
        ]),
      ),
      Text(p.opinion, maxLines: 3, overflow: TextOverflow.ellipsis, style: mcText(12, color: Ds.gray700)),
      for (final item in p.items) RxItemView(item),
      if (p.number != null) Text('처방전 ${p.number}', style: mcText(11.5, color: Ds.gray500, mono: true)),
    ]);
  }
}

class _ExampleRxRecord extends StatelessWidget {
  const _ExampleRxRecord();

  @override
  Widget build(BuildContext context) => McCard(children: [
        Text('2026.01.01 (목) 14:00', style: mcText(13.5, weight: FontWeight.w700, mono: true)),
        Text('예시 별님 · 예시반', style: mcText(13, weight: FontWeight.w600)),
        Text('예시 촉탁의', style: mcText(11.5, color: Ds.gray500)),
        Text('의료진이 비대면 진료 후 처방을 발행하면 날짜별로 여기에 쌓여요.', style: mcText(12, color: Ds.gray700)),
      ]);
}
