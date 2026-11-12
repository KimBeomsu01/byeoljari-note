import 'package:byeoljari_note/core/judgment.dart';
import 'package:byeoljari_note/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Stage s(int value, int baseline) => judge(value: value, baseline: baseline).stage;

void main() {
  group('절대 기준 경계 (기저치 영향 없게)', () {
    test('37.4 평소 / 37.5 주의', () {
      expect(s(374, 372), Stage.normal);
      expect(s(375, 372), Stage.caution);
    });
    test('37.9 주의 / 38.0 이상', () {
      expect(s(379, 375), Stage.caution);
      expect(s(380, 375), Stage.abnormal);
    });
    test('38.9 이상 / 39.0 위험', () {
      expect(s(389, 380), Stage.abnormal);
      expect(s(390, 380), Stage.danger);
    });
    test('35.6 평소 / 35.5 저온', () {
      expect(s(356, 362), Stage.normal);
      expect(s(355, 362), Stage.low);
    });
  });

  group('기저치 대비 경계 (기저치 36.0)', () {
    test('+0.4 평소 / +0.5 주의', () {
      expect(s(364, 360), Stage.normal);
      expect(s(365, 360), Stage.caution);
    });
    test('+0.9 주의 / +1.0 이상', () {
      expect(s(369, 360), Stage.caution);
      expect(s(370, 360), Stage.abnormal);
    });
    test('+1.4 이상 / +1.5 위험', () {
      expect(s(374, 360), Stage.abnormal);
      expect(s(375, 360), Stage.danger);
    });
    test('−0.9 평소 / −1.0 저온', () {
      expect(s(361, 370), Stage.normal);
      expect(s(360, 370), Stage.low);
    });
  });

  test('더 심한 쪽을 쓴다: 평소 37.1 별님의 37.6은 주의, 38.4는 이상, 39.1은 위험', () {
    expect(s(376, 371), Stage.caution);
    expect(s(384, 371), Stage.abnormal);
    expect(s(391, 371), Stage.danger);
  });

  test('판정에 당시 기저치와 차이를 함께 남긴다', () {
    final j = judge(value: 382, baseline: 368);
    expect(j.baseline, 368);
    expect(j.diff, 14);
    expect(j.stage, Stage.abnormal);
  });

  test('입력 범위 34.0~42.0', () {
    expect(isValidTemp(339), isFalse);
    expect(isValidTemp(340), isTrue);
    expect(isValidTemp(420), isTrue);
    expect(isValidTemp(421), isFalse);
  });

  test('표시 형식', () {
    expect(formatTemp(365), '36.5');
    expect(formatDiff(6), '+0.6');
    expect(formatDiff(-12), '−1.2');
  });
}
