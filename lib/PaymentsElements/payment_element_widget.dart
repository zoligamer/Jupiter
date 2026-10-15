import 'package:flutter/material.dart';
import 'package:jupiter/API/api_coms.dart';
import '../colors.dart';
import '../storage.dart';

class PaymentElementWidget extends StatelessWidget {
  final String ID;
  final int ammount;
  final int dueDateMs;
  final String name;
  final bool completed;
  final String? direction;
  final String? note;
  final String? currency;
  final bool isIgnored;

  const PaymentElementWidget({
    super.key,
    required this.ammount,
    required this.dueDateMs,
    required this.name,
    required this.ID,
    required this.completed,
    this.direction,
    this.note,
    this.currency,
    this.isIgnored = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    final double fontScale = DataCache.getFontScale();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dueDate = DateTime.fromMillisecondsSinceEpoch(dueDateMs);
    final isNonTimed = dueDateMs <= 0;
    final isMissed = dueDateMs < nowMs && !isNonTimed && !completed;

    final isPositive = ammount > 0;
    final isNegative = ammount < 0;

    final cardColor = isIgnored
        ? theme.textColor.withValues(alpha: 0.5)
        : completed
            ? (isPositive ? theme.currentClassGreen : theme.primary)
            : (isMissed ? theme.errorRed : const Color(0xFFFFA726));

    final curr = (currency != null && currency!.isNotEmpty) ? currency! : 'Ft';
    final absAmount = ammount.abs();
    final formattedNum = absAmount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        );

    final formattedAmount = isIgnored
        ? "$formattedNum $curr"
        : completed
            ? (isPositive ? "+$formattedNum $curr" : (isNegative ? "-$formattedNum $curr" : "$formattedNum $curr"))
            : "$formattedNum $curr";

    Color cardBg = isDark
        ? theme.secondary.withValues(alpha: 0.35)
        : theme.secondary.withValues(alpha: 0.10);
    Color cardBorder = isDark
        ? theme.secondary.withValues(alpha: 0.55)
        : theme.secondary.withValues(alpha: 0.25);
    double borderWidth = 1.0;

    if (isMissed) {
      cardBorder = theme.errorRed.withValues(alpha: 0.55);
      cardBg = isDark
          ? theme.errorRed.withValues(alpha: 0.08)
          : theme.errorRed.withValues(alpha: 0.04);
      borderWidth = 1.2;
    } else if (completed && isPositive) {
      cardBorder = theme.currentClassGreen.withValues(alpha: 0.40);
      cardBg = isDark
          ? theme.currentClassGreen.withValues(alpha: 0.07)
          : theme.currentClassGreen.withValues(alpha: 0.03);
    }

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
        boxShadow: (completed && isPositive)
            ? [
                BoxShadow(
                  color: theme.currentClassGreen.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. SOR: Határidő balra, Státusz matrica jobbra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isMissed
                      ? theme.errorRed.withValues(alpha: 0.15)
                      : theme.textColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isMissed
                        ? theme.errorRed.withValues(alpha: 0.4)
                        : theme.textColor.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNonTimed ? Icons.all_inclusive_rounded : Icons.calendar_today_rounded,
                      size: 11 * fontScale,
                      color: isMissed ? theme.errorRed : theme.textColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isNonTimed
                          ? "HATÁRIDŐ NÉLKÜLI"
                          : "${dueDate.year}. ${Generic.monthToText(dueDate.month)} ${dueDate.day}.",
                      style: TextStyle(
                        color: isMissed ? theme.errorRed : theme.textColor.withValues(alpha: 0.8),
                        fontSize: 10.5 * fontScale,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Jobb oldali státusz badge
              if (isIgnored) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "ÁTVEZETÉS",
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.8),
                      fontSize: 10.5 * fontScale,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ] else if (completed) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isPositive ? theme.currentClassGreen : theme.primary).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPositive ? theme.currentClassGreen : theme.primary,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: isPositive ? theme.currentClassGreen : theme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isPositive ? "JÓVÁÍRVA" : "BEFIZETVE",
                        style: TextStyle(
                          color: isPositive ? theme.currentClassGreen : theme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5 * fontScale,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isMissed) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.errorRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        "KÉSEDELEM",
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
                    color: const Color(0xFFFFA726).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFA726),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "FIZETENDŐ",
                    style: TextStyle(
                      color: const Color(0xFFFFA726),
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5 * fontScale,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),

          // 2. SOR: Tétel neve
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
          const SizedBox(height: 8),

          // 3. SOR: Irány/Megjegyzés balra, Összeg kiemelve jobbra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 14 * fontScale,
                      color: cardColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        direction ?? (isPositive ? "Jóváírás" : "Kiadás"),
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.65),
                          fontSize: 12.0 * fontScale,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedAmount,
                style: TextStyle(
                  color: cardColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16.5 * fontScale,
                  fontFamily: 'monospace',
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.45),
                fontSize: 11.0 * fontScale,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}