import 'dart:async';
import 'dart:convert' as conv;
import 'package:flutter/material.dart';
import 'package:jupiter/API/api_coms.dart';
import 'package:jupiter/storage.dart';
import 'package:provider/provider.dart';
import 'Pages/startup_page.dart';
import 'main.dart';

class AppPalette {
  final String paletteName;
  final bool basedOnDark;

  final Color primary;
  final Color onPrimary;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color onSecondaryContainer;
  final Color grade1;
  final Color grade2;
  final Color grade3;
  final Color grade4;
  final Color grade5;

  final Color navbarNavibarColor;
  final Color navbarStatusBarColor;

  final Color rootBackground;
  final Color textColor;

  final Color buttonEnabled;
  final Color buttonDisabled;

  final Color errorRed;

  final Color currentClassGreen;

  final Color roomHighlightColor;
  final Color onRoomHighlightColor;

  bool get isDark => basedOnDark;

  const AppPalette(
    this.paletteName, {
    required this.basedOnDark,
    required this.currentClassGreen,
    required this.errorRed,
    required this.buttonDisabled,
    required this.buttonEnabled,
    required this.textColor,
    required this.rootBackground,
    required this.navbarNavibarColor,
    required this.navbarStatusBarColor,
    required this.primary,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.onSecondaryContainer,
    required this.grade1,
    required this.grade2,
    required this.grade3,
    required this.grade4,
    required this.grade5,
    this.roomHighlightColor = const Color(0xFFFFA726),
    this.onRoomHighlightColor = const Color(0xFF000000),
  });

  /// Calculates a vibrant complementary accent color following print design color theory.
  /// Uses (Hue + 180°) % 360° with boosted saturation for sticker-like punchiness and readability.
  static Color calculateComplementaryRoomHighlight(Color baseColor, bool basedOnDark) {
    final hsl = HSLColor.fromColor(baseColor);
    final compHue = (hsl.hue + 180.0) % 360.0;
    final double sat = (hsl.saturation * 1.35).clamp(0.75, 1.0);
    final double light = basedOnDark ? 0.58 : 0.45;
    return HSLColor.fromAHSL(1.0, compHue, sat, light).toColor();
  }

  /// Calculates high-contrast text color (dark charcoal or crisp white) based on background luminance.
  static Color getContrastingTextColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.45 ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  }

  static AppPalette fromJson(String json, VoidCallback onColorOutdated) {
    AppPalette decodedColorPack;
    try {
      final color = conv.json.decode(json);
      final basePrimary = Color(color['primary']);
      final bool isDark = color['basedOnDark'] ?? false;
      final Color roomHigh = color['roomHighlightColor'] != null
          ? Color(color['roomHighlightColor'])
          : calculateComplementaryRoomHighlight(basePrimary, isDark);
      final Color onRoomHigh = color['onRoomHighlightColor'] != null
          ? Color(color['onRoomHighlightColor'])
          : getContrastingTextColor(roomHigh);

      decodedColorPack = AppPalette(
        color['paletteName'],
        primary: basePrimary,
        onPrimary: Color(color['onPrimary']),
        onPrimaryContainer: Color(color['onPrimaryContainer']),
        secondary: Color(color['secondary']),
        onSecondary: Color(color['secondary']),
        onSecondaryContainer: Color(color['onSecondaryContainer']),
        grade1: Color(color['grade1']),
        grade2: Color(color['grade2']),
        grade3: Color(color['grade3']),
        grade4: Color(color['grade4']),
        grade5: Color(color['grade5']),
        navbarNavibarColor: Color(color['navbarNavibarColor']),
        navbarStatusBarColor: Color(color['navbarStatusBarColor']),
        rootBackground: Color(color['rootBackground']),
        textColor: Color(color['textColor']),
        buttonDisabled: Color(color['buttonDisabled']),
        buttonEnabled: Color(color['buttonEnabled']),
        errorRed: Color(color['errorRed']),
        currentClassGreen: Color(color['currentClassGreen']),
        basedOnDark: isDark,
        roomHighlightColor: roomHigh,
        onRoomHighlightColor: onRoomHigh,
      );
      for (var item in AppColors._downloadedAppColors) {
        if (item.paletteName == decodedColorPack.paletteName) {
          AppColors._downloadedAppColors.removeAt(AppColors._downloadedAppColors.indexOf(item));
          break;
        }
      }
      AppColors._downloadedAppColors.add(decodedColorPack);
    } catch (error) {
      Future.delayed(Duration.zero, () {
        onColorOutdated();
      });
      return AppColors.getTheme();
    }
    return decodedColorPack;
  }

  static String toJson(AppPalette palette) {
    final json = conv.json.encode({
      'paletteName': palette.paletteName,
      'primary': palette.primary.toARGB32(),
      'onPrimary': palette.onPrimary.toARGB32(),
      'onPrimaryContainer': palette.onPrimaryContainer.toARGB32(),
      'secondary': palette.secondary.toARGB32(),
      'onSecondary': palette.onSecondary.toARGB32(),
      'onSecondaryContainer': palette.onSecondaryContainer.toARGB32(),
      'grade1': palette.grade1.toARGB32(),
      'grade2': palette.grade2.toARGB32(),
      'grade3': palette.grade3.toARGB32(),
      'grade4': palette.grade4.toARGB32(),
      'grade5': palette.grade5.toARGB32(),
      'navbarNavibarColor': palette.navbarNavibarColor.toARGB32(),
      'navbarStatusBarColor': palette.navbarStatusBarColor.toARGB32(),
      'rootBackground': palette.rootBackground.toARGB32(),
      'textColor': palette.textColor.toARGB32(),
      'buttonEnabled': palette.buttonEnabled.toARGB32(),
      'buttonDisabled': palette.buttonDisabled.toARGB32(),
      'errorRed': palette.errorRed.toARGB32(),
      'currentClassGreen': palette.currentClassGreen.toARGB32(),
      'roomHighlightColor': palette.roomHighlightColor.toARGB32(),
      'onRoomHighlightColor': palette.onRoomHighlightColor.toARGB32(),
      'basedOnDark': palette.basedOnDark
    });
    return json;
  }
}

