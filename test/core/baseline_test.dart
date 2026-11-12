import 'package:byeoljari_note/core/baseline.dart';
import 'package:byeoljari_note/core/judgment.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 28, 9, 41);
const r = Resident(id: 'R1', classId: 'C1', name: '테스트', order: 0);

Measurement m(int value, {int daysAgo = 1, Stage? stage, bool voided = false, String rid = 'R1'}) =>
    Measurement(
      id: 'M$value-$daysAgo',
      residentId: rid,
      classId: 'C1',
      value: value,
      measuredAt: now.subtract(Duration(days: daysAgo)),
      recordedBy: 'S1',
      judgment: Judgment(stage: stage ?? judge(value: value, baseline: 365).stage, baseline: 365, diff: 0),
      voidedAt: voided ? now : null,
    );

void main() {
  test('기록 10개 미만이면 36.5 임시값 + 계산 중 표시', () {
    final b = computeBaseline(resident: r, history: List.generate(9, (i) => m(368, daysAgo: i + 1)), now: now);
    expect(b.value, 365);
    expect(b.source, BaselineSource.provisional);
    expect(b.note, '기저치 계산 중 (기록 9/10)');
  });

  test('10개 이상이면 중앙값 (짝수 개는 가운데 둘 평균)', () {
    final vals = [362, 363, 364, 365, 366, 367, 368, 369, 370, 371];
    final b = computeBaseline(resident: r, history: [for (var i = 0; i < 10; i++) m(vals[i], daysAgo: i + 1)], now: now);
    expect(b.source, BaselineSource.median);
    expect(b.value, 367); // (366+367)/2 = 366.5 → 367
  });

  test('14일보다 오래된 값, 무효 값, 이상·위험·저온 값, 다른 별님 값은 뺀다', () {
    final history = [
      for (var i = 0; i < 10; i++) m(366, daysAgo: i + 1),
      m(300 + 85, daysAgo: 2, stage: Stage.abnormal),
      m(372, daysAgo: 15),
      m(372, daysAgo: 3, voided: true),
      m(372, daysAgo: 3, rid: 'R2'),
    ];
    final b = computeBaseline(resident: r, history: history, now: now);
    expect(b.count, 10);
    expect(b.value, 366);
  });

  test('간호사 지정값이 있으면 항상 우선', () {
    const manual = Resident(id: 'R1', classId: 'C1', name: '테스트', order: 0, baselineManual: 371);
    final b = computeBaseline(resident: manual, history: [for (var i = 0; i < 12; i++) m(365, daysAgo: i + 1)], now: now);
    expect(b.value, 371);
    expect(b.source, BaselineSource.manual);
  });
}
