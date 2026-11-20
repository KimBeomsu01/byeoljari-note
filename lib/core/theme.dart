// 디자인 토큰 — Claude Design "별자리노트" 캔버스의 tokens.css / tokens.json 값 그대로.
// 예전 이름(brandDark, inkMain …)은 다른 화면이 그대로 쓰도록 남겨 두고 값만 새 토큰으로 바꿨다.
import 'package:flutter/material.dart';

import 'models.dart';

// ── Color · Neutral
class Ds {
  static const bg = Color(0xFFF2F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF2F4F6);
  static const gray200 = Color(0xFFE5E8EB);
  static const gray300 = Color(0xFFD1D6DB);
  static const gray400 = Color(0xFFB0B8C1);
  static const gray500 = Color(0xFF8B95A1);
  static const gray600 = Color(0xFF6B7684);
  static const gray700 = Color(0xFF4E5968);
  static const gray800 = Color(0xFF333D4B);
  static const gray900 = Color(0xFF191F28);

  // ── Color · Brand / Status
  static const violet500 = Color(0xFF7C5CF0); // 주요 액션
  static const violet600 = Color(0xFF6A4BDF);
  static const violet50 = Color(0xFFF1EDFE);
  static const blue500 = Color(0xFF3182F6); // 정보 · 링크 · 보조 액션
  static const blue600 = Color(0xFF2563EB);
  static const blue50 = Color(0xFFE8F3FF);
  static const red500 = Color(0xFFF04452); // 긴급 · 체온 상승
  static const red50 = Color(0xFFFEECEE);
  static const red25 = Color(0xFFFFF5F5);
  static const green500 = Color(0xFF03B26C);
  static const green50 = Color(0xFFE8F9F1);
  static const orange500 = Color(0xFFFF8A00);
  static const orange50 = Color(0xFFFFF4E6);
  static const cyan500 = Color(0xFF00B8D9);
  static const cyan50 = Color(0xFFE6FCFF);

  // ── Alpha
  static const borderCard = Color(0x80E5E8EB);
  static const borderChip = Color(0xB3E5E8EB);
  static const borderDanger = Color(0x33F04452);
  static const borderInfo = Color(0x333182F6);

  // ── Elevation
  static const shadowSm = [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))];
  static const shadowBar = [BoxShadow(color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 1))];
  static const shadowTile = [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))];
  static const shadowCard = [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))];
  static const shadowFloat = [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))];
  static const shadowDial = [BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8))];
  static const shadowDanger = [BoxShadow(color: Color(0x0FF04452), blurRadius: 16, offset: Offset(0, 4))];
  static const shadowPrimary = [BoxShadow(color: Color(0x597C5CF0), blurRadius: 20, offset: Offset(0, 8))];

  /// 모바일 화면 폭 (최대 440).
  static const double screenMax = 440;
  static const double screenPad = 20;
}

/// 판정 색: 정상 = 초록, 주의 = 주황, 이상·위험 = 빨강, 저온 = 파랑.
class StageColors {
  const StageColors(this.ink, this.soft, this.line);
  final Color ink;
  final Color soft;
  final Color line;
}

const stageColors = <Stage, StageColors>{
  Stage.normal: StageColors(Ds.green500, Ds.green50, Color(0x6603B26C)),
  Stage.caution: StageColors(Color(0xFFE07A00), Ds.orange50, Color(0x66FF8A00)),
  Stage.abnormal: StageColors(Ds.red500, Ds.red50, Ds.borderDanger),
  Stage.danger: StageColors(Color(0xFFD62D3B), Ds.red50, Color(0x66F04452)),
  Stage.low: StageColors(Ds.blue500, Ds.blue50, Ds.borderInfo),
};

/// 평소 체온과의 차이 색: +0.5° 이상 빨강, −0.5° 이하 파랑, 그 사이 기본색 (README 표시 규칙).
Color diffColor(int diff) => diff >= 5 ? Ds.red500 : (diff <= -5 ? Ds.blue500 : Ds.gray900);

// ── 예전 이름 (다른 화면 호환). 값은 새 토큰.
const Color brandDark = Ds.violet500;
const Color paper = Ds.bg;
const Color coral = Ds.red500;
const Color navy = Ds.blue500;
const Color quickOrange = Ds.violet500;
const Color surface = Ds.surface;
const Color inkMain = Ds.gray900;
const Color inkSub = Ds.gray600;
const Color line = Ds.gray200;
const Color lineStrong = Ds.gray300;
const Color lineSoft = Ds.gray100;
const Color actionSoft = Ds.blue50;
const Color actionInk = Ds.blue500;
const Color alertSoft = Ds.red50;
const Color starYellow = Ds.orange500;
const Color sage = Ds.gray50;
const Color recordedGreen = Ds.green50;

// ── 글자 크기 (tokens.json font.scale)
class T {
  static const double micro = 11;
  static const double caption = 12;
  static const double label = 13;
  static const double body = 14;
  static const double bodyMd = 15;
  static const double bodyLg = 16;
  static const double heading = 18;
  static const double title = 20;
  static const double headline = 24;
  static const double number = 26;
  static const double display = 64;
}

// ── 간격 · 모양
class Gap {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double page = 20;
}

class Radii {
  static const double card = 24;
  static const double inner = 20;
  static const double sheet = 24;
  static const double button = 12;
  static const double tag = 6;
  static const double pill = 9999;
}

/// 누르는 것의 최소 높이 (터치 영역 44px).
const double tapHeight = 44;

