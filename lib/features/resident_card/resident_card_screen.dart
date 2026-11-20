// 04 별님카드 (Claude Design ResidentTimeline.dc.html).
// 맨 위: 체온 측정과 같은 반 · 별님 다이얼 (탭 · 좌우 밀기, 세로 밀기는 화면 스크롤).
// 그 아래: 프로필(평소 체온 · 14일 추이 · 투약 지침) → 검색 · 필터 칩 → 새 기록 배너 → 기록 타임라인.
// 아래에 떠 있는 ActionBar: [기록 남기기] + 필터. 탭 바는 app.dart가 그린다 (탭 모드일 때).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart' show residentCardTargetProvider;
import '../../core/models.dart';
import '../../core/photo.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'resident_photo_viewer.dart';
import 'resident_profile_card.dart';
import 'resident_sheets.dart';
import 'resident_timeline.dart';

const _dialMove = Duration(milliseconds: 240);
const _dialCurve = Cubic(0.2, 0.8, 0.2, 1);
const _tap = Duration(milliseconds: 150);

class ResidentCardScreen extends ConsumerStatefulWidget {
  /// [residentId]가 있으면 그 별님으로 연 별도 화면(뒤로가기 버튼), 없으면 하단 탭.
  const ResidentCardScreen({super.key, this.residentId});
  final String? residentId;

  @override
  ConsumerState<ResidentCardScreen> createState() => _ResidentCardScreenState();
}

class _ResidentCardScreenState extends ConsumerState<ResidentCardScreen> {
  /// 고른 별님. 없으면 기본 별님 (내 반의 이상 건 별님, 없으면 첫 별님).
  String? _residentId;

  /// 별님이 없는 반을 골랐을 때만 쓴다.
  String? _classId;

  ChipFilter _chip = ChipFilter.all;
  KindFilter _kind = KindFilter.all;
  PeriodFilter _period = PeriodFilter.all;
  final _search = TextEditingController();

  bool get _isTab => widget.residentId == null;

