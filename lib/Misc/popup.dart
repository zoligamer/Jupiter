import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:jupiter/Misc/custom_snackbar.dart';
import 'package:jupiter/Pages/main_page.dart';
import 'package:jupiter/colors.dart';
import 'package:jupiter/haptics.dart';
import 'package:jupiter/language.dart';
import 'package:jupiter/storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../API/api_coms.dart';
import '../API/api_coms.dart' as api;
import '../MailElements/mail_element_widget.dart';
import '../Pages/startup_page.dart';
import '../TimetableElements/timetable_element_widget.dart';
import 'emojirich_text.dart';

typedef Callback = void Function(dynamic);

class PopupWidgetHandler{
  static bool _hasPopupActive = false;
  static PopupWidgetHandler? _instance;
  bool _inUse = false;
  final linkedScroller = LinkedScrollControllerGroup();
  late ScrollController scrollController;

  final Callback callback;
  final VoidCallback? onCloseCallback;

  int? _settingsLanguagePrevious;
  int? _settingsLanguageCurrent;

  String? _settingsThemesPrevious;
  String? _settingsThemesCurrent;

  final int mode;

  AnimationController? widgetAnimController;

  static Duration animDuration = const Duration(milliseconds: 350);

  PopupWidgetHandler({required this.mode, required this.callback, this.onCloseCallback}){
    if(_hasPopupActive){
      return;
    }
    _instance = this;
    scrollController = linkedScroller.addAndGet();
  }

  bool hasListener = false;
  VoidCallback? _closeBlurCallback;

  static void doPopup(BuildContext context, {VoidCallback? blur = null, VoidCallback? closeBlur = null}){
    if(_instance!._inUse || PopupWidgetHandler._hasPopupActive){
      return;
    }
    _instance!._closeBlurCallback = closeBlur;
    PopupWidgetHandler._hasPopupActive = true;
    _instance!._inUse = true;
    _instance!._settingsLanguagePrevious = DataCache.getUserSelectedLanguage()!;
    _instance!._settingsLanguageCurrent = DataCache.getUserSelectedLanguage()!;

    _instance!._settingsThemesPrevious = DataCache.getPreferredAppTheme();
    _instance!._settingsThemesCurrent = DataCache.getPreferredAppTheme();

    if(blur == null){
      HomePageState.showBlurPopup(true);
    }
    else{
      blur();
    }
    AppHaptics.lightImpact();

    Future.wait([
      PackageInfo.fromPlatform(),
      Language.getAllLanguages(),
    ]).then((values){
      Navigator.of(context).push(
          PageRouteBuilder(
              pageBuilder: (context, anim, anim2) => PopupWidgetState(topPadding: MediaQuery.of(context).padding, mode: _instance!.mode, pinfo: values[0] as PackageInfo),
              opaque: false,
              barrierDismissible: true,
              transitionDuration: PopupWidgetHandler.animDuration,
              reverseTransitionDuration: Duration.zero,
              fullscreenDialog: true,
              transitionsBuilder: (_, __, ___, widget){
                return widget;
              }
          )
      );
    });
  }

  static closePopup(BuildContext context){
    if(_instance == null || !_instance!._inUse){
      PopupWidgetHandler._hasPopupActive = false;
      return;
    }
    _instance!._inUse = false;
    PopupWidgetHandler._hasPopupActive = false;
    if(_instance!.widgetAnimController != null){
      _instance!.widgetAnimController!.reverse(from: 1).whenComplete((){
        Future.delayed(Duration.zero, (){
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
        if(_instance!._settingsLanguageCurrent != _instance!._settingsLanguagePrevious || _instance!._settingsThemesCurrent != _instance!._settingsThemesPrevious){
          Navigator.popUntil(context, (route) => route.willHandlePopInternally);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Splitter()),
          );
        }
      });
    }

    if(_instance!._closeBlurCallback == null){
      HomePageState.showBlurPopup(false);
    }
    else{
      _instance!._closeBlurCallback!();
    }

    if(PopupWidgetHandler._instance!.onCloseCallback != null){
      PopupWidgetHandler._instance!.onCloseCallback!();
    }
  }
}

class PopupWidgetState extends StatefulWidget{
  PopupWidgetState({super.key, required this.topPadding, required this.mode, required this.pinfo});

  final EdgeInsets topPadding;
  final int mode;
  final PackageInfo? pinfo;

  @override
  State<StatefulWidget> createState() => PopupWidget();
}

class PopupWidget extends State<PopupWidgetState> with TickerProviderStateMixin{

  late AnimationController popupController;
  late Animation<double> poppuAnimation;
  late String _languageCurrSelect;
  late String _themesCurrSelect;
  GlobalKey _languageDropdownGlobalKey = GlobalKey();
  GlobalKey _themesDropdownGlobalKey = GlobalKey();