/// 서체: Pretendard (Claude Design 지정).
const String fontSmall = 'Pretendard';
const String fontBig = 'Pretendard';

/// 기호용 대체 글꼴.
const List<String> symbolFallback = ['Apple SD Gothic Neo', 'Malgun Gothic', 'Noto Sans KR', 'Segoe UI Symbol', 'Apple Color Emoji', 'Noto Color Emoji'];

/// 숫자 고정폭 (tabular-nums).
const tabular = [FontFeature.tabularFigures()];

/// [fontFamily]를 넘기면 그 글꼴로 바꾼다 (테스트용).
ThemeData buildTheme({String? fontFamily}) {
  final family = fontFamily ?? fontSmall;
  final scheme = ColorScheme.fromSeed(
    seedColor: Ds.violet500,
    primary: Ds.violet500,
    onPrimary: Colors.white,
    secondary: Ds.blue500,
    surface: Ds.surface,
    onSurface: Ds.gray900,
    onSurfaceVariant: Ds.gray600,
    outline: Ds.gray200,
    error: Ds.red500,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Ds.bg,
    fontFamily: family,
    fontFamilyFallback: symbolFallback,
  );
  TextStyle s(double size, FontWeight w, {double? h}) => TextStyle(
      fontFamily: family, fontFamilyFallback: symbolFallback, fontSize: size, fontWeight: w, height: h, letterSpacing: -0.2);
  final text = base.textTheme
      .copyWith(
        displaySmall: s(T.display, FontWeight.w800, h: 1),
        headlineSmall: s(T.headline, FontWeight.w700, h: 1.33),
        titleLarge: s(T.title, FontWeight.w700, h: 1.4),
        titleMedium: s(T.bodyLg, FontWeight.w700, h: 1.5),
        titleSmall: s(T.body, FontWeight.w700, h: 1.43),
        bodyLarge: s(T.bodyMd, FontWeight.w500, h: 1.5),
        bodyMedium: s(T.body, FontWeight.w500, h: 1.43),
        bodySmall: s(T.caption, FontWeight.w500, h: 1.33),
        labelLarge: s(T.body, FontWeight.w600),
        labelMedium: s(T.caption, FontWeight.w600),
        labelSmall: s(T.micro, FontWeight.w600),
      )
      .apply(bodyColor: Ds.gray900, displayColor: Ds.gray900);

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button));
  final buttonText = s(T.body, FontWeight.w600);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Ds.bg,
      foregroundColor: Ds.gray900,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 56,
      titleTextStyle: s(T.title, FontWeight.w700).copyWith(color: Ds.gray900),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(tapHeight, tapHeight),
        padding: buttonPadding,
        textStyle: buttonText,
        shape: buttonShape,
        backgroundColor: Ds.violet500,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(tapHeight, tapHeight),
        padding: buttonPadding,
        textStyle: buttonText,
        shape: buttonShape,
        elevation: 0,
        backgroundColor: Ds.gray100,
        foregroundColor: Ds.gray800,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(tapHeight, tapHeight),
        padding: buttonPadding,
        textStyle: buttonText,
        foregroundColor: Ds.gray800,
        side: const BorderSide(color: Ds.gray200),
        shape: buttonShape,
        backgroundColor: Ds.surface,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(tapHeight, tapHeight),
        textStyle: buttonText,
        foregroundColor: Ds.blue500,
        shape: buttonShape,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: s(T.caption, FontWeight.w500).copyWith(color: Ds.gray700),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      side: const BorderSide(color: Ds.borderChip),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      backgroundColor: Ds.surface,
      selectedColor: Ds.gray900,
      secondarySelectedColor: Ds.gray900,
      secondaryLabelStyle: s(T.caption, FontWeight.w600).copyWith(color: Colors.white),
      checkmarkColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: Ds.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: Ds.borderCard),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      titleTextStyle: s(T.body, FontWeight.w600).copyWith(color: Ds.gray900),
      subtitleTextStyle: s(T.caption, FontWeight.w500).copyWith(color: Ds.gray600, height: 1.45),
      leadingAndTrailingTextStyle: s(T.caption, FontWeight.w500).copyWith(color: Ds.gray600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Ds.gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: s(T.body, FontWeight.w500).copyWith(color: Ds.gray500),
      labelStyle: s(T.body, FontWeight.w500).copyWith(color: Ds.gray600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button), borderSide: const BorderSide(color: Ds.gray200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button), borderSide: const BorderSide(color: Ds.gray200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button), borderSide: const BorderSide(color: Ds.blue500, width: 1.5)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Ds.surface,
      showDragHandle: true,
      dragHandleColor: Ds.gray300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Ds.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      titleTextStyle: s(T.heading, FontWeight.w700).copyWith(color: Ds.gray900),
      contentTextStyle: s(T.body, FontWeight.w500).copyWith(color: Ds.gray700, height: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Ds.gray900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
      contentTextStyle: s(T.body, FontWeight.w600).copyWith(color: Colors.white, height: 1.4),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    dividerTheme: const DividerThemeData(color: Ds.gray100, thickness: 1, space: 1),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(tapHeight, tapHeight),
        textStyle: buttonText,
        selectedBackgroundColor: Ds.gray900,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: Ds.gray200),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: s(T.body, FontWeight.w700),
      unselectedLabelStyle: s(T.body, FontWeight.w500),
      labelColor: Ds.gray900,
      unselectedLabelColor: Ds.gray500,
      indicatorColor: Ds.gray900,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Ds.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: s(T.body, FontWeight.w500).copyWith(color: Ds.gray900),
    ),
  );
}
