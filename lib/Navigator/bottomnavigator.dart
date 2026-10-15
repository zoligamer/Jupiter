import 'package:flutter/material.dart';
import 'package:jupiter/colors.dart';
import 'package:jupiter/language.dart';
import '../Pages/main_page.dart';
import '../haptics.dart';

class BottomNavigatorWidget extends StatelessWidget {
  final HomePageState homePage;
  const BottomNavigatorWidget({super.key, required this.homePage});

  // A felhasználó által kért és megszeretett rugalmas (jiggly spring) cubic-bezier görbe
  static const Curve jigglyCurve = Cubic(0.34, 1.45, 0.64, 1.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: AppColors.getTheme().rootBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              // Finoman animált menücímke kiemelő színnel
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.25),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _getNameOfMenu(homePage.currentView).toUpperCase(),
                  key: ValueKey<int>(homePage.currentView),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.getTheme().primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Lebegő dokk ruganyos (jiggly) sikló indikátorral
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth - 32; // 16 margó mindkét oldalon
                  final tabWidth = (totalWidth - 12) / 5; // 6 belső padding mindkét oldalon

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Ruganyos túllendüléssel (jiggly spring) sikló kapszula indikátor
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: jigglyCurve,
                          left: homePage.currentView * tabWidth,
                          width: tabWidth,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.getTheme().primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.getTheme().primary.withValues(alpha: 0.55),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.getTheme().primary.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Navigációs gombok
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            _buildNavigationButton(0, Icons.calendar_month_rounded, Icons.calendar_month_outlined),
                            _buildNavigationButton(1, Icons.backpack_rounded, Icons.backpack_outlined),
                            _buildNavigationButton(2, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined),
                            _buildNavigationButton(3, Icons.timer_rounded, Icons.timer_outlined),
                            _buildNavigationButton(4, Icons.email_rounded, Icons.email_outlined),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  String _getNameOfMenu(int idx) {
    switch (idx) {
      case 0:
        return AppStrings.getLanguagePack().view_header_Calendar;
      case 1:
        return AppStrings.getLanguagePack().view_header_Subjects;
      case 2:
        return AppStrings.getLanguagePack().view_header_Payments;
      case 3:
        return AppStrings.getLanguagePack().view_header_Periods;
      case 4:
        return AppStrings.getLanguagePack().view_header_Messages;
      default:
        return '';
    }
  }

  Widget _buildNavigationButton(int index, IconData filledIcon, IconData outlinedIcon) {
    final bool isSelected = homePage.currentView == index;

    Widget iconWidget = Icon(
      isSelected ? filledIcon : outlinedIcon,
      color: isSelected
          ? AppColors.getTheme().primary
          : AppColors.getTheme().textColor.withValues(alpha: 0.45),
      size: 24,
    );

    if (index == 4 && homePage.unreadMailCount > 0) {
      iconWidget = Badge.count(
        count: homePage.unreadMailCount,
        backgroundColor: AppColors.getTheme().primary,
        textColor: AppColors.getTheme().onPrimary,
        child: iconWidget,
      );
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!isSelected) {
            homePage.switchView(index);
            AppHaptics.lightImpact();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.transparent,
          child: Center(
            child: AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 350),
              curve: jigglyCurve,
              child: iconWidget,
            ),
          ),
        ),
      ),
    );
  }
}
