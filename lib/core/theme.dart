// 디자인 토큰 (통합 명세 5-4 판정 색, 퀵 체온 시제품 색).
import 'package:flutter/material.dart';

import 'models.dart';

class StageColors {
  const StageColors(this.ink, this.soft, this.line);
  final Color ink;
  final Color soft;
  final Color line;
}

const stageColors = <Stage, StageColors>{
  Stage.normal: StageColors(Color(0xFF4C7D62), Color(0xFFE9F3ED), Color(0xFF75AA8D)),
  Stage.caution: StageColors(Color(0xFF8A5D12), Color(0xFFFBF1DD), Color(0xFFD9A44E)),
  Stage.abnormal: StageColors(Color(0xFF9A4F12), Color(0xFFFCEBDC), Color(0xFFD9853B)),
  Stage.danger: StageColors(Color(0xFFA8403F), Color(0xFFFBEAEA), Color(0xFFDC8584)),
  Stage.low: StageColors(Color(0xFF3F6EA0), Color(0xFFE8F0FA), Color(0xFF6A9ED5)),
};

/// 퀵 체온의 "기록 완료" 초록. 판정 색(평소)과 다른 색이다.
const Color recordedGreen = Color(0xFFCFE8CF);

const Color brandDark = Color(0xFF24543F);
const Color paper = Color(0xFFF6F4EC);
const Color inkMain = Color(0xFF26312B);
const Color inkSub = Color(0xFF6B7470);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: brandDark, surface: paper),
    scaffoldBackgroundColor: paper,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: inkMain, displayColor: inkMain),
  );
}
