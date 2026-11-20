// PC 03·04 대화상자: 화상 진료 시각 고르기 · 투약 이력 · 전체 기록 · 인수인계장에 인용.
// 의료 내용은 의료진이 쓴 글을 그대로 보여주기만 한다 (앱은 용량을 계산하지 않는다).
import 'package:flutter/material.dart';

import '../../core/ds.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../core/theme.dart';
import 'pc_calls_common.dart';

/// 비대면 화상 진료 시각 고르기. 지금 다음 10분 단위부터 몇 가지 시각을 보여준다.
Future<DateTime?> pickVideoTime(BuildContext context, DateTime now, {DateTime? current}) {
  final base = DateTime(now.year, now.month, now.day, now.hour, now.minute - now.minute % 10).add(const Duration(minutes: 10));
  final options = [for (final m in const [0, 10, 20, 30, 60, 90]) base.add(Duration(minutes: m))];
  var picked = 0;
  return showDialog<DateTime>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: const Text('화상 진료 시각 고르기'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (current != null) ...[
              Text('지금 예약: ${relTime(current, now)}', style: mcText(13, weight: FontWeight.w600, color: Ds.blue500)),
              const SizedBox(height: 10),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < options.length; i++)
                DsChip(label: relTime(options[i], now), selected: picked == i, onTap: () => set(() => picked = i)),
            ]),
            const SizedBox(height: 14),
            Text('※ 본 웹사이트 내 직접 통화/화상 송수신 기능은 미지원되며, 요청 알림 연동 전용입니다.',
                style: mcText(12, color: Ds.gray500)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Ds.blue500),
            onPressed: () => Navigator.pop(d, options[picked]),
            child: const Text('예약 알림 보내기'),
          ),
        ],
      ),
    ),
  );
}

Widget _section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: mcText(13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...children,
      ]),
    );

Widget _plain(String? text, {String empty = '기록 없음'}) => Text(
      (text == null || text.trim().isEmpty) ? empty : text,
      style: mcText(12.5, color: (text == null || text.trim().isEmpty) ? Ds.gray500 : Ds.gray800),
    );

/// 투약 이력: 상시 복약 · 필요시 투약 지시 · 전자처방전 · 이상 대응 투약 기록.
Future<void> showMedicationHistory(BuildContext context, InMemoryRepository repo, String residentId) {
  final r = repo.resident(residentId);
  final now = repo.now();
  final rxs = repo.prescriptionsOf(residentId);
  final meds = [
    for (final c in repo.casesOf(residentId))
      for (final e in repo.eventsOf(c.id))
        if (e.type == 'medication' && e.voidedBy == null) e,
  ]..sort((a, b) => b.at.compareTo(a.at));

  return showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text('${r.name} 투약 이력'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('의료진이 쓴 글을 그대로 보여줘요. 앱은 투약 용량을 계산하지 않아요.', style: mcText(12, color: Ds.gray500)),
            _section('상시 복약', [_plain(r.regularMeds)]),
            _section('필요시 투약 지시', [_plain(r.prnNote)]),
            _section('전자처방전 ${rxs.length}건', [
              if (rxs.isEmpty) _plain(null, empty: '아직 처방전이 없어요'),
              for (final p in rxs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      RxStatusPill(p),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${p.code} ${p.codeName}'.trim(),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: mcText(12.5, weight: FontWeight.w700)),
                      ),
                      Text(
                          p.issued
                              ? '${p.number ?? ''} · ${relTime(p.issuedAt ?? p.updatedAt, now)}'
                              : '저장 ${relTime(p.updatedAt, now)}',
                          style: mcText(11.5, color: Ds.gray500, mono: true)),
                    ]),
                    const SizedBox(height: 6),
                    for (final i in p.items) Padding(padding: const EdgeInsets.only(bottom: 6), child: RxItemView(i)),
                    if (p.items.isEmpty) _plain(null, empty: '처방약 없음'),
                  ]),
                ),
            ]),
            _section('이상 대응 투약 기록 ${meds.length}건', [
              if (meds.isEmpty) _plain(null, empty: '투약 기록이 없어요'),
              for (final e in meds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 92, child: Text(relTime(e.at, now), style: mcText(12, color: Ds.gray500, mono: true))),
                    Expanded(
                      child: Text('${e.data['text'] ?? ''} · ${repo.staff(e.actorId).displayName}',
                          style: mcText(12.5, color: Ds.gray800)),
                    ),
                  ]),
                ),
            ]),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('닫기'))],
    ),
  );
}

