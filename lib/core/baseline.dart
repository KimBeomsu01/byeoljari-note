// 기저치 계산 (통합 명세 5-3).
import 'models.dart';

const int defaultBaseline = 365;
const int baselineMinRecords = 10;
const Duration baselineWindow = Duration(days: 14);

enum BaselineSource { manual, median, provisional }

class BaselineResult {
  const BaselineResult(this.value, this.source, this.count);
  final int value;
  final BaselineSource source;

  /// 계산에 쓴 측정 개수.
  final int count;

  /// 화면 문구. provisional이면 "기저치 계산 중 (기록 n/10)".
  String get note => switch (source) {
        BaselineSource.manual => '간호사 지정',
        BaselineSource.median => '최근 14일 중앙값',
        BaselineSource.provisional => '기저치 계산 중 (기록 $count/$baselineMinRecords)',
      };
}

/// [history]는 이 별님의 측정 전체. [now] 기준 최근 14일에서
/// 무효가 아니고 이상·위험·저온이 아닌 값의 중앙값을 쓴다.
BaselineResult computeBaseline({
  required Resident resident,
  required Iterable<Measurement> history,
  required DateTime now,
}) {
  final manual = resident.baselineManual;
  final from = now.subtract(baselineWindow);
  final values = history
      .where((m) =>
          m.residentId == resident.id &&
          !m.isVoided &&
          !m.judgment.stage.opensCase &&
          m.measuredAt.isAfter(from) &&
          !m.measuredAt.isAfter(now))
      .map((m) => m.value)
      .toList()
    ..sort();

  if (manual != null) return BaselineResult(manual, BaselineSource.manual, values.length);
  if (values.length < baselineMinRecords) {
    return BaselineResult(defaultBaseline, BaselineSource.provisional, values.length);
  }
  final mid = values.length ~/ 2;
  final median = values.length.isOdd
      ? values[mid]
      : ((values[mid - 1] + values[mid]) / 2).round();
  return BaselineResult(median, BaselineSource.median, values.length);
}
