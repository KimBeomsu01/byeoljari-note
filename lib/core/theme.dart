// 디자인 토큰 (docs/design.md). 판정 색은 통합 명세 5-4 [확정] 그대로.
// 대상: 40~60대 생활관 선생님. 바쁜 근무 중 한 손으로, 돋보기 없이 읽혀야 한다.
import 'package:flutter/material.dart';

import 'models.dart';

class StageColors {
  const StageColors(this.ink, this.soft, this.line);
  final Color ink;
  final Color soft;
  final Color line;
}

const stageColors = <Stage, StageColors>{
  Stage.normal: StageColors(Color(0xFF3F6E54), Color(0xFFE6F2EA), Color(0xFF75AA8D)),
  Stage.caution: StageColors(Color(0xFF7A500E), Color(0xFFFBF0D9), Color(0xFFD9A44E)),
  Stage.abnormal: StageColors(Color(0xFF8F4610), Color(0xFFFCE8D6), Color(0xFFD9853B)),
  Stage.danger: StageColors(Color(0xFF9E3534), Color(0xFFFBE6E6), Color(0xFFDC8584)),
  Stage.low: StageColors(Color(0xFF345F8F), Color(0xFFE6EFFA), Color(0xFF6A9ED5)),
};

// ── 색 (이름은 예전 코드와 맞춰 두고 값만 바꿨다)
/// 밤하늘 남색: 주 버튼, 선택된 탭, 링크.
const Color brandDark = Color(0xFF1E3A66);

/// 새벽 하늘 바탕. 카드(흰색)와 구분된다.
const Color paper = Color(0xFFEEF2F7);

/// 카드·시트 바탕.
const Color surface = Color(0xFFFFFFFF);

/// 본문 글자. 흰 바탕 대비 약 15:1.
const Color inkMain = Color(0xFF142033);

/// 보조 글자. 흰 바탕 대비 약 9:1 — 옅은 회색 글자는 쓰지 않는다.
const Color inkSub = Color(0xFF3D4A5C);

/// 테두리·구분선.
const Color line = Color(0xFFC6D0DC);

/// 별빛 노랑: 앱에서 딱 한 곳, 가운데 '체온 재기' 버튼과 '새 기록' 점에만 쓴다.
const Color starYellow = Color(0xFFF5C518);

/// 퀵 체온의 "기록 완료" 초록. 판정 색(평소)과 다른 색이다.
const Color recordedGreen = Color(0xFFCFE8CF);

// ── 글자 크기 (최소 15)
class T {
  static const double caption = 15; // 시각, 작성자 같은 보조 정보
  static const double body = 17; // 본문, 버튼
  static const double title = 20; // 카드 제목, 별님 이름
  static const double headline = 24; // 화면 제목
  static const double number = 32; // 요약 숫자
  static const double display = 52; // 체온 숫자
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
  static const double card = 16; // 카드·시트
  static const double button = 14; // 버튼
  static const double pill = 999; // 상태 표시
}

/// 모든 누르는 것의 최소 높이.
const double tapHeight = 56;

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
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: inkMain,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
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
        side: const BorderSide(color: brandDark, width: 1.5),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
