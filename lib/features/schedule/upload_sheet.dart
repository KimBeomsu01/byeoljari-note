// SC-U 파일로 일정 올리기 (일정 명세 6장, 통합 명세 6-5 4번).
// 금요일 시연은 시제품처럼 실제 파일 해석 없이 예시 5건을 고정으로 보여주고, 반영해도 일정은 바뀌지 않는다.
// 순서가 있는 일이라 1·2·3 단계 번호를 크게 보여준다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

Future<void> showUploadSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: paper,
      builder: (_) => const UploadSheet(),
    );

/// 확인 화면의 한 줄.
typedef _Row = ({String date, String time, String title, String place, String staff, String target});

class UploadSheet extends ConsumerStatefulWidget {
  const UploadSheet({super.key});

  @override
  ConsumerState<UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<UploadSheet> {
  /// 0 = 파일 고르기, 1 = 내용 확인
  int _step = 0;

  /// 예시 5건. 사람·반 이름은 시드에서 가져온다 (코드에 박지 않음).
  List<_Row> _exampleRows() {
    final repo = ref.read(repoProvider);
    String homeroom(String classId) => repo.staff(repo.classOf(classId).homeroomId).displayName;
    String cls(String classId) => repo.classOf(classId).name;
    return [
      (date: '10월 29일 (목)', time: '10:00~11:00', title: '작업 치료', place: '1층 치료실', staff: homeroom('milkyway'), target: cls('milkyway')),
      (date: '10월 29일 (목)', time: '15:30~16:30', title: '체육 활동', place: '강당', staff: homeroom('milkyway'), target: cls('milkyway')),
      (date: '10월 30일 (금)', time: '10:00~11:00', title: '언어 치료', place: '2층 상담실', staff: homeroom('aries'), target: cls('aries')),
      (date: '10월 30일 (금)', time: '13:00~13:40', title: '목욕', place: '2층 목욕실', staff: homeroom('bear'), target: cls('bear')),
      (date: '10월 31일 (토)', time: '10:00~11:30', title: '여가 활동', place: '강당', staff: homeroom('whale'), target: cls('whale')),
    ];
  }

  static const _fileName = '10월 5주차_일과표 (시연 예시).hwpx';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.page, Gap.s, Gap.page, Gap.l + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('파일로 일정 올리기',
                style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
          ),
          IconButton(
            tooltip: '닫기',
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: inkMain),
          ),
        ]),
        const SizedBox(height: Gap.m),
        _Steps(step: _step),
        const SizedBox(height: Gap.l),
        Flexible(child: _step == 0 ? _pickStep() : _reviewStep()),
      ]),
    );
  }

  Widget _pickStep() => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const InfoCard(
            padding: EdgeInsets.all(Gap.xl),
            child: Column(children: [
              Icon(Icons.description_outlined, size: 48, color: brandDark),
              SizedBox(height: Gap.m),
              Text('한글(hwpx)이나 엑셀 파일을 골라 주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w700, color: inkMain)),
              SizedBox(height: Gap.s),
              Text('시연에서는 실제 파일을 읽지 않고 예시 표를 보여줘요',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: inkSub)),
            ]),
          ),
          const SizedBox(height: Gap.l),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
            onPressed: () => setState(() => _step = 1),
            icon: const Icon(Icons.folder_open, size: 24),
            label: const Text('파일 고르기'),
          ),
        ]),
      );

  Widget _reviewStep() {
    final rows = _exampleRows();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('일정 ${rows.length}건을 찾았어요',
          style: const TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
      const SizedBox(height: Gap.xs),
      const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.description_outlined, size: 20, color: inkSub)),
        SizedBox(width: Gap.s),
        Expanded(child: Text(_fileName, style: TextStyle(fontSize: T.caption, color: inkSub))),
      ]),
      const SizedBox(height: Gap.s),
      const Text('내용을 확인해 주세요. 반영하기 전에는 일정이 바뀌지 않아요.',
          style: TextStyle(fontSize: T.body, color: inkMain)),
      const SizedBox(height: Gap.m),
      Flexible(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
          itemBuilder: (_, i) => _RowCard(row: rows[i]),
        ),
      ),
      const SizedBox(height: Gap.l),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
        onPressed: () {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(const SnackBar(
            duration: Duration(seconds: 3),
            content: Text('시연용 예시라 실제 일정은 바뀌지 않아요'),
          ));
        },
        child: const Text('일정에 반영하기'),
      ),
      const SizedBox(height: Gap.s),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(tapHeight)),
        onPressed: () => setState(() => _step = 0),
        child: const Text('다른 파일 고르기'),
      ),
    ]);
  }
}

/// 표 한 줄을 카드로: ① 무엇 + 어느 반 ② 언제 ③ 어디 ④ 담당 (한 줄에 한 가지).
class _RowCard extends StatelessWidget {
  const _RowCard({required this.row});
  final _Row row;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Gap.l),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: Gap.s, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(row.title, style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
            StatusPill(row.target, color: brandDark),
          ]),
          const SizedBox(height: Gap.xs),
          Text('${row.date}  ${row.time}', style: const TextStyle(fontSize: T.caption, color: inkMain)),
          Text(row.place, style: const TextStyle(fontSize: T.caption, color: inkSub)),
          Text('담당 ${row.staff}', style: const TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
      );
}

/// 1 파일 고르기 → 2 내용 확인 → 3 반영.
class _Steps extends StatelessWidget {
  const _Steps({required this.step});
  final int step;

  static const _labels = ['파일 올리기', '내용 확인', '반영'];

  @override
  Widget build(BuildContext context) {
    Widget item(int i) {
      final done = step > i;
      final current = step == i;
      final on = done || current;
      return Expanded(
        child: Semantics(
          label: '${i + 1}단계 ${_labels[i]}${done ? ', 끝남' : current ? ', 지금 단계' : ''}',
          excludeSemantics: true,
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? brandDark : surface,
                shape: BoxShape.circle,
                border: Border.all(color: on ? brandDark : line, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check, size: 24, color: Colors.white)
                  : Text('${i + 1}',
                      style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: on ? Colors.white : inkSub)),
            ),
            const SizedBox(height: Gap.xs),
            Text(_labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: T.caption,
                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                    color: on ? inkMain : inkSub)),
          ]),
        ),
      );
    }

    Widget bar(int i) => Padding(
          padding: const EdgeInsets.only(top: 19),
          child: SizedBox(width: 24, height: 2, child: ColoredBox(color: step > i ? brandDark : line)),
        );

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      item(0),
      bar(0),
      item(1),
      bar(1),
      item(2),
    ]);
  }
}