class AppColors {
  static bool _hasInit = false;
  static final List<AppPalette> _appColors = [];
  static final List<AppPalette> _downloadedAppColors = [];
  static int _themeBatchSelectedIdx = 0;

  static final List<VoidCallback> _onThemeChangeCallbacks = [];
  static void clearThemeChangeCallbacks() {
    _onThemeChangeCallbacks.clear();
  }

  static void subThemeChangeCallback(VoidCallback callback) {
    _onThemeChangeCallbacks.add(callback);
  }

  static bool _isDark = false;

  static bool isDarktheme() {
    if (_themeBatchSelectedIdx == -1) {
      return _isDark;
    }
    return getAllThemes()[_themeBatchSelectedIdx].basedOnDark;
  }

  static void initialize() {
    if (_hasInit) {
      return;
    }
    _appColors.add(AppPalette('Light',
        primary: const Color.fromRGBO(0x6C, 0x8F, 0x96, 1.0),
        onPrimary: const Color.fromRGBO(0x00, 0x00, 0x00, 1.0),
        onPrimaryContainer: const Color.fromRGBO(0x45, 0x6C, 0x76, 1.0),
        secondary: const Color.fromRGBO(0xA7, 0xC4, 0xC8, 1.0),
        onSecondary: const Color.fromRGBO(0x1B, 0x1B, 0x1B, 1.0),
        onSecondaryContainer: const Color.fromRGBO(0x6C, 0x8F, 0x96, 1.0),
        grade1: const Color.fromRGBO(0xBD, 0x2E, 0x2E, 1.0),
        grade2: const Color.fromRGBO(0x95, 0x51, 0x51, 1.0),
        grade3: const Color.fromRGBO(0x9E, 0x97, 0x54, 1.0),
        grade4: const Color.fromRGBO(0x72, 0x88, 0x5A, 1.0),
        grade5: const Color.fromRGBO(0x56, 0x7B, 0x58, 1.0),
        navbarStatusBarColor: const Color.fromRGBO(0xF0, 0xF0, 0xF0, 1.0),
        navbarNavibarColor: const Color.fromRGBO(0xE0, 0xE0, 0xE0, 1.0),
        rootBackground: const Color.fromRGBO(0xE2, 0xE2, 0xE2, 1.0),
        textColor: const Color.fromRGBO(0x00, 0x00, 0x00, 1.0),
        buttonEnabled: const Color.fromRGBO(0xA7, 0xC4, 0xC8, 1.0),
        buttonDisabled: const Color.fromRGBO(0xD3, 0xDD, 0xDD, 1.0),
        errorRed: const Color.fromRGBO(0xFF, 0x52, 0x52, 1.0),
        currentClassGreen: const Color.fromRGBO(0x46, 0x97, 0x32, 1.0),
        roomHighlightColor: const Color(0xFFD96B27),
        onRoomHighlightColor: const Color(0xFFFFFFFF),
        basedOnDark: false));

    _appColors.add(AppPalette('Dark',
        primary: const Color.fromRGBO(0x6C, 0x8F, 0x96, 1.0),
        onPrimary: const Color.fromRGBO(0xFF, 0xFF, 0xFF, 1.0),
        onPrimaryContainer: const Color.fromRGBO(0x8A, 0xB6, 0xBF, 1.0),
        secondary: const Color.fromRGBO(0x4F, 0x69, 0x6E, 1.0),
        onSecondary: const Color.fromRGBO(0xB6, 0xB6, 0xB6, 1.0),
        onSecondaryContainer: const Color.fromRGBO(0x6C, 0x8F, 0x96, 1.0),
        grade1: const Color.fromRGBO(0xFF, 0x52, 0x52, 1.0),
        grade2: const Color.fromRGBO(0xEF, 0x9A, 0x9A, 1.0),
        grade3: const Color.fromRGBO(0xFF, 0xF5, 0x9D, 1.0),
        grade4: const Color.fromRGBO(0xC5, 0xE1, 0xA5, 1.0),
        grade5: const Color.fromRGBO(0xA5, 0xD6, 0xA7, 1.0),
        navbarStatusBarColor: const Color.fromRGBO(0x0C, 0x0C, 0x0C, 1.0),
        navbarNavibarColor: const Color.fromRGBO(0x1A, 0x1A, 0x1A, 1.0),
        rootBackground: const Color.fromRGBO(0x22, 0x22, 0x22, 1.0),
        textColor: const Color.fromRGBO(0xFF, 0xFF, 0xFF, 1.0),
        buttonEnabled: const Color.fromRGBO(0x31, 0x42, 0x42, 1.0),
        buttonDisabled: const Color.fromRGBO(0x22, 0x2B, 0x2B, 1.0),
        errorRed: const Color.fromRGBO(0xFF, 0xB0, 0xB0, 1.0),
        currentClassGreen: const Color.fromRGBO(0x8B, 0xD4, 0x81, 1.0),
        roomHighlightColor: const Color(0xFFFFA726),
        onRoomHighlightColor: const Color(0xFF140B00),
        basedOnDark: true));

    _appColors.add(AppPalette('AMOLED Black',
        primary: const Color(0xFF00ADB5),
        onPrimary: const Color(0xFF000000),
        onPrimaryContainer: const Color(0xFF00ADB5),
        secondary: const Color(0xFF222831),
        onSecondary: const Color(0xFFEEEEEE),
        onSecondaryContainer: const Color(0xFF00ADB5),
        grade1: const Color(0xFFFF5252),
        grade2: const Color(0xFFEF9A9A),
        grade3: const Color(0xFFFFF59D),
        grade4: const Color(0xFFC5E1A5),
        grade5: const Color(0xFFA5D6A7),
        navbarStatusBarColor: const Color(0xFF000000),
        navbarNavibarColor: const Color(0xFF000000),
        rootBackground: const Color(0xFF000000),
        textColor: const Color(0xFFFFFFFF),
        buttonEnabled: const Color(0xFF1E2A2C),
        buttonDisabled: const Color(0xFF121819),
        errorRed: const Color(0xFFFFB0B0),
        currentClassGreen: const Color(0xFF00E676),
        roomHighlightColor: const Color(0xFFFF6B35),
        onRoomHighlightColor: const Color(0xFF000000),
        basedOnDark: true));

    _appColors.add(AppPalette('Midnight Ocean',
        primary: const Color(0xFF48CAE4),
        onPrimary: const Color(0xFF03045E),
        onPrimaryContainer: const Color(0xFF90E0EF),
        secondary: const Color(0xFF1C2541),
        onSecondary: const Color(0xFFE0E1DD),
        onSecondaryContainer: const Color(0xFF48CAE4),
        grade1: const Color(0xFFFF5252),
        grade2: const Color(0xFFEF9A9A),
        grade3: const Color(0xFFFFF59D),
        grade4: const Color(0xFFC5E1A5),
        grade5: const Color(0xFFA5D6A7),
        navbarStatusBarColor: const Color(0xFF070B1A),
        navbarNavibarColor: const Color(0xFF070B1A),
        rootBackground: const Color(0xFF0B132B),
        textColor: const Color(0xFFFFFFFF),
        buttonEnabled: const Color(0xFF1C2D4D),
        buttonDisabled: const Color(0xFF121B2E),
        errorRed: const Color(0xFFFF8FA3),
        currentClassGreen: const Color(0xFF00F5D4),
        roomHighlightColor: const Color(0xFFFFB703),
        onRoomHighlightColor: const Color(0xFF1A1000),
        basedOnDark: true));

    _appColors.add(AppPalette('Emerald Forest',
        primary: const Color(0xFF52B788),
        onPrimary: const Color(0xFF081C15),
        onPrimaryContainer: const Color(0xFF74C69D),
        secondary: const Color(0xFF1B382B),
        onSecondary: const Color(0xFFD8F3DC),
        onSecondaryContainer: const Color(0xFF52B788),
        grade1: const Color(0xFFFF5252),
        grade2: const Color(0xFFEF9A9A),
        grade3: const Color(0xFFFFF59D),
        grade4: const Color(0xFFC5E1A5),
        grade5: const Color(0xFFA5D6A7),
        navbarStatusBarColor: const Color(0xFF0A1410),
        navbarNavibarColor: const Color(0xFF0A1410),
        rootBackground: const Color(0xFF0F1E17),
        textColor: const Color(0xFFFFFFFF),
        buttonEnabled: const Color(0xFF234435),
        buttonDisabled: const Color(0xFF152A21),
        errorRed: const Color(0xFFFF85A1),
        currentClassGreen: const Color(0xFF40916C),
        roomHighlightColor: const Color(0xFFFF3366),
        onRoomHighlightColor: const Color(0xFFFFFFFF),
        basedOnDark: true));

    _appColors.add(AppPalette('Sunset Amber',
        primary: const Color(0xFFE76F51),
        onPrimary: const Color(0xFF26130B),
        onPrimaryContainer: const Color(0xFFF4A261),
        secondary: const Color(0xFF33231D),
        onSecondary: const Color(0xFFFAEDCD),
        onSecondaryContainer: const Color(0xFFE76F51),
        grade1: const Color(0xFFFF5252),
        grade2: const Color(0xFFEF9A9A),
        grade3: const Color(0xFFFFF59D),
        grade4: const Color(0xFFC5E1A5),
        grade5: const Color(0xFFA5D6A7),
        navbarStatusBarColor: const Color(0xFF140F0D),
        navbarNavibarColor: const Color(0xFF140F0D),
        rootBackground: const Color(0xFF1E1714),
        textColor: const Color(0xFFFFFFFF),
        buttonEnabled: const Color(0xFF442D24),
        buttonDisabled: const Color(0xFF291B16),
        errorRed: const Color(0xFFFF6B6B),
        currentClassGreen: const Color(0xFF2A9D8F),
        roomHighlightColor: const Color(0xFF00C9A7),
        onRoomHighlightColor: const Color(0xFF00241E),
        basedOnDark: true));

    _appColors.add(AppPalette('Cyberpunk Violet',
        primary: const Color(0xFFB5179E),
        onPrimary: const Color(0xFFFFFFFF),
        onPrimaryContainer: const Color(0xFFF72585),
        secondary: const Color(0xFF271B4D),
        onSecondary: const Color(0xFFE2D9F3),
        onSecondaryContainer: const Color(0xFF7209B7),
        grade1: const Color(0xFFFF5252),
        grade2: const Color(0xFFEF9A9A),
        grade3: const Color(0xFFFFF59D),
        grade4: const Color(0xFFC5E1A5),
        grade5: const Color(0xFFA5D6A7),
        navbarStatusBarColor: const Color(0xFF0C091D),
        navbarNavibarColor: const Color(0xFF0C091D),
        rootBackground: const Color(0xFF140F2D),
        textColor: const Color(0xFFFFFFFF),
        buttonEnabled: const Color(0xFF3C2370),
        buttonDisabled: const Color(0xFF231442),
        errorRed: const Color(0xFFFF4D6D),
        currentClassGreen: const Color(0xFF4CC9F0),
        roomHighlightColor: const Color(0xFF00F5A0),
        onRoomHighlightColor: const Color(0xFF021F13),
        basedOnDark: true));

    _appColors.add(AppPalette('Neptun Dark',
        primary: const Color(0xFF00D285),
        onPrimary: const Color(0xFF061812),
        onPrimaryContainer: const Color(0xFF00F5A0),
        secondary: const Color(0xFF162E51),
        onSecondary: const Color(0xFFE2EAF4),
        onSecondaryContainer: const Color(0xFF2F70F2),
        grade1: const Color(0xFFFF5252),
        grade2: const Color(0xFFEF9A9A),
        grade3: const Color(0xFFFFF59D),
        grade4: const Color(0xFFC5E1A5),
        grade5: const Color(0xFFA5D6A7),
        navbarStatusBarColor: const Color(0xFF070E18),
        navbarNavibarColor: const Color(0xFF070E18),
        rootBackground: const Color(0xFF0A1320),
        textColor: const Color(0xFFFFFFFF),
        buttonEnabled: const Color(0xFF183864),
        buttonDisabled: const Color(0xFF0E2038),
        errorRed: const Color(0xFFFF5C6A),
        currentClassGreen: const Color(0xFF00E59B),
        roomHighlightColor: const Color(0xFF2F70F2),
        onRoomHighlightColor: const Color(0xFFFFFFFF),
        basedOnDark: true));

    _appColors.add(AppPalette('Neptun Light',
        primary: const Color(0xFF0F47D0),
        onPrimary: const Color(0xFFFFFFFF),
        onPrimaryContainer: const Color(0xFF0A2E8A),
        secondary: const Color(0xFFE1E8F5),
        onSecondary: const Color(0xFF162D50),
        onSecondaryContainer: const Color(0xFF0F47D0),
        grade1: const Color(0xFFBD2E2E),
        grade2: const Color(0xFF955151),
        grade3: const Color(0xFF9E9754),
        grade4: const Color(0xFF72885A),
        grade5: const Color(0xFF567B58),
        navbarStatusBarColor: const Color(0xFFEEF2F8),
        navbarNavibarColor: const Color(0xFFE6ECF5),
        rootBackground: const Color(0xFFF4F7FC),
        textColor: const Color(0xFF162D50),
        buttonEnabled: const Color(0xFF0F47D0),
        buttonDisabled: const Color(0xFFC6D4EA),
        errorRed: const Color(0xFFDC2626),
        currentClassGreen: const Color(0xFF00A86B),
        roomHighlightColor: const Color(0xFF00BFA5),
        onRoomHighlightColor: const Color(0xFF00382E),
        basedOnDark: false));

    final target = DataCache.getPreferredAppTheme()!;
    for (var item in getAllThemes()) {
      if (item.paletteName == target || (target == 'Neptun' && item.paletteName == (_isDark ? 'Neptun Dark' : 'Neptun Light'))) {
        _themeBatchSelectedIdx = getAllThemes().indexOf(item);
        break;
      }
    }
    _hasInit = true;
  }