  @override
  void initState() {
    super.initState();
    _residentId = widget.residentId ?? ref.read(residentCardTargetProvider);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _selectResident(String id) {
    if (id == _residentId && _classId == null) return;
    setState(() {
      _residentId = id;
      _classId = null;
    });
    // 탭에서는 다른 화면의 "별님카드로 가기"와 같은 값을 쓴다.
    if (_isTab) ref.read(residentCardTargetProvider.notifier).show(id);
  }

  void _selectClass(InMemoryRepository repo, String classId) {
    final rs = repo.residentsOf(classId);
    if (rs.isEmpty) {
      setState(() {
        _residentId = null;
        _classId = classId;
      });
    } else {
      _selectResident(rs.first.id);
    }
  }

  Resident? _defaultResident(InMemoryRepository repo, String me) {
    final mine = repo.myClasses(me);
    final classes = repo.classes.where((c) => mine.contains(c.id)).toList();
    final home = repo.homeClassOf(me);
    for (final c in [...classes.where((c) => c.id == home), ...classes.where((c) => c.id != home)]) {
      final rs = repo.residentsOf(c.id);
      if (rs.isEmpty) continue;
      return rs.firstWhere((r) => repo.openCaseOf(r.id) != null, orElse: () => rs.first);
    }
    return null;
  }

  String get _tuneLabel {
    final parts = [if (_kind != KindFilter.all) _kind.short, if (_period != PeriodFilter.all) _period.short];
    return parts.isEmpty ? '전체' : parts.join(' · ');
  }

  bool get _tuneActive => _kind != KindFilter.all || _period != PeriodFilter.all;

  void _openFilter() => showFilterSheet(
        context,
        kind: _kind,
        period: _period,
        onChanged: (k, p) => setState(() {
          _kind = k;
          _period = p;
        }),
      );

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final me = ref.watch(currentUserProvider);
    if (_isTab) {
      ref.listen<String?>(residentCardTargetProvider, (_, next) {
        if (next != null && next != _residentId) {
          setState(() {
            _residentId = next;
            _classId = null;
          });
        }
      });
    }
    final now = repo.now();
    // 내 담당 반만 (간호·사무·야간 당직은 전체 반). 다른 화면에서 그 별님으로 따로 열었으면 그 반도.
    final opened = widget.residentId == null ? null : repo.residents.where((r) => r.id == widget.residentId).firstOrNull;
    final mine = {...repo.myClasses(me), ?opened?.classId};
    final classes = repo.classes.where((c) => mine.contains(c.id)).toList();

    // 고른 별님 · 반 (명단이 바뀌어 없어졌으면 기본값으로).
    Resident? sel = _residentId == null ? null : repo.residents.where((r) => r.id == _residentId).firstOrNull;
    if (sel != null && !classes.any((c) => c.id == sel!.classId)) sel = null;
    String? classId = sel?.classId ?? (classes.any((c) => c.id == _classId) ? _classId : null);
    if (sel == null && classId == null) {
      sel = _defaultResident(repo, me);
      classId = sel?.classId ?? classes.firstOrNull?.id;
    }
    final residents = classId == null ? const <Resident>[] : repo.residentsOf(classId);

    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    final content = <Widget>[];
    if (sel != null) {
      final r = sel;
      final all = buildTimeline(repo, r.id, now);
      final queried =
          all.where((x) => matchesQuery(x, repo, now, kind: _kind, period: _period, text: _search.text)).toList();
      final shown = queried.where((x) => matchesChip(x, _chip)).toList();
      int count(ChipFilter f) => queried.where((x) => matchesChip(x, f)).length;
      final unread = repo.archiveEntriesOf(r.id).where((e) => !repo.isRead(e.id, me)).toList();

      content.addAll([
        ResidentProfileCard(
          repo: repo,
          resident: r,
          now: now,
          onOpenGuide: () => showGuideSheet(context, repo, r),
          onOpenPhotos: () => openPhotoHistory(context, r.id),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SearchField(controller: _search),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              _FilterChip(
                key: const Key('rc-chip-all'),
                label: '모두',
                count: count(ChipFilter.all),
                selected: _chip == ChipFilter.all,
                onTap: () => setState(() => _chip = ChipFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                key: const Key('rc-chip-resident'),
                label: r.name,
                count: count(ChipFilter.resident),
                selected: _chip == ChipFilter.resident,
                onTap: () => setState(() => _chip = ChipFilter.resident),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                key: const Key('rc-chip-notice'),
                label: '반 공지',
                count: count(ChipFilter.notice),
                selected: _chip == ChipFilter.notice,
                onTap: () => setState(() => _chip = ChipFilter.notice),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 2), color: Ds.gray300),
              const SizedBox(width: 8),
              _TuneButton(key: const Key('rc-tune'), label: _tuneLabel, active: _tuneActive, onTap: _openFilter),
            ]),
          ),
        ]),
        if (unread.isNotEmpty)
          NewRecordBanner(
            count: unread.length,
            onConfirmAll: () {
              final at = repo.now();
              for (final e in unread) {
                repo.markRead(e.id, me, at, source: 'archive');
              }
            },
          ),
        if (all.isEmpty && repo.isDev)
          const ExampleTimelineCard()
        else if (all.isEmpty)
          const _EmptyNote('아직 남긴 기록이 없어요')
        else if (shown.isEmpty)
          const _EmptyNote('조건에 맞는 기록이 없어요')
        else
          ResidentTimeline(records: shown, repo: repo, now: now, classId: r.classId),
      ]);
    } else {
      content.add(_EmptyNote(classes.isEmpty ? '아직 등록된 반이 없어요' : '이 반에는 아직 별님이 없어요'));
    }

    return Scaffold(
      backgroundColor: Ds.bg,
      body: Stack(children: [
        Positioned.fill(
          child: SingleChildScrollView(
            key: const Key('rc-scroll'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: EdgeInsets.only(top: safe.top),
                decoration: const BoxDecoration(
                  color: Ds.surface,
                  border: Border(bottom: BorderSide(color: Ds.borderCard)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!_isTab)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        child: IconButton(
                          tooltip: '뒤로',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Ds.gray900),
                        ),
                      ),
                    ),
                  _SwipeZone(
                    key: const Key('rc-class-dial'),
                    onStep: (d) {
                      final i = classes.indexWhere((c) => c.id == classId);
                      if (classes.isEmpty) return;
                      final next = (i + d).clamp(0, classes.length - 1);
                      if (next != i) _selectClass(repo, classes[next].id);
                    },
                    child: _ClassDial(classes: classes, selectedId: classId, onPick: (id) => _selectClass(repo, id)),
                  ),
                  _SwipeZone(
                    key: const Key('rc-resident-dial'),
                    onStep: (d) {
                      if (residents.isEmpty) return;
                      final i = math.max(0, residents.indexWhere((x) => x.id == sel?.id));
                      final next = (i + d).clamp(0, residents.length - 1);
                      if (next != i) _selectResident(residents[next].id);
                    },
                    child: _ResidentDial(
                        residents: residents,
                        selectedId: sel?.id,
                        onPick: _selectResident,
                        photoOf: (id) => repo.profilePhotoOf(id)?.url),
                  ),
                ]),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 104 + safe.bottom),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < content.length; i++) ...[if (i > 0) const SizedBox(height: 16), content[i]],
                ]),
              ),
            ]),
          ),
        ),
        // 상태 표시줄 자리 (스크롤한 내용이 그 밑으로 비치지 않게)
        if (safe.top > 0) Positioned(top: 0, left: 0, right: 0, height: safe.top, child: const ColoredBox(color: Ds.surface)),
        if (sel != null && !keyboard)
          Positioned(
            left: 16,
            right: 16,
            bottom: (_isTab ? 28 : 16) + safe.bottom,
            child: _ActionBar(
              filterActive: _tuneActive,
              onWrite: () => showResidentWriteSheet(context, sel!.id),
              onFilter: _openFilter,
            ),
          ),
      ]),
    );
  }
}