/// 전체 의무기록: 명단의 의료 글 그대로 + 최근 14일 체온.
Future<void> showFullRecord(BuildContext context, InMemoryRepository repo, String residentId) {
  final r = repo.resident(residentId);
  final cls = repo.classOf(r.classId);
  final now = repo.now();
  final from = now.subtract(const Duration(days: 14));
  final ms = repo.measurementsOf(residentId).where((m) => m.measuredAt.isAfter(from)).toList();

  Widget kv(String k, String? v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(k, style: mcText(12, color: Ds.gray500))),
          Expanded(child: _plain(v)),
        ]),
      );

  return showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text('${r.name} 전체 기록'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            kv('반 · 호실', '${cls.name} ${cls.room ?? ''}'.trim()),
            kv('기록 번호', r.code),
            kv('성별 · 나이', sexAge(r).isEmpty ? null : sexAge(r).substring(1, sexAge(r).length - 1)),
            kv('주진단', r.diagnosis),
            kv('금기 · 주의', r.cautions),
            kv('상시 복약', r.regularMeds),
            kv('필요시 투약', r.prnNote),
            _section('최근 14일 체온 ${ms.length}회', [
              if (ms.isEmpty) _plain(null, empty: '체온 기록이 없어요'),
              for (final m in ms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    SizedBox(width: 110, child: Text(relTime(m.measuredAt, now), style: mcText(12, color: Ds.gray500, mono: true))),
                    SizedBox(
                      width: 64,
                      child: Text(fmtC(m.value),
                          style: mcText(12.5,
                              weight: FontWeight.w700,
                              mono: true,
                              color: m.isVoided ? Ds.gray400 : vitalColor(m.judgment.stage, m.judgment.diff))),
                    ),
                    Expanded(
                      child: Text(
                          m.isVoided
                              ? '무효 (${m.voidReason ?? '잘못 잰 값'})'
                              : '${m.judgment.stage.label} · 평소보다 ${fmtDiffDeg(m.judgment.diff)}',
                          style: mcText(12, color: Ds.gray600)),
                    ),
                  ]),
                ),
            ]),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('닫기'))],
    ),
  );
}

/// 인수인계장에 인용: 고칠 수 있는 글 상자. 남길 글을 돌려준다 (취소면 null).
Future<String?> askQuote(BuildContext context, String initial, String residentName) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('인수인계장에 인용'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('$residentName 별님 관찰 기록으로 인수인계에 남겨요.', style: mcText(12.5, color: Ds.gray600)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            minLines: 3,
            maxLines: 6,
            style: mcText(13),
            decoration: const InputDecoration(hintText: '남길 내용을 적어 주세요'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Ds.blue500),
          onPressed: () {
            final t = ctrl.text.trim();
            if (t.isNotEmpty) Navigator.pop(d, t);
          },
          child: const Text('인수인계에 남기기'),
        ),
      ],
    ),
  );
}

/// 처방전 발행 확인. 발행하면 고칠 수 없다.
Future<bool> confirmIssue(BuildContext context, {required String code, required String codeName, required List<RxItem> items}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('전자처방전을 발행할까요?'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('발행하면 고칠 수 없어요. 케어팀 대화에 발행 안내가 남아요.', style: mcText(13, color: Ds.gray700)),
          const SizedBox(height: 12),
          Text('$code $codeName', style: mcText(13, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final i in items)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: RxItemView(i, highlight: true)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Ds.blue500),
          onPressed: () => Navigator.pop(d, true),
          child: const Text('서명하고 발행'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
