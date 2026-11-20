// PC 01 [전체 거주인 명부]: 반별 별님 표 + 반 추가 · 별님 추가.
// 개발 DB에서 실제 명단을 넣는 유일한 곳이다. 실제 반 · 별님이 하나라도 생기면 예시 명단은 저장소가 숨긴다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_dashboard_status.dart';
import 'pc_dashboard_ui.dart';

Future<void> showRosterDialog(BuildContext context) =>
    showPcDialog(context, maxWidth: 1040, height: 760, builder: (_) => const RosterPanel());

class RosterPanel extends ConsumerWidget {
  const RosterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final classes = repo.classes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PcDialogHeader('전체 거주인 명부', subtitle: '${classes.length}개 반 · 별님 ${repo.residents.length}명'),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _RosterList(repo: repo)),
              const SizedBox(width: 20),
              const SizedBox(width: 340, child: SingleChildScrollView(child: _RosterForms())),
            ],
          ),
        ),
      ],
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({required this.repo});
  final InMemoryRepository repo;

  @override
  Widget build(BuildContext context) {
    final classes = repo.classes;
    Widget head(String t, int flex, {TextAlign align = TextAlign.left}) => Expanded(
      flex: flex,
      child: Text(
        t,
        textAlign: align,
        style: pcText(13, weight: FontWeight.w700, color: Ds.gray600),
      ),
    );
    Widget cell(String t, int flex, {Color color = Ds.gray900, FontWeight weight = FontWeight.w400, Widget? extra}) => Expanded(
      flex: flex,
      child: Row(
        children: [
          Flexible(
            child: Text(
              t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pcText(14, weight: weight, color: color),
            ),
          ),
          if (extra != null) ...[const SizedBox(width: 6), extra],
        ],
      ),
    );

    return ListView(
      children: [
        if (repo.rosterIsExample)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Ds.orange50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x66FF8A00)),
            ),
            child: Row(
              children: [
                const ExampleTag(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '지금은 예시 명단이에요. 오른쪽에서 실제 반과 별님을 추가하면 예시는 사라져요.',
                    style: pcText(14, weight: FontWeight.w500, color: const Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ),
        for (final c in classes) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Ds.gray200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Ds.gray50,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: Color(c.color), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(classRoom(c), style: pcText(pcBase, weight: FontWeight.w700)),
                      if (c.example) ...[const SizedBox(width: 6), const ExampleTag()],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${c.sex} · 담임 ${repo.staff(c.homeroomId).displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: pcText(13, color: Ds.gray500),
                        ),
                      ),
                      Text(
                        '${repo.residentsOf(c.id).length}명',
                        style: pcText(14, weight: FontWeight.w700, color: Ds.blue500, mono: true),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Ds.gray100)),
                  ),
                  child: Row(children: [head('이름', 4), head('성별', 2), head('나이', 2), head('통학', 2), head('중증', 2), head('기록 번호', 4)]),
                ),
                if (repo.residentsOf(c.id).isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('아직 별님이 없어요', style: pcText(14, color: Ds.gray500)),
                  ),
                for (final r in repo.residentsOf(c.id))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Ds.gray100)),
                    ),
                    child: Row(
                      children: [
                        cell(r.name, 4, weight: FontWeight.w700, extra: r.example ? const ExampleTag() : null),
                        cell(r.sex ?? '-', 2),
                        cell(r.age == null ? '-' : '${r.age}세', 2),
                        cell(r.commutesToSchool ? '통학' : '-', 2, color: r.commutesToSchool ? Ds.blue500 : Ds.gray400),
                        cell(r.severe ? '중증' : '-', 2, color: r.severe ? Ds.red500 : Ds.gray400),
                        cell(r.code ?? '-', 4, color: Ds.gray600),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RosterForms extends ConsumerStatefulWidget {
  const _RosterForms();

  @override
  ConsumerState<_RosterForms> createState() => _RosterFormsState();
}

class _RosterFormsState extends ConsumerState<_RosterForms> {
  // 반 추가
  final _className = TextEditingController();
  final _room = TextEditingController();
  String _classSex = '남';
  String? _homeroom;
  String? _classError;

  // 별님 추가
  String? _classId;
  final _name = TextEditingController();
  final _age = TextEditingController();
  String? _sex;
  bool _commutes = false;
  String? _residentError;

  @override
  void dispose() {
    _className.dispose();
    _room.dispose();
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  void _addClass() {
    final repo = ref.read(repoProvider);
    final name = _className.text.trim();
    if (name.isEmpty) {
      setState(() => _classError = '반 이름을 적어 주세요');
      return;
    }
    if (repo.classes.any((c) => !c.example && c.name == name)) {
      setState(() => _classError = '같은 이름의 반이 이미 있어요');
      return;
    }
    final room = _room.text.trim();
    final c = repo.addClass(name: name, sex: _classSex, room: room.isEmpty ? null : room, homeroomId: _homeroom);
    _className.clear();
    _room.clear();
    setState(() {
      _classError = null;
      _classId = c.id;
      _sex = c.sex;
    });
    showDsToast(context, '"${c.name}" 반을 추가했어요');
  }

  void _addResident() {
    final repo = ref.read(repoProvider);
    final classId = _classId;
    final name = _name.text.trim();
    if (classId == null) {
      setState(() => _residentError = '반을 골라 주세요');
      return;
    }
    if (name.isEmpty) {
      setState(() => _residentError = '이름을 적어 주세요');
      return;
    }
    final ageText = _age.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    if (ageText.isNotEmpty && (age == null || age < 0 || age > 120)) {
      setState(() => _residentError = '나이는 0~120 사이 숫자로 적어 주세요');
      return;
    }
    final r = repo.addResident(classId: classId, name: name, sex: _sex ?? repo.classOf(classId).sex, age: age, commutes: _commutes);
    _name.clear();
    _age.clear();
    setState(() {
      _residentError = null;
      _commutes = false;
    });
    showDsToast(context, '${repo.classOf(classId).name}에 ${r.name} 별님을 추가했어요');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final realClasses = repo.classes.where((c) => !c.example).toList();
    if (_classId != null && !realClasses.any((c) => c.id == _classId)) _classId = null;
    _classId ??= realClasses.firstOrNull?.id;
    final careStaff = repo.allStaff.where((s) => s.role == Role.care).toList();
    if (_homeroom != null && !careStaff.any((s) => s.id == _homeroom)) _homeroom = null;

    Widget box(String title, IconData icon, List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Ds.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Ds.blue500),
              const SizedBox(width: 6),
              Text(title, style: pcText(pcBase, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );

    Widget sexPicker(String? value, ValueChanged<String> onPick) => Row(
      children: [
        Expanded(
          child: PcChoice(label: '남', selected: value == '남', onTap: () => onPick('남')),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PcChoice(label: '여', selected: value == '여', onTap: () => onPick('여')),
        ),
      ],
    );

    Widget dropdown<V>({
      required V? value,
      required List<DropdownMenuItem<V>> items,
      required ValueChanged<V?>? onChanged,
      required String hint,
    }) => Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Ds.gray100,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Ds.gray200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<V>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: pcText(15, color: Ds.gray400)),
          style: DefaultTextStyle.of(context).style.merge(pcText(15)),
          borderRadius: BorderRadius.circular(16),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );

    final selectedClass = _classId == null ? null : repo.classOf(_classId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        box('반 추가', Icons.add_home_outlined, [
          const PcLabel('반 이름'),
          TextField(
            key: const ValueKey('roster-class-name'),
            controller: _className,
            maxLength: 20,
            style: pcText(15),
            decoration: pcInput('예: 은하수자리').copyWith(counterText: ''),
            onSubmitted: (_) => _addClass(),
          ),
          const SizedBox(height: 8),
          const PcLabel('생활실'),
          TextField(
            key: const ValueKey('roster-class-room'),
            controller: _room,
            maxLength: 10,
            style: pcText(15),
            decoration: pcInput('예: 203호 (없으면 비워 두세요)').copyWith(counterText: ''),
          ),
          const SizedBox(height: 8),
          const PcLabel('성별'),
          sexPicker(_classSex, (v) => setState(() => _classSex = v)),
          const SizedBox(height: 8),
          const PcLabel('담임'),
          dropdown<String?>(
            value: _homeroom,
            hint: '지정 안 함',
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('지정 안 함', style: pcText(15, color: Ds.gray500)),
              ),
              for (final s in careStaff)
                DropdownMenuItem<String?>(
                  value: s.id,
                  child: Text(s.displayName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _homeroom = v),
          ),
          if (_classError != null) ...[
            const SizedBox(height: 8),
            Text(
              _classError!,
              style: pcText(13, color: Ds.red500, weight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          PcButton(
            key: const ValueKey('roster-add-class'),
            label: '반 추가',
            icon: Icons.add_rounded,
            onTap: _addClass,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            bg: Ds.blue500,
            fg: Colors.white,
            hoverBg: Ds.blue600,
            weight: FontWeight.w700,
          ),
        ]),
        box('별님 추가', Icons.person_add_alt_outlined, [
          const PcLabel('반'),
          if (realClasses.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Ds.gray50, borderRadius: BorderRadius.circular(16)),
              child: Text('먼저 위에서 반을 추가해 주세요', style: pcText(14, color: Ds.gray500)),
            )
          else
            dropdown<String>(
              value: _classId,
              hint: '반 고르기',
              items: [
                for (final c in realClasses)
                  DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(classRoom(c), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                _classId = v;
                _sex = null;
              }),
            ),
          const SizedBox(height: 8),
          const PcLabel('이름'),
          TextField(
            key: const ValueKey('roster-resident-name'),
            controller: _name,
            maxLength: 20,
            enabled: realClasses.isNotEmpty,
            style: pcText(15),
            decoration: pcInput('예: 김별님').copyWith(counterText: ''),
            onSubmitted: (_) => _addResident(),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const PcLabel('성별'), sexPicker(_sex ?? selectedClass?.sex, (v) => setState(() => _sex = v))],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PcLabel('나이'),
                    TextField(
                      key: const ValueKey('roster-resident-age'),
                      controller: _age,
                      enabled: realClasses.isNotEmpty,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                      style: pcText(15),
                      decoration: pcInput('세'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PcHover(
            onTap: realClasses.isEmpty ? null : () => setState(() => _commutes = !_commutes),
            semanticsLabel: '학교 통학',
            builder: (_) => Row(
              children: [
                Icon(
                  _commutes ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 22,
                  color: _commutes ? Ds.blue500 : Ds.gray400,
                ),
                const SizedBox(width: 6),
                Text(
                  '학교에 다녀요 (통학)',
                  style: pcText(15, weight: FontWeight.w500, color: Ds.gray700),
                ),
              ],
            ),
          ),
          if (_residentError != null) ...[
            const SizedBox(height: 8),
            Text(
              _residentError!,
              style: pcText(13, color: Ds.red500, weight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          PcButton(
            key: const ValueKey('roster-add-resident'),
            label: '별님 추가',
            icon: Icons.add_rounded,
            onTap: realClasses.isEmpty ? null : _addResident,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            bg: Ds.blue500,
            fg: Colors.white,
            hoverBg: Ds.blue600,
            weight: FontWeight.w700,
          ),
        ]),
        Text('기록은 지우지 않아요. 명단을 잘못 넣었다면 관리자에게 알려 주세요.', style: pcText(12, color: Ds.gray500)),
      ],
    );
  }
}