// ── 반 · 별님 다이얼 (SelectionGestureArea)

/// 좌우로 44만큼 밀 때마다 한 칸씩 넘긴다 (d = +1 다음, −1 이전). 세로 밀기는 화면 스크롤로 간다.
class _SwipeZone extends StatefulWidget {
  const _SwipeZone({super.key, required this.onStep, required this.child});
  final ValueChanged<int> onStep;
  final Widget child;

  @override
  State<_SwipeZone> createState() => _SwipeZoneState();
}

class _SwipeZoneState extends State<_SwipeZone> {
  double _acc = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _acc = 0,
        onHorizontalDragUpdate: (d) {
          _acc += d.primaryDelta ?? d.delta.dx;
          if (_acc.abs() >= 44) {
            widget.onStep(_acc < 0 ? 1 : -1);
            _acc = 0;
          }
        },
        child: widget.child,
      );
}

/// ClassDial: 칸 폭 116, 고른 반이 가운데 (반이 2개 이하면 묶어서 가운데).
class _ClassDial extends StatelessWidget {
  const _ClassDial({required this.classes, required this.selectedId, required this.onPick});
  final List<Class> classes;
  final String? selectedId;
  final ValueChanged<String> onPick;

  static const double _w = 116;

  @override
  Widget build(BuildContext context) {
    final n = classes.length;
    final ci = math.max(0, classes.indexWhere((c) => c.id == selectedId));
    final x = n <= 2 ? n * _w / 2 : ci * _w + _w / 2;
    return Semantics(
      label: '반',
      container: true,
      child: SizedBox(
        height: 12 + 40 + 4,
        child: LayoutBuilder(
          builder: (context, c) => Stack(clipBehavior: Clip.hardEdge, children: [
            AnimatedPositioned(
              duration: _dialMove,
              curve: _dialCurve,
              left: c.maxWidth / 2 - x,
              top: 12,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final cls in classes)
                  SizedBox(
                    width: _w,
                    child: Center(child: _ClassButton(name: cls.name, on: cls.id == selectedId, onTap: () => onPick(cls.id))),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ClassButton extends StatelessWidget {
  const _ClassButton({required this.name, required this.on, required this.onTap});
  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: _tap,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? Ds.gray100 : const Color(0x00F2F4F6), borderRadius: BorderRadius.circular(10)),
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: T.bodyLg,
                  height: 1.5,
                  letterSpacing: -0.4,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? Ds.gray900 : Ds.gray500,
                )),
          ),
        ),
      );
}

/// ResidentDial: 칸 폭 68, 고른 별님이 늘 가운데. 프로필 사진이 있으면 사진, 없으면 이름 두 글자.
class _ResidentDial extends StatelessWidget {
  const _ResidentDial({required this.residents, required this.selectedId, required this.onPick, this.photoOf = _noPhoto});

  static String? _noPhoto(String _) => null;
  final List<Resident> residents;
  final String? selectedId;
  final ValueChanged<String> onPick;

  /// 별님 id → 프로필 사진 주소.
  final String? Function(String residentId) photoOf;

  static const double _w = 68;

  @override
  Widget build(BuildContext context) {
    const height = 8 + 52 + 6 + 19.5 + 12;
    if (residents.isEmpty) {
      return const SizedBox(
        height: height,
        child: Center(child: Text('별님이 없어요', style: TextStyle(fontSize: T.label, color: Ds.gray500))),
      );
    }
    final ri = math.max(0, residents.indexWhere((r) => r.id == selectedId));
    return Semantics(
      label: '별님',
      container: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, c) => Stack(clipBehavior: Clip.hardEdge, children: [
            AnimatedPositioned(
              duration: _dialMove,
              curve: _dialCurve,
              left: c.maxWidth / 2 - (ri * _w + _w / 2),
              top: 8,
              child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final r in residents)
                  _ResidentButton(resident: r, on: r.id == selectedId, photoUrl: photoOf(r.id), onTap: () => onPick(r.id)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ResidentButton extends StatelessWidget {
  const _ResidentButton({required this.resident, required this.on, required this.onTap, this.photoUrl});
  final Resident resident;
  final bool on;
  final VoidCallback onTap;

  /// 프로필 사진 (있으면 동그라미 안에 사진, 없으면 이름 두 글자).
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 68,
        child: Semantics(
          button: true,
          selected: on,
          label: resident.name,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedOpacity(
              duration: _tap,
              opacity: on ? 1 : 0.4,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: _tap,
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? Ds.gray900 : Ds.gray100,
                    shape: BoxShape.circle,
                    boxShadow: on
                        ? const [
                            BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
                            BoxShadow(color: Ds.gray900, spreadRadius: 4),
                            BoxShadow(color: Colors.white, spreadRadius: 2),
                          ]
                        : const [],
                  ),
                  child: photoUrl != null
                      ? ResidentCircle(label: resident.shortName, url: photoUrl, size: 52)
                      : Text(resident.shortName,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: T.bodyMd,
                            height: 1.5,
                            fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                            color: on ? Colors.white : Ds.gray700,
                          )),
                ),
                const SizedBox(height: 6),
                Text(on ? resident.name : resident.shortName,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontSize: T.label,
                      height: 1.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? Ds.gray900 : Ds.gray700,
                    )),
              ]),
            ),
          ),
        ),
      );
}

