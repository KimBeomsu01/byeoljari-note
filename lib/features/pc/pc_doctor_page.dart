// PC 04 의료진 협진 포털 · 의사 모드 (Claude Design PcDoctorPortal). 사용자 역할이 촉탁의일 때 pc_shell 이 보여준다.
// 왼쪽 호출 목록(260) · 가운데 케어팀 대화 · 오른쪽 비대면 진단서 및 전자처방전 작성(440).
// 처방 글은 의사가 쓴 그대로 저장한다. 앱은 용량을 계산하거나 추천하지 않는다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_calls_common.dart';
import 'pc_calls_dialogs.dart';
import 'pc_medical_rooms.dart';

class PcDoctorPage extends StatelessWidget {
  const PcDoctorPage({super.key});

  @override
  Widget build(BuildContext context) => const McLayout(
        inbox: DoctorInbox(),
        rooms: ChatRooms(doctor: true),
        side: _RxPanel(),
      );
}

/// 입력 저장을 미루는 시간 (실시간 동기화).
const rxSaveDelay = Duration(milliseconds: 600);

class _RxPanel extends ConsumerWidget {
  const _RxPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repoProvider);
    final call = shownCall(ref);
    final p = call == null ? null : repo.prescriptionOf(call.id);
    final issued = p?.issued ?? false;

    return McPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Ds.gray200))),
          child: Row(children: [
            const Icon(Icons.edit_document, size: 20, color: Ds.blue500),
            const SizedBox(width: 8),
            Expanded(
              child: Text('비대면 진단서 및 전자처방전 작성',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(14, weight: FontWeight.w700)),
            ),
            McPill(
              issued ? '발행 완료' : '진단 작성중',
              bg: issued ? Ds.green50 : Ds.red50,
              fg: issued ? Ds.green500 : Ds.red500,
              border: issued ? const Color(0x4D03B26C) : mcRed200,
              size: 11,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
          ]),
        ),
        Expanded(
          child: call == null
              ? ColoredBox(
                  color: const Color(0x80F9FAFB),
                  child: repo.isDev
                      ? ListView(padding: const EdgeInsets.all(16), children: const [ExampleWrap(child: _ExampleRx())])
                      : Center(child: Text('호출을 고르면 진단서를 쓸 수 있어요', style: mcText(12.5, color: Ds.gray500))),
                )
              : _RxEditor(key: ValueKey(call.id), callId: call.id),
        ),
      ]),
    );
  }
}

/// 처방약 입력 한 줄의 글 상자들.
class _RxRow {
  _RxRow(RxItem? i)
      : name = TextEditingController(text: i?.name ?? ''),
        usage = TextEditingController(text: i?.usage ?? ''),
        amount = TextEditingController(text: i?.amount ?? '');
  final TextEditingController name;
  final TextEditingController usage;
  final TextEditingController amount;

  bool get blank => name.text.trim().isEmpty && usage.text.trim().isEmpty && amount.text.trim().isEmpty;
  RxItem get item => RxItem(name: name.text.trim(), usage: usage.text.trim(), amount: amount.text.trim());

  void dispose() {
    name.dispose();
    usage.dispose();
    amount.dispose();
  }
}

class _RxEditor extends ConsumerStatefulWidget {
  const _RxEditor({super.key, required this.callId});
  final String callId;

  @override
  ConsumerState<_RxEditor> createState() => _RxEditorState();
}

class _RxEditorState extends ConsumerState<_RxEditor> {
  late final InMemoryRepository _repo;
  late final TextEditingController _code;
  late final TextEditingController _codeName;
  late final TextEditingController _opinion;
  final _rows = <_RxRow>[];
  Timer? _debounce;
  String _doctorId = '';

  @override
  void initState() {
    super.initState();
    _repo = ref.read(repoProvider);
    _doctorId = ref.read(currentUserProvider);
    final p = _repo.prescriptionOf(widget.callId);
    _code = TextEditingController(text: p?.code ?? '');
    _codeName = TextEditingController(text: p?.codeName ?? '');
    _opinion = TextEditingController(text: p?.opinion ?? '');
    for (final i in p?.items ?? const <RxItem>[]) {
      _rows.add(_RxRow(i));
    }
    if (_rows.isEmpty) _rows.add(_RxRow(null));
  }

  bool get _pending => _debounce?.isActive ?? false;

  List<RxItem> get _items => [
        for (final r in _rows)
          if (!r.blank) r.item,
      ];

