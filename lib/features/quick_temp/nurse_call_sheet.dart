// 체온 측정 화면의 [간호쌤 호출]: 무슨 일인지 고르고 보내면
// 의료 호출함(간호사)에 호출이 가고, 별님카드에 "간호사 호출" 기록이 남는다 (repo.callNurse).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ds.dart';
import '../../core/judgment.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// 빠른 이유 (여러 개 고를 수 있다).
const nurseCallReasons = ['열이 나요', '기침·콧물', '구토·설사', '아파해요', '다쳤어요', '식사를 못 해요', '기타'];

/// 보냈으면 true.
Future<bool> showNurseCallSheet(BuildContext context, String residentId) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NurseCallSheet(residentId: residentId),
  );
  return sent ?? false;
}

class NurseCallSheet extends ConsumerStatefulWidget {
  const NurseCallSheet({super.key, required this.residentId});
  final String residentId;

  @override
  ConsumerState<NurseCallSheet> createState() => _NurseCallSheetState();
}

class _NurseCallSheetState extends ConsumerState<NurseCallSheet> {
  final _picked = <String>{};
  final _memo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _memo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  String get _reason {
    final chips = [for (final r in nurseCallReasons) if (_picked.contains(r)) r];
    final memo = _memo.text.trim();
    return [if (chips.isNotEmpty) chips.join(', '), if (memo.isNotEmpty) memo].join('. ');
  }

  void _send() {
    if (_reason.isEmpty) return;
    ref.read(repoProvider).callNurse(residentId: widget.residentId, by: ref.read(currentUserProvider), reason: _reason);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final r = repo.resident(widget.residentId);
    final latest = repo.latestOf(r.id);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboard),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const Text('간호 선생님 호출', style: TextStyle(fontSize: T.heading, height: 1.4, fontWeight: FontWeight.w700, color: Ds.gray900)),
          const SizedBox(height: 4),
          Text(
            '${repo.classOf(r.classId).name} ${r.name} 별님'
            '${latest == null ? '' : ' · 최근 체온 ${formatTemp(latest.value)}° (${hhmm(latest.measuredAt)})'}',
            style: const TextStyle(fontSize: T.label, height: 1.5, color: Ds.gray600),
          ),
          const SizedBox(height: 20),
          const Text('무슨 일인가요?', style: TextStyle(fontSize: T.body, height: 1.5, fontWeight: FontWeight.w700, color: Ds.gray900)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final reason in nurseCallReasons)
              DsChip(
                label: reason,
                selected: _picked.contains(reason),
                onTap: () => setState(() => _picked.contains(reason) ? _picked.remove(reason) : _picked.add(reason)),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            key: const Key('nurse-call-memo'),
            controller: _memo,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '자세한 내용 (선택)'),
          ),
          const SizedBox(height: 12),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: Ds.gray500),
            SizedBox(width: 6),
            Expanded(
              child: Text('의료 호출함(간호사)에 바로 알림이 가고, 별님카드에 호출 기록이 남아요.',
                  style: TextStyle(fontSize: T.caption, height: 1.5, color: Ds.gray500)),
            ),
          ]),
          const SizedBox(height: 20),
          DsButton(
            '호출하기',
            key: const Key('nurse-call-send'),
            icon: Icons.notifications_active_rounded,
            height: 52,
            expand: true,
            onPressed: _reason.isEmpty ? null : _send,
          ),
        ]),
      ),
    );
  }
}