// ── 검색 · 필터

/// SearchField: 44 높이, radius 20, 60자 제한.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  static final _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: const BorderSide(color: Ds.borderChip),
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: SizedBox(
          height: 44,
          child: TextField(
            key: const Key('rc-search'),
            controller: controller,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: T.body, height: 1.4, color: Ds.gray900),
            decoration: InputDecoration(
              hintText: '기록 검색 (체온, 식사, 행동)',
              hintStyle: const TextStyle(fontSize: T.body, height: 1.4, color: Ds.gray500),
              filled: true,
              fillColor: Ds.surface,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(0, 10, 16, 10),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 6),
                child: Icon(Icons.search_rounded, size: 20, color: Ds.gray500),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '검색어 지우기',
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close_rounded, size: 18, color: Ds.gray500),
                    ),
              border: _border,
              enabledBorder: _border,
              focusedBorder: _border.copyWith(borderSide: const BorderSide(color: Ds.blue500)),
            ),
          ),
        ),
      );
}

/// 필터 칩 (36, 글자 13 · 숫자 11, 고르면 gray-900).
class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.label, required this.count, required this.selected, required this.onTap});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: _tap,
          height: 36,
          decoration: BoxDecoration(
            color: selected ? Ds.gray900 : Ds.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: selected ? const Color(0x00E5E8EB) : Ds.borderChip),
            boxShadow: selected ? Ds.shadowSm : const [],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: selected ? 15 : 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: T.label,
                        height: 1.5,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? Colors.white : Ds.gray700,
                      )),
                  const SizedBox(width: 6),
                  Text('$count',
                      style: TextStyle(
                        fontSize: T.micro,
                        height: 1.5,
                        fontFeatures: tabular,
                        color: selected ? Colors.white.withValues(alpha: 0.8) : Ds.gray500,
                      )),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// 칩 줄 끝의 [전체] (tune): 기록 종류 · 기간 시트.