  static AppPalette? _cachedPalette;
  static AppPalette getTheme() {
    if (_themeBatchSelectedIdx == -1) {
      if (_isDark) {
        return _appColors[1];
      } else {
        return _appColors[0];
      }
    }
    _cachedPalette ??= getAllThemes()[_themeBatchSelectedIdx];
    return _cachedPalette!;
  }

  static void setCurrentSystemTheme(bool isDark) {
    _isDark = isDark;
    for (var item in _onThemeChangeCallbacks) {
      Future.delayed(Duration.zero, () {
        item();
      });
    }
  }

  static bool hasThemeDownloaded(String name) {
    for (var item in getAllThemes()) {
      if (item.paletteName == name) {
        return true;
      }
    }
    return false;
  }

  static void setUserTheme(BuildContext context) {
    _cachedPalette = null;
    refreshThemeIndexing();
    Provider.of<ThemeNotifier>(context, listen: false).createNewThemeData();
  }

  static void setUserThemeByName(String name, BuildContext context) {
    _cachedPalette = null;
    refreshThemeIndexingWithPrefered(name);
    Provider.of<ThemeNotifier>(context, listen: false).createNewThemeData();
  }

  static List<AppPalette> getAllThemes() {
    final List<AppPalette> list = [];
    list.addAll(_appColors);
    list.addAll(_downloadedAppColors);
    return list;
  }

