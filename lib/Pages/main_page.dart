import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:jupiter/API/ics_calendar.dart';
import 'package:jupiter/MailElements/mail_element_widget.dart';
import 'package:jupiter/colors.dart';
import 'package:jupiter/language.dart';
import 'package:jupiter/notifications.dart';
import 'package:jupiter/Misc/emojirich_text.dart';
import 'package:jupiter/PaymentsElements/payment_element_widget.dart';
import '../API/api_coms.dart' as api;
import '../Misc/auto_updater.dart';
import '../haptics.dart';
import '../storage.dart' as storage;
import '../TimetableElements/timetable_element_widget.dart' as t_table;
import '../MarkbookElements/markbook_element_widget.dart' as mbook;
import '../PeriodsElements/periods_element_widget.dart' as priods;
import '../Navigator/bottomnavigator.dart' as bottomnav;
import '../Navigator/topnavigator.dart' as topnav;
import '../Misc/to_office_service.dart';
import '../TimetableElements/to_office_widget.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../Pages/startup_page.dart' as root_page;
import '../Misc/app_drawer.dart';

class HomePage extends StatefulWidget{
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin{

  final List<Widget> _confettiList = [];
  final List<ConfettiHelper> _confettiHelperList = [];

  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;

  bool _confettiCanGetFreshAnim = true;
  bool _confettiCanBePlayed = false;
  bool _confettiRefreshRetrigger = true;


  static HomePageState? _instance;
  HomePageState(){
    _instance = this;
  }

  static BuildContext? getContext() => _instance?.context;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  static void showBlurPopup(bool b){
    if (_instance != null && _instance!.mounted) {
      _instance!.setBlurComplex(b);
    }
  }

  static void navigateToView(int to) {
    _instance?.switchView(to);
  }

  bool _showBlur = false;
  void setBlur(bool state){
    if (!mounted) return;
    setState(() {
      _showBlur = state;
    });
  }

  late AnimationController blurController;
  late Animation<double> blurAnimation;

  void setBlurComplex(bool state){
    if (!mounted) return;
    setState(() {
      if(state) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: AppColors.getTheme().navbarNavibarColor, // navigation bar color
            statusBarColor: AppColors.getTheme().navbarStatusBarColor, // status bar color
        ));
        blurController.forward();
        _showBlur = true;
        return;
      }
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: AppColors.getTheme().rootBackground, // navigation bar color
        statusBarColor: AppColors.getTheme().rootBackground, // status bar color
      ));
      blurController.reverse().whenComplete((){
        if (mounted) {
          setState(() {
            _showBlur = false;
          });
        }
      });
    });
  }

  late List<api.CalendarEntry> calendarEntries = <api.CalendarEntry>[].toList();
  late List<api.Subject> markbookEntries = <api.Subject>[].toList();
  late List<api.CashinEntry> paymentsEntries = <api.CashinEntry>[].toList();
  late List<api.PeriodEntry> periodEntries = <api.PeriodEntry>[].toList();
  late List<api.MailEntry> mailEntries = <api.MailEntry>[].toList();

  late final List<Widget> mondayCalendar = <Widget>[].toList();
  late final List<Widget> tuesdayCalendar = <Widget>[].toList();
  late final List<Widget> wednessdayCalendar = <Widget>[].toList();
  late final List<Widget> thursdayCalendar = <Widget>[].toList();
  late final List<Widget> fridayCalendar = <Widget>[].toList();
  late final List<Widget> saturdayCalendar = <Widget>[].toList();
  late final List<Widget> sundayCalendar = <Widget>[].toList();

  late final List<Widget> markbookList = <Widget>[].toList();

  late final List<Widget> paymentsList = <Widget>[].toList();
  late final List<Widget> periodList = <Widget>[].toList();
  late final List<Widget> mailList = <Widget>[].toList();

  late final LinkedScrollControllerGroup bottomnavScrollCntroller;
  late final ScrollController bottomnavController;

  late final TextEditingController settingsUserWeekOffset;
  late int settingsUserWeekOffsetPrev;
  String prevSettingsUserWeekOffset = '';
  static TextEditingController getUserWeekOffsetTextController(){
    return _instance!.settingsUserWeekOffset;
  }
  static Timer? settingsUserWeekOffsetPeriodicLooper = null;

  bool canDoCalendarPaging = false;
  int weeksSinceStart = 1;
  int currentWeekOffset = 1;
  late TabController calendarTabController;
  int currentView = 0;
  String calendarGreetText = "";

  int totalCredits = 0;
  int totalMoney = 0;
  double totalAvg = 0;
  double totalAvg30 = 0;

  int currentSemester = -1;
  int countActivePeriods = 0;
  int countFuturePeriods = 0;
  int countExpiredPeriods = 0;

  int unreadMailCount = 0;
  int totalMailCount = 0;
  int allLoadedMailCount = 0;

  double bottomNavSwitchValue = 0.0;
  bool bottomNavCanNavigate = true;
  static const int maxBottomNavWidgets = 5;

  double calendarWeekSwitchValue = 0.0;
  bool calendarWeekCanNavigate = true;
  bool isCalendarOffline = false;

  @override
  void initState() {
    super.initState();

    FlutterNativeSplash.remove();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.getTheme().rootBackground, // navigation bar color
      statusBarColor: AppColors.getTheme().rootBackground, // status bar color
    ));

    api.Generic.setupDaylightSavingsTime();

    if(storage.DataCache.getHasICSFile() ?? false){
      ICSCalendar.initialize();
    }

    Future.microtask(() async {
      await ToOfficeService.initialize();
      await ToOfficeService.checkAndResolveFacultyAsync();
      ToOfficeService.fetchAndRefreshSchedule();
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConn = results.any((r) => r != ConnectivityResult.none);
      if (hasConn && mounted) {
        // Csendes háttérbeli frissítés kapcsolat visszatérésekor
        Future.microtask(() => onCalendarRefresh(false));
      }
    });

    Future.delayed(const Duration(seconds: 4), () async {
      await LanguageManager.suggestLang(context, null, null);
    });
    Future.delayed(const Duration(seconds: 1), () async {
      await LanguageManager.refreshAllDownloadedLangs();
    });

    if(Platform.isAndroid){
      Future.delayed(Duration.zero, () async {
        try {
          tz.initializeTimeZones();
          final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
          final String timeZone = timeZoneInfo.identifier;
          tz.setLocalLocation(tz.getLocation(timeZone));
        } catch (_) {
          try {
            tz.setLocalLocation(tz.getLocation('Europe/Budapest'));
          } catch (_) {
            tz.setLocalLocation(tz.UTC);
          }
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppUpdater.initialize().then((_) {
          AppUpdater.checkSilentUpdate();
        });
      });
    }

    if(Platform.isAndroid && storage.DataCache.getIsInstalledFromGPlay() != 0){
      Future.delayed(const Duration(seconds: 4), ()async{
        final cacheTime = await storage.getInt('UpdateCacheTime') ?? -1;
        if(cacheTime <= 0){ // fresh app version
          storage.saveInt('UpdateCacheTime', DateTime.now().millisecondsSinceEpoch);
          return;
        }

        if((DateTime.now().millisecondsSinceEpoch - cacheTime) > const Duration(hours: 24).inMilliseconds || // once a day update check
        await Connectivity().checkConnectivity() == ConnectivityResult.none) // only check for updates, if there is internet
        {return;}

        final appupdateInfo = await InAppUpdate.checkForUpdate();
        storage.saveInt('UpdateCacheTime', DateTime.now().millisecondsSinceEpoch); // save last checked update time
        if(appupdateInfo.updateAvailability == UpdateAvailability.updateAvailable){ // has new version
          AppHaptics.attentionImpact();
          await InAppUpdate.startFlexibleUpdate().then((value) async { // install update
            await InAppUpdate.completeFlexibleUpdate();
          });
        }
      });
    }

    bottomnavScrollCntroller = LinkedScrollControllerGroup();
    bottomnavController = bottomnavScrollCntroller.addAndGet();

    final userWeekOffserValue = storage.DataCache.getUserWeekOffset()!;
    settingsUserWeekOffset = TextEditingController(text: (userWeekOffserValue == 0 ? '' : userWeekOffserValue.toString()));
    prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
    settingsUserWeekOffsetPrev = storage.DataCache.getUserWeekOffset()!;
    settingsUserWeekOffset.addListener(() {
      if(settingsUserWeekOffset.text != prevSettingsUserWeekOffset){
        _instance!.changedSettingsUserWeekOffset = true;
        _instance!.settingsUserWeekOffsetSetup();
      }
    });

    blurController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
    );
    blurAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: blurController, curve: Curves.linear),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _confettiAnimation = Tween<double>(begin: -0.2, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.linear)
    );

    currentMailPageController = ScrollController();
    currentMailPageController.addListener(() {
      if(currentMailPageController.position.atEdge && currentMailPageController.position.userScrollDirection == ScrollDirection.reverse && allLoadedMailCount < totalMailCount){
        if(currentMailLoadingDebounce){
          return;
        }
        currentMailLoadingDebounce = true;
        Future.delayed(Duration.zero, ()async{
          setState((){
            currentMailPage++;
            mailList.add(Column(
              children: [
                CircularProgressIndicator(
                  color: AppColors.getTheme().textColor,
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 5)),
                Text(
                 api.Generic.randomLoadingCommentMini(storage.DataCache.getNeedFamilyFriendlyComments()!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.getTheme().textColor.withValues(alpha: .4),
                    fontSize: 11,
                    fontWeight: FontWeight.w300
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8)),
              ],
            ),);
          });
          await fetchMails(force: true);
          setupMails(clear: true);
        }).whenComplete((){
          currentMailLoadingDebounce = false;
        });
      }
    });

    AppNotifications.initialize();
    Future.delayed(Duration.zero, ()async{
      if(((await storage.getInt('NextFirstWeekCacheTime')) ?? 0) < DateTime.now().millisecondsSinceEpoch){
        storage.DataCache.setHasCachedFirstWeekEpoch(0);
        storage.saveInt('NextFirstWeekCacheTime', DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch);
      }
      if(storage.DataCache.getHasCachedFirstWeekEpoch()!){
        return;
      }
      final firstWeekOfSemester = await api.InstitutesRequest.getFirstStudyweek();
      storage.DataCache.setHasCachedFirstWeekEpoch(1);
      await storage.DataCache.setFirstWeekEpoch(firstWeekOfSemester);
    }).whenComplete((){
      Future.delayed(const Duration(seconds: 1), (){
        setState(() {weeksSinceStart = calcPassedWeeks();});
      });
    });

    Future.delayed(Duration.zero,() async{
      await AppNotifications.cancelScheduledNotifs();
    }).whenComplete((){
      Future.microtask(() async {
        await fetchCalendar();
        if(storage.DataCache.getNeedExamNotifications() ?? false){
          if(storage.DataCache.getHasNetwork()){
            await _skimForExams();
          }
        }
        setupCalendar(true);
      });

      Future.microtask(() async {
        await fetchMarkbook();
        setupMarkbook();
      });

      Future.microtask(() async {
        await fetchPayments();
        setupPayments();
      });

      Future.microtask(() async {
        await fetchPeriods();
        setupPeriods();
      });

      Future.microtask(() async {
        await fetchMails();
        setupMails();
      });
    });

    setupCalendarGreetText();
    setupCalendarController(true, true);

    // Instant paint (~0.05s) from permanent cache on launch
    _loadPermanentCalendarEntries(currentWeekOffset).then((hasCached) {
      if (hasCached && mounted) {
        setState(() {
          isCalendarOffline = !storage.DataCache.getHasNetwork();
          _setupCalendar(true);
          canDoCalendarPaging = true;
          setupCalendarController(false, false);
        });
      }
    });

    AppColors.clearThemeChangeCallbacks();
    AppColors.subThemeChangeCallback((){
      if(!mounted){
        return;
      }
      setState(() {

      });
      Future.delayed(Duration.zero, (){
        onCalendarRefresh(false);
        onMarkbookRefresh();
        onPaymentsRefresh();
        onPeriodsRefresh();
        onMailRefresh();
      });
    });
  }

  void userUnavailableAccountLogout(){
    Future.delayed(Duration.zero, ()async{
      ToOfficeService.reset();
      await storage.DataCache.dataWipe();
      await AppNotifications.cancelScheduledNotifs();
    }).whenComplete((){
      Navigator.popUntil(context, (route) => route.willHandlePopInternally);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const root_page.Splitter()),
      );
    });
  }

  bool changedSettingsUserWeekOffset = false;

  void settingsUserWeekOffsetSetup(){
    if(settingsUserWeekOffset.text == '-'){
      return;
    }
    var newVal = int.tryParse(settingsUserWeekOffset.text);
    var correctedVal = 0;
    if(newVal == null || newVal == 0){
      settingsUserWeekOffset.text = '';
      prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
      Future.delayed(Duration.zero, ()async{
        await storage.DataCache.setUserWeekOffset(correctedVal);
      });
      return;
    }
    correctedVal = clampDouble(newVal.toDouble(), -calcPassedWeekOffsetless().toDouble(), 51 - calcPassedWeekOffsetless().toDouble()).toInt();
    settingsUserWeekOffset.text = correctedVal.toString();
    settingsUserWeekOffset.text = correctedVal.toString();
    prevSettingsUserWeekOffset = settingsUserWeekOffset.text;
    Future.delayed(Duration.zero, ()async{
      await storage.DataCache.setUserWeekOffset(correctedVal);
    });
  }

  static void settingsUserWeekOffsetAdd(int val){
    _instance!.changedSettingsUserWeekOffset = true;
    final oldVal = storage.DataCache.getUserWeekOffset()!;
    var correctedVal = oldVal + val;
    correctedVal = clampDouble(correctedVal.toDouble(), -_instance!.calcPassedWeekOffsetless().toDouble(), 51 - _instance!.calcPassedWeekOffsetless().toDouble()).toInt();
    _instance!.settingsUserWeekOffset.text = correctedVal.toString();
    _instance!.prevSettingsUserWeekOffset = _instance!.settingsUserWeekOffset.text;
    Future.delayed(Duration.zero, ()async{
      await storage.DataCache.setUserWeekOffset(correctedVal);
    });
  }

  static void settingsUserWeekOffsetChangeDetect(){
    _instance?._settingsUserWeekOffsetChangeDetect();
  }

  static void onSemesterChanged(){
    _instance?._onSemesterChanged();
  }

  void _onSemesterChanged(){
    Future.delayed(Duration.zero, () async {
      await storage.DataCache.setHasCachedMarkbook(0);
      await storage.DataCache.setHasCachedPeriods(0);
      await storage.DataCache.setHasCachedCalendar(0);
      await storage.DataCache.setHasCachedFirstWeekEpoch(0);

      final firstWeekOfSemester = await api.InstitutesRequest.getFirstStudyweek();
      if (firstWeekOfSemester != null) {
        await storage.DataCache.setFirstWeekEpoch(firstWeekOfSemester);
        storage.DataCache.setHasCachedFirstWeekEpoch(1);
      }

      if (mounted) {
        setState(() {
          weeksSinceStart = calcPassedWeeks();
        });
      }

      await Future.wait([
        onMarkbookRefresh(),
        onPeriodsRefresh(),
        onCalendarRefresh(false),
      ]);
    });
  }

  void _settingsUserWeekOffsetChangeDetect(){
    final currentOffset = storage.DataCache.getUserWeekOffset()!;
    if(settingsUserWeekOffsetPrev != currentOffset){
      settingsUserWeekOffsetPrev = currentOffset;
      Future.delayed(Duration.zero,() async{
        await storage.DataCache.setHasCachedCalendar(0);
        await AppNotifications.cancelScheduledNotifs();
      }).whenComplete(()async{
        await onCalendarRefresh(false);
      });
    }
  }

  void setupCalendarGreetText(){
    final currentTimeHour = DateTime.now().hour;
    if(currentTimeHour > 1 && currentTimeHour <= 6){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_1to6;
      });
    }
    else if(currentTimeHour > 6 && currentTimeHour <= 9){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_6to9;
      });
    }
    else if(currentTimeHour > 9 && currentTimeHour <= 13){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_9to13;
      });
    }
    else if(currentTimeHour > 13 && currentTimeHour <= 17){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_13to17;
      });
    }
    else if(currentTimeHour > 17 && currentTimeHour <= 21){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_17to21;
      });
    }
    else if(currentTimeHour > 21 || currentTimeHour <= 1){
      setState(() {
        calendarGreetText = AppStrings.getLanguagePack().topheader_calendar_greetMessage_21to1;
      });
    }
  }

  void clearCalendar(){
    setState(() {
      weeksSinceStart = calcPassedWeeks();
      calendarEntries.clear();
      mondayCalendar.clear();
      tuesdayCalendar.clear();
      wednessdayCalendar.clear();
      thursdayCalendar.clear();
      fridayCalendar.clear();
      saturdayCalendar.clear();
      sundayCalendar.clear();
    });
  }

  void clearMarkbook(){
    setState(() {
      markbookEntries.clear();
      markbookList.clear();
    });
  }

  void clearPayments(){
    setState(() {
      paymentsEntries.clear();
      paymentsList.clear();
    });
  }
  void clearPeriods(){
    setState(() {
      periodEntries.clear();
      periodList.clear();
      currentSemester = -1;
      countActivePeriods = 0;
      countExpiredPeriods = 0;
      countFuturePeriods = 0;
    });
  }

  void clearMails(){
    setState(() {
      mailEntries.clear();
      mailList.clear();
      currentMailPage = 1;
      currentMailLoadingDebounce = false;
      unreadMailCount = 0;
      totalMailCount = 0;
      allLoadedMailCount = 0;
    });
  }

  void setupCalendar(bool thisweekCalendar){
    setState(() {
      _setupCalendar(thisweekCalendar);
      canDoCalendarPaging = true;
      setupCalendarController(false, false);
    });
  }
  void setupMarkbook(){
    setState(() {
      _setupMarkbook();
    });
  }

  void setupPayments(){
    setState(() {
      _setupPayments();
    });
  }

  void setupPeriods(){
    setState(() {
      _setupPeriods();
    });
  }

  void setupMails({bool clear = false}){
    setState(() {
      _setupMails(clearLoader: clear);
    });
  }

  static void setupExamNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupExamNotifications(_instance!._examNotificationList);
    });
  }

  static void cancelExamNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelExamNotifications();
    });
  }

  final _examNotificationList = <api.CalendarEntry>[];
  
  Future<void> _skimForExams()async{
    _examNotificationList.clear();
    for(int i = 0; i < 3; i++){
      final result = await fetchCalendarToList(i);
      _examNotificationList.addAll(result);
    }

    _setupExamNotifications(_examNotificationList);
  }
  
  Future<void> _setupExamNotifications(List<api.CalendarEntry> items)async{
    await _cancelExamNotifications();
    if(_examNotificationList.isEmpty){
      return;
    }
    final now = DateTime.now();
    for(var item in items){ // add notifiers for exams
      if(!item.isExam || now.millisecondsSinceEpoch > item.startEpoch){
        continue;
      }
      await _setupNotificationsForSkimmedExams(item, now);
    }
  }

  Future<void> _setupNotificationsForSkimmedExams(api.CalendarEntry item, DateTime now)async{
    final daysTillExam = (Duration(milliseconds: item.startEpoch) - Duration(milliseconds: now.millisecondsSinceEpoch)).inDays;
    for(int i = 1; i <= daysTillExam + 1; i++){
      if(i == 1){
        await AppNotifications.scheduleNotification('Vizsga emlékeztető!', '"${item.title}" tárgyból vizsgád lesz MA!', DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 06, 00), 0);
        continue;
      }
      else if(i == 2){
        await AppNotifications.scheduleNotification('Vizsga emlékeztető!', '"${item.title}" tárgyból vizsgád lesz HOLNAP!', DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 09, 00), 0);
        continue;
      }
      await AppNotifications.scheduleNotification('Vizsga emlékeztető!', '"${item.title}" tárgyból vizsgád lesz $i nap múlva!', DateTime(now.year, now.month, now.day + daysTillExam - i + 2, 09, 00), 0);
    }
  }

  Future<void> _cancelExamNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(0);
  }

  static void setupClassesNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupClassesNotifications(_instance!._classesNotificationList);
    });
  }

  static void cancelClassesNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelClassesNotifications();
    });
  }

  final List<api.CalendarEntry> _classesNotificationList = <api.CalendarEntry>[].toList();

  Future<void> _setupClassesNotifications(List<api.CalendarEntry> items)async{
    await _cancelClassesNotifications();
    if(!storage.DataCache.getNeedClassNotifications()!){
      return;
    }
    for(var item in items){
      // set up notifications for today
      final now = DateTime.now();
      if(now.millisecondsSinceEpoch < item.startEpoch && !item.isExam){ // did not pass them in time

        String finalRoom = item.location;
        if (item.classInstanceId != null && item.classInstanceId!.isNotEmpty) {
          String? cachedRoom = await storage.getString('room_${item.classInstanceId}');
          if (cachedRoom != null && cachedRoom.isNotEmpty && cachedRoom != "Nincs terem") {
            finalRoom = cachedRoom;
          }
        }
        // -------------------------------------------------------------------------------

        await AppNotifications.scheduleNotification('Óra', '"${item.title}" órád lesz itt: "$finalRoom" 10 perc múlva!', DateTime.fromMillisecondsSinceEpoch((Duration(milliseconds: item.startEpoch) - const Duration(minutes: 10)).inMilliseconds), 1);
        await AppNotifications.scheduleNotification('Óra', '"${item.title}" órád lesz itt: "$finalRoom" 5 perc múlva!', DateTime.fromMillisecondsSinceEpoch((Duration(milliseconds: item.startEpoch) - const Duration(minutes: 5)).inMilliseconds), 1);
        await AppNotifications.scheduleNotification('Óra', '"${item.title}" órád van itt: "$finalRoom"!', DateTime.fromMillisecondsSinceEpoch(item.startEpoch), 1);
      }
    }
  }
  
  Future<void> _cancelClassesNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(1);
  }

  static void setupPaymentsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupPaymentsNotification(_instance!._paymentsNotificationList);
    });
  }

  static void cancelPaymentsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelPaymentsNotifications();
    });
  }

  final List<api.CashinEntry> _paymentsNotificationList = <api.CashinEntry>[].toList();

  Future<void> _setupPaymentsNotification(List<api.CashinEntry> items)async{
    await _cancelPaymentsNotifications();
    if(!storage.DataCache.getNeedPaymentsNotifications()! || _paymentsNotificationList.isEmpty){
      return;
    }
    final now = DateTime.now();
    for(var item in items){
      if(item.dueDateMs == 0){
        for(int i = 0; i <= 31; i++){
          await AppNotifications.scheduleNotification('Befizetés', '${item.ammount}Ft-al lógsz. Fizesd be! (Nincs határidő)', DateTime(now.year, now.month, now.day + i, 11, 00),2 );
        }
        continue;
      }
      final daysRemaining = (Duration(milliseconds: item.dueDateMs) - Duration(milliseconds: now.millisecondsSinceEpoch)).inDays;
      final time = DateTime.fromMillisecondsSinceEpoch(item.dueDateMs);
      for(int i = 0; i <= daysRemaining; i++){
        await AppNotifications.scheduleNotification('Befizetés', '${item.ammount}Ft-al lógsz. Fizesd be: ${daysRemaining > 61 ? "(${time.year})" : ""} ${api.Generic.monthToText(time.month)}. ${time.day}.-ig!', DateTime(now.year, now.month, now.day + i, 11, 00), 2);
      }
    }
  }

  Future<void> _cancelPaymentsNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(2);
  }
  
  static void setupPeriodsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._setupPeriodsNotification(_instance!._periodsNotificationList);
    });
  }

  static void cancelPeriodsNotifications(){
    Future.delayed(Duration.zero, ()async{
      await _instance!._cancelPeriodsNotifications();
    });
  }

  final List<api.PeriodEntry> _periodsNotificationList = <api.PeriodEntry>[].toList();
  
  Future<void> _setupPeriodsNotification(List<api.PeriodEntry> items)async{
    await _cancelPeriodsNotifications();
    if(!storage.DataCache.getNeedPeriodsNotifications()! || _periodsNotificationList.isEmpty){
      return;
    }

    for(var item in items){
      final time = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      await AppNotifications.scheduleNotification('Időszak', '"${api.Generic.capitalizePeriodText(item.name)}" időszak lesz HOLNAP!', DateTime(time.year, time.month, time.day - 1, 11, 00), 3);
      await AppNotifications.scheduleNotification('Időszak', '"${api.Generic.capitalizePeriodText(item.name)}" időszak van MA!', DateTime(time.year, time.month, time.day, 06, 00), 3);
    }
  }

  Future<void> _cancelPeriodsNotifications()async{
    await AppNotifications.cancelScheduledNotifsId(3);
  }

  void _setupCalendar(bool thisweekCalendar){
    mondayCalendar.clear();
    tuesdayCalendar.clear();
    wednessdayCalendar.clear();
    thursdayCalendar.clear();
    fridayCalendar.clear();
    saturdayCalendar.clear();
    sundayCalendar.clear();

    if (thisweekCalendar) {
      _classesNotificationList.clear();
    }

    // Sort entries chronologically
    calendarEntries.sort((a, b) => a.startEpoch.compareTo(b.startEpoch));

    int idx = 1;
    int prev = 0;
    api.CalendarEntry? prevEntry;
    final currWeekday = DateTime.now().weekday;
    final now = DateTime.now();
    final Map<int, api.CalendarEntry> prevClassPerWkday = {};
    final Set<String> shownToSlotsKey = {};

    for(var item in calendarEntries){
      final wkday = DateTime.fromMillisecondsSinceEpoch(item.startEpoch).weekday;
      if(prev != wkday){
        idx = 1;
        prev = wkday;
        prevEntry = item;
      } else if (prevEntry != null && item.startEpoch == prevEntry.startEpoch) {
        // Same timeslot
      } else {
        idx++;
      }
      prevEntry = item;

      if(thisweekCalendar && currWeekday == wkday && !item.isExam){
        _classesNotificationList.add(item);
      }

      // Szünet detektálása az azonos napon lévő egymást követő órák között
      final prevClass = prevClassPerWkday[wkday];
      if (prevClass != null && !prevClass.isExam && !item.isExam) {
        final breakStart = prevClass.endEpoch;
        final breakEnd = item.startEpoch;
        final breakMs = breakEnd - breakStart;
        if (breakMs >= 5 * 60 * 1000 && breakMs < 24 * 3600 * 1000) { // legalább 5 perces és maximum 24 órás szünet
          final isCurrentBreak = now.millisecondsSinceEpoch >= breakStart &&
              now.millisecondsSinceEpoch < breakEnd &&
              wkday == currWeekday &&
              currentWeekOffset == 1;

          ToOfficeSlot? breakMatchedToSlot;
          if (storage.DataCache.getShowToOfficeSchedule()) {
            final toSlots = ToOfficeService.getSlotsForDay(wkday);
            final bStartDate = DateTime.fromMillisecondsSinceEpoch(breakStart);
            final bEndDate = DateTime.fromMillisecondsSinceEpoch(breakEnd);
            final bStartMin = bStartDate.hour * 60 + bStartDate.minute;
            final bEndMin = bEndDate.hour * 60 + bEndDate.minute;

            for (var slot in toSlots) {
              final sStartMin = slot.startHour * 60 + slot.startMinute;
              final sEndMin = slot.endHour * 60 + slot.endMinute;
              final slotKey = '$wkday-${slot.startHour}:${slot.startMinute}';
              if (bStartMin < sEndMin && bEndMin > sStartMin && !shownToSlotsKey.contains(slotKey)) {
                breakMatchedToSlot = slot;
                shownToSlotsKey.add(slotKey);
                break;
              }
            }
          }

          final breakWidget = t_table.BreakElementWidget(
            startEpoch: breakStart,
            endEpoch: breakEnd,
            isCurrent: isCurrentBreak,
            nextClassTitle: item.title,
            toOfficeSlot: breakMatchedToSlot,
          );

          switch(wkday){
            case 1: mondayCalendar.add(breakWidget); break;
            case 2: tuesdayCalendar.add(breakWidget); break;
            case 3: wednessdayCalendar.add(breakWidget); break;
            case 4: thursdayCalendar.add(breakWidget); break;
            case 5: fridayCalendar.add(breakWidget); break;
            case 6: saturdayCalendar.add(breakWidget); break;
            case 7: sundayCalendar.add(breakWidget); break;
          }
        }
      }

      prevClassPerWkday[wkday] = item;

      final isCurrent = !item.isExam && now.millisecondsSinceEpoch >= item.startEpoch && now.millisecondsSinceEpoch <= item.endEpoch && wkday == currWeekday && currentWeekOffset == 1;

      Widget classWidget;
      if (storage.DataCache.getShowToOfficeSchedule()) {
        final toSlots = ToOfficeService.getSlotsForDay(wkday);
        final classStartDate = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
        final classEndDate = DateTime.fromMillisecondsSinceEpoch(item.endEpoch);
        final cStartMin = classStartDate.hour * 60 + classStartDate.minute;
        final cEndMin = classEndDate.hour * 60 + classEndDate.minute;

        ToOfficeSlot? matchedSlot;
        for (var slot in toSlots) {
          final sStartMin = slot.startHour * 60 + slot.startMinute;
          final sEndMin = slot.endHour * 60 + slot.endMinute;
          final slotKey = '$wkday-${slot.startHour}:${slot.startMinute}';
          if (cStartMin < sEndMin && cEndMin > sStartMin && !shownToSlotsKey.contains(slotKey)) {
            matchedSlot = slot;
            shownToSlotsKey.add(slotKey);
            break;
          }
        }

        if (matchedSlot != null) {
          final isSlotCurrent = wkday == currWeekday && currentWeekOffset == 1 && ToOfficeService.isCurrentlyOpen();
          classWidget = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: t_table.TimetableElementWidget(
                      entry: item,
                      position: idx,
                      isCurrent: isCurrent,
                      fullWidthMargin: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToOfficeOverlayWidget(
                    slot: matchedSlot,
                    isCurrent: isSlotCurrent,
                  ),
                ],
              ),
            ),
          );
        } else {
          classWidget = t_table.TimetableElementWidget(
            entry: item,
            position: idx,
            isCurrent: isCurrent,
          );
        }
      } else {
        classWidget = t_table.TimetableElementWidget(
          entry: item,
          position: idx,
          isCurrent: isCurrent,
        );
      }

      switch(wkday){
        case 1:
          mondayCalendar.add(classWidget);
          break;
        case 2:
          tuesdayCalendar.add(classWidget);
          break;
        case 3:
          wednessdayCalendar.add(classWidget);
          break;
        case 4:
          thursdayCalendar.add(classWidget);
          break;
        case 5:
          fridayCalendar.add(classWidget);
          break;
        case 6:
          saturdayCalendar.add(classWidget);
          break;
        case 7:
          sundayCalendar.add(classWidget);
          break;
      }
    }

    if (storage.DataCache.getShowToOfficeSchedule()) {
      for (int d = 1; d <= 7; d++) {
        final daySlots = ToOfficeService.getSlotsForDay(d);
        for (var slot in daySlots) {
          final slotKey = '$d-${slot.startHour}:${slot.startMinute}';
          if (!shownToSlotsKey.contains(slotKey)) {
            final banner = ToOfficeStandaloneBanner(
              slot: slot,
              isCurrent: d == currWeekday && currentWeekOffset == 1 && ToOfficeService.isCurrentlyOpen(),
            );
            switch (d) {
              case 1: mondayCalendar.insert(0, banner); break;
              case 2: tuesdayCalendar.insert(0, banner); break;
              case 3: wednessdayCalendar.add(banner); break;
              case 4: thursdayCalendar.insert(0, banner); break;
              case 5: fridayCalendar.insert(0, banner); break;
              case 6: saturdayCalendar.insert(0, banner); break;
              case 7: sundayCalendar.insert(0, banner); break;
            }
          }
        }
      }
    }

    final dayLists = [
      mondayCalendar,
      tuesdayCalendar,
      wednessdayCalendar,
      thursdayCalendar,
      fridayCalendar,
      saturdayCalendar,
      sundayCalendar,
    ];

    if (storage.DataCache.getShowPeriodsInCalendar()) {
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      final activePeriods = periodEntries.where((p) => nowEpoch >= p.startEpoch && nowEpoch <= p.endEpoch).toList();
      if (activePeriods.isNotEmpty) {
        final periodNames = activePeriods.map((p) => api.Generic.capitalizePeriodText(p.name)).join(' • ');
        final periodBadge = Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.getTheme().primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.getTheme().primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_rounded, size: 15, color: AppColors.getTheme().primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  periodNames,
                  style: TextStyle(
                    color: AppColors.getTheme().primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        for (var list in dayLists) {
          if (list.isNotEmpty) {
            list.insert(0, periodBadge);
          }
        }
      }
    }

    bool dayHasClasses(int dayIdx) {
      if (dayIdx < 0 || dayIdx >= dayLists.length) return false;
      return dayLists[dayIdx].any((w) => w is t_table.TimetableElementWidget);
    }

    int firstDayWithClasses() {
      for (int i = 0; i < dayLists.length; i++) {
        if (dayHasClasses(i)) return i;
      }
      return 0; // Alapértelmezett: Hétfő
    }

    int targetIndex = calendarTabController.index;

    if (currentWeekOffset == 1) {
      int todayIndex = currWeekday - 1;
      if (todayIndex < 0 || todayIndex > 6) todayIndex = 0;
      targetIndex = todayIndex;
    } else {
      // Másik hétre váltáskor: ha az adott napon nincs óra, ugorjunk a hét első tanórás napjára (pl. Hétfőre)
      if (!dayHasClasses(targetIndex)) {
        targetIndex = firstDayWithClasses();
      }
    }

    if (targetIndex >= 0 && targetIndex < calendarTabController.length) {
      calendarTabController.index = targetIndex;
    }
  }

  List<Widget> calendarTabs = <Widget>[].toList();
  List<Widget> calendarTabViews = <Widget>[].toList();

  void setupCalendarController(bool replaceController, bool isLoading){
    calendarTabs = <Widget>[].toList();
    calendarTabViews = <Widget>[].toList();
    getCalendarTabViews(context, isLoading);
    if(replaceController) {
      calendarTabController = TabController(length: calendarTabs.length, vsync: this);
    }
    setState(() {
      isLoadingCalendar = isLoading;
    });
  }

  void _fillOneCalendarElement(BuildContext context, List<Widget> w, String name, bool isLoading){
    calendarTabs.add(Tab(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          name,
          textAlign: TextAlign.center,
        ),
      ),
    ));
    calendarTabViews.add(RefreshIndicator(
      onRefresh: ()async{AppHaptics.lightImpact(); onCalendarRefresh(false);},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey<String>('day_${name}_${weeksSinceStart}_${w.length}_$isLoading'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: w.isNotEmpty ? w : isLoading ? <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.getTheme().primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.getTheme().textColor.withValues(alpha: .3),
                    fontWeight: FontWeight.w400,
                    fontSize: 11,
                  ),
                ),
              ] : <Widget>[const t_table.FreedayElementWidget()],
            ),
          ),
        ),
      ),
    ));
  }

  void getCalendarTabViews(BuildContext context, bool isLoading){
    final nowWk = DateTime.now().weekday;
    final isCurrentWeek = currentWeekOffset == 1;
    String formatDayTab(int dayNum, String shortName) {
      if (isCurrentWeek && nowWk == dayNum) {
        return '$shortName (Ma)';
      }
      return shortName;
    }

    _fillOneCalendarElement(context, mondayCalendar, formatDayTab(1, 'H'), isLoading);
    _fillOneCalendarElement(context, tuesdayCalendar, formatDayTab(2, 'K'), isLoading);
    _fillOneCalendarElement(context, wednessdayCalendar, formatDayTab(3, 'Sze'), isLoading);
    _fillOneCalendarElement(context, thursdayCalendar, formatDayTab(4, 'Cs'), isLoading);
    _fillOneCalendarElement(context, fridayCalendar, formatDayTab(5, 'P'), isLoading);
    _fillOneCalendarElement(context, saturdayCalendar, formatDayTab(6, 'Szo'), isLoading);
    _fillOneCalendarElement(context, sundayCalendar, formatDayTab(7, 'V'), isLoading);
  }

  void _mbookPopupResult(int result, int idx){
    if(result == -1){
      setState(() {
        final e = markbookList[idx] as mbook.MarkbookElementWidget;
        setState(() {
          markbookList[idx] = mbook.MarkbookElementWidget(
            name: e.name,
            credit: e.credit,
            completed: e.completed,
            grade: e.grade,
            isFailed: e.isFailed,
            onPopupResult: e.onPopupResult,
            listIndex: e.listIndex,
            ghostGrade: -1,
          );
          _markbookCalcGhostAvg();
        });
      });
      return;
    }

    final grade = result + 1;
    final e = markbookList[idx] as mbook.MarkbookElementWidget;
    setState(() {
      markbookList[idx] = mbook.MarkbookElementWidget(
        name: e.name,
        credit: e.credit,
        completed: e.completed,
        grade: e.grade,
        isFailed: e.isFailed,
        onPopupResult: e.onPopupResult,
        listIndex: e.listIndex,
        ghostGrade: grade,
      );
      _markbookCalcGhostAvg();
    });
  }
  
  void _setupMarkbook(){
    markbookList.clear();
    totalCredits = 0;
    totalAvg = 5;
    totalAvg30 = 5;
    if(markbookEntries.isEmpty){
      markbookList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().markbookPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }

    //order them
    for (int i = 0; i < markbookEntries.length; i++){
      for (int j = i; j < markbookEntries.length; j++){
        if(markbookEntries[j].credit > markbookEntries[i].credit){
          final tmp = markbookEntries[i];
          markbookEntries[i] = markbookEntries[j];
          markbookEntries[j] = tmp;
        }
      }
    }

    // set them up
    totalCredits = 0;
    totalAvg = 0;
    totalAvg30 = 0;
    var hasCompleted = false;
    var hasIncomplete = false;
    int idx = 0;
    for (var item in markbookEntries){
      totalCredits += item.credit;
      if(item.completed){
        hasCompleted = true;
        continue;
      }
      hasIncomplete = true;
      markbookList.add(mbook.MarkbookElementWidget(
        name: item.name,
        credit: item.credit,
        completed: item.completed,
        grade: item.grade,
        isFailed: item.failState == 1,
        onPopupResult: _mbookPopupResult,
        listIndex: idx,
        ghostGrade: -1,
      ));
      idx++;
    }
    if(hasCompleted) {
      if(hasIncomplete){
        markbookList.add(
            _getSeparatorLine(AppStrings.getLanguagePack().markbookPage_CompletedLine)
        );
        idx++;
      }

      for (var item in markbookEntries) {
        if (!item.completed) {
          continue;
        }
        markbookList.add(mbook.MarkbookElementWidget(
          name: item.name,
          credit: item.credit,
          completed: item.completed,
          grade: item.grade,
          isFailed: item.failState == 1,
          onPopupResult: _mbookPopupResult,
          listIndex: idx,
          ghostGrade: -1,
        ));
        idx++;
      }
    }
    _confettiCanBePlayed = !hasIncomplete && hasCompleted; // all finished
    _markbookCalcAvg();
  }

  void _markbookCalcAvg(){
    if(markbookEntries.isEmpty){
      return;
    }
    var currCredits = 0;
    for(var item in markbookEntries){
      if (!item.completed) {
        continue;
      }
      if (item.grade >= 2) {
        currCredits += item.credit;
        totalAvg += item.grade * item.credit;
      }
    }
    totalAvg30 = totalAvg / 30;
    totalAvg /= currCredits;
  }

  void _markbookCalcGhostAvg(){
    if(markbookEntries.isEmpty){
      return;
    }
    var currCredits = 0;
    totalAvg = 0;
    totalAvg30 = 0;
    for(var item in markbookList){
      try{
        final itm = item as mbook.MarkbookElementWidget;
        if(!itm.completed && itm.ghostGrade == -1){
          continue;
        }
        if (item.grade >= 2) {
          currCredits += item.credit;
          totalAvg += item.grade * item.credit;
        }
        else if(item.ghostGrade != -1){
          currCredits += item.credit;
          totalAvg += item.ghostGrade * item.credit;
        }
      }
      catch(_){}
    }
    totalAvg30 = totalAvg / 30;
    totalAvg /= currCredits;
  }

  void _setupPayments(){
    _paymentsNotificationList.clear();
    paymentsList.clear();
    totalMoney = 0;

    // Sort descending by date (newest first)
    paymentsEntries.sort((a, b) => b.dueDateMs.compareTo(a.dueDateMs));

    for(var item in paymentsEntries){
      if(!item.isIgnored && item.completed && item.ammount < 0){
        totalMoney += item.ammount.abs();
      }
      if(!item.completed && !item.isIgnored && (item.dueDateMs > DateTime.now().millisecondsSinceEpoch || item.dueDateMs == 0)){
        _paymentsNotificationList.add(item);
      }
      paymentsList.add(PaymentElementWidget(
        ammount: item.ammount,
        dueDateMs: item.dueDateMs,
        ID: item.ID,
        name: item.comment,
        completed: item.completed,
        direction: item.direction,
        note: item.note,
        currency: item.currency,
        isIgnored: item.isIgnored,
      ));
    }

    if(_paymentsNotificationList.isNotEmpty){
      Future.delayed(Duration.zero,()async{
        await _setupPaymentsNotification(_paymentsNotificationList);
      });
    }

    if(paymentsEntries.isEmpty){
      paymentsList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().paymentPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }
  }

  Widget _getSeparatorLine(String text, {bool expired = false}) {
    final theme = AppColors.getTheme();
    final badgeColor = expired ? theme.errorRed : theme.textColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    badgeColor.withValues(alpha: 0.0),
                    badgeColor.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: expired
                  ? theme.errorRed.withValues(alpha: 0.12)
                  : theme.secondary.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: expired
                    ? theme.errorRed.withValues(alpha: 0.35)
                    : theme.textColor.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: expired
                    ? theme.errorRed
                    : theme.textColor.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    badgeColor.withValues(alpha: 0.25),
                    badgeColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setupPeriods(){
    _periodsNotificationList.clear();
    periodList.clear();
    countActivePeriods = 0;
    countFuturePeriods = 0;
    countExpiredPeriods = 0;
    //order them
    for (int i = 0; i < periodEntries.length; i++){
      for (int j = i; j < periodEntries.length; j++){
        if(periodEntries[j].startEpoch < periodEntries[i].startEpoch){
          final tmp = periodEntries[i];
          periodEntries[i] = periodEntries[j];
          periodEntries[j] = tmp;
        }
      }
    }

    int prevSemester = -1;

    List<api.PeriodEntry> expiredPeriods = [];
    bool hasFuturePeriodLine = false;
    //Map<String, List<api.PeriodType>> values = Map<String, List<api.PeriodType>>.identity();
    for(var item in periodEntries){
      if(item.isActive){
        countActivePeriods++;
      }
      else if(item.endEpoch > DateTime.now().millisecondsSinceEpoch){
        if(!hasFuturePeriodLine){
          hasFuturePeriodLine = true;
          periodList.add(
              const Padding(padding: EdgeInsets.only(top: 10))
          );
          periodList.add(
              _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_FutureText)
          );
        }
        countFuturePeriods++;
      }
      else{
        countExpiredPeriods++;
      }

      final starttime = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      final endtime = DateTime.fromMillisecondsSinceEpoch(item.endEpoch);
      final now = DateTime.now().millisecondsSinceEpoch;
      if(now > endtime.millisecondsSinceEpoch){
        expiredPeriods.add(item);
        continue; // expired
      }
      if(prevSemester == -1 && countActivePeriods != 0){
        prevSemester = item.partofSemester;
        periodList.add(
            const Padding(padding: EdgeInsets.only(top: 10))
        );
        periodList.add(
            _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_ActiveText)
        );
      }
      else if(item.partofSemester != prevSemester){
        prevSemester = item.partofSemester;
      }
      if(!item.isActive){ // exclude today
        _periodsNotificationList.add(item);
      }
      periodList.add(priods.PeriodsElementWidget(
        displayName: api.Generic.capitalizePeriodText(item.name),
        formattedStartTime: '${api.Generic.monthToText(starttime.month)}. ${starttime.day}.',
        formattedStartTimeYear: '${starttime.year}',
        formattedEndTime: '${api.Generic.monthToText(endtime.month)}. ${endtime.day}.',
        formattedEndTimeYear: '${endtime.year}',
        isActive: item.isActive,
        periodType: item.type,
        startTime: item.startEpoch,
        endTime: (DateTime.fromMillisecondsSinceEpoch(item.endEpoch).millisecondsSinceEpoch),
        expired: false,
      ));
      if(currentSemester == -1) {
        currentSemester = item.partofSemester;
      }
    }

    if(expiredPeriods.isNotEmpty){
      periodList.add(
          const Padding(padding: EdgeInsets.only(top: 10))
      );

      periodList.add(
          _getSeparatorLine(AppStrings.getLanguagePack().topheader_periods_ExpiredText, expired: true)
      );
    }
    
    for(var item in expiredPeriods){
      final starttime = DateTime.fromMillisecondsSinceEpoch(item.startEpoch);
      final endtime = DateTime.fromMillisecondsSinceEpoch(item.endEpoch);
      periodList.add(priods.PeriodsElementWidget(
        displayName: api.Generic.capitalizePeriodText(item.name),
        formattedStartTime: '${api.Generic.monthToText(starttime.month)}. ${starttime.day}.',
        formattedStartTimeYear: '${starttime.year}',
        formattedEndTime: '${api.Generic.monthToText(endtime.month)}. ${endtime.day}.',
        formattedEndTimeYear: '${endtime.year}',
        isActive: item.isActive,
        periodType: item.type,
        startTime: item.startEpoch,
        endTime: (DateTime.fromMillisecondsSinceEpoch(item.endEpoch).millisecondsSinceEpoch),
        expired: true,
      ));
    }

    if(_periodsNotificationList.isNotEmpty){
      Future.delayed(Duration.zero,()async{
        await _setupPeriodsNotification(_periodsNotificationList);
      });
    }

    if(periodEntries.isEmpty){
      periodList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().periodPage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }
  }

  void _setupMails({bool clearLoader = false}){
    if(mailEntries.isEmpty){
      mailList.add(Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: EmojiRichText(
            text: AppStrings.getLanguagePack().messagePage_Empty,
            defaultStyle: TextStyle(
              color: AppColors.getTheme().onPrimaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 26.0,
            ),
            emojiStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontSize: 26.0,
                fontFamily: "Noto Color Emoji"
            ),
          ),
        ),
      ));
    }

    if(clearLoader && mailList.isNotEmpty){
      mailList.removeAt(mailList.length-1);
    }

    int idx = 0;
    var prevDate = DateTime.now();
    mailList.add(
        const Padding(padding: EdgeInsets.only(top: 10))
    );
    for(var item in mailEntries){
      allLoadedMailCount++;
      final date = DateTime.fromMillisecondsSinceEpoch(item.sendDateMs);
      final currDate = DateTime(date.year, date.month, date.day);
      if(mailEntries.length != ++idx && prevDate != currDate){
        prevDate = currDate;
        mailList.add(_getSeparatorLine('${currDate.year}. ${api.Generic.monthToText(date.month)}. ${date.day}.'));
      }
      mailList.add(MailElementWidget(subject: item.subject, details: item.detail, sender: item.senderName, sendTime: item.sendDateMs, isRead: item.isRead, mailID: item.ID, callback: (element){
        setState(() {
          if(element.isRead){
            return;
          }
          final indx = mailList.indexOf(element);
          mailList.insert(indx, MailElementWidget(subject: element.subject, details: element.details, sender: element.sender, sendTime: element.sendTime, isRead: true, mailID: element.mailID, callback: (_){}));
          mailList.remove(element);
          unreadMailCount--;
          storage.saveInt('CachedMailsUnread', unreadMailCount);
          Future.delayed(Duration.zero, ()async{
            await api.MailRequest.setMailRead(MailPopupDisplayTexts.mailID);
            if(currentMailPage == 1){
              storage.DataCache.setHasCachedMail(0);
            }
          });
        });
      },));
    }
  }

  Future<void> markAllMailsAsRead() async {
    final unreadItems = mailEntries.where((m) => !m.isRead).toList();
    for (var item in mailEntries) {
      item.isRead = true;
    }
    unreadMailCount = 0;
    await storage.saveInt('CachedMailsUnread', 0);
    await storage.DataCache.setUnreadMailCount(0);
    setupMails(clear: true);

    Fluttertoast.showToast(
      msg: AppStrings.getLanguagePack().messagePage_AllMarkedAsReadToast,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.SNACKBAR,
      backgroundColor: AppColors.getTheme().rootBackground,
      textColor: AppColors.getTheme().textColor,
    );
    if (mounted) setState(() {});

    Future.delayed(Duration.zero, () async {
      try {
        for (var item in unreadItems) {
          await api.MailRequest.setMailRead(item.ID);
        }
        final count = await api.MailRequest.getUnreadMessageCount();
        if (mounted) {
          setState(() {
            unreadMailCount = count;
          });
        }
      } catch (e) {
        debugPrint("Hiba az összes olvasottá tétele során: $e");
      }
    });
  }

  Future<void> stepCalendarBack() async{
    currentWeekOffset--;
    AppHaptics.lightImpact();
    await onCalendarRefresh(true);
  }
  Future<void> stepCalendarForward() async{
    currentWeekOffset++;
    AppHaptics.lightImpact();
    await onCalendarRefresh(true);
  }

  bool _isCalendarIdentical(List<api.CalendarEntry> a, List<api.CalendarEntry> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].startEpoch != b[i].startEpoch ||
          a[i].endEpoch != b[i].endEpoch ||
          a[i].title != b[i].title ||
          a[i].location != b[i].location ||
          a[i].eventType != b[i].eventType ||
          a[i].classInstanceId != b[i].classInstanceId ||
          a[i].teacher != b[i].teacher) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _loadPermanentCalendarEntries(int weekOffset) async {
    final activeTerm = storage.DataCache.getSelectedTermId() ?? '';
    final cachedTerm = await storage.getString('CalendarCacheTermId');
    final bool hasNetwork = storage.DataCache.getHasNetwork();

    final permKey = 'PermanentCalendar_w$weekOffset';
    int? len = await storage.getInt('${permKey}_len');
    String? permTerm = await storage.getString('${permKey}_term');

    if (len == null || len <= 0) {
      final weekKey = 'CachedCalendar_w$weekOffset';
      len = await storage.getInt('${weekKey}_len');
      if (len == null && weekOffset == 1) {
        len = await storage.getInt('CachedCalendarLength');
      }
    }

    if (len != null && len > 0 && (permTerm == activeTerm || cachedTerm == activeTerm || activeTerm.isEmpty || !hasNetwork)) {
      final List<api.CalendarEntry> loaded = [];
      for (int i = 0; i < len; i++) {
        final calEntry = await storage.getString('${permKey}_$i') ??
            await storage.getString('CachedCalendar_w${weekOffset}_$i') ??
            (weekOffset == 1 ? await storage.getString('CachedCalendar_$i') : null);
        if (calEntry != null) {
          loaded.add(api.CalendarEntry('0', '0', 'NULL', 'NULL', false).fillWithExisting(calEntry));
        }
      }
      if (loaded.isNotEmpty) {
        calendarEntries = loaded;
        storage.DataCache.setHasCachedFirstWeekEpoch(1);
        api.CalendarRequest.fillMissingDetails(calendarEntries, () {
          if (mounted) setState(() {});
        });
        if (weekOffset == 1) {
          Future.delayed(Duration.zero, () async {
            await _setupClassesNotifications(_classesNotificationList);
          });
        }
        return true;
      }
    }
    return false;
  }

  Future<List<api.CalendarEntry>> fetchCalendarToList(int offset) async{
    //final userOffset = storage.DataCache.getUserWeekOffset()!;
    final request = await api.CalendarRequest.makeCalendarRequest(api.CalendarRequest.getCalendarOneWeekJSON(storage.DataCache.getUsername()!, storage.DataCache.getPassword()!, currentWeekOffset + offset));
    final list = api.CalendarRequest.getCalendarEntriesFromJSON(request);
    //return list2;
    return list;
  }

  Future<void> fetchCalendar({bool allowCache = true, bool silentRefreshIfOnline = true}) async{
    if(storage.DataCache.getHasICSFile() ?? false){
      final DateTime now = DateTime.now();
      final mondayThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final int deltaWeeks = currentWeekOffset - 1;

      final startOfTargetWeek = mondayThisWeek.add(Duration(days: deltaWeeks * 7));
      final endOfTargetWeek = startOfTargetWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

      final epochStart = startOfTargetWeek.millisecondsSinceEpoch;
      final epochEnd = endOfTargetWeek.millisecondsSinceEpoch;

      calendarEntries.clear();
      calendarEntries = ICSCalendar.getCalendarInterval(epochStart, epochEnd);

      storage.DataCache.setHasCachedFirstWeekEpoch(1);
      return;
    }

    final activeTerm = storage.DataCache.getSelectedTermId() ?? '';
    final bool hasNetwork = storage.DataCache.getHasNetwork();

    // 1. Helyi tárolóból betöltés offline használathoz és azonnali megjelenítéshez (~0.05s)
    if (allowCache) {
      final loaded = await _loadPermanentCalendarEntries(currentWeekOffset);
      if (loaded) {
        isCalendarOffline = !hasNetwork;

        // Azonnali megjelenítés a felületen
        if (mounted) {
          _setupCalendar(currentWeekOffset == 1);
          canDoCalendarPaging = true;
          setupCalendarController(false, false);
        }

        // Ha offline vagy nem kérünk csendes frissítést, kész vagyunk
        if (!hasNetwork || !silentRefreshIfOnline) {
          return;
        }
      }
    }

    // 2. Ha nincs internet kapcsolat
    if (!hasNetwork) {
      isCalendarOffline = true;
      if (mounted) setState(() {});
      return;
    }

    // 3. Friss adatok lekérése a hálózatról
    try {
      final request = await api.CalendarRequest.makeCalendarRequest(
        api.CalendarRequest.getCalendarOneWeekJSON(
          storage.DataCache.getUsername()!,
          storage.DataCache.getPassword()!,
          currentWeekOffset,
        ),
      );
      final list = api.CalendarRequest.getCalendarEntriesFromJSON(request);

      // Smart Dual-Cache: SOHA ne írjuk felül 0/üres adattal a meglévő naptárat!
      if (list.isNotEmpty) {
        final bool changed = !_isCalendarIdentical(calendarEntries, list);
        calendarEntries = list;
        isCalendarOffline = false;

        api.CalendarRequest.fillMissingDetails(calendarEntries, () {
          if (mounted) setState(() {});
        });

        // Smart comparison: csak akkor írunk háttértárba, ha valóban változott (~1ms check)
        if (changed) {
          // 1. Tartós tárolás (Permanent cache)
          final permKey = 'PermanentCalendar_w$currentWeekOffset';
          await storage.saveInt('${permKey}_len', calendarEntries.length);
          await storage.saveString('${permKey}_term', activeTerm);
          for (int i = 0; i < calendarEntries.length; i++) {
            await storage.saveString('${permKey}_$i', calendarEntries[i].toString());
          }

          // 2. Átmeneti munkamenet tárolás (Session cache)
          final weekKey = 'CachedCalendar_w$currentWeekOffset';
          await storage.saveInt('${weekKey}_len', calendarEntries.length);
          for (int i = 0; i < calendarEntries.length; i++) {
            await storage.saveString('${weekKey}_$i', calendarEntries[i].toString());
          }

          if (currentWeekOffset == 1) {
            await storage.saveInt('CachedCalendarLength', calendarEntries.length);
            await storage.saveString('CalendarCacheTermId', activeTerm);
            for (int i = 0; i < calendarEntries.length; i++) {
              await storage.saveString('CachedCalendar_$i', calendarEntries[i].toString());
            }
            final now = DateTime.now();
            await storage.saveString('CalendarCacheTime', DateTime(now.year, now.month, now.day, 0, 0, 0).toString());
            await storage.DataCache.setHasCachedCalendar(1);
          }
        }

        if (mounted) {
          setupCalendar(currentWeekOffset == 1);
        }

        if (currentWeekOffset == 1) {
          Future.delayed(Duration.zero, () async {
            await _setupClassesNotifications(_classesNotificationList);
          });
        }
      } else {
        // A szerver üreset adott vissza (pl. alt-tab utáni session drop vagy hálózati hiba):
        // Nem írjuk felül a tartós naptárat, megőrizzük a meglévő órákat!
        isCalendarOffline = true;
        if (calendarEntries.isEmpty) {
          final restored = await _loadPermanentCalendarEntries(currentWeekOffset);
          if (restored && mounted) {
            setupCalendar(currentWeekOffset == 1);
          }
        } else if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint("Hiba a naptár hálózati lekérésekor: $e");
      isCalendarOffline = true;
      if (calendarEntries.isEmpty) {
        final restored = await _loadPermanentCalendarEntries(currentWeekOffset);
        if (restored && mounted) {
          setupCalendar(currentWeekOffset == 1);
        }
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> fetchMarkbook() async{
    markbookEntries.clear();
    bool hasCachedMarkbook= storage.DataCache.getHasCachedMarkbook() ?? false;
    final cacheTime = await storage.getString('MarkbookCacheTime');
    final cachedTerm = await storage.getString('MarkbookCacheTermId');
    final currentTerm = storage.DataCache.getSelectedTermId() ?? '';

    if(!hasCachedMarkbook && !storage.DataCache.getHasNetwork()){
      return;
    }

    // if we had a save, and the cached value is not older than a day, and term matches, we can load that up
    if(hasCachedMarkbook && (cachedTerm == currentTerm || currentTerm.isEmpty) && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds) {
      final len = await storage.getInt('CachedMarkbookLength');
      if (len != null && len > 0) {
        for(int i = 0; i < len; i++){
          final calEntry = await storage.getString('CachedMarkbook_$i');
          if (calEntry != null) {
            markbookEntries.add(api.Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(calEntry));
          }
        }
        if (markbookEntries.isNotEmpty) {
          return;
        }
      }
    }

    //otherwise, just fetch again
    final request = await api.MarkbookRequest.getMarkbookSubjects(termId: currentTerm.isNotEmpty ? currentTerm : null);
    if(request == null || request.isEmpty){
      markbookEntries = [];
      return;
    }
    markbookEntries = request;

    if (markbookEntries.isNotEmpty) {
      storage.saveInt('CachedMarkbookLength', markbookEntries.length);
      for (int i = 0; i < markbookEntries.length; i++) {
        storage.saveString('CachedMarkbook_$i', markbookEntries[i].toString());
      }
      storage.saveString('MarkbookCacheTime', DateTime.now().toString());
      storage.saveString('MarkbookCacheTermId', currentTerm);
      storage.DataCache.setHasCachedMarkbook(1);
    }
  }

  Future<void> fetchPayments() async{
    paymentsEntries.clear();
    bool hasCachedPayments = storage.DataCache.getHasCachedPayments() ?? false;

    final cacheTime = await storage.getString('PaymentsCacheTime');

    if(!hasCachedPayments && !storage.DataCache.getHasNetwork()){
      return;
    }

    // if we had a save, and the cached value is not older than a day, we can load that up
    if(hasCachedPayments && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds) {
      final len = await storage.getInt('CachedPaymentsLength');
      if (len != null && len > 0) {
        for(int i = 0; i < len; i++){
          final calEntry = await storage.getString('CachedPayments_$i');
          if (calEntry != null) {
            final entry = api.CashinEntry(0, 0, "ERROR", "ERROR", "").fillWithExisting(calEntry);
            paymentsEntries.add(entry);
          }
        }
        if (paymentsEntries.isNotEmpty) {
          return;
        }
      }
    }

    //otherwise, just fetch again
    final request = await api.CashinRequest.getAllCashins();
    await api.CashinRequest.getCollectiveInvoiceBalance();
    if(request == null || request.isEmpty){
      paymentsEntries = [];
      return;
    }
    paymentsEntries = request;

    if (paymentsEntries.isNotEmpty) {
      storage.saveInt('CachedPaymentsLength', paymentsEntries.length);
      for (int i = 0; i < paymentsEntries.length; i++) {
        storage.saveString('CachedPayments_$i', paymentsEntries[i].toString());
      }
      storage.saveString('PaymentsCacheTime', DateTime.now().toString());
      storage.DataCache.setHasCachedPayments(1);
    }
  }

  Future<void> fetchPeriods() async{
    periodEntries.clear();
    bool hasCachedPeriods = storage.DataCache.getHasCachedPeriods() ?? false;

    final cacheTime = await storage.getString('PeriodsCacheTime');
    final cachedTerm = await storage.getString('PeriodsCacheTermId');
    final currentTerm = storage.DataCache.getSelectedTermId() ?? '';

    if(!hasCachedPeriods && !storage.DataCache.getHasNetwork()){
      return;
    }

    // if we had a save, and the cached value is not older than a day, and term matches, we can load that up
    if(hasCachedPeriods && (cachedTerm == currentTerm || currentTerm.isEmpty) && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds) {
      final len = await storage.getInt('CachedPeriodsLength');
      if (len != null && len > 0) {
        for(int i = 0; i < len; i++){
          final calEntry = await storage.getString('CachedPeriods_$i');
          if (calEntry != null) {
            final entry = api.PeriodEntry("ERROR", 0, 0, 0).fillWithExisting(calEntry);
            periodEntries.add(entry);
          }
        }
        if (periodEntries.isNotEmpty) {
          return;
        }
      }
    }

    //otherwise, just fetch again
    final request = await api.PeriodsRequest.getPeriods(termId: currentTerm.isNotEmpty ? currentTerm : null);
    if(request == null || request.isEmpty){
      periodEntries = [];
      return;
    }
    periodEntries = request;

    if (periodEntries.isNotEmpty) {
      storage.saveInt('CachedPeriodsLength', periodEntries.length);
      for (int i = 0; i < periodEntries.length; i++) {
        storage.saveString('CachedPeriods_$i', periodEntries[i].toString());
      }
      storage.saveString('PeriodsCacheTime', DateTime.now().toString());
      storage.saveString('PeriodsCacheTermId', currentTerm);
      storage.DataCache.setHasCachedPeriods(1);
    }
  }

  int currentMailPage = 1;
  bool currentMailLoadingDebounce = false;
  late ScrollController currentMailPageController;
  Future<void> fetchMails({bool force = false})async{
    bool hasCachedMails = storage.DataCache.getHasCachedMail() ?? false;

    final cacheTime = await storage.getString('MailCacheTime');

    if(!hasCachedMails && !storage.DataCache.getHasNetwork() && !force){
      return;
    }

    if(!force && hasCachedMails && cacheTime != null && (DateTime.now().millisecondsSinceEpoch - DateTime.parse(cacheTime).millisecondsSinceEpoch) < const Duration(hours: 24).inMilliseconds) {
      final len = await storage.getInt('CachedMailsLength');
      unreadMailCount = (await storage.getInt('CachedMailsUnread')) ?? 0;
      totalMailCount = (await storage.getInt('CachedMailsTotal')) ?? 0;
      for(int i = 0; i < len!; i++){
        final calEntry = await storage.getString('CachedMails_$i');
        mailEntries.add(api.MailEntry("ERROR", "ERROR", "ERROR", 0, false,"").fillWithExisting(calEntry!));
      }
      return;
    }

    final request = await api.MailRequest.getMails(currentMailPage);
    if(request == null || request.isEmpty){
      return;
    }
    mailEntries = request;

    if(force){
      return;
    }
    
    final nums = await api.MailRequest.getUnreadMessagesAndAllMessages();
    unreadMailCount = nums[0];
    totalMailCount = nums[1];

    storage.saveInt('CachedMailsLength', mailEntries.length);
    storage.saveInt('CachedMailsUnread', nums[0]);
    storage.saveInt('CachedMailsTotal', nums[1]);
    //cache calendar
    for (int i = 0; i < mailEntries.length; i++) {
      storage.saveString('CachedMails_$i', mailEntries[i].toString());
    }
    storage.saveString('MailCacheTime', DateTime.now().toString());

    storage.DataCache.setHasCachedMail(1);
  }

  Timer? _calendarTimer;

  bool _calendarDebounce = false;
  bool isLoadingCalendar = true;

  bool keepHomeButtonHidden = true;

  bool _noRefreshCalendar = false;

  Future<void> onCalendarRefresh(bool isPaging) async{
    if(_noRefreshCalendar){
      Future.delayed(const Duration(seconds: 2), (){
        _noRefreshCalendar = false;
      });
    }
    if(_calendarDebounce || _noRefreshCalendar){
      return;
    }
    _calendarTimer?.cancel();
    _calendarDebounce = true;
    keepHomeButtonHidden = false;
    setState(() {
      weeksSinceStart = calcPassedWeeks();
      canDoCalendarPaging = false;
      if (isPaging) {
        isLoadingCalendar = false;
      } else {
        isLoadingCalendar = true;
      }
    });

    try {
      await fetchCalendar(allowCache: isPaging, silentRefreshIfOnline: true);
      setupCalendar(false);
    } catch (e) {
      debugPrint("Hiba az onCalendarRefresh során: $e");
    } finally {
      _calendarDebounce = false;
      if (mounted) {
        setState(() {
          isLoadingCalendar = false;
          canDoCalendarPaging = true;
        });
      }
    }
  }

  bool _markbookDebounce = false;
  bool _noRefreshMarkbook = false;
  Future<void> onMarkbookRefresh() async{
    if(_noRefreshMarkbook){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshMarkbook = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _markbookDebounce || _noRefreshMarkbook){
      return;
    }
    _markbookDebounce = true;
    clearMarkbook();
    await storage.DataCache.setHasCachedMarkbook(0);
    await api.TermsRequest.getTerms(forceRefresh: true);
    await fetchMarkbook();
    setupMarkbook();
    _markbookDebounce = false;
  }

  bool _paymentsDebounce = false;
  bool _noRefreshPayments = false;

  Future<void> onPaymentsRefresh() async{
    if(_noRefreshPayments){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshPayments = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _paymentsDebounce || _noRefreshPayments){
      return;
    }
    _paymentsDebounce = true;
    clearPayments();
    await storage.DataCache.setHasCachedPayments(0);
    await fetchPayments();
    setupPayments();
    _paymentsDebounce = false;
  }

  bool _periodsDebounce = false;
  bool _noRefreshPeriods = false;

  Future<void> onPeriodsRefresh()async{
    if(_noRefreshPeriods){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshPeriods = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _periodsDebounce || _noRefreshPeriods){
      return;
    }
    _periodsDebounce = true;
    clearPeriods();
    await storage.DataCache.setHasCachedPeriods(0);
    await api.TermsRequest.getTerms(forceRefresh: true);
    await fetchPeriods();
    setupPeriods();
    _periodsDebounce = false;
  }

  bool _mailsDebounce = false;
  bool _noRefreshMail = false;

  Future<void> onMailRefresh()async{
    if(_noRefreshMail){
      Future.delayed(Duration(seconds: 2), (){
        _noRefreshMail = false;
      });
    }
    if(!storage.DataCache.getHasNetwork() || _mailsDebounce || _noRefreshMail){
      return;
    }
    _mailsDebounce = true;
    clearMails();
    await storage.DataCache.setHasCachedMail(0);
    await fetchMails();
    setupMails();
    _mailsDebounce = false;
  }

  DateTime getClosestMondayTo(DateTime time){
    if(time.weekday == DateTime.monday){
      return time;
    }
    final result = time.add(Duration(days: 8 - time.weekday));
    return result;
  }

  int calcPassedWeeks() {
    final epochsemester = storage.DataCache.getFirstWeekEpoch()!;
    final now = DateTime.now();
    final determiner = epochsemester > 0 ? DateTime.fromMillisecondsSinceEpoch(epochsemester) : getClosestMondayTo(DateTime(now.year - (now.millisecondsSinceEpoch > DateTime(now.year, 9, 1).millisecondsSinceEpoch ? 0 : 1), 9, 1));
    final yearlessNow = DateTime(1, now.month, now.day);
    final sepOne = DateTime(yearlessNow.year - 1, determiner.month, determiner.day); // first week

    final timepassSinceSepOne = Duration(milliseconds: (yearlessNow.millisecondsSinceEpoch - sepOne.millisecondsSinceEpoch));
    final weeksPassed = timepassSinceSepOne.inDays / 7;
    final userOffset = storage.DataCache.getUserWeekOffset()!;
    int rawWeek = (weeksPassed.floor() + currentWeekOffset + userOffset);
    if (rawWeek <= 0) {
      return ((rawWeek % 52) + 52);
    }
    return ((rawWeek - 1) % 52) + 1;
  }
  
  int calcPassedWeekOffsetless(){
    final epochsemester = storage.DataCache.getFirstWeekEpoch()!;
    final now = DateTime.now();
    final determiner = epochsemester > 0 ? DateTime.fromMillisecondsSinceEpoch(epochsemester) : getClosestMondayTo(DateTime(now.year - (now.millisecondsSinceEpoch > DateTime(now.year, 9, 1).millisecondsSinceEpoch ? 0 : 1), 9, 1));
    final yearlessNow = DateTime(1, now.month, now.day);
    final sepOne = DateTime(yearlessNow.year - 1, determiner.month, determiner.day); // first week

    final timepassSinceSepOne = Duration(milliseconds: (yearlessNow.millisecondsSinceEpoch - sepOne.millisecondsSinceEpoch));
    final weeksPassed = timepassSinceSepOne.inDays / 7;

    return ((weeksPassed.floor() % 52));
  }

  @override
  void dispose() {
    if (_instance == this) {
      _instance = null;
    }
    _connectivitySubscription?.cancel();
    _calendarTimer?.cancel();
    super.dispose();
    calendarEntries.clear();
    mondayCalendar.clear();
    tuesdayCalendar.clear();
    wednessdayCalendar.clear();
    thursdayCalendar.clear();
    fridayCalendar.clear();
    saturdayCalendar.clear();
    sundayCalendar.clear();
    markbookEntries.clear();
    markbookList.clear();
    calendarTabController.dispose();
    paymentsEntries.clear();
    paymentsList.clear();
    periodList.clear();
    periodEntries.clear();
    mailList.clear();
    mailEntries.clear();
    currentMailPageController.dispose();
    blurController.dispose();
  }

  static Container getSeparatorLine(BuildContext context){
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 1,
      color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
    );
  }

  void switchView(int to){
    if(currentView == to){
      return;
    }
    setState(() {
      currentView = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getTheme().rootBackground,
      drawer: AppDrawer(
          loggedInUsername: storage.DataCache.getUsername() ?? '',
          loggedInURL: (storage.DataCache.getInstituteUrl() ?? '').replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Visibility(
                visible: currentView == 0,
                maintainState: true,
                child: CalendarPageWidget(homePage: this, greetText: calendarGreetText, calendarTabs: calendarTabs, calendarTabViews: calendarTabViews)
            ),
            Visibility(
                visible: currentView == 1,
                maintainState: true,
                child: MarkbookPageWidget(homePage: this, totalCredits: totalCredits, totalAvg: totalAvg, totalAvg30: totalAvg30,)
            ),
            Visibility(
                visible: currentView == 2,
                maintainState: true,
                child: PaymentsPageWidget(homePage: this, totalMoney: totalMoney)
            ),
            Visibility(
              visible: currentView == 3,
              maintainState: true,
              child: PeriodsPageWidget(homePage: this, currentSemester: currentSemester),
            ),
            Visibility(
              visible: currentView == 4,
              maintainState: true,
              child: MailsPageWidget(homePage: this),
            ),
            Visibility(
              visible: _showBlur,
              child: AnimatedBuilder(
                animation: blurController,
                builder: (context, widget) {
                  return Positioned.fill(
                    child: BackdropFilter(
                       filter: ImageFilter.blur(sigmaX: blurAnimation.value * 15, sigmaY: blurAnimation.value * 15),
                       child: Container(
                         color: Colors.black.withValues(alpha: blurAnimation.value * 0.4),
                       ),
                     ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomnav.BottomNavigatorWidget(homePage: this),
    );
  }
}

class CalendarPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final String greetText;
  final List<Widget> calendarTabs;
  final List<Widget> calendarTabViews;
  const CalendarPageWidget({super.key, required this.homePage, required this.greetText, required this.calendarTabs, required this.calendarTabViews});

  @override
  Widget build(BuildContext context){
    final dayIndex = homePage.calendarTabController.index;
    final dayText = api.Generic.dayToText(dayIndex + 1);
    final calendarHintText = '$dayText • ${homePage.weeksSinceStart}. hét';

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        topnav.TopNavigatorWidget(
          homePage: homePage,
          displayString: AppStrings.getLanguagePack().view_header_Calendar,
          smallHintText: calendarHintText,
          loggedInUsername: storage.DataCache.getUsername() ?? '',
          loggedInURL: (storage.DataCache.getInstituteUrl() ?? '').replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", ''),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                color: homePage.canDoCalendarPaging ? AppColors.getTheme().textColor : AppColors.getTheme().textColor.withValues(alpha: 0.25),
                onPressed: homePage.canDoCalendarPaging ? homePage.stepCalendarBack : null,
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
              ),
              Expanded(
                child: TabBar(
                  tabs: calendarTabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  dividerColor: Colors.transparent,
                  controller: homePage.calendarTabController,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(
                      width: 2.5,
                      color: AppColors.getTheme().onPrimaryContainer,
                    ),
                    insets: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AppColors.getTheme().onPrimaryContainer,
                  unselectedLabelColor: AppColors.getTheme().textColor.withValues(alpha: 0.5),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                color: homePage.canDoCalendarPaging ? AppColors.getTheme().textColor : AppColors.getTheme().textColor.withValues(alpha: 0.25),
                onPressed: homePage.canDoCalendarPaging ? homePage.stepCalendarForward : null,
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: homePage.calendarTabController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: calendarTabViews,
          ),
        ),
      ],
    );
  }
}

class MarkbookPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int totalCredits;
  final double totalAvg;
  final double totalAvg30;
  const MarkbookPageWidget({super.key, required this.homePage, required this.totalCredits, required this.totalAvg, required this.totalAvg30});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage._confettiRefreshRetrigger = true;
    homePage.onMarkbookRefresh();
  }

  List<Widget> _getConfetti(BuildContext context){
    if(homePage._confettiList.isNotEmpty){
      return homePage._confettiList;
    }
    final confettiAmount = 55 + Random().nextInt(234243) % 30;
    for(int i = 0; i < confettiAmount; i++){
      final randomRed = 0xCC000000 + Random().nextInt(0x33000000);
      final randomGreen = 0x00CC0000 + Random().nextInt(0x0033000);
      final randomBlue = 0x0000CC00 + Random().nextInt(0x00003300);
      final alpha = 0x000000FF;
      final added = randomRed + randomBlue + randomGreen + alpha;
      final confetti = ConfettiHelper(
        confettiColor: Color(added),
        startOffset: Offset(lerpDouble(0, MediaQuery.of(context).size.width, Random().nextDouble() % 0.9999)!, lerpDouble(-MediaQuery.of(context).size.height, -50, Random().nextDouble() % 0.9999)!),
        startRotation: Random().nextDouble() % 360.0,
        rotationMultiplier: -60 + Random().nextInt(60*2),
        startSize: Size((8 + Random().nextInt(12)).toDouble(), (8 + Random().nextInt(12)).toDouble()),
        offsetMultiplier: -200 + Random().nextInt(200*2),
        startRadius: BorderRadius.only(topLeft: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), topRight: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), bottomRight: Radius.circular(4 + 12 * Random().nextDouble() % 0.999), bottomLeft: Radius.circular(4 + 12 * Random().nextDouble() % 0.999))
      );
      homePage._confettiHelperList.add(confetti);
      homePage._confettiList.add(
        IgnorePointer(
          child: AnimatedBuilder(
            animation: homePage._confettiController,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(
                    confetti.startOffset.dx + confetti.offsetMultiplier * homePage._confettiAnimation.value,
                    lerpDouble(confetti.startOffset.dy, confetti.startOffset.dy + MediaQuery.of(context).size.height * 2 + (confetti.offsetMultiplier < 0 ? -confetti.offsetMultiplier : confetti.offsetMultiplier) * 6 * homePage._confettiAnimation.value, homePage._confettiAnimation.value)!
                ),
                child: Transform.rotate(
                  angle: confetti.startRotation + confetti.rotationMultiplier * homePage._confettiAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: confetti.confettiColor,
                      borderRadius: confetti.startRadius
                    ),
                    width: confetti.startSize.width,
                    height: confetti.startSize.height,
                  ),
                ),
              );
            }
          ),
        )
      );
    }
    return homePage._confettiList;
  }

  @override
  Widget build(BuildContext context){
    if(homePage._confettiCanBePlayed && homePage._confettiCanGetFreshAnim && homePage._confettiRefreshRetrigger){
      homePage._confettiCanGetFreshAnim = false;
      homePage._confettiRefreshRetrigger = false;
      homePage._confettiController.forward().whenComplete((){
        homePage._confettiCanGetFreshAnim = true;
        homePage._confettiList.clear();
        homePage._confettiHelperList.clear();
        homePage._confettiController.reset();
      });
    }
    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Subjects, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_subjects_CreditsInSemester, [totalCredits]), loggedInUsername: storage.DataCache.getUsername() ?? '', loggedInURL: (storage.DataCache.getInstituteUrl() ?? '').replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
            HomePageState.getSeparatorLine(context),
            Expanded(
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      scrollDirection: Axis.vertical,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Visibility(
                            visible: homePage.markbookList.isNotEmpty,
                            child: Builder(
                              builder: (context) {
                                final theme = AppColors.getTheme();
                                final isDark = theme.isDark;
                                return Container(
                                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  width: MediaQuery.of(context).size.width,
                                  decoration: BoxDecoration(
                                    color: isDark ? theme.secondary.withValues(alpha: 0.35) : theme.secondary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(16.0),
                                    border: Border.all(
                                      color: theme.textColor.withValues(alpha: isDark ? 0.08 : 0.06),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  totalAvg.isNaN || totalAvg <= 0 ? '-' : totalAvg.toStringAsFixed(2),
                                                  style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    color: theme.textColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  api.Generic.reactionForAvg(totalAvg),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontFamily: 'Noto Color Emoji',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'SÚLYOZOTT ÁTLAG',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: theme.textColor.withValues(alpha: 0.55),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 36,
                                        color: theme.textColor.withValues(alpha: 0.08),
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  totalAvg30.isNaN || totalAvg30 <= 0 ? '-' : totalAvg30.toStringAsFixed(2),
                                                  style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    color: theme.textColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  api.Generic.reactionForAvg(totalAvg30),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontFamily: 'Noto Color Emoji',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'ÖSZTÖNDÍJINDEX',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: theme.textColor.withValues(alpha: 0.55),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 36,
                                        color: theme.textColor.withValues(alpha: 0.08),
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: theme.roomHighlightColor.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '$totalCredits',
                                                style: TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: theme.roomHighlightColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'KREDIT',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: theme.textColor.withValues(alpha: 0.55),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: homePage.markbookList.isNotEmpty ? homePage.markbookList : <Widget>[
                                Center(
                                  child: SizedBox(
                                    height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                    width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                    child: CircularProgressIndicator(
                                    color: AppColors.getTheme().textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                      fontWeight: FontWeight.w300,
                                      fontSize: 10
                                  ),
                                )
                              ]
                            ),
                          ),
                        ],
                      ),
                  )
                )
            ),
          ],
        ),
        Stack(
          children: _getConfetti(context),
        )
      ],
    );
  }
}

