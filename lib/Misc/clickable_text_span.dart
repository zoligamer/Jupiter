import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jupiter/haptics.dart';
import 'package:jupiter/language.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';

class ClickableTextSpan extends StatelessWidget{
  final VoidCallback callback;
  final String text;
  final TextStyle style;

  const ClickableTextSpan({super.key, required this.callback, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){
        AppHaptics.lightImpact();
        callback();
      },
      child: Text(
        text,
        style: style,
      ),
      onLongPress: ()async{
        AppHaptics.attentionLightImpact();
        await Clipboard.setData(ClipboardData(text: text));
        if(!Platform.isAndroid){
          return;
        }
        Fluttertoast.showToast(
          msg: AppStrings.getLanguagePack().clickableText_OnCopy,
          toastLength: Toast.LENGTH_SHORT,
          fontSize: 14,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: AppColors.getTheme().rootBackground,
          textColor: AppColors.getTheme().textColor,
        );
      },
    );
  }

  static WidgetSpan getNewClickableSpan(VoidCallback callback, String text, TextStyle style){
    return WidgetSpan(child: ClickableTextSpan(callback: callback, text: text, style: style));
  }

  static TextStyle getStockStyle(){
    return TextStyle(color: AppColors.getTheme().onSecondaryContainer, decoration: TextDecoration.underline, decorationColor: AppColors.getTheme().onSecondaryContainer);
  }

  /// Only web and mail links are opened.
  static Uri? allowedLinkUri(String text) {
    final url = Uri.tryParse(text.trim());
    if (url == null || !const {'http', 'https', 'mailto'}.contains(url.scheme)) {
      return null;
    }
    return url;
  }

  static VoidCallback getNewOpenLinkCallback(String text){
    return ()async{
      if(!Platform.isAndroid){
        return;
      }
      final url = allowedLinkUri(text);
      if (url == null) {
        return;
      }
      await launchUrl(url);
    };
  }
}