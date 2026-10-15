import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../API/api_coms.dart';
import '../Pages/main_page.dart';
import '../colors.dart';
import '../haptics.dart';
import '../storage.dart' as storage;
import '../Pages/startup_page.dart' as root_page;
import '../Misc/emojirich_text.dart';
import '../language.dart';
import '../notifications.dart';
import '../Pages/settings_page.dart';
import '../Pages/petitions_page.dart';
import '../Pages/profile_hub_page.dart';
import '../Pages/document_storage_page.dart';
import '../Misc/auto_updater.dart';
import 'to_office_service.dart';
import 'dart:convert' as conv;

class AppDrawer extends StatefulWidget {
  final String loggedInUsername;
  final String loggedInURL;

  const AppDrawer({super.key, required this.loggedInUsername, required this.loggedInURL});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<Term> _terms = [];
  String? _selectedTermId;
  bool _isLoadingTerms = true;
  double? _accountBalance;
  String _accountCurrency = 'HUF';
  bool _isLoadingBalance = true;
  int _unreadCount = 0;
  String? _userAvatarBase64;
  String? _fallbackColorHex;

  @override
  void initState() {
    super.initState();
    _selectedTermId = storage.DataCache.getSelectedTermId();
    _accountBalance = storage.DataCache.getAccountBalance();
    _accountCurrency = storage.DataCache.getAccountBalanceCurrency();
    _unreadCount = storage.DataCache.getUnreadMailCount();
    _isLoadingBalance = _accountBalance == null;
    _userAvatarBase64 = storage.DataCache.getCachedUserAvatarBase64();
    _fallbackColorHex = storage.DataCache.getCachedFallbackColor();
    _loadTerms();
    _loadFinancialAndMessages();
    _loadUserAvatarIfNeeded();
  }

  Future<void> _loadUserAvatarIfNeeded() async {
    if (_userAvatarBase64 == null) {
      final img = await UserProfileRequest.getUserAvatar();
      if (mounted && img != null && img.isNotEmpty) {
        setState(() {
          _userAvatarBase64 = img;
        });
      }
    }
  }

  Future<void> _loadTerms() async {
    final terms = await TermsRequest.getTerms();
    if (mounted) {
      setState(() {
        _terms = terms;
        _selectedTermId = storage.DataCache.getSelectedTermId() ?? (_terms.isNotEmpty ? _terms.last.id : null);
        _isLoadingTerms = false;
      });
    }
  }

  Future<void> _loadFinancialAndMessages() async {
    try {
      final balanceFuture = CashinRequest.getCollectiveInvoiceBalance();
      final unreadFuture = MailRequest.getUnreadMessageCount();
      final results = await Future.wait([balanceFuture, unreadFuture]);
      if (mounted) {
        setState(() {
          _accountBalance = results[0] as double?;
          _accountCurrency = storage.DataCache.getAccountBalanceCurrency();
          _unreadCount = (results[1] as int?) ?? 0;
          _isLoadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
        });
      }
    }
  }

  String _formatBalance(double amount, String currency) {
    int intVal = amount.round();
    String s = intVal.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String formatted = s.replaceAllMapped(reg, (Match m) => '${m[1]} ');
    String currSymbol = currency == 'HUF' ? 'Ft' : currency;
    return '$formatted $currSymbol';
  }

