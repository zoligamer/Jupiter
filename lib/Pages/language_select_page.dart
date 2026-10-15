import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../API/api_coms.dart' as api;
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';
import '../storage.dart';
import '../Misc/emojirich_text.dart';
import 'setup_page.dart' as setup_page;

class LanguageOption {
  final String langId;
  final String nativeName;
  final String englishName;
  final String flag;
  final String langURL;

  const LanguageOption({
    required this.langId,
    required this.nativeName,
    required this.englishName,
    required this.flag,
    this.langURL = '',
  });
}

class LanguageSelectPage extends StatefulWidget {
  final bool isFromSetup;

  const LanguageSelectPage({
    super.key,
    this.isFromSetup = false,
  });

  @override
  State<LanguageSelectPage> createState() => _LanguageSelectPageState();
}

class _LanguageSelectPageState extends State<LanguageSelectPage> {
  static const Map<String, ({String nativeName, String englishName, String flag})> _knownLanguages = {
    'hu': (nativeName: 'Magyar', englishName: 'Hungarian', flag: '🇭🇺'),
    'en': (nativeName: 'English', englishName: 'English', flag: '🇬🇧'),
    'de': (nativeName: 'Deutsch', englishName: 'German', flag: '🇩🇪'),
    'fr': (nativeName: 'Français', englishName: 'French', flag: '🇫🇷'),
    'es': (nativeName: 'Español', englishName: 'Spanish', flag: '🇪🇸'),
    'it': (nativeName: 'Italiano', englishName: 'Italian', flag: '🇮🇹'),
    'ro': (nativeName: 'Română', englishName: 'Romanian', flag: '🇷🇴'),
    'sk': (nativeName: 'Slovenčina', englishName: 'Slovak', flag: '🇸🇰'),
    'uk': (nativeName: 'Українська', englishName: 'Ukrainian', flag: '🇺🇦'),
    'ru': (nativeName: 'Русский', englishName: 'Russian', flag: '🇷🇺'),
    'zh': (nativeName: '中文', englishName: 'Chinese', flag: '🇨🇳'),
    'tr': (nativeName: 'Türkçe', englishName: 'Turkish', flag: '🇹🇷'),
    'pl': (nativeName: 'Polski', englishName: 'Polish', flag: '🇵🇱'),
    'sr': (nativeName: 'Српски', englishName: 'Serbian', flag: '🇷🇸'),
    'hr': (nativeName: 'Hrvatski', englishName: 'Croatian', flag: '🇭🇷'),
    'sl': (nativeName: 'Slovenščina', englishName: 'Slovenian', flag: '🇸🇮'),
    'cs': (nativeName: 'Čeština', englishName: 'Czech', flag: '🇨🇿'),
  };

  List<LanguageOption> _options = [];
  String? _selectedCode;
  bool _isLoading = false;
  String _loadingMessage = '';

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _selectedCode = DataCache.getUserSelectedLanguageCode();
    if (_selectedCode == null || _selectedCode!.isEmpty) {
      // If not yet selected, detect system locale default
      try {
        _selectedCode = Platform.localeName.split('_')[0].toLowerCase();
      } catch (_) {
        _selectedCode = 'hu';
      }
    }
    _buildLanguageList();
    _fetchOnlineLanguages();
  }

  void _buildLanguageList() {
    final rawList = api.Language.getAllLanguagesWithNative();
    final List<LanguageOption> list = [];
    final Set<String> seenIds = {};

    for (var raw in rawList) {
      if (seenIds.contains(raw.langId)) continue;
      seenIds.add(raw.langId);

      final known = _knownLanguages[raw.langId];
      if (known != null) {
        list.add(LanguageOption(
          langId: raw.langId,
          nativeName: known.nativeName,
          englishName: known.englishName,
          flag: known.flag,
          langURL: raw.langURL,
        ));
      } else {
        list.add(LanguageOption(
          langId: raw.langId,
          nativeName: raw.langName,
          englishName: raw.langName,
          flag: raw.langFlag.isNotEmpty ? raw.langFlag : '🌐',
          langURL: raw.langURL,
        ));
      }
    }

    setState(() {
      _options = list;
    });
  }

  Future<void> _fetchOnlineLanguages() async {
    if (!DataCache.getHasNetwork()) return;
    try {
      final onlineLangs = await api.Language.getAllLanguages();
      if (onlineLangs != null && mounted) {
        _buildLanguageList();
      }
    } catch (_) {}
  }

  Future<void> _onSelectLanguage(LanguageOption option) async {
    AppHaptics.lightImpact();

    setState(() {
      _selectedCode = option.langId;
    });

    // Check if downloading is needed
    if (!AppStrings.hasLanguageDownloaded(option.langId) && option.langURL.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _loadingMessage = AppStrings.getLanguagePack().popup_case1_langSwap_DownloadingLang;
      });

      try {
        final allLangs = await api.Language.getAllLanguages();
        await api.Language.getLanguagePackById(allLangs, option.langId);
        AppStrings.saveDownloadedLanguageData();
      } catch (e) {
        debugPrint("Error downloading language: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }

    // Persist choice immediately
    final allCodes = AppStrings.getAllLangCodes();
    final newIdx = allCodes.indexOf(option.langId);
    await DataCache.setUserSelectedLanguage(newIdx >= 0 ? newIdx : 0);
    await DataCache.setUserSelectedLanguageCode(option.langId);
    AppStrings.initialize();

    if (!mounted) return;

    if (widget.isFromSetup) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const setup_page.SetupPageLoginTypeSelection(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.getTheme().rootBackground,
      statusBarColor: AppColors.getTheme().rootBackground,
    ));

    final theme = AppColors.getTheme();

    return Scaffold(
      backgroundColor: theme.rootBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Header section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.isFromSetup)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_rounded, color: theme.textColor),
                            onPressed: () {
                              AppHaptics.lightImpact();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.translate_rounded,
                          color: theme.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Choose Language / Nyelv',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select your preferred language\nVálaszd ki a kívánt nyelvet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textColor.withValues(alpha: 0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Language options list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _options.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _options[index];
                      final isSelected = item.langId == _selectedCode;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onSelectLanguage(item),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.primary.withValues(alpha: 0.08)
                                  : theme.textColor.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? theme.primary
                                    : theme.textColor.withValues(alpha: 0.12),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Circular flag badge
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.textColor.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: theme.textColor.withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: EmojiRichText(
                                    text: item.flag,
                                    defaultStyle: const TextStyle(fontSize: 22),
                                    emojiStyle: const TextStyle(
                                      fontSize: 22,
                                      fontFamily: "Noto Color Emoji",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Native and English language title
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.nativeName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? theme.primary : theme.textColor,
                                        ),
                                      ),
                                      if (item.nativeName.toLowerCase() != item.englishName.toLowerCase()) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.englishName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: theme.textColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Selection checkmark or trailing indicator
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: theme.primary,
                                    size: 24,
                                  )
                                else
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: theme.textColor.withValues(alpha: 0.3),
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Footer note
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    'You can always change this later in Settings\nKésőbb a Beállításokban bármikor módosíthatod',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textColor.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),

            // Loading overlay when downloading external language
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    decoration: BoxDecoration(
                      color: theme.rootBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: theme.primary),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage.isNotEmpty ? _loadingMessage : 'Loading...',
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