  /// 입력이 바뀌면 잠깐 뒤에 임시 저장 (간호사 화면 프리뷰에 바로 보인다).
  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(rxSaveDelay, _save);
    setState(() {});
  }

  void _save() {
    _debounce?.cancel();
    _debounce = null;
    _write(_repo, widget.callId, _doctorId, _code.text, _codeName.text, _opinion.text, _items);
    if (mounted) setState(() {});
  }

  static void _write(InMemoryRepository repo, String callId, String doctorId, String code, String codeName, String opinion,
      List<RxItem> items) {
    final p = repo.prescriptionOf(callId);
    if (p != null && p.issued) return;
    repo.saveDraft(
      callId: callId,
      doctorId: doctorId,
      code: code.trim(),
      codeName: codeName.trim(),
      opinion: opinion.trim(),
      items: items,
    );
  }

  @override
  void dispose() {
    if (_pending) {
      // 다른 호출로 넘어가도 쓰던 글은 남긴다 (화면 정리가 끝난 뒤 저장).
      final repo = _repo, id = widget.callId, doc = _doctorId;
      final code = _code.text, name = _codeName.text, opinion = _opinion.text, items = _items;
      scheduleMicrotask(() => _write(repo, id, doc, code, name, opinion, items));
    }
    _debounce?.cancel();
    _code.dispose();
    _codeName.dispose();
    _opinion.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _toast(String text, {bool info = false}) => showDsToast(context, text,
      icon: info ? Icons.info_outline : Icons.check_circle, iconColor: info ? Ds.orange500 : Ds.green500);

  Future<void> _issue() async {
    final items = _items;
    if (_code.text.trim().isEmpty || _codeName.text.trim().isEmpty || items.isEmpty || items.any((i) => i.name.isEmpty)) {
      _toast('질병코드 · 상병명과 처방약 이름을 적어 주세요', info: true);
      return;
    }
    _save();
    final ok = await confirmIssue(context, code: _code.text.trim(), codeName: _codeName.text.trim(), items: items);
    if (!ok || !mounted) return;
    final issued = _repo.issuePrescription(widget.callId, _doctorId);
    _toast('전자처방전을 발행했어요 (${issued.number})');
  }

  void _addRow() {
    setState(() => _rows.add(_RxRow(null)));
  }

  void _removeRow(_RxRow r) {
    setState(() => _rows.remove(r));
    // 글 상자가 화면에서 빠진 뒤에 정리한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => r.dispose());
    if (_rows.isEmpty) _rows.add(_RxRow(null));
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    _doctorId = ref.watch(currentUserProvider);
    final call = repo.callById(widget.callId);
    final r = repo.resident(call.residentId);
    final cls = repo.classOf(r.classId);
    final p = repo.prescriptionOf(call.id);
    final issued = p?.issued ?? false;

    TextStyle hint(TextStyle s) => s.copyWith(color: Ds.gray400, fontWeight: FontWeight.w400);
    Widget field(TextEditingController c, TextStyle style, String hintText, {Key? key, TextAlign align = TextAlign.start, bool multi = false}) =>
        TextField(
          key: key,
          controller: c,
          onChanged: (_) => _changed(),
          style: style,
          textAlign: align,
          minLines: 1,
          maxLines: multi ? 3 : 1,
          // 디자인처럼 글만 보이고, 누르면 파란 밑줄.
          decoration: InputDecoration(
            isDense: true,
            isCollapsed: true,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            hintText: hintText,
            hintStyle: hint(style),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Ds.blue500)),
          ),
        );

    final codeStyle = mcText(12, weight: FontWeight.w700, color: Ds.blue500, mono: true);
    final nameStyle = mcText(12, weight: FontWeight.w500);
    final opinionStyle = mcText(12, height: 1.625);

    final diag = _DiagCard(
      sync: issued ? '발행됨 · 고칠 수 없음' : (_pending ? '저장 중…' : '실시간 동기화'),
      code: issued
          ? Text(p!.code, style: codeStyle)
          : field(_code, codeStyle, '코드', key: const ValueKey('rx-code')),
      codeName: issued
          ? Text(p!.codeName, style: nameStyle)
          : field(_codeName, nameStyle, '상병명', key: const ValueKey('rx-code-name')),
      opinion: issued
          ? _ReadBox(child: Text(p!.opinion.isEmpty ? '소견 없음' : p.opinion, style: opinionStyle))
          : TextField(
              key: const ValueKey('rx-opinion'),
              controller: _opinion,
              onChanged: (_) => _changed(),
              minLines: 3,
              maxLines: 8,
              style: opinionStyle,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Ds.gray100,
                hoverColor: Colors.transparent,
                hintText: '진료 소견과 원격 지도사항을 적어 주세요',
                hintStyle: hint(opinionStyle),
                contentPadding: const EdgeInsets.all(10),
                border: _line(Ds.gray200, 1),
                enabledBorder: _line(Ds.gray200, 1),
                focusedBorder: _line(const Color(0x663182F6), 2),
              ),
            ),
    );

    final rxCard = _RxCard(
      count: issued ? p!.items.length : _items.length,
      rows: issued
          ? [for (final i in p!.items) RxItemView(i, highlight: true)]
          : [
              for (var i = 0; i < _rows.length; i++)
                _RxEditRow(
                  index: i,
                  name: field(_rows[i].name, mcText(12, weight: FontWeight.w700), '약 이름 (의사가 쓴 그대로)',
                      key: ValueKey('rx-name-$i'), multi: true),
                  usage: field(_rows[i].usage, mcText(11, color: Ds.gray600), '용법 · 횟수 (의사가 쓴 그대로)',
                      key: ValueKey('rx-usage-$i'), multi: true),
                  amount: field(_rows[i].amount, mcText(11, weight: FontWeight.w700, color: Ds.blue500, mono: true), '양',
                      key: ValueKey('rx-amount-$i'), align: TextAlign.center),
                  onRemove: () => _removeRow(_rows[i]),
                ),
            ],
      onAdd: issued ? null : _addRow,
    );

    final signer = issued ? repo.staff(p!.doctorId) : repo.staff(_doctorId);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ColoredBox(
          color: const Color(0x80F9FAFB),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _PatientCard(r: r, place: '${cls.name} ${cls.room ?? ''}'.trim(), latest: repo.latestOf(r.id)),
            const SizedBox(height: 14),
            diag,
            const SizedBox(height: 14),
            rxCard,
          ]),
        ),
      ),
      // 전자서명 · 발행
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Ds.gray200))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '의사 전자서명: '),
                    TextSpan(text: signer.displayName, style: const TextStyle(color: Ds.gray900, fontWeight: FontWeight.w700)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mcText(11, color: Ds.gray600),
                ),
              ),
              if (issued) ...[
                const Icon(Icons.verified, size: 14, color: Ds.green500),
                const SizedBox(width: 4),
                Text('서명 완료', style: mcText(11, weight: FontWeight.w600, color: Ds.green500)),
              ] else
                Text('발행하면 고칠 수 없어요', style: mcText(11, color: Ds.gray500)),
            ]),
          ),
          const SizedBox(height: 8),
          if (issued)
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Ds.green50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x4D03B26C)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.verified, size: 18, color: Ds.green500),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('발행 완료 · ${p!.number ?? ''} · ${hhmm(p.issuedAt ?? p.updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mcText(14, weight: FontWeight.w700, color: Ds.green500, height: 1.2)),
                ),
              ]),
            )
          else
            McBlueButton(
              label: '전자서명 완료 및 전자처방전 발행·전송',
              icon: Icons.verified,
              height: 44,
              fontSize: 15,
              iconSize: 18,
              gap: 8,
              onTap: _issue,
            ),
        ]),
      ),
    ]);
  }
}

