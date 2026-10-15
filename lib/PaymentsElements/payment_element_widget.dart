import 'package:flutter/material.dart';
import 'package:jupiter/API/api_coms.dart';
import 'package:jupiter/language.dart';
import '../Misc/emojirich_text.dart';
import '../colors.dart';
import '../storage.dart';

class PaymentElementWidget extends StatelessWidget{
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
    double fontScale = DataCache.getFontScale();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dueDate = DateTime.fromMillisecondsSinceEpoch(dueDateMs);
    final isNonTimed = dueDateMs <= 0;
    final isMissed = dueDateMs < nowMs && !isNonTimed && !completed;

    final isPositive = ammount > 0;
    final isNegative = ammount < 0;

    final cardColor = isIgnored
        ? AppColors.getTheme().textColor.withValues(alpha: 0.45)
        : completed
            ? (isPositive ? AppColors.getTheme().currentClassGreen : AppColors.getTheme().onPrimaryContainer)
            : (isMissed ? AppColors.getTheme().errorRed : Colors.amber.shade600);

    final curr = (currency != null && currency!.isNotEmpty) ? currency! : 'Ft';
    final absAmount = ammount.abs();
    final formattedNum = absAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');

    final formattedAmount = isIgnored
        ? "$formattedNum $curr"
        : completed
            ? (isPositive ? "+$formattedNum $curr" : (isNegative ? "-$formattedNum $curr" : "$formattedNum $curr"))
            : "$formattedNum $curr";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
        border: Border.all(
            color: cardColor.withValues(alpha: 0.5),
            width: 1
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.getTheme().textColor,
              fontWeight: FontWeight.w700,
              fontSize: 15.0 * fontScale,
            ),
          ),
          if (isIgnored) ...[
            const SizedBox(height: 3),
            Text(
              "Belső átvezetés (gyűjtőszámla)",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                fontSize: 11.5 * fontScale,
              ),
            ),
          ] else if (direction != null && direction!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              direction!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
                fontSize: 12.0 * fontScale,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              EmojiRichText(
                text: isIgnored ? '🔄' : (completed ? (isPositive ? '📥' : '📤') : (isMissed ? '🙉' : '💰')),
                defaultStyle: TextStyle(
                  color: cardColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20.0 * fontScale,
                ),
                emojiStyle: TextStyle(
                    color: AppColors.getTheme().onPrimaryContainer,
                    fontSize: (isMissed ? 26.0 : 20.0) * fontScale,
                    fontFamily: "Noto Color Emoji"
                ),
              ),
              Expanded(
                  flex: 2,
                  child: Text(
                    formattedAmount,
                    style: TextStyle(
                      color: cardColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18.0 * fontScale,
                    ),
                    textAlign: TextAlign.center,
                  )
              ),
              !isNonTimed ? const Expanded(flex: 1, child: SizedBox()) : const SizedBox(),
              !isNonTimed ? Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      dueDate.year.toString(),
                      style: TextStyle(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w400,
                        fontSize: 12.0 * fontScale,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${Generic.monthToText(dueDate.month)} ${dueDate.day}',
                      style: TextStyle(
                        color: AppColors.getTheme().textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.0 * fontScale,
                      ),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ) : const SizedBox(),
            ],
          ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.5),
                fontSize: 11.0 * fontScale,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 5),
          !isNonTimed && !completed ? Text(
            isMissed ? AppStrings.getStringWithParams(AppStrings.getLanguagePack().paymentPage_PaymentMissedTime, [-(Duration(milliseconds: dueDateMs - nowMs).inDays + 1)]) : AppStrings.getStringWithParams(AppStrings.getLanguagePack().paymentPage_PaymentDeadlineTime, [Duration(milliseconds: dueDateMs - nowMs).inDays + 1]),
            style: TextStyle(
              color: isMissed ? AppColors.getTheme().errorRed.withValues(alpha: 0.8) : AppColors.getTheme().textColor.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              fontSize: 12.0 * fontScale,
            ),
            textAlign: TextAlign.center,
          ) : const SizedBox(),
        ],
      ),
    );
  }
}