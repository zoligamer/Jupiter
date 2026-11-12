import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jupiter/Pages/main_page.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';
import '../storage.dart';
import '../notifications.dart';
import '../Misc/emojirich_text.dart';
import '../Misc/background_service.dart';
import '../Pages/startup_page.dart';
import '../Misc/auto_updater.dart';
import '../Widgets/app_tutorial_modal.dart';
import '../Widgets/widget_data_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _languageCurrSelect;
  late String _themesCurrSelect;
  late double _currentFontScale;
  late int _bgIntervalMinutes;
  late bool _bgWifiOnly;
  late bool _bgSyncEnabled;
  late bool _widgetSyncEnabled;
  late bool _seasonalThemeEnabled;
  List<LangPackMap> _availableLanguages = Language.getAllLanguagesWithNative();

  @override
  void initState() {
    super.initState();

    // loading defaults
    _currentFontScale = DataCache.getFontScale();
    _themesCurrSelect = AppColors.getTheme().paletteName;
    _bgIntervalMinutes = DataCache.getBackgroundSyncInterval();
    _bgWifiOnly = DataCache.getBackgroundSyncWifiOnly();
    _bgSyncEnabled = DataCache.getBackgroundSyncEnabled();
    _widgetSyncEnabled = DataCache.getWidgetBackgroundSyncEnabled();
    _seasonalThemeEnabled = DataCache.getSeasonalThemeEnabled();

    _initLanguageSelection();
    _loadOnlineLanguages();
  }

  void _initLanguageSelection() {
    final selectedCode = DataCache.getUserSelectedLanguageCode();
    final selectedIdx = DataCache.getUserSelectedLanguage() ?? -1;
    final allCodes = _availableLanguages.map((l) => l.langId).toList();

    int targetIdx = -1;
    if (selectedCode != null && selectedCode.isNotEmpty) {
      targetIdx = allCodes.indexOf(selectedCode);
    }
    if (targetIdx == -1 && selectedIdx >= 0 && selectedIdx < _availableLanguages.length) {
      targetIdx = selectedIdx;
    }
    if (targetIdx == -1) {
      final deviceCode = Platform.localeName.split('_')[0].toLowerCase();
      targetIdx = allCodes.indexOf(deviceCode);
    }
    if (targetIdx == -1) {
      targetIdx = 0;
    }

    final targetLang = _availableLanguages[targetIdx];
    _languageCurrSelect = "${targetLang.langFlag} ${targetLang.langName}";
  }

  Future<void> _loadOnlineLanguages() async {
    if (DataCache.getHasNetwork()) {
      final onlineLangs = await Language.getAllLanguages();
      if (onlineLangs != null && mounted) {
        setState(() {
          _availableLanguages = Language.getAllLanguagesWithNative();
          _initLanguageSelection();
        });
      }
    }
  }

  // Section header helper
  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = AppColors.getTheme();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: theme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    IconData? icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = AppColors.getTheme();
    return SwitchListTile(
      secondary: icon != null ? Icon(icon, color: theme.primary, size: 22) : null,
      title: Text(
        title,
        style: TextStyle(
          color: theme.textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5),
            )
          : null,
      activeThumbColor: theme.primary,
      activeTrackColor: theme.primary.withValues(alpha: 0.35),
      inactiveThumbColor: theme.textColor.withValues(alpha: 0.6),
      inactiveTrackColor: theme.textColor.withValues(alpha: 0.15),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return theme.primary;
        }
        return theme.textColor.withValues(alpha: 0.25);
      }),
      value: value,
      onChanged: onChanged,
    );
  }

  void _confirmClearCache() {
    AppHaptics.mediumImpact();
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: theme.textColor.withValues(alpha: 0.15)),
          ),
          title: Row(
            children: [
              Icon(Icons.cleaning_services_rounded, color: theme.errorRed),
              const SizedBox(width: 10),
              Text(
                'Gyorsítótár kiürítése',
                style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Biztosan törölni szeretnéd a helyi gyorsítótárat? A bejelentkezésed és jelszavad megmarad, a tantárgyak, naptár és üzenetek újra letöltődnek a Neptun szerverről.',
            style: TextStyle(color: theme.textColor.withValues(alpha: 0.8), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Mégsem', style: TextStyle(color: theme.textColor.withValues(alpha: 0.7))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.errorRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await DataCache.clearLocalCachePreservingLogin();
                Fluttertoast.showToast(msg: "🧹 Gyorsítótár sikeresen kiürítve!");
                setState(() {});
              },
              child: const Text('Igen, törlés', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();

    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: AppBar(
        backgroundColor: theme.rootBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textColor),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: EmojiRichText(
          text: AppStrings.getLanguagePack().topmenu_buttons_Settings,
          defaultStyle: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 20),
          emojiStyle: TextStyle(color: theme.textColor, fontSize: 20, fontFamily: "Noto Color Emoji"),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // ==========================================
          // 1. KATEGÓRIA: MEGJELENÉS ÉS NYELV
          // ==========================================
          _buildSectionHeader("Megjelenés és Nyelv", Icons.palette_rounded),

          // Időszakos (Szezonális) téma kapcsoló
          SwitchListTile(
            secondary: Icon(Icons.auto_awesome_rounded, color: theme.primary, size: 22),
            title: const Text(
              "Időszakos téma (Automatikus)",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              _seasonalThemeEnabled
                  ? "Aktív: ${AppColors.getSeasonalThemeName()} (szezonális naptár szerint)"
                  : "Évszakokhoz, ünnepekhez és vizsgákhoz igazodó megjelenés",
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
            ),
            value: _seasonalThemeEnabled,
            activeThumbColor: theme.currentClassGreen,
            onChanged: (bool value) async {
              AppHaptics.lightImpact();
              await DataCache.setSeasonalThemeEnabled(value);
              if (!context.mounted) return;
              AppColors.setUserTheme(context);
              AppColors.refreshThemeIndexing();
              setState(() {
                _seasonalThemeEnabled = value;
                _themesCurrSelect = AppColors.getTheme().paletteName;
              });
            },
          ),

          // Témaválasztó (Lebegőablakos négyzethálós választó)
          ListTile(
            leading: Icon(Icons.color_lens_outlined, color: theme.primary, size: 22),
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption9_ThemeSwap, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              _seasonalThemeEnabled ? "Időszakos téma aktív (koppints a módosításhoz)" : "${AppColors.getAllThemes().length} elérhető témapaletta",
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.55), fontSize: 11.5),
            ),
            trailing: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showThemePickerDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.getTheme().primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.getTheme().primary.withValues(alpha: 0.4), blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
                      child: Text(
                        _themesCurrSelect,
                        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: theme.primary, size: 18),
                  ],
                ),
              ),
            ),
          ),

          // Nyelvválasztó
          ListTile(
            leading: Icon(Icons.translate_rounded, color: theme.primary, size: 22),
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption8_LangaugeSelection, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
            trailing: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.12)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _availableLanguages.any((l) => "${l.langFlag} ${l.langName}" == _languageCurrSelect)
                      ? _languageCurrSelect
                      : "${_availableLanguages.first.langFlag} ${_availableLanguages.first.langName}",
                  dropdownColor: theme.rootBackground,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: theme.primary),
                  isExpanded: true,
                  items: _availableLanguages.map((LangPackMap item) {
                    final strValue = "${item.langFlag} ${item.langName}";
                    return DropdownMenuItem<String>(
                      value: strValue,
                      child: EmojiRichText(
                        text: strValue,
                        defaultStyle: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14),
                        emojiStyle: TextStyle(color: theme.textColor, fontSize: 18, fontFamily: "Noto Color Emoji"),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) async {
                    if (value == null) return;
                    AppHaptics.lightImpact();

                    final selected = _availableLanguages.firstWhere(
                      (l) => "${l.langFlag} ${l.langName}" == value,
                      orElse: () => _availableLanguages.first,
                    );

                    if (!AppStrings.hasLanguageDownloaded(selected.langId) && selected.langURL.isNotEmpty) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.getTheme().rootBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const CircularProgressIndicator(),
                          ),
                        ),
                      );

                      final allLangs = await Language.getAllLanguages();
                      await Language.getLanguagePackById(allLangs, selected.langId);
                      AppStrings.saveDownloadedLanguageData();
                      if (mounted && Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    }

                    final allCodes = AppStrings.getAllLangCodes();
                    final newIdx = allCodes.indexOf(selected.langId);
                    await DataCache.setUserSelectedLanguage(newIdx >= 0 ? newIdx : 0);
                    await DataCache.setUserSelectedLanguageCode(selected.langId);

                    if (mounted) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Splitter()));
                    }
                  },
                ),
              ),
            ),
          ),

          // Betűméret skálázás
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("App Betűméret skálázás", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${(_currentFontScale * 100).toInt()}%",
                        style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _currentFontScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: "${(_currentFontScale * 100).toInt()}%",
                  activeColor: theme.primary,
                  inactiveColor: theme.textColor.withValues(alpha: 0.15),
                  thumbColor: theme.primary,
                  onChanged: (val) {
                    setState(() {
                      _currentFontScale = val;
                    });
                  },
                  onChangeEnd: (val) {
                    AppHaptics.lightImpact();
                    DataCache.setFontScale(val);
                    HomePageState.refreshCalendarView();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          // ==========================================
          // 2. KATEGÓRIA: ÉRTESÍTÉSEK ÉS RIASZTÁSOK
          // ==========================================
          _buildSectionHeader("Értesítések és Riasztások", Icons.notifications_active_rounded),

          // Üzenet értesítések (Neptun Mail) - Kifejezetten a felhasználó kérésére hozzáadva!
          _buildSwitchTile(
            icon: Icons.mail_outline_rounded,
            title: 'Neptun üzenet értesítések',
            subtitle: 'Új beérkező hivatalos és oktatói levelek automatikus jelzése',
            value: DataCache.getNeedMessageNotifications() ?? true,
            onChanged: (b) async {
              AppHaptics.lightImpact();
              await DataCache.setNeedMessageNotifications(b ? 1 : 0);
              setState(() {});
            },
          ),

          // Órarendi értesítések
          _buildSwitchTile(
            icon: Icons.schedule_rounded,
            title: AppStrings.getLanguagePack().popup_case1_settingOption3_ClassNotifications,
            subtitle: 'Figyelmeztetés a következő tanóra megkezdése előtt',
            value: DataCache.getNeedClassNotifications() ?? true,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedClassNotifications(b ? 1 : 0);
              b ? HomePageState.setupClassesNotifications() : HomePageState.cancelClassesNotifications();
              setState(() {});
            },
          ),

          // Vizsgaértesítések
          _buildSwitchTile(
            icon: Icons.fact_check_outlined,
            title: AppStrings.getLanguagePack().popup_case1_settingOption2_ExamNotifications,
            subtitle: 'Figyelmeztetés a felvett vizsgák időpontjai előtt',
            value: DataCache.getNeedExamNotifications() ?? true,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedExamNotifications(b ? 1 : 0);
              b ? HomePageState.setupExamNotifications() : HomePageState.cancelExamNotifications();
              setState(() {});
            },
          ),

          // Pénzügyi értesítések
          _buildSwitchTile(
            icon: Icons.payment_rounded,
            title: AppStrings.getLanguagePack().popup_case1_settingOption4_PaymentNotifications,
            subtitle: 'Értesítés közeledő és lejárt befizetési határidőkről',
            value: DataCache.getNeedPaymentsNotifications() ?? true,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedPaymentsNotifications(b ? 1 : 0);
              b ? HomePageState.setupPaymentsNotifications() : HomePageState.cancelPaymentsNotifications();
              setState(() {});
            },
          ),

          // Intelligens pénzügyi színezés
          _buildSwitchTile(
            icon: Icons.palette_outlined,
            title: 'Intelligens pénzügyi színezés (+/-)',
            subtitle: 'Kísérleti: bevételek és ösztöndíjak automatikus színezése (alapértelmezetten kikapcsolva)',
            value: DataCache.getEnablePaymentColoring(),
            onChanged: (b) async {
              AppHaptics.lightImpact();
              await DataCache.setEnablePaymentColoring(b);
              setState(() {});
            },
          ),

          // Időszak értesítések
          _buildSwitchTile(
            icon: Icons.date_range_rounded,
            title: AppStrings.getLanguagePack().popup_case1_settingOption5_PeriodsNotifications,
            subtitle: 'Határidők, tárgyfelvételi és vizsgaidőszakok kezdetének jelzése',
            value: DataCache.getNeedPeriodsNotifications() ?? true,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedPeriodsNotifications(b ? 1 : 0);
              b ? HomePageState.setupPeriodsNotifications() : HomePageState.cancelPeriodsNotifications();
              setState(() {});
            },
          ),

          // Teszt értesítés küldése gomb
          ListTile(
            leading: Icon(Icons.notification_add_outlined, color: theme.primary, size: 22),
            title: Text(
              'Teszt értesítés küldése',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Rendszerértesítési csatorna és hang tesztelése',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5),
            ),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary.withValues(alpha: 0.15),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(Icons.send_rounded, size: 14, color: theme.primary),
              label: Text('Küldés', style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () async {
                AppHaptics.mediumImpact();
                await AppNotifications.initialize();
                await AppNotifications.showNotification(
                  "Jupiter Értesítés Teszt",
                  "Az értesítési rendszer tökéletesen működik! 🔔",
                );
                Fluttertoast.showToast(msg: "Teszt értesítés elküldve!");
              },
            ),
          ),

          // ==========================================
          // 3. KATEGÓRIA: HÁTTÉRMOTOR & SZINKRONIZÁCIÓ
          // ==========================================
          _buildSectionHeader("Háttérmotor & Szinkronizáció", Icons.sync_rounded),

          // Háttérszolgáltatás főkapcsoló
          _buildSwitchTile(
            icon: Icons.cloud_sync_outlined,
            title: 'Háttérszolgáltatás futtatása',
            subtitle: 'Automatikus háttérszinkronizáció és új üzenetek figyelése',
            value: _bgSyncEnabled,
            onChanged: (b) async {
              AppHaptics.lightImpact();
              setState(() => _bgSyncEnabled = b);
              await DataCache.setBackgroundSyncEnabled(b);
              if (b) {
                await BackgroundService.registerPeriodicCheck(
                  intervalMinutes: _bgIntervalMinutes,
                  wifiOnly: _bgWifiOnly,
                );
                Fluttertoast.showToast(msg: "Háttérszolgáltatás aktiválva ($_bgIntervalMinutes perc)");
              } else {
                await BackgroundService.cancelPeriodicCheck();
                Fluttertoast.showToast(msg: "Háttérszolgáltatás felfüggesztve");
              }
            },
          ),

          // Szinkronizálási gyakoriság (User requested 5-minute monitor option!)
          ListTile(
            leading: Icon(Icons.timer_rounded, color: theme.primary, size: 22),
            title: Text(
              'Szinkronizálási gyakoriság',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              _bgIntervalMinutes == 5
                  ? '🚀 5 perc: Intenzív Monitor mód'
                  : '$_bgIntervalMinutes percenkénti háttérellenőrzés',
              style: TextStyle(
                color: _bgIntervalMinutes == 5 ? (isDark ? Colors.cyanAccent : const Color(0xFF0F47D0)) : theme.textColor.withValues(alpha: 0.6),
                fontSize: 11.5,
                fontWeight: _bgIntervalMinutes == 5 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: Container(
              width: 155,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.12)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _bgIntervalMinutes,
                  dropdownColor: theme.rootBackground,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: theme.primary),
                  isExpanded: true,
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 12.5),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('🚀 5 perc (Monitor)')),
                    DropdownMenuItem(value: 15, child: Text('⚡ 15 perc (Normál)')),
                    DropdownMenuItem(value: 30, child: Text('⏱️ 30 perc')),
                    DropdownMenuItem(value: 60, child: Text('🔋 60 perc (Kímélő)')),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    AppHaptics.lightImpact();
                    setState(() => _bgIntervalMinutes = val);
                    await DataCache.setBackgroundSyncInterval(val);
                    if (_bgSyncEnabled) {
                      await BackgroundService.registerPeriodicCheck(
                        intervalMinutes: val,
                        wifiOnly: _bgWifiOnly,
                      );
                    }
                    Fluttertoast.showToast(
                      msg: val == 5
                          ? "🚀 5 perces Monitor mód beállítva!"
                          : "Szinkronizálási időközt $val percre módosítottuk.",
                    );
                  },
                ),
              ),
            ),
          ),

          // Csak Wi-Fi kapcsolaton
          _buildSwitchTile(
            icon: Icons.wifi_rounded,
            title: 'Csak Wi-Fi kapcsolaton szinkronizáljon',
            subtitle: 'Mobil adatforgalom kímélése háttérlekérdezések során',
            value: _bgWifiOnly,
            onChanged: (b) async {
              AppHaptics.lightImpact();
              setState(() => _bgWifiOnly = b);
              await DataCache.setBackgroundSyncWifiOnly(b);
              if (_bgSyncEnabled) {
                await BackgroundService.registerPeriodicCheck(
                  intervalMinutes: _bgIntervalMinutes,
                  wifiOnly: b,
                );
              }
            },
          ),

          // Kezdőképernyő widgetek háttérfrissítése
          _buildSwitchTile(
            icon: Icons.widgets_outlined,
            title: 'Kezdőképernyő widgetek szinkronizálása',
            subtitle: 'Widget adatok frissítése a háttérben (kikapcsolva kíméli az akkut és netet)',
            value: _widgetSyncEnabled,
            onChanged: (b) async {
              AppHaptics.lightImpact();
              setState(() => _widgetSyncEnabled = b);
              await DataCache.setWidgetBackgroundSyncEnabled(b);
              if (b) {
                await WidgetDataService.updateAllWidgets();
                Fluttertoast.showToast(msg: "Widget szinkronizáció engedélyezve");
              } else {
                Fluttertoast.showToast(msg: "Widget háttérfrissítés felfüggesztve");
              }
            },
          ),

          // ==========================================
          // 4. KATEGÓRIA: ÓRAREND & TERVEZŐ
          // ==========================================
          _buildSectionHeader("Órarend & Tervező", Icons.calendar_month_rounded),

          // Tanulmányi Osztály (T.O.) szűrőgomb az órarendben
          _buildSwitchTile(
            icon: Icons.account_balance_outlined,
            title: 'Tanulmányi Osztály (T.O.) szűrőgomb',
            subtitle: 'T.O. szűrőgomb és ügyfélszolgálati idősávok engedélyezése az órarendben',
            value: DataCache.getEnableToOfficeToggler(),
            onChanged: (b) async {
              AppHaptics.lightImpact();
              await DataCache.setEnableToOfficeToggler(b);
              HomePageState.refreshCalendarView();
              setState(() {});
            },
          ),

          // Időszakok a naptárban
          _buildSwitchTile(
            icon: Icons.event_note_rounded,
            title: 'Időszakok a heti naptárban',
            subtitle: 'Aktuális regisztrációs és vizsgaidőszakok jelölése az órarend felett',
            value: DataCache.getShowPeriodsInCalendar(),
            onChanged: (b) async {
              AppHaptics.lightImpact();
              await DataCache.setShowPeriodsInCalendar(b);
              HomePageState.refreshCalendarView();
              setState(() {});
            },
          ),

          // Heti naptár eltolás (Week Offset)
          ListTile(
            leading: Icon(Icons.date_range_outlined, color: theme.primary, size: 22),
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption7_WeekOffset, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('Manuális félévi hétkorrekció', style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5)),
            trailing: Container(
              width: 120,
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove, color: theme.primary, size: 18),
                    onPressed: () {
                      AppHaptics.lightImpact();
                      HomePageState.settingsUserWeekOffsetAdd(-1);
                      HomePageState.refreshCalendarView();
                      setState(() {});
                    },
                  ),
                  Expanded(
                    child: Text(
                      HomePageState.getUserWeekOffsetTextController().text.isEmpty
                          ? "Auto"
                          : HomePageState.getUserWeekOffsetTextController().text,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add, color: theme.primary, size: 18),
                    onPressed: () {
                      AppHaptics.lightImpact();
                      HomePageState.settingsUserWeekOffsetAdd(1);
                      HomePageState.refreshCalendarView();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),

          // ==========================================
          // 5. KATEGÓRIA: RENDSZER & KARBANTARTÁS
          // ==========================================
          _buildSectionHeader("Rendszer & Karbantartás", Icons.build_circle_rounded),

          // Haptikus rezgések
          _buildSwitchTile(
            icon: Icons.vibration_rounded,
            title: AppStrings.getLanguagePack().popup_case1_settingOption6_AppHaptics,
            subtitle: 'Finom rezgéses visszajelzés gombok és váltók megérintésekor',
            value: DataCache.getNeedsHaptics() ?? true,
            onChanged: (b) async {
              if (b) AppHaptics.lightImpact();
              await AppHaptics.setVibrationState(b);
              setState(() {});
            },
          ),

          // Családbarát idézetek
          _buildSwitchTile(
            icon: Icons.sentiment_satisfied_alt_rounded,
            title: AppStrings.getLanguagePack().popup_case1_settingOption1_FamilyFriendlyLoadingText,
            subtitle: 'Kulturált, szalonképes szövegek betöltő képernyőkön',
            value: DataCache.getNeedFamilyFriendlyComments() ?? false,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedFamilyFriendlyComments(b ? 1 : 0);
              setState(() {});
            },
          ),

          // Gyorsítótár kiürítése gomb
          ListTile(
            leading: Icon(Icons.cleaning_services_rounded, color: theme.errorRed, size: 22),
            title: Text(
              'Helyi gyorsítótár kiürítése',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Órarend, jegyek és levelek törlése (újratöltés kényszerítése)',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5),
            ),
            trailing: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.errorRed.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _confirmClearCache,
              child: Text('Kiürítés', style: TextStyle(color: theme.errorRed, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),

          // Alkalmazás frissítés ellenőrzése
          ListTile(
            leading: Icon(Icons.system_update_rounded, color: theme.primary, size: 22),
            title: Text(AppStrings.getLanguagePack().popup_case7_ButtonUpdateNow, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              'Telepített verzió: ${AppUpdater.installedVersion.isNotEmpty ? AppUpdater.installedVersion : "1.0.5"}',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5),
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: theme.textColor.withValues(alpha: 0.4)),
            onTap: () {
              AppHaptics.lightImpact();
              AppUpdater.checkAndInstallUpdate(context, force: true);
            },
          ),

          // Alkalmazás bemutató újrajátszása
          ListTile(
            leading: Icon(Icons.help_outline_rounded, color: theme.primary, size: 22),
            title: Text(
              'Alkalmazás bemutató újrajátszása',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'A Jupiter funkcióinak és trükkjeinek bemutatása',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5),
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: theme.textColor.withValues(alpha: 0.4)),
            onTap: () {
              AppHaptics.lightImpact();
              AppTutorialModal.showTutorial(context);
            },
          ),

          // Újdonságok és kiadási megjegyzések (Changelog)
          ListTile(
            leading: Icon(Icons.notes_rounded, color: theme.primary, size: 22),
            title: Text(
              'Újdonságok (Kiadási megjegyzések)',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Verzióinformációk és változtatások áttekintése',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5),
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: theme.textColor.withValues(alpha: 0.4)),
            onTap: () {
              AppHaptics.lightImpact();
              AppUpdater.showReleaseChangelog(context);
            },
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  /// Megjeleníti a modern, görgethető négyzethálós témaválasztó lebegőablakot
  void _showThemePickerDialog(BuildContext context) {
    final theme = AppColors.getTheme();
    final allThemes = AppColors.getAllThemes();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: theme.rootBackground,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: theme.textColor.withValues(alpha: 0.12), width: 1),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fejléc
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.palette_rounded, color: theme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Téma választása",
                              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              "${allThemes.length} elérhető témapaletta",
                              style: TextStyle(color: theme.textColor.withValues(alpha: 0.55), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: theme.textColor.withValues(alpha: 0.6)),
                        onPressed: () => Navigator.pop(ctx),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Görgethető kerekített négyzetek rácsa
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: allThemes.length,
                        itemBuilder: (context, index) {
                          final p = allThemes[index];
                          final isSelected = p.paletteName == _themesCurrSelect;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                AppHaptics.lightImpact();
                                if (_seasonalThemeEnabled) {
                                  await DataCache.setSeasonalThemeEnabled(false);
                                }
                                await DataCache.setPreferredAppTheme(p.paletteName);
                                if (!context.mounted) return;
                                AppColors.setUserThemeByName(p.paletteName, context);
                                AppColors.refreshThemeIndexing();
                                setState(() {
                                  _themesCurrSelect = p.paletteName;
                                  _seasonalThemeEnabled = false;
                                });
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: p.rootBackground,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? p.primary
                                        : theme.textColor.withValues(alpha: 0.15),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: p.primary.withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Felső sor: Kis körök a téma színeivel + Kijelölő ikon
                                    Row(
                                      children: [
                                        // 3 kis kör
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: p.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: p.secondary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: p.roomHighlightColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (isSelected)
                                          Icon(Icons.check_circle_rounded, color: p.primary, size: 18)
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: p.textColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              p.isDark ? "Sötét" : "Világos",
                                              style: TextStyle(
                                                color: p.textColor.withValues(alpha: 0.7),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Alsó sor: Téma neve és stílus
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          p.paletteName,
                                          style: TextStyle(
                                            color: p.textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isSelected ? "● Aktív téma" : (p.isDark ? "Sötét mód" : "Világos mód"),
                                          style: TextStyle(
                                            color: isSelected ? p.primary : p.textColor.withValues(alpha: 0.55),
                                            fontSize: 10,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}