OutlineInputBorder _line(Color c, double w) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c, width: w));

/// 회색 글 상자 (읽기 전용 소견).
class _ReadBox extends StatelessWidget {
  const _ReadBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Ds.gray100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Ds.gray200),
        ),
        child: child,
      );
}

/// 별님 요약 + 처방 주의 (금기).
class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.r, required this.place, required this.latest});
  final Resident r;
  final String place;
  final Measurement? latest;

  @override
  Widget build(BuildContext context) {
    final head = cautionHead(r);
    final m = latest;
    return McCard(children: [
      Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ds.gray100))),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Ds.blue50, borderRadius: BorderRadius.circular(24)),
            child: Text(r.shortName, style: mcText(13, weight: FontWeight.w700, color: Ds.blue500, height: 1.2)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(starName(r.name),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(13, weight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Text(sexAge(r), style: mcText(11, color: Ds.gray500)),
              ]),
              Text('$place${r.code == null ? '' : ' · ${r.code}'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(10.5, color: Ds.gray500, mono: true)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('현재 체온', style: mcText(10, color: Ds.gray500)),
            Text(
              m == null ? '기록 없음' : fmtC(m.value),
              style: mcText(m == null ? 12 : 16,
                  weight: FontWeight.w900,
                  mono: true,
                  height: 1.3,
                  color: m == null ? Ds.gray500 : vitalColor(m.judgment.stage, m.judgment.diff)),
            ),
          ]),
        ]),
      ),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: head == null ? Ds.gray100 : mcRed50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: head == null ? Ds.gray200 : mcRed200),
        ),
        child: Row(children: [
          Icon(Icons.block, size: 15, color: head == null ? Ds.gray500 : Ds.red500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              head == null ? '처방 주의: 등록된 금기 없음' : '처방 주의: $head',
              style: mcText(11.5, weight: FontWeight.w700, color: head == null ? Ds.gray600 : Ds.red500),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// 진단 상병 및 질병코드 (KCD-8) + 진료 소견.
class _DiagCard extends StatelessWidget {
  const _DiagCard({required this.code, required this.codeName, required this.opinion, required this.sync});
  final Widget code;
  final Widget codeName;
  final Widget opinion;
  final String sync;

  @override
  Widget build(BuildContext context) => McCard(padding: 16, gap: 12, children: [
        const McCardTitle('진단 상병 및 질병코드 (KCD-8)', icon: Icons.assignment_outlined, size: 13),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Ds.gray100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: mcGray200a70),
          ),
          child: Row(children: [
            SizedBox(width: 64, child: code),
            const SizedBox(width: 6),
            Expanded(child: codeName),
            const SizedBox(width: 6),
            McPill('주상병',
                bg: Colors.white,
                fg: Ds.gray700,
                border: Ds.gray200,
                size: 10,
                radius: 12,
                weight: FontWeight.w400,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('진료 소견 및 원격 지도사항', style: mcText(11.5, weight: FontWeight.w700, color: Ds.gray700))),
            Text(sync, style: mcText(10.5, color: Ds.blue500, mono: true)),
          ]),
          const SizedBox(height: 6),
          opinion,
        ]),
      ]);
}

