// AR 기록 찾기 시트 (시제품 '기록 찾기'): 검색어 · 기간 · [조건 초기화] · [결과 보기].
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'archive_widgets.dart';

typedef SearchConditions = ({String query, int days});

/// 결과: [결과 보기]·[조건 초기화]면 조건, 그냥 닫으면 null.
Future<SearchConditions?> showSearchSheet(BuildContext context, {required String query, required int days}) =>
    showModalBottomSheet<SearchConditions>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SearchSheet(query: query, days: days),
    );

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.query, required this.days});
  final String query;
  final int days;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final _text = TextEditingController(text: widget.query);
  late int _days = widget.days;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _apply() => Navigator.pop(context, (query: _text.text.trim(), days: _days));

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: T.body, fontWeight: FontWeight.w800, color: inkMain);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          SheetTitle('기록 찾기'),
          const SizedBox(height: Gap.m),
          const Text('검색어', style: label),
          const SizedBox(height: Gap.s),
          TextField(
            controller: _text,
            maxLength: 80,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _apply(),
            style: const TextStyle(fontSize: T.body, color: inkMain),
            decoration: const InputDecoration(
              hintText: '내용 또는 기록자 · 예: 소리',
              counterText: '',
              filled: true,
              fillColor: Color(0xFFFFFAF8),
              constraints: BoxConstraints(minHeight: tapHeight),
            ),
          ),
          const SizedBox(height: Gap.l + 2),
          const Text('기간', style: label),
          const SizedBox(height: Gap.s),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: segTrack, borderRadius: BorderRadius.circular(Radii.button)),
            child: Row(children: [
              for (final (i, d) in const [0, 7, 30].indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: _days == d,
                    inMutuallyExclusiveGroup: true,
                    child: Material(
                      color: _days == d ? surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => setState(() => _days = d),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: tapHeight),
                          child: Center(
                            child: Text(d == 0 ? '전체 기간' : '최근 $d일',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: T.body,
                                  fontWeight: _days == d ? FontWeight.w800 : FontWeight.w500,
                                  color: _days == d ? inkMain : inkSub,
                                )),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: Gap.m),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: inkMain, padding: const EdgeInsets.symmetric(horizontal: 6)),
              onPressed: () => Navigator.pop(context, (query: '', days: 0)),
              child: const Text('조건 초기화'),
            ),
          ),
          const SizedBox(height: Gap.s),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: _apply,
            child: const Text('결과 보기'),
          ),
        ]),
      ),
    );
  }
}
