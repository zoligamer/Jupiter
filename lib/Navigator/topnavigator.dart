import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../Pages/main_page.dart';
import '../colors.dart';
import '../haptics.dart';
import '../Misc/emojirich_text.dart';
import '../Misc/auto_updater.dart';
import '../storage.dart' as storage;
import '../language.dart';

class TopNavigatorWidget extends StatelessWidget {
  final HomePageState homePage;
  final String displayString;
  final String smallHintText;
  final String loggedInUsername;
  final String loggedInURL;

  const TopNavigatorWidget({
    super.key,
    required this.homePage,
    required this.displayString,
    required this.smallHintText,
    required this.loggedInUsername,
    required this.loggedInURL,
  });

  void _showCalendarFilterSheet(BuildContext context) {
    AppHaptics.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getTheme().rootBackground,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final showTO = storage.DataCache.getShowToOfficeSchedule();
            final showPeriods = storage.DataCache.getShowPeriodsInCalendar();
            final bottomSafe = math.max(
              MediaQuery.of(context).padding.bottom,
              MediaQuery.of(context).viewPadding.bottom,
            );

            return SafeArea(
              bottom: true,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + (bottomSafe > 0 ? 8 : 16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppColors.getTheme().primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.getLanguagePack().calendarFilter_Title,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Különálló kapcsoló 1: Tanulmányi Iroda
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: showTO
                            ? Colors.orange.withValues(alpha: 0.5)
                            : AppColors.getTheme().textColor.withValues(alpha: 0.08),
                      ),
                    ),
                    child: SwitchListTile(
                      activeColor: Colors.orange,
                      title: Text(
                        AppStrings.getLanguagePack().calendarFilter_TO,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        AppStrings.getLanguagePack().calendarFilter_TODesc,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      value: showTO,
                      onChanged: (bool val) async {
                        AppHaptics.lightImpact();
                        await storage.DataCache.setShowToOfficeSchedule(val);
                        setSheetState(() {});
                        homePage.setupCalendar(false);
                      },
                    ),
                  ),

                  // Különálló kapcsoló 2: Időszakok az órarendben
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: showPeriods
                            ? AppColors.getTheme().primary.withValues(alpha: 0.5)
                            : AppColors.getTheme().textColor.withValues(alpha: 0.08),
                      ),
                    ),
                    child: SwitchListTile(
                      activeColor: AppColors.getTheme().primary,
                      title: Text(
                        AppStrings.getLanguagePack().calendarFilter_Periods,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        AppStrings.getLanguagePack().calendarFilter_PeriodsDesc,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      value: showPeriods,
                      onChanged: (bool val) async {
                        AppHaptics.lightImpact();
                        await storage.DataCache.setShowPeriodsInCalendar(val);
                        setSheetState(() {});
                        homePage.setupCalendar(false);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentTermName = storage.DataCache.getSelectedTermName() ?? '';

    return Container(
      color: AppColors.getTheme().rootBackground,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 14,
        right: 14,
        bottom: 8,
      ),
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          homePage.bottomNavCanNavigate = true;
          homePage.bottomNavSwitchValue = 0.0;
        },
        onHorizontalDragEnd: (_) {
          homePage.bottomNavCanNavigate = false;
          homePage.bottomNavSwitchValue = 0.0;
        },
        onHorizontalDragUpdate: (e) {
          if (!homePage.bottomNavCanNavigate) {
            return;
          }
          if (homePage.bottomNavSwitchValue < -50) {
            homePage.bottomNavCanNavigate = false;
            final val = homePage.currentView + 1 > HomePageState.maxBottomNavWidgets - 1 ? 0 : homePage.currentView + 1;
            homePage.switchView(val);
            AppHaptics.lightImpact();
            return;
          } else if (homePage.bottomNavSwitchValue > 50) {
            homePage.bottomNavCanNavigate = false;
            final val = homePage.currentView - 1 < 0 ? HomePageState.maxBottomNavWidgets - 1 : homePage.currentView - 1;
            homePage.switchView(val);
            AppHaptics.lightImpact();
            return;
          }
          homePage.bottomNavSwitchValue -= e.delta.dx;
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Drawer Hamburger Button
            ValueListenableBuilder<bool>(
              valueListenable: AppUpdater.hasUpdateNotifier,
              builder: (context, hasUpdate, _) {
                return Badge(
                  isLabelVisible: hasUpdate,
                  backgroundColor: AppColors.getTheme().errorRed,
                  smallSize: 10,
                  largeSize: 16,
                  label: const Text(
                    "!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  offset: const Offset(-2, -2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Scaffold.of(context).openDrawer();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Icon(
                          Icons.menu_rounded,
                          color: AppColors.getTheme().textColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 12),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayString,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.getTheme().textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (smallHintText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    EmojiRichText(
                      text: smallHintText,
                      defaultStyle: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTheme().primary,
                      ),
                      emojiStyle: TextStyle(
                        fontSize: 13.0,
                        color: AppColors.getTheme().primary,
                        fontFamily: "Noto Color Emoji",
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Right-side actions: Calendar Settings & Semester Pill
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (homePage.currentView == 0) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        AppHaptics.lightImpact();
                        final cur = storage.DataCache.getShowToOfficeSchedule();
                        await storage.DataCache.setShowToOfficeSchedule(!cur);
                        homePage.setupCalendar(false);
                      },
                      onLongPress: () => _showCalendarFilterSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: storage.DataCache.getShowToOfficeSchedule()
                              ? Colors.orange.withValues(alpha: 0.12)
                              : AppColors.getTheme().textColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: storage.DataCache.getShowToOfficeSchedule()
                                ? Colors.orange.withValues(alpha: 0.5)
                                : AppColors.getTheme().textColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: storage.DataCache.getShowToOfficeSchedule()
                                    ? Colors.orange
                                    : AppColors.getTheme().textColor.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              storage.DataCache.getShowToOfficeSchedule()
                                  ? AppStrings.getLanguagePack().topbar_TOOn
                                  : AppStrings.getLanguagePack().topbar_TOOff,
                              style: TextStyle(
                                color: storage.DataCache.getShowToOfficeSchedule()
                                    ? AppColors.getTheme().primary
                                    : AppColors.getTheme().textColor.withValues(alpha: 0.6),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (currentTermName.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () {
                      AppHaptics.lightImpact();
                      Scaffold.of(context).openDrawer();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        currentTermName,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}