/// 처방약 입력 한 줄: 이름 · 용법 · 양 · 빼기.
class _RxEditRow extends StatelessWidget {
  const _RxEditRow({required this.index, required this.name, required this.usage, required this.amount, required this.onRemove});
  final int index;
  final Widget name;
  final Widget usage;
  final Widget amount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Ds.gray100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: mcGray200a70),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [name, const SizedBox(height: 2), usage]),
          ),
          const SizedBox(width: 8),
          Container(
            width: 92,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Ds.gray200),
            ),
            child: amount,
          ),
          const SizedBox(width: 2),
          McIconButton(icon: Icons.close, tooltip: '이 약 빼기', size: 28, iconSize: 16, onTap: onRemove),
        ]),
      );
}

/// 비대면 처방의약품 지정.
class _RxCard extends StatelessWidget {
  const _RxCard({required this.count, required this.rows, required this.onAdd});
  final int count;
  final List<Widget> rows;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => McCard(padding: 16, gap: 12, children: [
        McCardTitle('비대면 처방의약품 지정',
            icon: Icons.medication_outlined,
            size: 13,
            trailing: Text('$count개 품목', style: mcText(11, weight: FontWeight.w700, color: Ds.green500))),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < rows.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 8), child: rows[i]),
          if (rows.isEmpty) Text('처방약 없음', style: mcText(12, color: Ds.gray500)),
        ]),
        if (onAdd != null)
          Align(
            alignment: Alignment.centerLeft,
            child: McChipButton(icon: Icons.add, iconColor: Ds.blue500, label: '처방약 추가', big: true, onTap: onAdd!),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('의사가 쓴 글 그대로 저장돼요. 앱은 투약 용량을 계산하거나 추천하지 않아요.', style: mcText(11, color: Ds.gray500)),
        ),
      ]);
}

/// 개발 DB 예시: 진단서 작성 모양.
class _ExampleRx extends StatelessWidget {
  const _ExampleRx();

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _PatientCard(
          r: Resident(id: 'example', classId: 'example', name: '예시 별님', order: 0, sex: '남', age: 20, code: 'HJ-0000-000'),
          place: '예시반 000호',
          latest: null,
        ),
        const SizedBox(height: 14),
        _DiagCard(
          sync: '실시간 동기화',
          code: Text('코드', style: mcText(12, weight: FontWeight.w700, color: Ds.blue500)),
          codeName: Text('의사가 고른 상병명이 여기에 보여요', style: mcText(12, weight: FontWeight.w500)),
          opinion: _ReadBox(child: Text('의사가 쓴 진료 소견이 그대로 보여요.', style: mcText(12, height: 1.625))),
        ),
        const SizedBox(height: 14),
        const _RxCard(
          count: 1,
          rows: [RxItemView(RxItem(name: '예시 약 이름', usage: '의사가 쓴 용법이 그대로 보여요', amount: '예시'), highlight: true)],
          onAdd: null,
        ),
      ]);
}