  Widget _buildVersionBadge(BuildContext context, bool hasUpdate, String? latestTag) {
    final currVer = AppUpdater.installedVersion.isNotEmpty
        ? AppUpdater.installedVersion
        : "1.0.5";
    final displayVer = currVer.startsWith('v') ? currVer : "v$currVer";

    if (hasUpdate && latestTag != null && latestTag.isNotEmpty) {
      final cleanLatest = latestTag.startsWith('v') ? latestTag : "v$latestTag";
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            AppHaptics.attentionLightImpact();
            final rootCtx = HomePageState.getContext() ?? context;
            Navigator.pop(context);
            AppUpdater.checkAndInstallUpdate(rootCtx, force: true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.getTheme().errorRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.getTheme().errorRed.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.getTheme().errorRed,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  cleanLatest,
                  style: TextStyle(
                    color: AppColors.getTheme().errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Up-to-date state
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          AppHaptics.lightImpact();
          final rootCtx = HomePageState.getContext() ?? context;
          AppUpdater.checkAndInstallUpdate(rootCtx, force: true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.getTheme().textColor.withValues(alpha: 0.45),
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                displayVer,
                style: TextStyle(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFallbackColor() {
    if (_fallbackColorHex != null && _fallbackColorHex!.isNotEmpty) {
      try {
        final clean = _fallbackColorHex!.replaceAll('#', '').trim();
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {}
    }
    return AppColors.getTheme().primary;
  }

  Widget _buildDrawerAvatar() {
    if (_userAvatarBase64 != null && _userAvatarBase64!.isNotEmpty) {
      try {
        final bytes = conv.base64Decode(_userAvatarBase64!);
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.getTheme().primary, width: 2),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {}
    }

    return CircleAvatar(
      backgroundColor: _getFallbackColor(),
      radius: 28,
      child: Text(
        widget.loggedInUsername.isNotEmpty ? widget.loggedInUsername[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.getTheme().rootBackground,
      child: SafeArea( // this solves navbar overlap!
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- header (welcome) - clickable to open ProfileHubPage ---
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  AppHaptics.lightImpact();
                  Navigator.pop(context); // close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileHubPage()),
                  ).then((_) {
                    setState(() {
                      _userAvatarBase64 = storage.DataCache.getCachedUserAvatarBase64();
                      _fallbackColorHex = storage.DataCache.getCachedFallbackColor();
                    });
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                    border: Border(bottom: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.1), width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDrawerAvatar(),
                          ValueListenableBuilder<bool>(
                            valueListenable: AppUpdater.hasUpdateNotifier,
                            builder: (context, hasUpdate, _) {
                              return ValueListenableBuilder<String?>(
                                valueListenable: AppUpdater.latestVersionNotifier,
                                builder: (context, latestTag, _) {
                                  return _buildVersionBadge(context, hasUpdate, latestTag);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: EmojiRichText(
                              text: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_Greet, [storage.DataCache.getEffectiveDisplayName()]),
                              defaultStyle: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 18),
                              emojiStyle: TextStyle(color: AppColors.getTheme().textColor, fontSize: 20, fontFamily: "Noto Color Emoji"),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.getTheme().textColor.withValues(alpha: 0.4)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      EmojiRichText(
                        text: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_LoginPlace, [widget.loggedInURL]),
                        defaultStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7), fontSize: 13),
                        emojiStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7), fontSize: 13, fontFamily: "Noto Color Emoji"),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- Scrollable middle section ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    // --- School Account Balance Card ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            AppHaptics.lightImpact();
                            Navigator.pop(context);
                            HomePageState.navigateToView(2); // Payments view
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.getTheme().currentClassGreen.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppColors.getTheme().currentClassGreen),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.getLanguagePack().topmenu_AccountBalance,
                                        style: TextStyle(
                                          color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (_isLoadingBalance && _accountBalance == null)
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTheme().currentClassGreen),
                                        )
                                      else
                                        Text(
                                          _accountBalance != null
                                              ? _formatBalance(_accountBalance!, _accountCurrency)
                                              : '0 Ft',
                                          style: TextStyle(
                                            color: AppColors.getTheme().textColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- Unread Messages Card ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            AppHaptics.lightImpact();
                            Navigator.pop(context);
                            HomePageState.navigateToView(4); // Messages view
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _unreadCount > 0
                                  ? AppColors.getTheme().primary.withValues(alpha: 0.08)
                                  : AppColors.getTheme().textColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _unreadCount > 0
                                    ? AppColors.getTheme().primary.withValues(alpha: 0.3)
                                    : AppColors.getTheme().textColor.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _unreadCount > 0
                                        ? AppColors.getTheme().primary.withValues(alpha: 0.2)
                                        : AppColors.getTheme().textColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _unreadCount > 0 ? Icons.mark_email_unread_rounded : Icons.mail_outline_rounded,
                                    size: 20,
                                    color: _unreadCount > 0 ? AppColors.getTheme().primary : AppColors.getTheme().textColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.getLanguagePack().topmenu_MessagesTitle,
                                        style: TextStyle(
                                          color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _unreadCount > 0
                                            ? AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_UnreadMessagesBadge, ['$_unreadCount'])
                                            : AppStrings.getLanguagePack().topmenu_NoUnreadMessages,
                                        style: TextStyle(
                                          color: _unreadCount > 0 ? AppColors.getTheme().primary : AppColors.getTheme().textColor,
                                          fontSize: 14,
                                          fontWeight: _unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.getTheme().errorRed,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$_unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // --- Semester Selector ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.getTheme().primary),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.getLanguagePack().topmenu_SemesterSelectorTitle.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.getTheme().primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (_isLoadingTerms)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTheme().secondary),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "...",
                                      style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            else if (_terms.isEmpty)
                              Text(
                                "-",
                                style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 13),
                              )
                            else
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _terms.any((t) => t.id == _selectedTermId)
                                      ? _selectedTermId
                                      : (_terms.isNotEmpty ? _terms.last.id : null),
                                  dropdownColor: AppColors.getTheme().rootBackground,
                                  icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTheme().textColor),
                                  isExpanded: true,
                                  isDense: true,
                                  style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 14),
                                  items: _terms.map((Term term) {
                                    return DropdownMenuItem<String>(
                                      value: term.id,
                                      child: Text(
                                        term.termName,
                                        style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? val) async {
                                    if (val == null || val == _selectedTermId) return;
                                    AppHaptics.lightImpact();
                                    final chosenTerm = _terms.firstWhere(
                                      (t) => t.id == val,
                                      orElse: () => _terms.first,
                                    );
                                    setState(() {
                                      _selectedTermId = val;
                                    });
                                    await storage.DataCache.setSelectedTermId(chosenTerm.id);
                                    await storage.DataCache.setSelectedTermName(chosenTerm.termName);

                                    HomePageState.onSemesterChanged();

                                    if (Platform.isAndroid) {
                                      Fluttertoast.showToast(
                                        msg: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_SemesterToast, [chosenTerm.termName]),
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.SNACKBAR,
                                        backgroundColor: AppColors.getTheme().rootBackground,
                                        textColor: AppColors.getTheme().textColor,
                                      );
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // --- menus ---
                    ListTile(
                      leading: Icon(Icons.assignment_turned_in_rounded, color: AppColors.getTheme().primary),
                      title: Text(
                        AppStrings.getLanguagePack().topmenu_PetitionsTitle,
                        style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.pop(context); // closes drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PetitionsPage()),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.folder_shared_rounded, color: AppColors.getTheme().primary),
                      title: Text(
                        AppStrings.getLanguagePack().topmenu_DocumentsTitle,
                        style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.pop(context); // closes drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DocumentStoragePage()),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.settings_rounded, color: AppColors.getTheme().textColor),
                      title: Text(AppStrings.getLanguagePack().topmenu_buttons_Settings, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.pop(context); // closes drawer

                        // open new page >> old popup dart
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        ).then((_) {
                          // check if calendar needs to refresh if closing menu
                          HomePageState.settingsUserWeekOffsetChangeDetect();
                        });
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.system_update_rounded, color: AppColors.getTheme().textColor),
                      title: Text(AppStrings.getLanguagePack().popup_case7_ButtonUpdateNow, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
                      trailing: ValueListenableBuilder<bool>(
                        valueListenable: AppUpdater.hasUpdateNotifier,
                        builder: (context, hasUpdate, _) {
                          if (hasUpdate) {
                            final latestTag = AppUpdater.latestVersionNotifier.value ?? '';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.getTheme().errorRed.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.getTheme().errorRed.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.getTheme().errorRed,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      "!",
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    latestTag.isNotEmpty ? latestTag : "Update",
                                    style: TextStyle(
                                      color: AppColors.getTheme().errorRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Icon(Icons.chevron_right_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.3));
                        },
                      ),
                      onTap: () {
                        AppHaptics.lightImpact();
                        final rootContext = HomePageState.getContext() ?? context;
                        Navigator.pop(context);
                        AppUpdater.checkAndInstallUpdate(rootContext, force: true);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                      title: Text(AppStrings.getLanguagePack().topmenu_buttons_SupportDev, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.pop(context);
                        if(Platform.isAndroid){
                          launchUrl(Uri.parse('https://buymeacoffee.com/zoligamer')).whenComplete(() {
                            Fluttertoast.showToast(msg: '❤️', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.SNACKBAR, backgroundColor: AppColors.getTheme().rootBackground, textColor: AppColors.getTheme().textColor);
                          });
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.bug_report_rounded, color: AppColors.getTheme().textColor),
                      title: Text(AppStrings.getLanguagePack().topmenu_buttons_Bugreport, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600)),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.pop(context);
                        if(Platform.isAndroid){
                          launchUrl(Uri.parse('https://github.com/zoligamer/Neptun-Mobile-fork/issues/new/choose'));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // --- bottom (logout) ---
            Divider(color: AppColors.getTheme().textColor.withValues(alpha: 0.1), height: 1),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: AppColors.getTheme().errorRed),
              title: Text(AppStrings.getLanguagePack().topmenu_buttons_Logout, style: TextStyle(color: AppColors.getTheme().errorRed, fontWeight: FontWeight.w700)),
              onTap: () {
                AppHaptics.lightImpact();
                Future.delayed(Duration.zero, ()async{
                  ToOfficeService.reset();
                  await storage.DataCache.dataWipe();
                  await AppNotifications.cancelScheduledNotifs();
                }).whenComplete((){
                  Navigator.popUntil(context, (route) => route.willHandlePopInternally);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const root_page.Splitter()));
                });
                if(Platform.isAndroid){
                  Fluttertoast.showToast(msg: AppStrings.getLanguagePack().topmenu_buttons_LogoutSuccessToast, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.SNACKBAR, backgroundColor: AppColors.getTheme().rootBackground, textColor: AppColors.getTheme().textColor);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}