  static int appThemeToIdx(String name) {
    for (var item in getAllThemes()) {
      if (item.paletteName == name || (name == 'Neptun' && item.paletteName == (_isDark ? 'Neptun Dark' : 'Neptun Light'))) {
        return getAllThemes().indexOf(item);
      }
    }
    return -1;
  }

  static void refreshThemeIndexing() {
    final List<AppPalette> batch = getAllThemes();
    final userPreference = DataCache.getPreferredAppTheme();
    var idx = -1;
    for (var item in batch) {
      if (item.paletteName == userPreference || (userPreference == 'Neptun' && item.paletteName == (_isDark ? 'Neptun Dark' : 'Neptun Light'))) {
        idx = batch.indexOf(item);
        break;
      }
    }
    _themeBatchSelectedIdx = idx;
    for (var item in _onThemeChangeCallbacks) {
      Future.delayed(Duration.zero, () {
        item();
      });
    }
  }

  static void refreshThemeIndexingWithPrefered(String prefered) {
    final List<AppPalette> batch = getAllThemes();
    final userPreference = prefered;
    var idx = -1;
    for (var item in batch) {
      if (item.paletteName == userPreference || (userPreference == 'Neptun' && item.paletteName == (_isDark ? 'Neptun Dark' : 'Neptun Light'))) {
        idx = batch.indexOf(item);
        break;
      }
    }
    _themeBatchSelectedIdx = idx;
    for (var item in _onThemeChangeCallbacks) {
      Future.delayed(Duration.zero, () {
        item();
      });
    }
  }

