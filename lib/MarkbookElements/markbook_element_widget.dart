import 'package:flutter/material.dart';
import 'package:jupiter/Misc/popup.dart';
import '../colors.dart';
import '../haptics.dart';
import '../storage.dart';

typedef Callback = void Function(int, int);

class MarkbookElementWidget extends StatelessWidget {
  final String name;
  final int credit;
  final bool completed;
  final int grade;
  final bool isFailed;
  final Callback onPopupResult;
  final int listIndex;
  final int ghostGrade;

  const MarkbookElementWidget({
    super.key,
    required this.name,
    required this.credit,
    required this.completed,
    required this.grade,
    required this.isFailed,
    required this.onPopupResult,
    required this.listIndex,
    required this.ghostGrade,
  });

  Color getGradeColor() {
    final theme = AppColors.getTheme();
    if (ghostGrade != -1) {
      return theme.textColor.withValues(alpha: 0.6);
    }
    switch (grade) {
      case 5:
        return theme.grade5;
      case 4:
        return theme.grade4;
      case 3:
        return theme.grade3;
      case 2:
        return theme.grade2;
      case 1:
        return theme.grade1;
      default:
        return theme.textColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    final double fontScale = DataCache.getFontScale();
    final gradeColor = getGradeColor();

    Color cardBg = isDark
        ? theme.secondary.withValues(alpha: 0.35)
        : theme.secondary.withValues(alpha: 0.10);
    Color cardBorder = isDark
        ? theme.secondary.withValues(alpha: 0.55)
        : theme.secondary.withValues(alpha: 0.25);
    double borderWidth = 1.0;

    final bool isFailure = (!completed && isFailed) || grade == 1;

    if (completed || ghostGrade != -1) {
      if (grade >= 2 || ghostGrade >= 2) {
        cardBorder = gradeColor.withValues(alpha: 0.45);
        cardBg = isDark
            ? gradeColor.withValues(alpha: 0.08)
            : gradeColor.withValues(alpha: 0.04);
      }
    } else if (isFailure) {
      cardBorder = theme.errorRed.withValues(alpha: 0.55);
      cardBg = isDark
          ? theme.errorRed.withValues(alpha: 0.09)
          : theme.errorRed.withValues(alpha: 0.04);
      borderWidth = 1.2;
    }

    final bool canSimulate = grade < 2 && credit > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: GestureDetector(
        onTap: canSimulate
            ? () {
                AppHaptics.lightImpact();
                PopupWidgetHandler(
                  mode: 0,
                  callback: (r) {
                    onPopupResult(r as int, listIndex);
                  },
                );
                PopupWidgetHandler.doPopup(context);
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: cardBorder,
              width: borderWidth,
            ),
            boxShadow: (completed && grade >= 4)
                ? [
                    BoxShadow(
                      color: gradeColor.withValues(alpha: 0.15),
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
              // 1. SOR: Kredit badge a bal oldalon, Jegy/Státusz matrica a jobb oldalon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.roomHighlightColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      "$credit KREDIT",
                      style: TextStyle(
                        color: theme.onRoomHighlightColor,
                        fontSize: 10.5 * fontScale,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),

                  // Jobb oldali Jegy matrica
                  if (completed || ghostGrade != -1) ...[
                    if (credit == 0 || (grade < 2 && ghostGrade == -1))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.grade5,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              "ALÁÍRVA",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.0 * fontScale,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: gradeColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          ghostGrade != -1 ? "👻 $ghostGrade" : "$grade",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.0 * fontScale,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ] else if (isFailure) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.errorRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            grade == 1 ? "ELÉGTELEN" : "BUKOTT",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5 * fontScale,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.textColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.textColor.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 13,
                            color: theme.textColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            "FELVÉVE",
                            style: TextStyle(
                              color: theme.textColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5 * fontScale,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),

              // 2. SOR: Tantárgy neve
              Text(
                name,
                style: TextStyle(
                  color: isDark ? Colors.white : theme.textColor,
                  fontSize: 15.5 * fontScale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // 3. SOR: Információs alsó sor / Szellemjegy tipp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        completed
                            ? Icons.check_circle_rounded
                            : (isFailure
                                ? Icons.cancel_rounded
                                : (ghostGrade != -1
                                    ? Icons.auto_awesome_rounded
                                    : Icons.hourglass_top_rounded)),
                        size: 13 * fontScale,
                        color: completed
                            ? gradeColor
                            : (isFailure
                                ? theme.errorRed
                                : theme.textColor.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        completed
                            ? "Teljesített tantárgy"
                            : (isFailure
                                ? "Nem teljesített"
                                : (ghostGrade != -1
                                    ? "Szimulált szellemjegy"
                                    : "Értékelésre vár")),
                        style: TextStyle(
                          color: completed
                              ? gradeColor.withValues(alpha: 0.85)
                              : (isFailure
                                  ? theme.errorRed.withValues(alpha: 0.85)
                                  : theme.textColor.withValues(alpha: 0.55)),
                          fontSize: 11.5 * fontScale,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (canSimulate && ghostGrade == -1)
                    Text(
                      "Kattints céljegyhez",
                      style: TextStyle(
                        color: theme.primary.withValues(alpha: 0.85),
                        fontSize: 11.0 * fontScale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}