import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jupiter/Pages/main_page.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';
import '../storage.dart';
import '../Misc/emojirich_text.dart';
import '../Pages/startup_page.dart';
import '../Misc/auto_updater.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _languageCurrSelect;
  late String _themesCurrSelect;
  late double _currentFontScale;
  List<LangPackMap> _availableLanguages = Language.getAllLanguagesWithNative();

  @override
  void initState() {
    super.initState();

    // loading defaults
    _currentFontScale = DataCache.getFontScale();
    _themesCurrSelect = AppColors.getTheme().paletteName;

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

  // header helpers
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.getTheme().primary, size: 20),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
                color: AppColors.getTheme().primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.getTheme().textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      activeColor: AppColors.getTheme().primary,
      activeTrackColor: AppColors.getTheme().primary.withValues(alpha: 0.35),
      inactiveThumbColor: AppColors.getTheme().textColor.withValues(alpha: 0.6),
      inactiveTrackColor: AppColors.getTheme().textColor.withValues(alpha: 0.15),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.getTheme().primary;
        }
        return AppColors.getTheme().textColor.withValues(alpha: 0.25);
      }),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getTheme().rootBackground,
      appBar: AppBar(
        backgroundColor: AppColors.getTheme().rootBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.getTheme().textColor),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: EmojiRichText(
          text: AppStrings.getLanguagePack().topmenu_buttons_Settings,
          defaultStyle: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 20),
          emojiStyle: TextStyle(color: AppColors.getTheme().textColor, fontSize: 20, fontFamily: "Noto Color Emoji"),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // --- 1. appearance and language ---
          _buildSectionHeader("Megjelenés és Nyelv", Icons.palette_rounded),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption9_ThemeSwap, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.12))
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _themesCurrSelect,
                  dropdownColor: AppColors.getTheme().rootBackground,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTheme().primary),
                  isExpanded: true,
                  style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600),
                  items: AppColors.getThemesOnline().map((String value) {
                    return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: AppColors.getThemePopupAccentByName(value), size: 16),
                            const SizedBox(width: 10),
                            Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
                          ],
                        )
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value == null) return;
                    AppHaptics.lightImpact();
                    DataCache.setPreferredAppTheme(value);
                    if(!AppColors.hasThemeDownloaded(value)){
                      // download logic from old popup
                      Future.delayed(Duration.zero, ()async{
                        final pack = await Coloring.getAllThemes();
                        await Coloring.getThemePackById(pack, value).then((val)async{
                          if(val != null){
                            AppColors.saveDownloadedPaletteData();
                            AppColors.setUserThemeByName(val.paletteName, context);
                            AppColors.refreshThemeIndexing();
                            setState(() { _themesCurrSelect = value; });
                          }
                        });
                      });
                    } else {
                      setState(() {
                        _themesCurrSelect = value;
                        AppColors.setUserTheme(context);
                        AppColors.refreshThemeIndexing();
                      });
                    }
                  },
                ),
              ),
            ),
          ),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption8_LangaugeSelection, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.12))
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _availableLanguages.any((l) => "${l.langFlag} ${l.langName}" == _languageCurrSelect)
                      ? _languageCurrSelect
                      : "${_availableLanguages.first.langFlag} ${_availableLanguages.first.langName}",
                  dropdownColor: AppColors.getTheme().rootBackground,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTheme().primary),
                  isExpanded: true,
                  items: _availableLanguages.map((LangPackMap item) {
                    final strValue = "${item.langFlag} ${item.langName}";
                    return DropdownMenuItem<String>(
                        value: strValue,
                        child: EmojiRichText(
                          text: strValue,
                          defaultStyle: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 14),
                          emojiStyle: TextStyle(color: AppColors.getTheme().textColor, fontSize: 18, fontFamily: "Noto Color Emoji"),
                        )
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("App Betűméret skálázás", style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 16)),
                Slider(
                  value: _currentFontScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: "${(_currentFontScale * 100).toInt()}%",
                  activeColor: AppColors.getTheme().primary,
                  inactiveColor: AppColors.getTheme().textColor.withValues(alpha: 0.15),
                  thumbColor: AppColors.getTheme().primary,
                  onChanged: (val) {
                    setState(() { _currentFontScale = val; });
                  },
                  onChangeEnd: (val) {
                    AppHaptics.lightImpact();
                    DataCache.setFontScale(val);
                    // ui update!
                    setState((){});
                  },
                ),
              ],
            ),
          ),

          // --- 2. notifications ---
          _buildSectionHeader("Értesítések", Icons.notifications_active_rounded),

          _buildSwitchTile(
            title: AppStrings.getLanguagePack().popup_case1_settingOption2_ExamNotifications,
            value: DataCache.getNeedExamNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedExamNotifications(b ? 1 : 0);
              b ? HomePageState.setupExamNotifications() : HomePageState.cancelExamNotifications();
              setState(() {});
            },
          ),
          _buildSwitchTile(
            title: AppStrings.getLanguagePack().popup_case1_settingOption3_ClassNotifications,
            value: DataCache.getNeedClassNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedClassNotifications(b ? 1 : 0);
              b ? HomePageState.setupClassesNotifications() : HomePageState.cancelClassesNotifications();
              setState(() {});
            },
          ),
          _buildSwitchTile(
            title: AppStrings.getLanguagePack().popup_case1_settingOption4_PaymentNotifications,
            value: DataCache.getNeedPaymentsNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedPaymentsNotifications(b ? 1 : 0);
              b ? HomePageState.setupPaymentsNotifications() : HomePageState.cancelPaymentsNotifications();
              setState(() {});
            },
          ),
          _buildSwitchTile(
            title: AppStrings.getLanguagePack().popup_case1_settingOption5_PeriodsNotifications,
            value: DataCache.getNeedPeriodsNotifications()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedPeriodsNotifications(b ? 1 : 0);
              b ? HomePageState.setupPeriodsNotifications() : HomePageState.cancelPeriodsNotifications();
              setState(() {});
            },
          ),

          // --- 3. operation and others ---
          _buildSectionHeader("Működés és Egyéb", Icons.build_circle_rounded),

          _buildSwitchTile(
            title: AppStrings.getLanguagePack().popup_case1_settingOption1_FamilyFriendlyLoadingText,
            value: DataCache.getNeedFamilyFriendlyComments()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedFamilyFriendlyComments(b ? 1 : 0);
              setState(() {});
            },
          ),
          _buildSwitchTile(
            title: AppStrings.getLanguagePack().popup_case1_settingOption6_AppHaptics,
            value: DataCache.getNeedsHaptics()!,
            onChanged: (b) {
              AppHaptics.lightImpact();
              DataCache.setNeedsHaptics(b ? 1 : 0);
              setState(() {});
            },
          ),

          ListTile(
            title: Text(AppStrings.getLanguagePack().popup_case1_settingOption7_WeekOffset, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Container(
              width: 120,
              decoration: BoxDecoration(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.12)),
              ),
              child: Row(
                 children: [
                   IconButton(
                     icon: Icon(Icons.remove, color: AppColors.getTheme().primary, size: 18),
                     onPressed: () { AppHaptics.lightImpact(); HomePageState.settingsUserWeekOffsetAdd(-1); setState((){}); },
                   ),
                   Expanded(
                     child: Text(HomePageState.getUserWeekOffsetTextController().text.isEmpty ? "Auto" : HomePageState.getUserWeekOffsetTextController().text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
                   ),
                   IconButton(
                     icon: Icon(Icons.add, color: AppColors.getTheme().primary, size: 18),
                     onPressed: () { AppHaptics.lightImpact(); HomePageState.settingsUserWeekOffsetAdd(1); setState((){}); },
                   ),
                 ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.system_update_rounded, color: AppColors.getTheme().primary),
            title: Text(AppStrings.getLanguagePack().popup_case7_ButtonUpdateNow, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.4)),
            onTap: () {
              AppHaptics.lightImpact();
              AppUpdater.checkAndInstallUpdate(context, force: true);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}