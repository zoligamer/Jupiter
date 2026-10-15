import 'dart:core';
import 'package:flutter/material.dart';
import 'package:jupiter/API/api_coms.dart';
import 'package:jupiter/Misc/popup.dart';
// import 'package:jupiter/language.dart';

import '../Misc/emojirich_text.dart';
import '../colors.dart';
import '../storage.dart'; // ÚJ: Betűméret lekéréséhez

class MailPopupDisplayTexts{
  static String title = "";
  static List<InlineSpan> description = [];
  static String mailID = "";
}

class MailElementWidget extends StatelessWidget{
  final String subject;
  final String details;
  final String sender;
  final int sendTime;
  final bool isRead;
  final String mailID;
  final Function(MailElementWidget) callback;

  const MailElementWidget({super.key, required this.subject, required this.details, required this.sender, required this.sendTime, required this.isRead, required this.mailID, required this.callback});

  @override
  Widget build(BuildContext context) {
    double fontScale = DataCache.getFontScale(); // ÚJ: Betűméret szorzó

    final pattern = RegExp(r'<a[^>]*>(.*?)</a>');
    List<String> parts = details.split(pattern);

    return GestureDetector(
      onTap: (){
        MailPopupDisplayTexts.title = subject;
        MailPopupDisplayTexts.description = Generic.textToInlineSpan(details);
        MailPopupDisplayTexts.mailID = mailID;

        PopupWidgetHandler(mode: 3, callback: (_){}, onCloseCallback: (){
          callback(this);
        });
        PopupWidgetHandler.doPopup(context);
      },
      child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
              color: !isRead 
                  ? AppColors.getTheme().primary.withValues(alpha: 0.12)
                  : AppColors.getTheme().textColor.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              border: Border.all(
                  color: !isRead
                      ? AppColors.getTheme().primary.withValues(alpha: 0.7)
                      : AppColors.getTheme().textColor.withValues(alpha: 0.12),
                  width: !isRead ? 1.8 : 1.0
              )
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              EmojiRichText(
                text: isRead ? '📭' : '📬',
                defaultStyle: TextStyle(
                  color: !isRead ? AppColors.getTheme().primary : AppColors.getTheme().onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 24.0 * fontScale, // Skálázott
                ),
                emojiStyle: TextStyle(
                    color: !isRead ? AppColors.getTheme().primary : AppColors.getTheme().onPrimaryContainer,
                    fontSize: 24.0 * fontScale, // Skálázott
                    fontFamily: "Noto Color Emoji"
                ),
              ),
              const SizedBox(width: 15), // Pici távolságtartás a logótól
              Expanded(
                flex: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!isRead)
                          Container(
                            width: 8 * fontScale,
                            height: 8 * fontScale,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.getTheme().primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            subject,
                            style: TextStyle(
                              color: !isRead ? AppColors.getTheme().textColor : AppColors.getTheme().onPrimaryContainer,
                              fontWeight: !isRead ? FontWeight.w800 : FontWeight.w600,
                              fontSize: (isRead ? 15.0 : 16.0) * fontScale, // Skálázott
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.8),
                          size: 16 * fontScale,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            sender,
                            style: TextStyle(
                              color: AppColors.getTheme().textColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.0 * fontScale, // Skálázott
                            ),
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(parts.join().toString()).replaceAll('\n', ' ').replaceAll('\t', ' ')}...',
                      style: TextStyle(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.6), // Halványabb előnézet
                        fontWeight: FontWeight.w500,
                        fontSize: 12.0 * fontScale, // Skálázott
                      ),
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2, // Engedünk 2 sort az előnézetnek
                    ),
                  ],
                ),
              )
            ],
          )
      ),
    );
  }
}