class ConfettiHelper{
  final Color confettiColor;
  final Offset startOffset;
  final double startRotation;
  final int rotationMultiplier;
  final Size startSize;
  final int offsetMultiplier;
  final BorderRadius startRadius;

  const ConfettiHelper({required this.startRadius, required this.confettiColor, required this.startOffset, required this.startRotation, required this.rotationMultiplier, required this.startSize, required this.offsetMultiplier});
}

class PaymentsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int totalMoney;
  const PaymentsPageWidget({super.key, required this.homePage, required this.totalMoney});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onPaymentsRefresh();
  }

  @override
  Widget build(BuildContext context){
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Payments, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_payments_TotalMoneySpent, [totalMoney]), loggedInUsername: storage.DataCache.getUsername() ?? '', loggedInURL: (storage.DataCache.getInstituteUrl() ?? '').replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
        HomePageState.getSeparatorLine(context),
        Expanded(
            child: RefreshIndicator(
                onRefresh: onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: homePage.paymentsList.isNotEmpty ? homePage.paymentsList : <Widget>[
                          Center(
                            child: SizedBox(
                              height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                              width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                              child: CircularProgressIndicator(
                                color: AppColors.getTheme().textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                fontWeight: FontWeight.w300,
                                fontSize: 10
                            ),
                          )
                        ]
                    ),
                  ),
                )
            )
        ),
      ],
    );
  }
}

class PeriodsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  final int currentSemester;
  const PeriodsPageWidget({super.key, required this.homePage, required this.currentSemester});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onPeriodsRefresh();
  }

  @override
  Widget build(BuildContext context){
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Periods, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_periods_MainHeader, [homePage.countActivePeriods, AppStrings.getLanguagePack().topheader_periods_ActiveText, homePage.countFuturePeriods, AppStrings.getLanguagePack().topheader_periods_FutureText, homePage.countExpiredPeriods, AppStrings.getLanguagePack().topheader_periods_ExpiredText]), loggedInUsername: storage.DataCache.getUsername() ?? '', loggedInURL: (storage.DataCache.getInstituteUrl() ?? '').replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
        HomePageState.getSeparatorLine(context),
        Expanded(
            child: RefreshIndicator(
                onRefresh: onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: homePage.periodList.isNotEmpty ? homePage.periodList : <Widget>[
                          Center(
                            child: SizedBox(
                              height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                              width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                              child: CircularProgressIndicator(
                                color: AppColors.getTheme().textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                fontWeight: FontWeight.w300,
                                fontSize: 10
                            ),
                          )
                        ]
                    ),
                  ),
                )
            )
        ),
      ],
    );
  }
}

class MailsPageWidget extends StatelessWidget{
  final HomePageState homePage;
  const MailsPageWidget({super.key, required this.homePage});