  static void saveDownloadedPaletteData() {
    List<String> saveList = [];
    for (var item in _downloadedAppColors) {
      saveList.add(AppPalette.toJson(item));
    }
    DataCache.setAllDownloadedAppThemes(saveList);
  }

  static Timer _loadDownloadColorTimer = Timer(Duration.zero, () {});

  static Future<void> loadDownloadedPaletteData(BuildContext context) async {
    final downloadedPalattesJson = DataCache.getAllDownloadedAppThemes();
    for (var item in downloadedPalattesJson) {
      await Future.delayed(Duration.zero, () {
        AppPalette.fromJson(item, () async {
          if (!DataCache.getHasNetwork()) {
            return;
          }
          _loadDownloadColorTimer.cancel();
          _loadDownloadColorTimer = Timer(const Duration(seconds: 3), () {
            saveDownloadedPaletteData();
          });
          Navigator.popUntil(context, (route) => route.willHandlePopInternally);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Splitter()),
          );
        });
      });
    }
    refreshThemeIndexing();
  }

  static List<String> getThemesOnline() {
    final List<String> list = [];
    final List<ThemePackMap>? themes = Coloring.getAllThemesCache();
    final obtainedList = getAllThemes();
    for (var item in obtainedList) {
      list.add(item.paletteName);
    }
    if (themes == null) {
      return list;
    }
    for (var item in themes) {
      if (list.contains(item.themeName)) {
        continue;
      }
      list.add(item.themeName);
    }
    return list;
  }

  static Color getThemePopupAccentByName(String name) {
    for (var theme in getAllThemes()) {
      if (theme.paletteName == name) {
        return theme.primary;
      }
    }
    final onlineThemes = Coloring.getAllThemesCache();
    if (onlineThemes == null) {
      return Colors.transparent;
    }
    for (var item in onlineThemes) {
      if (item.themeName == name) {
        return item.themepackAccent;
      }
    }
    return Colors.transparent;
  }
}