import 'dart:core';
import 'package:flutter/material.dart';
import 'package:jupiter/API/api_coms.dart';
import 'package:jupiter/Misc/popup.dart';
import '../colors.dart';
import '../haptics.dart';
import '../storage.dart';

class MailPopupDisplayTexts {
  static String title = "";
  static List<InlineSpan> description = [];
  static String mailID = "";
}

class MailElementWidget extends StatelessWidget {
  final String subject;
  final String details;
  final String sender;
  final int sendTime;
  final bool isRead;
  final String mailID;
  final Function(MailElementWidget) callback;

  const MailElementWidget({
    super.key,
    required this.subject,
    required this.details,
    required this.sender,
    required this.sendTime,
    required this.isRead,
    required this.mailID,
    required this.callback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    final double fontScale = DataCache.getFontScale();

    final sendDate = DateTime.fromMillisecondsSinceEpoch(sendTime);
    final now = DateTime.now();
    final isToday = sendDate.year == now.year && sendDate.month == now.month && sendDate.day == now.day;
    final dateStr = isToday
        ? '${sendDate.hour.toString().padLeft(2, '0')}:${sendDate.minute.toString().padLeft(2, '0')}'
        : '${sendDate.month}. ${sendDate.day}.';

    final pattern = RegExp(r'<a[^>]*>(.*?)</a>');
    List<String> parts = details.split(pattern);
    final previewText = parts.join(' ').replaceAll('\n', ' ').replaceAll('\t', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    Color cardBg = isDark
        ? theme.secondary.withValues(alpha: 0.35)
        : theme.secondary.withValues(alpha: 0.10);
    Color cardBorder = isDark
        ? theme.secondary.withValues(alpha: 0.55)
        : theme.secondary.withValues(alpha: 0.25);
    double borderWidth = 1.0;

    if (!isRead) {
      cardBorder = theme.primary.withValues(alpha: 0.65);
      cardBg = isDark
          ? theme.primary.withValues(alpha: 0.12)
          : theme.primary.withValues(alpha: 0.06);
      borderWidth = 1.3;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: GestureDetector(
        onTap: () {
          AppHaptics.lightImpact();
          MailPopupDisplayTexts.title = subject;
          MailPopupDisplayTexts.description = Generic.textToInlineSpan(details);
          MailPopupDisplayTexts.mailID = mailID;

          PopupWidgetHandler(
            mode: 3,
            callback: (_) {},
            onCloseCallback: () {
              callback(this);
            },
          );
          PopupWidgetHandler.doPopup(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: cardBorder,
              width: borderWidth,
            ),
            boxShadow: !isRead
                ? [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.14),
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
              // 1. SOR: Feladó balra, Dátum matrica jobbra
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14 * fontScale,
                          color: !isRead ? theme.primary : theme.textColor.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            sender,
                            style: TextStyle(
                              color: !isRead ? theme.primary : theme.textColor.withValues(alpha: 0.75),
                              fontWeight: !isRead ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12.0 * fontScale,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: !isRead
                          ? theme.primary.withValues(alpha: 0.15)
                          : theme.textColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        color: !isRead ? theme.primary : theme.textColor.withValues(alpha: 0.75),
                        fontSize: 10.5 * fontScale,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),

              // 2. SOR: Olvasatlan pötty + Tárgy
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isRead) ...[
                    Container(
                      width: 7 * fontScale,
                      height: 7 * fontScale,
                      margin: const EdgeInsets.only(top: 5, right: 7),
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: Text(
                      subject,
                      style: TextStyle(
                        color: isDark ? Colors.white : theme.textColor,
                        fontWeight: !isRead ? FontWeight.w800 : FontWeight.w700,
                        fontSize: 15.0 * fontScale,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 3. SOR: Szöveges előnézet
              Text(
                previewText.isEmpty ? 'Nincs szöveges előnézet' : '$previewText...',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.55),
                  fontSize: 12.0 * fontScale,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}