  Future<void> onRefresh() async{
    AppHaptics.lightImpact();
    homePage.onMailRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        topnav.TopNavigatorWidget(homePage: homePage, displayString: AppStrings.getLanguagePack().view_header_Messages, smallHintText: AppStrings.getStringWithParams(AppStrings.getLanguagePack().topheader_messages_UnreadMessages, [homePage.unreadMailCount]), loggedInUsername: storage.DataCache.getUsername() ?? '', loggedInURL: (storage.DataCache.getInstituteUrl() ?? '').replaceAll(RegExp(r'/hallgato/MobileService\.svc'), '').replaceAll("https://", '')),
                HomePageState.getSeparatorLine(context),
                if (homePage.mailEntries.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              homePage.unreadMailCount > 0 ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded,
                              size: 18,
                              color: homePage.unreadMailCount > 0 ? AppColors.getTheme().primary : AppColors.getTheme().currentClassGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              homePage.unreadMailCount > 0
                                  ? AppStrings.getStringWithParams(AppStrings.getLanguagePack().topmenu_UnreadMessagesBadge, [homePage.unreadMailCount])
                                  : AppStrings.getLanguagePack().topmenu_NoUnreadMessages,
                              style: TextStyle(
                                color: AppColors.getTheme().textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (homePage.unreadMailCount > 0)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              AppHaptics.lightImpact();
                              await homePage.markAllMailsAsRead();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.getTheme().primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.getTheme().primary,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.done_all_rounded,
                                    size: 16,
                                    color: AppColors.getTheme().primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    AppStrings.getLanguagePack().messagePage_MarkAllAsRead,
                                    style: TextStyle(
                                      color: AppColors.getTheme().primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: onRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          controller: homePage.currentMailPageController,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.max,
                                children: homePage.mailList.isNotEmpty ? homePage.mailList : <Widget>[
                                  Center(
                                    child: SizedBox(
                                      height: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      width: MediaQuery.of(context).size.width < MediaQuery.of(context).size.height ? MediaQuery.of(context).size.width * 0.10 : MediaQuery.of(context).size.height * 0.10,
                                      child: CircularProgressIndicator(
                                        color: AppColors.getTheme().textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    api.Generic.randomLoadingComment(storage.DataCache.getNeedFamilyFriendlyComments()!),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.getTheme().textColor.withValues(alpha: .2),
                                        fontWeight: FontWeight.w300,
                                        fontSize: 10
                                    ),
                                  )
                                ]
                            ),
                          ),
                        )
                    )
                ),
              ],
            );
  }
}