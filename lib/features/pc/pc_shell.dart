// PC 웹 틀 (Claude Design PC 01~04 공통): 왼쪽 레일 80 + 위쪽 머리 64 + 가운데 내용 (최대 1720).
// 화면: 통합 관제 현황판 · 통합 일정 관리 · 의료 호출함(간호사) · 의료진 협진 포털(의사).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'pc_calls_page.dart';
import 'pc_dashboard_page.dart';
import 'pc_doctor_page.dart';
import 'pc_schedule_page.dart';

enum PcPage { dashboard, schedule, calls, doctor }

/// 지금 PC 화면.
final pcPageProvider = NotifierProvider<PcPageNotifier, PcPage>(PcPageNotifier.new);

class PcPageNotifier extends Notifier<PcPage> {
  @override
  PcPage build() => PcPage.dashboard;
  void go(PcPage p) => state = p;
}

/// 의료 호출함에서 고른 호출 (현황판 · 타임라인에서 눌러 들어올 때도 쓴다).
final selectedCallProvider = NotifierProvider<SelectedCall, String?>(SelectedCall.new);

class SelectedCall extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

/// PC 최소 폭. 이보다 좁으면 가로로 밀어서 본다.
const double pcMinWidth = 1280;

class PcShell extends ConsumerWidget {
  const PcShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(pcPageProvider);
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    // 의료진 주소(/doctor)이거나 의사 계정이면 협진 포털만
    final isDoctor = ref.watch(screenKindProvider) == 'doctor' || repo.staff(me).role == Role.doctor;
    // 의사 계정은 협진 포털, 그 밖에는 의사 포털 대신 의료 호출함
    final shown = isDoctor ? PcPage.doctor : (page == PcPage.doctor ? PcPage.calls : page);

    final body = switch (shown) {
      PcPage.dashboard => const PcDashboardPage(),
      PcPage.schedule => const PcSchedulePage(),
      PcPage.calls => const PcCallsPage(),
      PcPage.doctor => const PcDoctorPage(),
    };

    return Scaffold(
      backgroundColor: Ds.gray100,
      body: LayoutBuilder(builder: (context, size) {
        final content = Row(children: [
          _Rail(page: shown, isDoctor: isDoctor),
          Expanded(
            child: Column(children: [
              _Header(isDoctor: isDoctor),
              Expanded(child: body),
            ]),
          ),
        ]);
        if (size.maxWidth >= pcMinWidth) return content;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: pcMinWidth, height: size.maxHeight, child: content),
        );
      }),
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({required this.page, required this.isDoctor});
  final PcPage page;
  final bool isDoctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    // 알림 수: 의사 = 별님 채팅방 안 읽은 글 + 새 호출, 간호사 = 새 호출 + 의료진 채팅 안 읽은 글
    final openCalls = isDoctor ? repo.doctorUnread(me) : repo.nurseUnread(me);
    Widget nav(PcPage p, IconData icon, String title, {int badge = 0}) {
      final on = page == p;
      return Tooltip(
        message: title,
        child: Material(
          color: on ? Ds.blue500 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            hoverColor: Ds.gray100,
            onTap: () => ref.read(pcPageProvider.notifier).go(p),
            child: Container(
              width: 44,
              height: 44,
              decoration: on
                  ? BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: const [
                      BoxShadow(color: Color(0x4D3182F6), blurRadius: 12, offset: Offset(0, 4)),
                    ])
                  : null,
              child: Stack(alignment: Alignment.center, children: [
                Icon(icon, size: 22, color: on ? Colors.white : Ds.gray600),
                if (badge > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Ds.red500, borderRadius: BorderRadius.circular(8)),
                      child: Text('$badge', style: const TextStyle(fontSize: 10, height: 1, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Ds.gray200)),
        boxShadow: Ds.shadowTile,
      ),
      child: Column(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Ds.blue50, borderRadius: BorderRadius.circular(16), boxShadow: Ds.shadowSm),
          child: const Icon(Icons.auto_awesome_rounded, color: Ds.blue500, size: 22),
        ),
        const SizedBox(height: 24),
        if (isDoctor)
          nav(PcPage.doctor, Icons.medical_services_rounded, '의료진 협진 포털', badge: openCalls)
        else ...[
          nav(PcPage.dashboard, Icons.space_dashboard_rounded, '전체 현황판'),
          const SizedBox(height: 8),
          nav(PcPage.schedule, Icons.calendar_month_rounded, '일정 관리'),
          const SizedBox(height: 8),
          nav(PcPage.calls, Icons.medical_services_rounded, '의료 호출함', badge: openCalls),
        ],
        const Spacer(),
        Tooltip(
          message: '내 정보 · 로그아웃',
          child: InkResponse(
            radius: 24,
            onTap: () => showProfileSheet(context, ref),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Ds.gray100,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x4D3182F6), spreadRadius: 2)],
              ),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: Ds.gray800, shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: Ds.green500, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Header extends ConsumerStatefulWidget {
  const _Header({required this.isDoctor});
  final bool isDoctor;

  @override
  ConsumerState<_Header> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<_Header> {
  late final Timer _timer;
  final _loginAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = repo.staff(ref.watch(currentUserProvider));
    // 서버 로그인은 12시간 유지된다 (backend/passkey.dart loginDuration).
    final left = const Duration(hours: 12) - DateTime.now().difference(_loginAt);
    String two(int v) => v.toString().padLeft(2, '0');
    final leftText = left.isNegative ? '00:00:00' : '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    const sep = Text('/', style: TextStyle(color: Ds.gray300, fontSize: T.body));

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xE6FFFFFF),
        border: Border(bottom: BorderSide(color: Ds.gray200)),
      ),
      child: Row(children: [
        const Text('별자리노트', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        const SizedBox(width: 4),
        sep,
        const SizedBox(width: 4),
        Text(widget.isDoctor ? '의료진 전용 협진 포털' : '오피스 웹',
            style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w500, color: Ds.gray700)),
        const SizedBox(width: 4),
        sep,
        const SizedBox(width: 4),
        const Text('실시간 임상 관리', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: Ds.blue500)),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Ds.gray100, borderRadius: BorderRadius.circular(99), border: Border.all(color: Ds.gray200)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.apartment_rounded, size: 16, color: Ds.gray700),
            const SizedBox(width: 4),
            const Text('울산 혜진원 장애인거주시설', style: TextStyle(fontSize: T.label, fontWeight: FontWeight.w700)),
            if (repo.isDev) ...[const SizedBox(width: 8), const ExampleTag()],
          ]),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Ds.gray100, borderRadius: BorderRadius.circular(99), border: Border.all(color: Ds.gray200)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Ds.green500, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Text('로그인 세션', style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w500, color: Ds.gray800)),
            const SizedBox(width: 6),
            const Text('|', style: TextStyle(fontSize: T.caption, color: Ds.gray300)),
            const SizedBox(width: 6),
            Text('$leftText 남음',
                style: const TextStyle(fontSize: T.caption, fontWeight: FontWeight.w600, color: Ds.blue500, fontFeatures: tabular)),
          ]),
        ),
        const SizedBox(width: 16),
        Container(width: 1, height: 32, color: Ds.gray200),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showProfileSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(me.displayName, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w700)),
                Text(me.team ?? '혜진원', style: const TextStyle(fontSize: T.micro, color: Ds.gray500)),
              ]),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Ds.gray900, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