class _TuneButton extends StatelessWidget {
  const _TuneButton({super.key, required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '기록 거르기 $label',
        excludeSemantics: true,
        child: Material(
          color: Ds.surface,
          shape: StadiumBorder(side: BorderSide(color: active ? Ds.gray300 : Ds.borderChip)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.tune_rounded, size: 15, color: active ? Ds.violet500 : Ds.gray500),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                      fontSize: T.caption,
                      height: 1.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Ds.gray900 : Ds.gray700,
                    )),
              ]),
            ),
          ),
        ),
      );
}

/// NewRecordBanner: 내가 아직 확인 안 한 기록 수 + [모두 확인]. 점은 세 번 깜빡이고 멈춘다.
class NewRecordBanner extends StatefulWidget {
  const NewRecordBanner({super.key, required this.count, required this.onConfirmAll});
  final int count;
  final VoidCallback onConfirmAll;

  @override
  State<NewRecordBanner> createState() => _NewRecordBannerState();
}

class _NewRecordBannerState extends State<NewRecordBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && _pulse.value == 0 && !_pulse.isAnimating) _pulse.forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Ds.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Ds.borderInfo),
          boxShadow: Ds.shadowSm,
        ),
        child: Row(children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Opacity(opacity: 0.75 + 0.25 * math.cos(2 * math.pi * 3 * _pulse.value), child: child),
            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Ds.blue500, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('새 기록 ${widget.count}건',
                style: const TextStyle(fontSize: T.label, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900)),
          ),
          InkWell(
            onTap: widget.onConfirmAll,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('모두 확인', style: TextStyle(fontSize: T.caption, height: 1.5, fontWeight: FontWeight.w700, color: Ds.blue500)),
            ),
          ),
        ]),
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: T.body, height: 1.5, color: Ds.gray500)),
      );
}

/// ActionBar: [기록 남기기](violet) + 필터.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onWrite, required this.onFilter, required this.filterActive});
  final VoidCallback onWrite;
  final VoidCallback onFilter;
  final bool filterActive;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x527C5CF0), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Material(
              color: Ds.violet500,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('rc-write'),
                onTap: onWrite,
                child: const SizedBox(
                  height: 48,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.edit_outlined, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text('기록 남기기', style: TextStyle(fontSize: T.bodyMd, height: 1.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '필터',
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: Ds.shadowSm),
            child: Material(
              color: Ds.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Ds.gray200)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('rc-filter'),
                onTap: onFilter,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(alignment: Alignment.center, children: [
                    const Icon(Icons.filter_list_rounded, size: 20, color: Ds.gray700),
                    if (filterActive)
                      Positioned(
                        top: 11,
                        right: 11,
                        child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Ds.violet500, shape: BoxShape.circle)),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]);
}
