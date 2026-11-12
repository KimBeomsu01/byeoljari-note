// SC-U 파일로 일정 올리기 (일정 명세 6장, 통합 명세 6-5 4번).
// 금요일 시연은 시제품처럼 실제 파일 해석 없이 예시 5건을 고정으로 보여주고, 반영해도 일정은 바뀌지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';

Future<void> showUploadSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: paper,
      builder: (_) => const UploadSheet(),
    );

/// 표 확인 화면의 한 줄.
typedef _Row = ({String date, String time, String title, String place, String staff, String target});

class UploadSheet extends ConsumerStatefulWidget {
  const UploadSheet({super.key});

  @override
  ConsumerState<UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<UploadSheet> {
  /// 0 = 올리기, 1 = 표 확인
  int _step = 0;

  /// 예시 5건. 사람·반 이름은 시드에서 가져온다 (코드에 박지 않음).
  List<_Row> _exampleRows() {
    final repo = ref.read(repoProvider);
    String homeroom(String classId) => repo.staff(repo.classOf(classId).homeroomId).displayName;
    String cls(String classId) => repo.classOf(classId).name;
    return [
      (date: '10/29 (목)', time: '10:00–11:00', title: '작업 치료', place: '1층 치료실', staff: homeroom('milkyway'), target: cls('milkyway')),
      (date: '10/29 (목)', time: '15:30–16:30', title: '체육 활동', place: '강당', staff: homeroom('milkyway'), target: cls('milkyway')),
      (date: '10/30 (금)', time: '10:00–11:00', title: '언어 치료', place: '2층 상담실', staff: homeroom('aries'), target: cls('aries')),
      (date: '10/30 (금)', time: '13:00–13:40', title: '목욕', place: '2층 목욕실', staff: homeroom('bear'), target: cls('bear')),
      (date: '10/31 (토)', time: '10:00–11:30', title: '여가 활동', place: '강당', staff: homeroom('whale'), target: cls('whale')),
    ];
  }

  static const _fileName = '10월 5주차_일과표 (시연 예시).hwpx';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFFCCCFC8), borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(children: [
          const Expanded(
            child: Text('파일로 일정 올리기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
        _Steps(step: _step),
        const SizedBox(height: 12),
        Flexible(child: _step == 0 ? _pickStep() : _reviewStep()),
      ]),
    );
  }

  Widget _pickStep() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD9DCD5)),
          ),
          child: const Column(children: [
            Icon(Icons.description_outlined, size: 36, color: brandDark),
            SizedBox(height: 8),
            Text('hwpx 또는 엑셀 파일을 골라 주세요', textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text('시연에서는 실제 파일을 읽지 않고 예시 표를 보여줘요',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: inkSub)),
          ]),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => setState(() => _step = 1),
          icon: const Icon(Icons.folder_open),
          label: const Text('파일 고르기'),
        ),
      ]);

  Widget _reviewStep() {
    final rows = _exampleRows();
    const head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: inkSub);
    Widget cell(String t, {TextStyle? style}) =>
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text(t, style: style));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.description_outlined, size: 18, color: brandDark),
        const SizedBox(width: 6),
        const Expanded(child: Text(_fileName, overflow: TextOverflow.ellipsis)),
        Text('${rows.length}건', style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      const Text('내용을 확인해 주세요. 반영하기 전에는 일정이 바뀌지 않아요.', style: TextStyle(fontSize: 12, color: inkSub)),
      const SizedBox(height: 8),
      Flexible(
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E2DC)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: const TableBorder(horizontalInside: BorderSide(color: Color(0xFFEDEDE8))),
                children: [
                  TableRow(children: [
                    for (final h in const ['날짜', '시간', '프로그램', '장소', '담당', '대상']) cell(h, style: head),
                  ]),
                  for (final r in rows)
                    TableRow(children: [
                      cell(r.date),
                      cell(r.time),
                      cell(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      cell(r.place),
                      cell(r.staff),
                      cell(r.target),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => setState(() => _step = 0),
            child: const Text('다시 올리기'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              messenger.showSnackBar(const SnackBar(
                duration: Duration(seconds: 3),
                content: Text('시연용 예시라 실제 일정은 바뀌지 않아요'),
              ));
            },
            child: const Text('일정에 반영'),
          ),
        ),
      ]),
    ]);
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    Widget dot(int i, String label) {
      final on = step >= i;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: on ? brandDark : const Color(0xFFD9DCD5),
          child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: on ? inkMain : inkSub, fontWeight: step == i ? FontWeight.w700 : null)),
      ]);
    }

    return Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
      dot(0, '올리기'),
      const Icon(Icons.chevron_right, size: 16, color: inkSub),
      dot(1, '표 확인'),
      const Icon(Icons.chevron_right, size: 16, color: inkSub),
      dot(2, '반영'),
    ]);
  }
}
