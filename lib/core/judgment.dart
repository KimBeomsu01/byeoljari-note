// 판정 계산은 앱 전체에서 이 파일 하나만 쓴다 (통합 명세 5-2).
// 숫자는 [초안]: 간호사 확인 전까지 바뀔 수 있다.
import 'models.dart';

/// 입력 가능한 범위 (×10). 의료 기준이 아니라 입력 제한이다 (5-1).
const int minTemp = 340;
const int maxTemp = 420;

bool isValidTemp(int value) => value >= minTemp && value <= maxTemp;

/// 기저치 대비 차이와 절대 기준 중 더 심한 쪽을 판정으로 쓴다.
/// 판단 순서: 위험 → 이상 → 저온 → 주의 → 평소.
Judgment judge({required int value, required int baseline}) {
  final diff = value - baseline;
  final Stage stage;
  if (diff >= 15 || value >= 390) {
    stage = Stage.danger;
  } else if (diff >= 10 || value >= 380) {
    stage = Stage.abnormal;
  } else if (diff <= -10 || value <= 355) {
    stage = Stage.low;
  } else if (diff >= 5 || value >= 375) {
    stage = Stage.caution;
  } else {
    stage = Stage.normal;
  }
  return Judgment(stage: stage, baseline: baseline, diff: diff);
}

/// 화면 표시용: 365 → '36.5'
String formatTemp(int value) => (value / 10).toStringAsFixed(1);

/// 화면 표시용: 6 → '+0.6', -12 → '−1.2'
String formatDiff(int diff) {
  final sign = diff >= 0 ? '+' : '−';
  return '$sign${(diff.abs() / 10).toStringAsFixed(1)}';
}
