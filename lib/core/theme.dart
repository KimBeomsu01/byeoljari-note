// 디자인 토큰 (docs/design.md). 팀 시제품(인수인계 명세 13장)의 색·모양 + 중장년용으로 키운 글자.
// 판정 색은 통합 명세 5-4 [확정] 그대로.
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

// ── 색 (이름은 예전 코드와 맞춰 두고 값만 바꿨다)
/// 짙은 녹회색: 주 버튼, 선택된 탭, 퀵 체온 버튼, 요약 카드.
const Color brandDark = Color(0xFF2F3A34);

/// 따뜻한 미색 바탕.
const Color paper = Color(0xFFF7F7F2);

/// 카드·시트 바탕.
const Color surface = Color(0xFFFFFFFF);

/// 본문 글자.
const Color inkMain = Color(0xFF2B2F2C);

/// 보조 글자 (시제품의 진한 쪽 보조색). 이보다 옅은 회색은 쓰지 않는다.
const Color inkSub = Color(0xFF4D554F);

/// 카드 테두리·구분선.
const Color line = Color(0xFFE2E6E0);

/// 미확인·새 기록 표시 (시제품 미확인 배지).
const Color starYellow = Color(0xFFD9A44E);

/// 연한 녹색 면 (퀵 체온 바탕, 선택된 칩 등).
const Color sage = Color(0xFFE9F0E6);

/// 퀵 체온의 "기록 완료" 초록. 판정 색(평소)과 다른 색이다.
const Color recordedGreen = Color(0xFFCFE8CF);

// ── 글자 크기: 시제품(12~14)보다 한 단계씩 크게, 최소 14
class T {
  static const double caption = 14; // 시각, 작성자 같은 보조 정보
  static const double body = 16; // 본문, 버튼
  static const double title = 19; // 카드 제목, 별님 이름
  static const double headline = 24; // 화면 제목
  static const double number = 28; // 요약 숫자
  static const double display = 46; // 체온 숫자
}

// ── 간격·모양
class Gap {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double page = 20; // 화면 좌우 여백
}

class Radii {
  static const double card = 13; // 카드 (시제품)
  static const double sheet = 26; // 시트 위쪽
  static const double button = 12; // 버튼
  static const double pill = 999; // 상태 표시
}

/// 모든 누르는 것의 최소 높이 (시제품 40 → 앱 기준 44 이상, 넉넉하게 48).
const double tapHeight = 48;

/// [fontFamily]는 화면 확인용 스크린샷 테스트에서만 넘긴다. 앱은 기기 기본 글꼴을 쓴다.
ThemeData buildTheme({String? fontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandDark,
    primary: brandDark,
    onPrimary: Colors.white,
    surface: surface,
    onSurface: inkMain,
    onSurfaceVariant: inkSub,
    outline: line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: paper, fontFamily: fontFamily);
  final text = base.textTheme
      .copyWith(
        displaySmall: TextStyle(fontFamily: fontFamily, fontSize: T.display, fontWeight: FontWeight.w600, height: 1.1),
        headlineSmall: TextStyle(fontFamily: fontFamily, fontSize: T.headline, fontWeight: FontWeight.w700, height: 1.3),
        titleLarge: TextStyle(fontFamily: fontFamily, fontSize: T.title, fontWeight: FontWeight.w700, height: 1.35),
        titleMedium: TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w700, height: 1.4),
        titleSmall: TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w600, height: 1.4),
        bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: T.body, height: 1.5),
        bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: T.body, height: 1.5),
        bodySmall: TextStyle(fontFamily: fontFamily, fontSize: T.caption, height: 1.45),
        labelLarge: TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontFamily: fontFamily, fontSize: T.caption, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(fontFamily: fontFamily, fontSize: T.caption, fontWeight: FontWeight.w600),
      )
      .apply(bodyColor: inkMain, displayColor: inkMain, fontFamily: fontFamily);

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button));
  final buttonText = TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w700);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: inkMain,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: T.headline, fontWeight: FontWeight.w800, color: inkMain),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(tapHeight, tapHeight),
        padding: buttonPadding,
        textStyle: buttonText,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(tapHeight, tapHeight),
        padding: buttonPadding,
        textStyle: buttonText,
        foregroundColor: brandDark,
        side: const BorderSide(color: line, width: 1.5),
        shape: buttonShape,
        backgroundColor: surface,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: buttonText,
        foregroundColor: brandDark,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      side: const BorderSide(color: line, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      backgroundColor: surface,
      selectedColor: brandDark,
      secondarySelectedColor: brandDark,
      secondaryLabelStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w700, color: Colors.white),
      checkmarkColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: line),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w600, color: inkMain),
      subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: T.caption, color: inkSub, height: 1.45),
      leadingAndTrailingTextStyle: TextStyle(fontFamily: fontFamily, fontSize: T.caption, color: inkSub),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, color: inkSub),
      labelStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, color: inkSub),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button), borderSide: const BorderSide(color: line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button), borderSide: const BorderSide(color: line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button), borderSide: const BorderSide(color: brandDark, width: 2)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: T.title, fontWeight: FontWeight.w700, color: inkMain),
      contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, color: inkMain, height: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: inkMain,
      contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, color: Colors.white, height: 1.4),
      insetPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(tapHeight, 52),
        textStyle: buttonText,
        selectedBackgroundColor: brandDark,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: line, width: 1.5),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: fontFamily, fontSize: T.body, fontWeight: FontWeight.w500),
      labelColor: brandDark,
      unselectedLabelColor: inkSub,
      indicatorColor: brandDark,
    ),
  );
}
