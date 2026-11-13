// 할 일 완료 동작 (첫 화면 '이어받은 할 일'과 기록 카드 [완료하기]가 같이 쓴다).
// 체온 할 일은 퀵 체온으로 (저장하면 저절로 완료), 메모 할 일은 "완료할까요?" 확인 시트.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../quick_temp/quick_temp_controller.dart';
import 'handover_common.dart';

/// 퀵 체온을 그 별님으로 연다. 퀵 체온은 앱 공통 틀 위의 레이어라, 쌓인 화면을 먼저 닫는다.
void openQuickTempFor(BuildContext context, WidgetRef ref, String residentId) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  ref.read(quickTempProvider.notifier).openFor(residentId);
}

/// 메모 할 일 완료: 확인 시트 → 완료 + 토스트. 완료했으면 true.
Future<bool> confirmCompleteTask(BuildContext context, WidgetRef ref, Entry entry, {VoidCallback? beforeComplete}) async {
  final t = entry.task!;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (s) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '완료할까요?',
              style: TextStyle(fontSize: T.title, fontWeight: FontWeight.w800, color: inkMain),
            ),
            const SizedBox(height: Gap.s),
            Text('할 일: ${t.label}', style: const TextStyle(fontSize: T.body, color: inkMain)),
            const SizedBox(height: Gap.xl),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(s, false), child: const Text('취소'))),
                const SizedBox(width: Gap.s),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(s, true), child: const Text('완료했어요'))),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  beforeComplete?.call();
  ref.read(repoProvider).completeTask(entry.id, ref.read(currentUserProvider), ref.read(clockProvider)());
  showToast(context, '${t.label} 완료');
  return true;
}
