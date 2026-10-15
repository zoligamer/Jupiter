import 'package:flutter/material.dart';
import 'package:jupiter/language.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../storage.dart';

class PeriodsElementWidget extends StatelessWidget {
  final String displayName;
  final String formattedStartTime;
  final String formattedStartTimeYear;
  final String formattedEndTime;
  final String formattedEndTimeYear;
  final bool isActive;
  final PeriodType periodType;
  final int endTime;
  final int startTime;
  final bool expired;

  const PeriodsElementWidget({
    super.key,
    required this.displayName,
    required this.formattedStartTime,
    required this.formattedEndTime,
    required this.formattedEndTimeYear,
    required this.formattedStartTimeYear,
    required this.isActive,
    required this.periodType,
    required this.startTime,
    required this.endTime,
    required this.expired,
  });

  String _getTypeLabel(PeriodType type) {
    switch (type) {
      case PeriodType.timetableRegistration:
        return 'ÓRARENDFELVÉTEL';
      case PeriodType.gradingTime:
        return 'VIZSGAIDŐSZAK';
      case PeriodType.loginTime:
        return 'BEJELENTKEZÉS';
      case PeriodType.pregivenGradingAccepting:
        return 'MEGTEKINTÉS';
      case PeriodType.timetableFinalization:
        return 'VÉGLEGESÍTÉS';
      case PeriodType.coursesRegistration:
        return 'TÁRGYFELVÉTEL';
      case PeriodType.nerdTime:
        return 'SZORGALMI IDŐSZAK';
      case PeriodType.examTime:
        return 'VIZSGÁK';
      case PeriodType.signinTime:
        return 'BEIRATKOZÁS';
      default:
        return 'IDŐSZAK';
    }
  }

  IconData _getTypeIcon(PeriodType type) {
    switch (type) {
      case PeriodType.timetableRegistration:
        return Icons.event_note_rounded;
      case PeriodType.gradingTime:
        return Icons.star_rounded;
      case PeriodType.loginTime:
        return Icons.badge_rounded;
      case PeriodType.pregivenGradingAccepting:
        return Icons.fact_check_rounded;
      case PeriodType.timetableFinalization:
        return Icons.checklist_rounded;
      case PeriodType.coursesRegistration:
        return Icons.menu_book_rounded;
      case PeriodType.nerdTime:
        return Icons.school_rounded;
      case PeriodType.examTime:
        return Icons.history_edu_rounded;
      case PeriodType.signinTime:
        return Icons.app_registration_rounded;
      default:
        return Icons.date_range_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    final double fontScale = DataCache.getFontScale();

    final now = DateTime.now().millisecondsSinceEpoch;
    final totalDuration = (endTime - startTime).clamp(1, double.infinity);
    final elapsed = (now - startTime).clamp(0, totalDuration);
    final double progress = (elapsed / totalDuration).clamp(0.0, 1.0);

    Color cardBg = isDark
        ? theme.secondary.withValues(alpha: 0.35)
        : theme.secondary.withValues(alpha: 0.10);
    Color cardBorder = isDark
        ? theme.secondary.withValues(alpha: 0.55)
        : theme.secondary.withValues(alpha: 0.25);
    double borderWidth = 1.0;

    if (isActive) {
      cardBorder = theme.currentClassGreen;
      cardBg = isDark
          ? theme.currentClassGreen.withValues(alpha: 0.08)
          : theme.currentClassGreen.withValues(alpha: 0.04);
      borderWidth = 1.4;
    } else if (expired) {
      cardBg = isDark
          ? theme.secondary.withValues(alpha: 0.18)
          : theme.secondary.withValues(alpha: 0.05);
      cardBorder = isDark
          ? theme.secondary.withValues(alpha: 0.30)
          : theme.secondary.withValues(alpha: 0.15);
    }

    final accentColor = isActive
        ? theme.currentClassGreen
        : (expired ? theme.textColor.withValues(alpha: 0.5) : theme.primary);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: cardBorder,
          width: borderWidth,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.currentClassGreen.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. SOR: Időszak típus matrica balra, Státusz badge jobbra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTypeIcon(periodType),
                      size: 12 * fontScale,
                      color: accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getTypeLabel(periodType),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10.5 * fontScale,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Jobb oldali státusz badge
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.currentClassGreen,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: theme.currentClassGreen.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "AKTÍV",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5 * fontScale,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                )
              else if (expired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "LEJÁRT",
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5 * fontScale,
                      fontFamily: 'monospace',
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.primary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "KÖVETKEZŐ",
                    style: TextStyle(
                      color: theme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5 * fontScale,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),

          // 2. SOR: Időszak címe
          Text(
            displayName,
            style: TextStyle(
              color: isDark ? Colors.white : theme.textColor,
              fontSize: 15.5 * fontScale,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 7),

          // 3. SOR: Dátumtartomány balra, Hátralévő idő jobbra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13 * fontScale,
                      color: theme.textColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "$formattedStartTime – $formattedEndTime",
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.75),
                          fontSize: 11.5 * fontScale,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                expired
                    ? AppStrings.getStringWithParams(
                        AppStrings.getLanguagePack().periodPage_ExpiredDays,
                        [-(Duration(milliseconds: endTime - now).inDays + 1) * (Duration(milliseconds: endTime - now).inDays == 0 ? -1 : 1)],
                      )
                    : !isActive
                        ? AppStrings.getStringWithParams(
                            AppStrings.getLanguagePack().periodPage_StartDays,
                            [Duration(milliseconds: startTime - now).inDays + 1],
                          )
                        : AppStrings.getStringWithParams(
                            AppStrings.getLanguagePack().periodPage_ActiveDays,
                            [Duration(milliseconds: endTime - now).inDays + 1],
                          ),
                style: TextStyle(
                  color: isActive
                      ? theme.currentClassGreen
                      : theme.textColor.withValues(alpha: 0.6),
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 11.5 * fontScale,
                ),
              ),
            ],
          ),

          // Aktív időszak esetén haladási sáv
          if (isActive) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.currentClassGreen.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(theme.currentClassGreen),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}