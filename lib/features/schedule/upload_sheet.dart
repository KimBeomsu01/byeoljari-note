// SC-U 파일로 일정 올리기 (일정 명세 6장, 통합 명세 6-5 4번). 팀 시제품 '파일 → 표' 시트 그대로, 글자만 한 단계 크게.
// 금요일 시연은 시제품처럼 실제 파일 해석 없이 예시 5건을 고정으로 보여주고, 반영해도 일정은 바뀌지 않는다.
// 흐름: 짙은 안내 띠('AI 자동 변환 · 다음 단계 적용 예정') → 파일 고르기 → 정리된 표 → 다시 올리기 / 일정에 반영 (시연).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'schedule_widgets.dart';

Future<void> showUploadSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: surface,
      builder: (_) => const UploadSheet(),
    );

/// 정리된 표의 한 줄.
typedef _Row = ({String date, String time, String title, String place, String staff, String target});

class UploadSheet extends ConsumerStatefulWidget {
  const UploadSheet({super.key});

  @override
  ConsumerState<UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<UploadSheet> {
  /// 0 = 파일 고르기, 1 = 정리된 표 확인
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
      (date: '10/30 (금)', time: '13:00–13:40', title: '목욕 · 체온 측정', place: '2층 목욕실', staff: homeroom('bear'), target: cls('bear')),
      (date: '10/31 (토)', time: '10:00–11:30', title: '여가 활동', place: '강당', staff: homeroom('whale'), target: cls('whale')),
    ];
  }

  static const _fileName = '10월 5주차_일과표 (시연 예시).hwpx';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, Gap.xl + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('파일로 일정 올리기',
                style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain)),
          ),
          IconButton(
            tooltip: '닫기',
            iconSize: 22,
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F1)),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: inkSub),
          ),
        ]),
        const SizedBox(height: Gap.s),
        const _AiBanner(),
        const SizedBox(height: Gap.m),
        Flexible(child: _step == 0 ? _pickStep() : _reviewStep()),
      ]),
    );
  }

  Widget _pickStep() => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CustomPaint(
            foregroundPainter: const DashedBorderPainter(color: Color(0xFFB4BCB1), radius: 14, width: 1.5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 22),
              decoration: BoxDecoration(color: const Color(0xFFFAFAF7), borderRadius: BorderRadius.circular(14)),
              child: const Column(children: [
                Icon(Icons.upload_outlined, size: 30, color: inkSub),
                SizedBox(height: 6),
                Text('hwpx · 엑셀(xlsx) 파일 선택',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain)),
                SizedBox(height: 2),
                Text('여러 파일은 사무국 웹에서 한 번에 올리면 편해요',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: inkSub)),
              ]),
            ),
          ),
          const SizedBox(height: Gap.m),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: brandDark, minimumSize: const Size.fromHeight(52)),
            onPressed: () => setState(() => _step = 1),
            icon: const Icon(Icons.folder_open_outlined, size: 22),
            label: const Text('파일 고르기'),
          ),
          const SizedBox(height: Gap.s),
          const Text('시연에서는 실제 파일을 읽지 않고 예시 표를 보여줘요',
              textAlign: TextAlign.center, style: TextStyle(fontSize: T.caption, color: inkSub)),
        ]),
      );

  Widget _reviewStep() {
    final rows = _exampleRows();
    final ok = stageColors[Stage.normal]!;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Flexible(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // 고른 파일: 초록 띠
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 10),
              decoration: BoxDecoration(color: ok.soft, borderRadius: BorderRadius.circular(Radii.button)),
              child: Row(children: [
                Text('✓', style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: ok.ink)),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: Text(_fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: T.caption, fontWeight: FontWeight.w800, color: ok.ink)),
                ),
              ]),
            ),
            const SizedBox(height: Gap.s + 2),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '일정 ${rows.length}개를 표로 정리했어요'),
                const TextSpan(text: ' (시연용 예시 결과)', style: TextStyle(fontSize: T.caption, color: inkSub)),
              ]),
              style: const TextStyle(fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain),
            ),
            const SizedBox(height: 2),
            const Text('반영하기 전에는 일정이 바뀌지 않아요. 표는 옆으로 밀어 볼 수 있어요.',
                style: TextStyle(fontSize: T.caption, color: inkSub)),
            const SizedBox(height: Gap.s + 2),
            _Table(rows: rows),
          ]),
        ),
      ),
      const SizedBox(height: Gap.m),
      Row(children: [
        Expanded(
          flex: 10,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: line),
              foregroundColor: inkMain,
              padding: const EdgeInsets.symmetric(horizontal: Gap.s),
            ),
            onPressed: () => setState(() => _step = 0),
            child: const Text('다시 올리기', textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: Gap.s),
        Expanded(
          flex: 14,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: brandDark,
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: Gap.s),
            ),
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              messenger.showSnackBar(const SnackBar(
                duration: Duration(seconds: 3),
                content: Text('시연용 예시라 실제 일정은 바뀌지 않아요'),
              ));
            },
            child: const Text('일정에 반영 (시연)', textAlign: TextAlign.center),
          ),
        ),
      ]),
    ]);
  }
}

/// 짙은 안내 띠 (시제품): ✦ AI 자동 변환 · 다음 단계 적용 예정.
class _AiBanner extends StatelessWidget {
  const _AiBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: brandDark, borderRadius: BorderRadius.circular(Radii.button)),
        child: const Row(children: [
          Text('✦', style: TextStyle(fontSize: 20, color: Color(0xFFE7CF8F))),
          SizedBox(width: Gap.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI 자동 변환 · 다음 단계 적용 예정',
                  style: TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: Colors.white)),
              SizedBox(height: 2),
              Text("지금은 '올리기 → 정리된 표 → 반영' 흐름만 보여주는 시연 화면이에요.",
                  style: TextStyle(fontSize: T.caption, color: Color(0xFFDDE2DD), height: 1.45)),
            ]),
          ),
        ]),
      );
}

/// 정리된 일정 표 (시제품): 날짜 · 시간 · 프로그램 · 장소 · 담당 · 대상. 폭이 모자라면 옆으로 민다.
class _Table extends StatelessWidget {
  const _Table({required this.rows});
  final List<_Row> rows;

  static const _head = ['날짜', '시간', '프로그램', '장소', '담당', '대상'];

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(t,
              softWrap: false,
              style: TextStyle(
                  fontSize: T.caption,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: inkMain,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        );
    return Semantics(
      label: '정리된 일정 표',
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: line), borderRadius: BorderRadius.circular(Radii.button)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: const TableBorder(horizontalInside: BorderSide(color: Color(0xFFEEF0EC))),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF3F5EF)),
                children: [for (final h in _head) cell(h, bold: true)],
              ),
              for (final r in rows)
                TableRow(children: [
                  cell(r.date),
                  cell(r.time),
                  cell(r.title, bold: true),
                  cell(r.place),
                  cell(r.staff),
                  cell(r.target),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