  double _currentFontScale = 1.0; // ITT VAN A HELYES HELYEN

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.getTheme().navbarNavibarColor,
      statusBarColor: AppColors.getTheme().navbarStatusBarColor,
    ));

    _currentFontScale = DataCache.getFontScale();

    popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    poppuAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: popupController, curve: Curves.easeInOutCubic),
    );
    PopupWidgetHandler._instance!.widgetAnimController = popupController;
    popupController.forward(from: 0);

    final l_idx = DataCache.getUserSelectedLanguage()!;
    if(l_idx <= -1){
      final langCodeIdx = AppStrings.getAllLangCodes().indexOf(Platform.localeName.split('_')[0].toLowerCase());
      _languageCurrSelect = AppStrings.getLanguageNamesWithFlag()[langCodeIdx];
    }
    else{
      _languageCurrSelect = AppStrings.getLanguageNamesWithFlag()[l_idx];
    }

    _themesCurrSelect = AppColors.getTheme().paletteName;
  }

  @override
  void dispose() {
    PopupWidgetHandler._hasPopupActive = false;
    if (PopupWidgetHandler._instance != null) {
      PopupWidgetHandler._instance!._inUse = false;
      PopupWidgetHandler._instance!.onCloseCallback?.call();
      if (PopupWidgetHandler._instance!._closeBlurCallback != null) {
        PopupWidgetHandler._instance!._closeBlurCallback!();
      } else {
        HomePageState.showBlurPopup(false);
      }
    }
    popupController.dispose();
    super.dispose();
  }

  int selectionValue = -1;

  
  Widget _buildActionButton({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
    Color? customColor,
  }) {
    final theme = AppColors.getTheme();
    final primaryColor = customColor ?? theme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.16)),
          overlayColor: WidgetStateProperty.all(primaryColor.withValues(alpha: 0.25)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: primaryColor.withValues(alpha: 0.40),
              width: 1.2,
            ),
          )),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 40, vertical: 14)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: theme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
            fontSize: 16.0,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  List<Widget> getWidgets(int mode){
    List<Widget> list = <Widget>[];
    switch (mode){
      case 0:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case0_GhostGradeHeader,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 3));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 2,
        ));
        list.add(const SizedBox(height: 20));
        if(selectionValue == -1) {
          list.add(Text(
            AppStrings.getLanguagePack().popup_case0_SelectGrade,
            style: TextStyle(
                color: AppColors.getTheme().textColor.withValues(alpha: .7),
                fontSize: 15,
                fontWeight: FontWeight.w400
            ),
          ));
        }
        list.add(
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                  decelerationRate: ScrollDecelerationRate.fast
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: (){
                      if(!PopupWidgetHandler._instance!._inUse || !mounted){
                        return;
                      }
                      AppHaptics.lightImpact();
                      setState(() {
                        selectionValue = 0;
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    icon: Text(
                      '1',
                      style: TextStyle(
                          color: selectionValue == -1 || selectionValue == 0 ? AppColors.getTheme().grade1 : AppColors.getTheme().grade1.withValues(alpha: .4),
                          fontSize: 30,
                          fontWeight: selectionValue != -1 && selectionValue == 0 ? FontWeight.w800 : FontWeight.normal
                      ),
                    ),
                    color: AppColors.getTheme().grade1,
                    enableFeedback: true,
                  ),
                  IconButton(
                    onPressed: (){
                      if(!PopupWidgetHandler._instance!._inUse || !mounted){
                        return;
                      }
                      AppHaptics.lightImpact();
                      setState(() {
                        selectionValue = 1;
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    icon: Text(
                      '2',
                      style: TextStyle(
                          color: selectionValue == -1 || selectionValue == 1 ? AppColors.getTheme().grade2 : AppColors.getTheme().grade2.withValues(alpha: .4),
                          fontSize: 30,
                          fontWeight: selectionValue != -1 && selectionValue == 1 ? FontWeight.w800 : FontWeight.normal
                      ),
                    ),
                    color: AppColors.getTheme().grade2,
                    enableFeedback: true,
                  ),
                  IconButton(
                    onPressed: (){
                      if(!PopupWidgetHandler._instance!._inUse || !mounted){
                        return;
                      }
                      AppHaptics.lightImpact();
                      setState(() {
                        selectionValue = 2;
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    icon: Text(
                      '3',
                      style: TextStyle(
                          color: selectionValue == -1 || selectionValue == 2 ? AppColors.getTheme().grade3 : AppColors.getTheme().grade3.withValues(alpha: .4),
                          fontSize: 30,
                          fontWeight: selectionValue != -1 && selectionValue == 2 ? FontWeight.w800 : FontWeight.normal
                      ),
                    ),
                    color: AppColors.getTheme().grade3,
                    enableFeedback: true,
                  ),
                  IconButton(
                    onPressed: (){
                      if(!PopupWidgetHandler._instance!._inUse || !mounted){
                        return;
                      }
                      AppHaptics.lightImpact();
                      setState(() {
                        selectionValue = 3;
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    icon: Text(
                      '4',
                      style: TextStyle(
                          color: selectionValue == -1 || selectionValue == 3 ? AppColors.getTheme().grade4 : AppColors.getTheme().grade4.withValues(alpha: .4),
                          fontSize: 30,
                          fontWeight: selectionValue != -1 && selectionValue == 3 ? FontWeight.w800 : FontWeight.normal
                      ),
                    ),
                    color: AppColors.getTheme().grade4,
                    enableFeedback: true,
                  ),
                  IconButton(
                    onPressed: (){
                      if(!PopupWidgetHandler._instance!._inUse || !mounted){
                        return;
                      }
                      AppHaptics.lightImpact();
                      setState(() {
                        selectionValue = 4;
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    icon: Text(
                      '5',
                      style: TextStyle(
                          color: selectionValue == -1 || selectionValue == 4 ? AppColors.getTheme().grade5 : AppColors.getTheme().grade5.withValues(alpha: .4),
                          fontSize: 30,
                          fontWeight: selectionValue != -1 && selectionValue == 4 ? FontWeight.w800 : FontWeight.normal
                      ),
                    ),
                    color: AppColors.getTheme().grade5,
                    enableFeedback: true,
                  ),
                ],
              ),
            )
        );
        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.getLanguagePack().popup_caseAll_OkButton,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(selectionValue);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));

        return list;

      case 1:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case1_SettingsHeader,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 3));
        list.add(Container(
          height: 1,
          color: AppColors.getTheme().textColor.withValues(alpha: .1),
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                "Betűméret / Font scale",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Expanded(
              flex: 3,
              child: Slider(
                value: _currentFontScale,
                min: 0.8,
                max: 1.5,
                divisions: 7,
                activeColor: AppColors.getTheme().secondary,
                inactiveColor: AppColors.getTheme().buttonDisabled,
                thumbColor: AppColors.getTheme().textColor,
                onChanged: (val) {
                  setState(() {
                    _currentFontScale = val;
                  });
                },
                onChangeEnd: (val) async {
                  await DataCache.setFontScale(val);
                  AppColors.refreshThemeIndexing();
                },
              ),
            )
          ],
        ));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 2,
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption1_FamilyFriendlyLoadingText,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption1_FamilyFriendlyLoadingTextDescription, 8);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              child: Switch(
                value: DataCache.getNeedFamilyFriendlyComments()!,
                onChanged: (b){
                  DataCache.setNeedFamilyFriendlyComments(b ? 1 : 0);
                  AppHaptics.lightImpact();
                  if(mounted) {setState((){});}
                },
                activeThumbColor: AppColors.getTheme().secondary,
                activeTrackColor: AppColors.getTheme().onPrimaryContainer,
                hoverColor: AppColors.getTheme().textColor.withValues(alpha: .1),
                inactiveTrackColor: AppColors.getTheme().buttonDisabled,
                inactiveThumbColor: AppColors.getTheme().textColor,
              ),
            )
          ],
        ));
        list.add(Container(
          height: 1,
          color: AppColors.getTheme().textColor.withValues(alpha: .1),
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption_MessageNotifications,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption_MessageNotificationsDescription, 8);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              child: Switch(
                value: DataCache.getNeedMessageNotifications() ?? true,
                onChanged: (b){
                  DataCache.setNeedMessageNotifications(b ? 1 : 0);
                  AppHaptics.lightImpact();
                  if(mounted) {setState((){});}
                },
                activeThumbColor: AppColors.getTheme().secondary,
                activeTrackColor: AppColors.getTheme().onPrimaryContainer,
                hoverColor: AppColors.getTheme().textColor.withValues(alpha: .1),
                inactiveTrackColor: AppColors.getTheme().buttonDisabled,
                inactiveThumbColor: AppColors.getTheme().textColor,
              ),
            )
          ],
        ));
        list.add(Container(
          height: 1,
          color: AppColors.getTheme().textColor.withValues(alpha: .1),
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption2_ExamNotifications,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption2_ExamNotificationsDescription, 12);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              child: Switch(
                value: DataCache.getNeedExamNotifications()!,
                onChanged: (b){
                  DataCache.setNeedExamNotifications(b ? 1 : 0);
                  AppHaptics.lightImpact();
                  if(b){
                    HomePageState.setupExamNotifications();
                  }
                  else{
                    HomePageState.cancelExamNotifications();
                  }
                  if(mounted) {setState((){});}
                },
                activeThumbColor: AppColors.getTheme().secondary,
                activeTrackColor: AppColors.getTheme().onPrimaryContainer,
                hoverColor: AppColors.getTheme().textColor.withValues(alpha: .1),
                inactiveTrackColor: AppColors.getTheme().buttonDisabled,
                inactiveThumbColor: AppColors.getTheme().textColor,
              ),
            )
          ],
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption3_ClassNotifications,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption3_ClassNotificationsDescription, 12);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              child: Switch(
                value: DataCache.getNeedClassNotifications()!,
                onChanged: (b){
                  DataCache.setNeedClassNotifications(b ? 1 : 0);
                  AppHaptics.lightImpact();
                  if(b){
                    HomePageState.setupClassesNotifications();
                  }
                  else{
                    HomePageState.cancelClassesNotifications();
                  }
                  if(mounted) {setState((){});}
                },
                activeThumbColor: AppColors.getTheme().secondary,
                activeTrackColor: AppColors.getTheme().onPrimaryContainer,
                hoverColor: AppColors.getTheme().textColor.withValues(alpha: .1),
                inactiveTrackColor: AppColors.getTheme().buttonDisabled,
                inactiveThumbColor: AppColors.getTheme().textColor,
              ),
            )
          ],
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption4_PaymentNotifications,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption4_PaymentNotificationsDescription, 8);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              child: Switch(
                value: DataCache.getNeedPaymentsNotifications()!,
                onChanged: (b){
                  DataCache.setNeedPaymentsNotifications(b ? 1 : 0);
                  AppHaptics.lightImpact();
                  if(b){
                    HomePageState.setupPaymentsNotifications();
                  }
                  else{
                    HomePageState.cancelPaymentsNotifications();
                  }
                  if(mounted) {setState((){});}
                },
                activeThumbColor: AppColors.getTheme().secondary,
                activeTrackColor: AppColors.getTheme().onPrimaryContainer,
                hoverColor: AppColors.getTheme().textColor.withValues(alpha: .1),
                inactiveTrackColor: AppColors.getTheme().buttonDisabled,
                inactiveThumbColor: AppColors.getTheme().textColor,
              ),
            )
          ],
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption5_PeriodsNotifications,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption5_PeriodsNotificationsDescription, 8);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              child: Switch(
                value: DataCache.getNeedPeriodsNotifications()!,
                onChanged: (b){
                  DataCache.setNeedPeriodsNotifications(b ? 1 : 0);
                  AppHaptics.lightImpact();
                  if(b){
                    HomePageState.setupPeriodsNotifications();
                  }
                  else{
                    HomePageState.cancelPeriodsNotifications();
                  }
                  if(mounted) {setState((){});}
                },
                activeThumbColor: AppColors.getTheme().secondary,
                activeTrackColor: AppColors.getTheme().onPrimaryContainer,
                hoverColor: AppColors.getTheme().textColor.withValues(alpha: .1),
                inactiveTrackColor: AppColors.getTheme().buttonDisabled,
                inactiveThumbColor: AppColors.getTheme().textColor,
              ),
            )
          ],
        ));
        list.add(Container(
          height: 1,
          color: AppColors.getTheme().textColor.withValues(alpha: .1),
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption6_AppHaptics,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption6_AppHapticsDescription, 6);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              child: Switch(
                value: DataCache.getNeedsHaptics()!,
                onChanged: (b){
                  DataCache.setNeedsHaptics(b ? 1 : 0);
                  AppHaptics.lightImpact();
                  if(mounted) {setState((){});}
                },
                activeThumbColor: AppColors.getTheme().secondary,
                activeTrackColor: AppColors.getTheme().onPrimaryContainer,
                hoverColor: AppColors.getTheme().textColor.withValues(alpha: .1),
                inactiveTrackColor: AppColors.getTheme().buttonDisabled,
                inactiveThumbColor: AppColors.getTheme().textColor,
              ),
            )
          ],
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption8_LangaugeSelection,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption8_LangaugeSelectionDescription, 4);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(10),
                child: DropdownButtonFormField<String>(
                    key: _languageDropdownGlobalKey,
                    borderRadius: BorderRadius.circular(12),
                    initialValue: _languageCurrSelect,
                    icon: const SizedBox(),
                    style: TextStyle(
                        color: AppColors.getTheme().textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600
                    ),
                    enableFeedback: true,
                    onTap: AppHaptics.lightImpact,
                    focusColor: Colors.transparent,
                    dropdownColor: AppColors.getTheme().rootBackground,
                    decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(18),
                        suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                        labelStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTheme().textColor.withValues(alpha: .6),
                            fontWeight: FontWeight.w400
                        ),
                        border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none
                        ),
                        filled: true,
                        fillColor: AppColors.getTheme().textColor.withValues(alpha: .05)
                    ),
                    items: AppStrings.getLanguageNamesWithFlag().map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                          value: AppStrings.getLanguageNamesWithFlag()[AppStrings.getLanguageNamesWithFlag().indexOf(value)],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                            child: EmojiRichText(
                              text: value,
                              defaultStyle: TextStyle(
                                color: AppColors.getTheme().textColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14.0,
                              ),
                              emojiStyle: TextStyle(
                                  color: AppColors.getTheme().textColor,
                                  fontSize: 18.0,
                                  fontFamily: "Noto Color Emoji"
                              ),
                            ),
                          )
                      );
                    }).toList(),
                    selectedItemBuilder: (context){
                      return AppStrings.getLanguageNamesWithFlag().map<Widget>((String value){
                        return Container(
                          constraints: BoxConstraints(maxWidth: _languageDropdownGlobalKey.currentContext?.findRenderObject() == null ? MediaQuery.of(context).size.width : ((_languageDropdownGlobalKey.currentContext!.findRenderObject() as RenderBox).size.width - 60) < 0 ? 0 : ((_languageDropdownGlobalKey.currentContext!.findRenderObject() as RenderBox).size.width - 60)),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: EmojiRichText(
                              text: value,
                              defaultStyle: TextStyle(
                                color: AppColors.getTheme().textColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 0.0,
                              ),
                              emojiStyle: TextStyle(
                                  color: AppColors.getTheme().textColor,
                                  fontSize: 20.0,
                                  fontFamily: "Noto Color Emoji"
                              ),
                            ),
                          ),
                        );
                      }).toList();
                    },
                  onChanged: (String? value) async {
                    AppHaptics.lightImpact();
                    if (value == null) return;

                    final flagWeLookFor = value.split(' ')[0];
                    final languageIdx = AppStrings.getAllLangFlags().indexOf(flagWeLookFor);
                    var selectedLangCode = '';

                    for (var item in Language.getAllLanguagesWithNative()) {
                      if (item.langFlag == flagWeLookFor) {
                        selectedLangCode = item.langId;
                        break;
                      }
                    }

                    DataCache.setUserSelectedLanguage(languageIdx <= -1 ? AppStrings.getAllLangFlags().length : languageIdx);

                    if (!AppStrings.hasLanguageDownloaded(selectedLangCode)) {
                      if (!DataCache.getHasNetwork()) {
                        Fluttertoast.showToast(msg: AppStrings.getLanguagePack().popup_case1_langSwap_DownloadingLangFail);
                        return;
                      }

                      final pack = await Language.getAllLanguages();
                      final valuePack = await Language.getLanguagePackById(pack, selectedLangCode);

                      if (valuePack != null) {
                        AppStrings.setupPopupPreviews(valuePack);
                        Fluttertoast.showToast(msg: AppStrings.popupLangPrev_ObtainingLang);
                        AppStrings.saveDownloadedLanguageData();
                      }
                    }

                    setState(() {
                      _languageCurrSelect = value;
                      PopupWidgetHandler._instance!._settingsLanguageCurrent = AppStrings.getLanguageNamesWithFlag().indexOf(value);
                    });

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const Splitter()),
                          (route) => false,
                    );
                  },
                ),
              ),
            ),
          ],
        ));
        list.add(Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: Container(
              margin: const EdgeInsets.all(10),
              child: Text(
                AppStrings.getLanguagePack().popup_case1_settingOption9_ThemeSwap,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTheme().textColor
                ),
              ),
            )),
            Container(
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: AppColors.getTheme().textColor.withValues(alpha: .06)
              ),
              child: IconButton(
                onPressed: (){
                  _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption9_ThemeSwapDescription, 4);
                  AppHaptics.attentionLightImpact();
                },
                icon: Icon(
                  Icons.question_mark_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: .4),
                ),
                enableFeedback: true,
                iconSize: 24,
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(10),
                child: DropdownButtonFormField<String>(
                    key: _themesDropdownGlobalKey,
                    borderRadius: BorderRadius.circular(12),
                    initialValue: _themesCurrSelect,
                    icon: const SizedBox(),
                    style: TextStyle(
                        color: AppColors.getTheme().textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600
                    ),
                    enableFeedback: true,
                    onTap: AppHaptics.lightImpact,
                    focusColor: Colors.transparent,
                    dropdownColor: AppColors.getTheme().rootBackground,
                    decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(18),
                        suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                        labelStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTheme().textColor.withValues(alpha: .6),
                            fontWeight: FontWeight.w400
                        ),
                        border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none
                        ),
                        filled: true,
                        fillColor: AppColors.getTheme().textColor.withValues(alpha: .05)
                    ),
                    items: AppColors.getThemesOnline().map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                          value: value,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                            child: EmojiRichText(
                              text: '■',
                              defaultStyle: TextStyle(
                                color: AppColors.getThemePopupAccentByName(value),
                                fontWeight: FontWeight.w500,
                                fontSize: 14.0,
                              ),
                              emojiStyle: TextStyle(
                                  color: AppColors.getThemePopupAccentByName(value),
                                  fontSize: 18.0,
                                  fontFamily: "Noto Color Emoji"
                              ),
                            ),
                          )
                      );
                    }).toList(),
                    selectedItemBuilder: (context){
                      return AppColors.getThemesOnline().map<Widget>((String value){
                        return Container(
                          constraints: BoxConstraints(maxWidth: _themesDropdownGlobalKey.currentContext?.findRenderObject() == null ? MediaQuery.of(context).size.width : ((_themesDropdownGlobalKey.currentContext!.findRenderObject() as RenderBox).size.width - 60) < 0 ? 0 : ((_themesDropdownGlobalKey.currentContext!.findRenderObject() as RenderBox).size.width - 60)),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: EmojiRichText(
                              text: '■',
                              defaultStyle: TextStyle(
                                color: AppColors.getThemePopupAccentByName(value),
                                fontWeight: FontWeight.w500,
                                fontSize: 16.0,
                              ),
                              emojiStyle: TextStyle(
                                  color: AppColors.getThemePopupAccentByName(value),
                                  fontSize: 20.0,
                                  fontFamily: "Noto Color Emoji"
                              ),
                            ),
                          ),
                        );
                      }).toList();
                    },
                    onChanged: (String? value) {
                      AppHaptics.lightImpact();
                      if(value == null){
                        return;
                      }
                      DataCache.setPreferredAppTheme(value);
                      if(!AppColors.hasThemeDownloaded(value)){
                        Future.delayed(Duration.zero, ()async{
                          if(!DataCache.getHasNetwork()){
                            if(Platform.isAndroid){
                              Fluttertoast.showToast(
                                msg: AppStrings.getLanguagePack().popup_case1_themeSwap_DownloadingThemeFail,
                                toastLength: Toast.LENGTH_SHORT,
                                fontSize: 14,
                                gravity: ToastGravity.SNACKBAR,
                                backgroundColor: AppColors.getTheme().rootBackground,
                                textColor: AppColors.getTheme().textColor,
                              );
                            }
                            return;
                          }
                          final pack = await Coloring.getAllThemes();
                          await Coloring.getThemePackById(pack, value).then((value)async{
                            if(value == null){
                              return;
                            }
                            if(Platform.isAndroid){
                              Fluttertoast.showToast(
                                  msg: AppStrings.getLanguagePack().popup_case1_themeSwap_DownloadingThemeFail,
                                  toastLength: Toast.LENGTH_SHORT,
                                  fontSize: 14,
                                  gravity: ToastGravity.SNACKBAR,
                                  backgroundColor: AppColors.getTheme().rootBackground,
                                  textColor: AppColors.getTheme().textColor
                              );
                            }
                            AppColors.saveDownloadedPaletteData();
                            AppColors.setUserThemeByName(value.paletteName, context);
                            AppColors.refreshThemeIndexing();
                          });
                          return;
                        });
                      }
                      setState(() {
                        _themesCurrSelect = value;
                        PopupWidgetHandler._instance!._settingsThemesCurrent = value;
                        AppColors.setUserTheme(context);
                        AppColors.refreshThemeIndexing();
                      });
                    }
                ),
              ),
            ),
          ],
        ));
        list.add(Container(
          height: 1,
          color: AppColors.getTheme().textColor.withValues(alpha: .1),
        ));
        list.add(const SizedBox(height: 6));
        list.add(
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 4, child: Container(
                      margin: const EdgeInsets.all(10),
                      child: Text(
                        AppStrings.getLanguagePack().popup_case1_settingOption7_WeekOffset,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTheme().textColor
                        ),
                      ),
                    )),
                    Container(
                      decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          color: AppColors.getTheme().textColor.withValues(alpha: .06)
                      ),
                      child: IconButton(
                        onPressed: (){
                          _showSnackbar(AppStrings.getLanguagePack().popup_case1_settingOption7_WeekOffsetDescription, 6);
                          AppHaptics.attentionLightImpact();
                        },
                        icon: Icon(
                          Icons.question_mark_rounded,
                          color: AppColors.getTheme().textColor.withValues(alpha: .4),
                        ),
                        enableFeedback: true,
                        iconSize: 24,
                      ),
                    ),
                    const Padding(padding: EdgeInsets.only(right: 16)),
                    Container(
                      decoration: BoxDecoration(
                          color: AppColors.getTheme().textColor.withValues(alpha: .05),
                          borderRadius: const BorderRadius.all(Radius.circular(14))
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 65,
                            child: TextField(
                                controller: HomePageState.getUserWeekOffsetTextController(),
                                scrollPhysics: const AlwaysScrollableScrollPhysics(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: true),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppColors.getTheme().textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600
                                ),
                                maxLines: 1,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  isDense: true,
                                  hintText: AppStrings.getLanguagePack().popup_case1_settingOption7_WeekOffsetAuto,
                                  hintStyle: TextStyle(
                                      color: AppColors.getTheme().textColor.withValues(alpha: .4),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400
                                  ),
                                  border: const OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))
                                  ),
                                  contentPadding: const EdgeInsets.all(6),
                                  filled: false,
                                )
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: GestureDetector(
                                  onLongPressStart: (_){
                                    HomePageState.settingsUserWeekOffsetPeriodicLooper = Timer.periodic(const Duration(milliseconds: 100), (timer) {
                                      AppHaptics.lightImpact();
                                      HomePageState.settingsUserWeekOffsetAdd(1);
                                    });
                                  },
                                  onLongPressEnd: (_){
                                    HomePageState.settingsUserWeekOffsetPeriodicLooper!.cancel();
                                    HomePageState.settingsUserWeekOffsetPeriodicLooper = null;
                                  },
                                  child: IconButton(
                                    onPressed: () {
                                      AppHaptics.lightImpact();
                                      HomePageState.settingsUserWeekOffsetAdd(1);
                                    },
                                    icon: Icon(
                                      Icons.arrow_drop_up_rounded,
                                      color: AppColors.getTheme().textColor.withValues(alpha: .5),
                                      size: 16,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: GestureDetector(
                                  onLongPressStart: (_){
                                    HomePageState.settingsUserWeekOffsetPeriodicLooper = Timer.periodic(const Duration(milliseconds: 100), (timer) {
                                      AppHaptics.lightImpact();
                                      HomePageState.settingsUserWeekOffsetAdd(-1);
                                    });
                                  },
                                  onLongPressEnd: (_){
                                    HomePageState.settingsUserWeekOffsetPeriodicLooper!.cancel();
                                    HomePageState.settingsUserWeekOffsetPeriodicLooper = null;
                                  },
                                  child: IconButton(
                                    onPressed: () {
                                      AppHaptics.lightImpact();
                                      HomePageState.settingsUserWeekOffsetAdd(-1);
                                    },
                                    icon: Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: AppColors.getTheme().textColor.withValues(alpha: .5),
                                      size: 16,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
        );
        list.add(const SizedBox(height: 6));
        final pinfo = widget.pinfo ?? PackageInfo(appName: 'neptun2', packageName: 'com.domedav.neptun2', version: '1.1.2', buildNumber: '7', buildSignature: '');
        list.add(Container(
          alignment: Alignment.bottomLeft,
          margin: const EdgeInsets.all(10),
          child: Text(
            AppStrings.getStringWithParams(AppStrings.getLanguagePack().popup_case1_settingBottomText_InstallOrigin, ['v${pinfo.version} (${pinfo.buildNumber})']) + (DataCache.getIsInstalledFromGPlay()! != 0 ? AppStrings.getLanguagePack().popup_case1_settingBottomText_InstallOriginGPlay : AppStrings.getLanguagePack().popup_case1_settingBottomText_InstallOrigin3rdParty),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 9,
                color: AppColors.getTheme().onSecondary.withValues(alpha: .8)
            ),
          ),
        ));
        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.getLanguagePack().popup_caseAll_OkButton,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));
        return list;

      case 2:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case2_RateAppPopup,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 3));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 2,
        ));
        list.add(Text(
          AppStrings.getLanguagePack().popup_case2_RateAppPopupDescription,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 14,
              fontWeight: FontWeight.w400
          ),
        ));
        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.getLanguagePack().popup_case2_RateButton,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));
        return list;
      case 3:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case3_MessagesHeader,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 3));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 2,
        ));

        list.add(SelectableText.rich(
          TextSpan(
            text: MailPopupDisplayTexts.title,
            style: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 20
            ),
          ),
          textAlign: TextAlign.start,
        ));
        list.add(const SizedBox(height: 20));
        list.add(FutureBuilder<String>(
          future: api.MailRequest.getMailContent(
              MailPopupDisplayTexts.mailID,
              MailPopupDisplayTexts.description.map((e) => e.toPlainText()).join()
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator())
              );
            }
            if (snapshot.hasError) {
              return Text("Hiba: ${snapshot.error}", style: TextStyle(color: AppColors.getTheme().errorRed));
            }

            return SelectableText.rich(
              TextSpan(
                children: api.Generic.textToInlineSpan(snapshot.data ?? "Üres üzenet."),
                style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontWeight: FontWeight.w400,
                    fontSize: 14
                ),
              ),
              textAlign: TextAlign.start,
            );
          },
        ));

        list.add(const SizedBox(height: 20));
        list.add(TextButton(
          onPressed: (){
            if(!PopupWidgetHandler._instance!._inUse || !mounted){
              return;
            }
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
            Future.delayed(Duration.zero, ()async{
              await MailRequest.setMailRead(MailPopupDisplayTexts.mailID);
            });
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(AppColors.getTheme().textColor.withValues(alpha: .1)),
            overlayColor: WidgetStateProperty.all(AppColors.getTheme().textColor.withValues(alpha: .05)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 15),
            child: Text(AppStrings.getLanguagePack().popup_caseAll_OkButton,
              style: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontWeight: FontWeight.w900,
                fontSize: 18.0,
              ),
            ),
          ),
        ));
        return list;
      case 4:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case4_SubjectInfo,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w600,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.12),
          margin: const EdgeInsets.symmetric(vertical: 12),
          height: 1.2,
        ));
        final entry = TimetableCurrentlySelected.entry;
        final theme = AppColors.getTheme();
        list.add(SelectableText(
          entry!.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18.5,
          ),
        ));
        list.add(const SizedBox(height: 16));

        Widget buildDetailCard({
          required IconData icon,
          required String label,
          required String value,
          Color? accentColor,
        }) {
          final col = accentColor ?? theme.primary;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.textColor.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: col, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SelectableText(
                        value,
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (entry.teacher.trim().isNotEmpty && entry.teacher != 'Nincs megadva' && entry.teacher != 'Nincs tanár') {
          list.add(buildDetailCard(
            icon: Icons.person_rounded,
            label: "Oktató",
            value: entry.teacher,
            accentColor: theme.onPrimaryContainer,
          ));
        }

        if (entry.courseType != null && entry.courseType!.trim().isNotEmpty && entry.courseType != '-') {
          list.add(buildDetailCard(
            icon: Icons.menu_book_rounded,
            label: "Típus",
            value: entry.courseType!,
            accentColor: theme.currentClassGreen,
          ));
        }

        if (entry.location.trim().isNotEmpty && entry.location != 'NULL' && entry.location != 'Nincs megadva') {
          list.add(buildDetailCard(
            icon: Icons.location_on_rounded,
            label: "Terem / Helyszín",
            value: entry.location,
            accentColor: theme.roomHighlightColor,
          ));
        }

        final timeStart = DateTime.fromMillisecondsSinceEpoch(entry.startEpoch);
        final timeEnd = DateTime.fromMillisecondsSinceEpoch(entry.endEpoch);
        list.add(buildDetailCard(
          icon: Icons.access_time_filled_rounded,
          label: "Időtartam",
          value: '${timeStart.hour.toString().padLeft(2, '0')}:${timeStart.minute.toString().padLeft(2, '0')} - ${timeEnd.hour.toString().padLeft(2, '0')}:${timeEnd.minute.toString().padLeft(2, '0')}',
          accentColor: theme.primary,
        ));

        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.getLanguagePack().popup_caseAll_OkButton,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));
        return list;

      case 5:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case5_ExamInfo,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w600,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.12),
          margin: const EdgeInsets.symmetric(vertical: 12),
          height: 1.2,
        ));
        final entryExam = TimetableCurrentlySelected.entry;
        final themeExam = AppColors.getTheme();
        list.add(SelectableText(
          entryExam!.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: themeExam.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18.5,
          ),
        ));
        list.add(const SizedBox(height: 16));

        Widget buildExamDetailCard({
          required IconData icon,
          required String label,
          required String value,
          Color? accentColor,
        }) {
          final col = accentColor ?? themeExam.primary;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: themeExam.textColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: themeExam.textColor.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: col, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: themeExam.textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SelectableText(
                        value,
                        style: TextStyle(
                          color: themeExam.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (entryExam.subjectCode.trim().isNotEmpty && entryExam.subjectCode != '-') {
          list.add(buildExamDetailCard(
            icon: Icons.tag_rounded,
            label: "Tárgykód",
            value: entryExam.subjectCode,
            accentColor: themeExam.onPrimaryContainer,
          ));
        }

        if (entryExam.location.trim().isNotEmpty && entryExam.location != 'NULL' && entryExam.location != 'Nincs megadva') {
          list.add(buildExamDetailCard(
            icon: Icons.location_on_rounded,
            label: "Terem / Helyszín",
            value: entryExam.location,
            accentColor: themeExam.roomHighlightColor,
          ));
        }

        final timeStartExam = DateTime.fromMillisecondsSinceEpoch(entryExam.startEpoch);
        list.add(buildExamDetailCard(
          icon: Icons.access_time_filled_rounded,
          label: "Kezdés",
          value: '${timeStartExam.hour.toString().padLeft(2, '0')}:${timeStartExam.minute.toString().padLeft(2, '0')}',
          accentColor: themeExam.errorRed,
        ));

        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.getLanguagePack().popup_caseAll_OkButton,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));
        return list;
      case 6:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case6_AccountError,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 3));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 2,
        ));
        list.add(Text(
          AppStrings.getLanguagePack().popup_case6_AccountErrorDescription,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 14,
              fontWeight: FontWeight.w400
          ),
        ));
        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.getLanguagePack().popup_caseAll_OkButton,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));
        return list;
      case 7:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case7_ObsolteAppVersion,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 3));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 2,
        ));
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_case7_ObsolteAppVersionDescription,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 14.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.getLanguagePack().popup_case7_ButtonUpdateNow,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));
        return list;
      case 8:
        list.add(EmojiRichText(
          text: AppStrings.popupLangPrev_Header,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 3));
        list.add(Container(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.3),
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 2,
        ));
        list.add(EmojiRichText(
          text: AppStrings.popupLangPrev_Description,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 14.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.popupLangPrev_Button,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));
        return list;
      case 9: // 2FA Mód
        list.add(Text(
          AppStrings.getLanguagePack().popup_2fa_title,
          style: TextStyle(
            color: AppColors.getTheme().textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ));
        list.add(const SizedBox(height: 10));
        list.add(Text(
          AppStrings.getLanguagePack().popup_2fa_desc,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ));
        list.add(const SizedBox(height: 25));
        list.add(TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.getTheme().textColor,
            fontSize: 28,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: AppColors.getTheme().textColor.withValues(alpha: 0.05),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.15),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.getTheme().primary,
                width: 1.8,
              ),
            ),
          ),
          onChanged: (val) {
            if (val.length == 6) {
              PopupWidgetHandler._instance!.callback(val);
            }
          },
        ));
        list.add(const SizedBox(height: 15));
        list.add(Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                PopupWidgetHandler.closePopup(context);
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.20),
                    width: 1.0,
                  ),
                )),
              ),
              child: Text(
                AppStrings.getLanguagePack().popup_2fa_cancel,
                style: TextStyle(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.75),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ));
        return list;
      default:
        list.add(EmojiRichText(
          text: AppStrings.getLanguagePack().popup_caseDefault_InvalidPopupState,
          defaultStyle: TextStyle(
            color: AppColors.getTheme().textColor,
            fontWeight: FontWeight.w500,
            fontSize: 22.0,
          ),
          emojiStyle: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 19.0,
              fontFamily: "Noto Color Emoji"
          ),
        ));
        list.add(const SizedBox(height: 24));
        list.add(_buildActionButton(
          context: context,
          text: AppStrings.getLanguagePack().popup_caseAll_OkButton,
          onPressed: () {
            if(!PopupWidgetHandler._instance!._inUse || !mounted) return;
            PopupWidgetHandler._instance!.callback(null);
            PopupWidgetHandler.closePopup(context);
            AppHaptics.lightImpact();
          },
        ));
        return list;
    }
  }

  String _snackbarMessage = "";
  Duration _displayDuration = Duration.zero;
  bool _shouldShowSnackbar = false;
  //double _snackbarDelta = 0;

  void _showSnackbar(String text, int displayDurationSec){
    if(!mounted){
      return;
    }
    setState(() {
      _shouldShowSnackbar = true;
      _displayDuration = Duration(seconds: displayDurationSec);
      _snackbarMessage = text;
      //_snackbarDelta = 0;
    });
  }


  Widget getPopup(BuildContext context){
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: (){
          PopupWidgetHandler.closePopup(context);
        },
        behavior: HitTestBehavior.deferToChild,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) { // <-- DYNAMIC RESULT
            if (didPop) return;
            PopupWidgetHandler.closePopup(context);
          },
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  padding: widget.topPadding,
                  margin: EdgeInsets.only(
                    bottom: mounted
                        ? (MediaQuery.of(context).viewInsets.bottom +
                            math.max(MediaQuery.of(context).padding.bottom,
                                MediaQuery.of(context).viewPadding.bottom))
                        : 0,
                  ),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: PopupWidgetHandler._instance!.scrollController,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                      margin: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.getTheme().rootBackground,
                        borderRadius: const BorderRadius.all(Radius.circular(20)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: getWidgets(PopupWidgetHandler._instance!.mode),
                      ),
                    ),
                  )
              ),
              Visibility(
                visible: _shouldShowSnackbar,
                child: AppSnackbar(text: _snackbarMessage, displayDuration: _displayDuration, changer: (){
                  if(!mounted){
                    return;
                  }
                  AppSnackbar.cancelTimer();
                  setState(() {
                    _shouldShowSnackbar = false;
                  });
                }, state: _shouldShowSnackbar,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: popupController,
        builder: (context, _) {
          return Transform.scale(
              scale: poppuAnimation.value,
              child: getPopup(context)
          );
        }
    );
  }
}