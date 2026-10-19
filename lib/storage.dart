import 'dart:convert' as conv;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> saveString(String key, String value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> saveInt(String key, int value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt(key, value);
}

Future<void> saveFloat(String key, double value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(key, value);
}

Future<void> saveStringList(String key, List<String> value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(key, value);
}

Future<String?> getString(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<int?> getInt(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getInt(key);
}

Future<void> saveDouble(String key, double value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(key, value);
}

Future<double?> getDouble(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getDouble(key);
}

Future<List<String>?> getStringList(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(key);
}

class DataCache{
  static Future<void> dataWipe() async{
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.reload();
    await clearSecureData();
    _instance._localWipe();
  }

  static Future<void> dataWipeNoKeep()async{
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.reload();
    await clearSecureData();
  }

  void _localWipe(){
    _username = '';
    _password = '';
    _instituteUrl = '';
    _accessToken = '';
    _refreshToken = '';
    _sessionCookieName = '';
    _hasLogin = false;
    _hasCachedCalendar = false;
    _hasCachedMarkbook = false;
    _hasCachedPayments = false;
    _hasCachedFirstWeekEpoch = false;
    _hasCachedPeriods = false;
    _firstweekOfSemesterEpoch = 0;
    _isDemoAccount = false;
    _icsLocationPath = '';
    _icsIsUploaded = false;
    _selectedTermId = null;
    _selectedTermName = null;
    _cachedTermsList = [];
    _cachedPetitionTemplatesRaw = [];
    _cachedSubmittedPetitionsRaw = [];
    _cachedStartedPetitionsRaw = [];
    _cachedUserAvatarBase64 = null;
    _cachedAvatarBytes = null;
    _cachedFallbackColor = null;
    _cachedPersonalDataRaw = null;
    _cachedPersonalContactsRaw = null;
    _cachedPersonalDocumentsRaw = null;
    _cachedStudentCardRaw = null;
    _cachedBankAccountRaw = null;
    _cachedProfileSettingsRaw = null;
    _cachedStorageDashboardRaw = null;
    _cachedStorageForStudentDocsRaw = [];
    _cachedStorageByStudentDocsRaw = [];
    _cachedStorageTrDocsRaw = [];
    _studentTrainingId = null;
    setNeedFamilyFriendlyComments(_persistentSetting_familyFriendlyLoadingComments! ? 1 : 0);
    setNeedExamNotifications(_persistentSetting_showExamNotifications! ? 1 : 0);
    setNeedClassNotifications(_persistentSetting_showClassNotifications! ? 1 : 0);
    setNeedClassNotifications(_persistentSetting_showPaymentsNotifications! ? 1 : 0);
    setNeedClassNotifications(_persistentSetting_showPeriodsNotifications! ? 1 : 0);
    setUserWeekOffset(_persistentSetting_weekOffset!);
    setUserSelectedLanguage(_persistentSetting_userSelectedLanguage!);
    setUserSelectedLanguageCode(_persistentSetting_userSelectedLanguageCode);
    setNeedsHaptics(_persistentSetting_needBetterHaptics! ? 1 : 0);
    setIsInstalledFromGPlay(_permanentConfiguration_isInstalledFromGooglePlay!);
    setDownloadedSupportedLanguages(_languageJsonSupportedLangs);
    setDownloadedSupportedLanguagesData(_languageJsonBatch);
    setPreferredAppTheme(_themePreference!);
    setAllDownloadedAppThemes(_themesJsonBatch);
  }

  static final DataCache _instance = DataCache();

  late String? _username = '';
  late String? _password = '';
  late String? _instituteUrl = '';
  late String? _accessToken = ''; //new systems token query
  late String? _refreshToken = '';
  late String? _sessionCookieName = '';
  String? _selectedTermId;
  String? _selectedTermName;
  List<String> _cachedTermsList = [];
  String? _studentTrainingId;
  late bool _hasNetwork = false;
  late bool? _hasLogin = false;
  late bool? _hasCachedCalendar = false;
  late bool? _hasCachedMarkbook = false;
  late bool? _hasCachedPayments = false;
  late bool? _hasCachedPeriods = false;
  late bool? _hasCachedMail = false;
  late bool? _hasCachedFirstWeekEpoch = false;
  late int? _firstweekOfSemesterEpoch = 0;
  late bool? _isDemoAccount = false;

  bool _isModernApi = false;

  static bool getIsModernApi() {
    return _instance._isModernApi;
  }

  static Future<void> setIsModernApi(bool value) async {
    _instance._isModernApi = value;
    await saveInt('IsModernApi', value ? 1 : 0);
  }

  Future<void> saveBool(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }
  double _fontScale = 1.0;
  static double getFontScale() {
    return _instance._fontScale;
  }

  static Future<void> setFontScale(double scale) async {
    _instance._fontScale = scale;
    await saveDouble('FontScale', scale);
  }

  double? _accountBalance;
  String? _accountBalanceCurrency = 'HUF';
  int _unreadMailCount = 0;

  late bool? _persistentSetting_familyFriendlyLoadingComments = false;
  late bool? _persistentSetting_showExamNotifications = true;
  late bool? _persistentSetting_showClassNotifications = true;
  late bool? _persistentSetting_showPaymentsNotifications = true;
  late bool? _persistentSetting_showPeriodsNotifications = true;
  late bool? _persistentSetting_showMessageNotifications = true;
  late bool? _persistentSetting_enableToOfficeToggler = true;
  late bool? _persistentSetting_showToOfficeSchedule = true;
  late bool? _persistentSetting_showPeriodsInCalendar = true;
  int _backgroundSyncIntervalMinutes = 15;
  bool _backgroundSyncWifiOnly = false;
  bool _backgroundSyncEnabled = true;
  late int? _persistentSetting_weekOffset = 0;
  late bool? _persistentSetting_needBetterHaptics = true;
  late int? _persistentSetting_userSelectedLanguage = -1;
  String? _persistentSetting_userSelectedLanguageCode;

  late int? _permanentConfiguration_isInstalledFromGooglePlay = 0;



  late List<String> _languageJsonSupportedLangs = [];
  late List<String> _languageJsonBatch = [];

  late String? _themePreference = '';
  late List<String> _themesJsonBatch = [];
  List<String> _cachedPetitionTemplatesRaw = [];
  List<String> _cachedSubmittedPetitionsRaw = [];
  List<String> _cachedStartedPetitionsRaw = [];
  String? _cachedUserAvatarBase64;
  Uint8List? _cachedAvatarBytes;
  String? _cachedFallbackColor;
  String? _cachedPersonalDataRaw;
  String? _cachedPersonalContactsRaw;
  String? _cachedPersonalDocumentsRaw;
  String? _cachedStudentCardRaw;
  String? _cachedBankAccountRaw;
  String? _cachedProfileSettingsRaw;
  String? _cachedStorageDashboardRaw;
  List<String> _cachedStorageForStudentDocsRaw = [];
  List<String> _cachedStorageByStudentDocsRaw = [];
  List<String> _cachedStorageTrDocsRaw = [];
  String? _userNickname;
  bool _isNicknameVisible = false;
  bool _isLoginNameVisible = true;

  String? _stickyServerId;
  String? _cachedDeviceCookie;

  late String? _icsLocationPath = '';
  late bool? _icsIsUploaded = false;

  static Future<void> loadData() async{return _instance._loadData();}

  Future<void> _loadData() async{
    int? tmp;

    _username = await getString('Username');
    _instituteUrl = await getString('URL');

    _password = await _secureStorage.read(key: 'neptun_password');


    if (_password == null) {
      String? oldPassword = await getString('Password');
      if (oldPassword != null && oldPassword.isNotEmpty) {
        _password = oldPassword;
        await _secureStorage.write(key: 'neptun_password', value: oldPassword);

      }
    }

    _accessToken = await _secureStorage.read(key: 'neptun_jwt_token');

    if (_accessToken == null) {
      String? oldToken = await getString('AccessToken');
      if (oldToken != null && oldToken.isNotEmpty) {
        _accessToken = oldToken;
        await _secureStorage.write(key: 'neptun_jwt_token', value: oldToken);
      }
    }

    _refreshToken = await _secureStorage.read(key: 'neptun_refresh_token');
    _sessionCookieName = await _secureStorage.read(key: 'neptun_session_cookie_name');
    _stickyServerId = await getString('StickyServerId');
    if (_username != null && _username!.isNotEmpty) {
      _cachedDeviceCookie = await _secureStorage.read(key: 'devicecookie_${_username!.toUpperCase()}');
    }

    tmp = await getInt('IsModernApi');
    _isModernApi = tmp != null && tmp != 0;

    tmp = await getInt('HasLogin');
    _hasLogin = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedCalendar');
    _hasCachedCalendar = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedMarkbook');
    _hasCachedMarkbook = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedPayments');
    _hasCachedPayments = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedPeriods');
    _hasCachedPeriods = tmp != null && tmp != 0;

    tmp = await getInt('HasCachedMail');
    _hasCachedMail = tmp != null && tmp != 0;

    final connResults = await Connectivity().checkConnectivity();
    _hasNetwork = connResults.any((r) => r != ConnectivityResult.none);
    Connectivity().onConnectivityChanged.listen((event) {
      _hasNetwork = event.any((r) => r != ConnectivityResult.none);
    });

    tmp = await getInt('HasCachedFirstWeekEpoch');
    _hasCachedFirstWeekEpoch = tmp != null && tmp != 0;

    tmp = await getInt('FirstWeekOfSemesterEpoch');
    _firstweekOfSemesterEpoch = tmp ?? 0;

    tmp = await getInt('IsDemoAccount');
    _isDemoAccount = tmp != null && tmp != 0;

    final prefs = await SharedPreferences.getInstance();
    _displayClasses = prefs.getBool('CALENDAR_DisplayClasses') ?? true;
    _displayExams = prefs.getBool('CALENDAR_DisplayExams') ?? true;
    _displayPeriods = prefs.getBool('CALENDAR_DisplayPeriods') ?? true;

    tmp = await getInt('SETTING_IsFamilyFriendlyLoading');
    _persistentSetting_familyFriendlyLoadingComments = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_familyFriendlyLoadingComments = false;  // this is the default value
    }

    tmp = await getInt('SETTING_IsNeedExamNotifications');
    _persistentSetting_showExamNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showExamNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedClassNotifications');
    _persistentSetting_showClassNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showClassNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedPaymentsNotifications');
    _persistentSetting_showPaymentsNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showPaymentsNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedPeriodsNotifications');
    _persistentSetting_showPeriodsNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showPeriodsNotifications = true;  // this is the default value, not false
    }

    tmp = await getInt('SETTING_IsNeedMessageNotifications');
    _persistentSetting_showMessageNotifications = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_showMessageNotifications = true;
    }

    tmp = await getInt('SETTING_EnableToOfficeToggler');
    _persistentSetting_enableToOfficeToggler = tmp != null ? tmp != 0 : true;

    tmp = await getInt('SETTING_ShowToOfficeSchedule');
    _persistentSetting_showToOfficeSchedule = tmp != null ? tmp != 0 : true;

    tmp = await getInt('SETTING_ShowPeriodsInCalendar');
    _persistentSetting_showPeriodsInCalendar = tmp != null ? tmp != 0 : true;

    tmp = await getInt('SETTING_NeedHaptics');
    _persistentSetting_needBetterHaptics = tmp != null && tmp != 0;
    if(tmp == null){
      _persistentSetting_needBetterHaptics = true;
    }

    tmp = await getInt('SETTING_UserWeekOffset');
    _persistentSetting_weekOffset = tmp ?? 0;

    tmp = await getInt('SETTING_UserSelectedLanguage');
    _persistentSetting_userSelectedLanguage = tmp ?? -1;

    _persistentSetting_userSelectedLanguageCode = await getString('SETTING_UserSelectedLanguageCode');

    _selectedTermId = await getString('SELECTED_TermId');
    _selectedTermName = await getString('SELECTED_TermName');
    _cachedTermsList = await getStringList('CACHED_TermsList') ?? [];
    _cachedPetitionTemplatesRaw = await getStringList('CACHED_PetitionTemplates') ?? [];
    _cachedSubmittedPetitionsRaw = await getStringList('CACHED_SubmittedPetitions') ?? [];
    _cachedStartedPetitionsRaw = await getStringList('CACHED_StartedPetitions') ?? [];
    _cachedUserAvatarBase64 = await getString('USER_CachedAvatarBase64');
    if (_cachedUserAvatarBase64 != null && _cachedUserAvatarBase64!.isNotEmpty) {
      try {
        _cachedAvatarBytes = conv.base64Decode(_cachedUserAvatarBase64!);
      } catch (_) {
        _cachedAvatarBytes = null;
      }
    } else {
      _cachedAvatarBytes = null;
    }
    _cachedFallbackColor = await getString('USER_FallbackAvatarColor');
    // SEC-03: Érzékeny személyes és banki adatok titkosított betöltése Keystore-ból
    _cachedPersonalDataRaw = await _secureStorage.read(key: 'sec_USER_PersonalDataRaw') ?? await getString('USER_PersonalDataRaw');
    _cachedPersonalContactsRaw = await _secureStorage.read(key: 'sec_USER_PersonalContactsRaw') ?? await getString('USER_PersonalContactsRaw');
    _cachedPersonalDocumentsRaw = await _secureStorage.read(key: 'sec_USER_PersonalDocumentsRaw') ?? await getString('USER_PersonalDocumentsRaw');
    _cachedStudentCardRaw = await _secureStorage.read(key: 'sec_USER_StudentCardRaw') ?? await getString('USER_StudentCardRaw');
    _cachedBankAccountRaw = await _secureStorage.read(key: 'sec_USER_BankAccountRaw') ?? await getString('USER_BankAccountRaw');
    _cachedProfileSettingsRaw = await getString('USER_ProfileSettingsRaw');
    _cachedStorageDashboardRaw = await getString('STORAGE_DashboardRaw');
    _cachedStorageForStudentDocsRaw = await getStringList('STORAGE_ForStudentDocs') ?? [];
    _cachedStorageByStudentDocsRaw = await getStringList('STORAGE_ByStudentDocs') ?? [];
    _cachedStorageTrDocsRaw = await getStringList('STORAGE_TrDocs') ?? [];
    _studentTrainingId = await getString('STUDENT_TrainingId');
    _userNickname = await getString('USER_Nickname');
    final nickVis = await getInt('USER_IsNicknameVisible');
    _isNicknameVisible = nickVis != null ? nickVis != 0 : false;
    final loginVis = await getInt('USER_IsLoginNameVisible');
    _isLoginNameVisible = loginVis != null ? loginVis != 0 : true;

    tmp = await getInt('CONFIG_IsInstalledFromGPlay');
    _permanentConfiguration_isInstalledFromGooglePlay = tmp ?? 0;


    _languageJsonSupportedLangs = await getStringList('LANGUAGE_DownloadedSupportedLangs') ?? [];
    _languageJsonBatch = await getStringList('LANGUAGE_DownloadedLanguagesJsonBatch') ?? [];

    _icsLocationPath = await getString('ICS_FileLocation') ?? '';

    tmp = await getInt('ICS_HasIcsUpload');
    _icsIsUploaded = tmp != null && tmp != 0;

    final fs = await getDouble('FontScale');
    _fontScale = fs ?? 1.0;

    _accountBalance = await getDouble('ACCOUNT_Balance');
    _accountBalanceCurrency = await getString('ACCOUNT_BalanceCurrency') ?? 'HUF';
    final unread = await getInt('CachedMailsUnread');
    _unreadMailCount = unread ?? 0;

    final syncInt = await getInt('SETTING_BackgroundSyncInterval');
    _backgroundSyncIntervalMinutes = syncInt ?? 15;
    final syncWifi = await getInt('SETTING_BackgroundSyncWifiOnly');
    _backgroundSyncWifiOnly = syncWifi == 1;
    final syncEn = await getInt('SETTING_BackgroundSyncEnabled');
    _backgroundSyncEnabled = syncEn != 0;
  }

  static Future<void> loadThemeOnly()async{
    _instance._themePreference = await getString('THEME_AppTheme') ?? 'Dark';
    _instance._themesJsonBatch = await getStringList('THEME_ThemesJsonBatch') ?? [];
  }

  static String? getUsername(){return _instance._username;}
  static Future<void> setUsername(String? value) async{
    _instance._username = value;
    await saveString('Username', value.toString());
  }

  // A kritikus dolgoknak (jelszó, token) létrehozzuk a Secure Storage-ot
  static const _secureStorage = FlutterSecureStorage();
  // PASSWORD HANDLING:



// SZINKRON GETTER! Így a többi fájl nem fog pirosodni,
  // mert azonnal a memóriából kapják meg az adatot.
  static String? getPassword() {
    return _instance._password;
  }

  // ASZINKRON SETTER (Ide mentjük el biztonságosan)
  static Future<void> setPassword(String? password) async {
    _instance._password = password; // Frissítjük a memóriában is

    if (password == null) {
      await _secureStorage.delete(key: 'neptun_password');
    } else {
      await _secureStorage.write(key: 'neptun_password', value: password);
    }
  }

  static String? getInstituteUrl(){return _instance._instituteUrl;}

  static Future<void> setInstituteUrl(String? value) async{
    if (value != null && value.isNotEmpty && !value.endsWith('MobileService.svc')) {
      value = value.replaceAll(RegExp(r'/login(\.aspx)?$', caseSensitive: false), '');
    }
    _instance._instituteUrl = value;
    await saveString('URL', value.toString());
  }


// ASZINKRON SETTER
  static Future<void> setAccessToken(String? token) async {
    _instance._accessToken = token; // Frissítjük a memóriában

    if (token == null) {
      await _secureStorage.delete(key: 'neptun_jwt_token');
    } else {
      await _secureStorage.write(key: 'neptun_jwt_token', value: token);
    }
  }

  static String? getAccessToken() {
    return _instance._accessToken;
  }

  static String? getRefreshToken() {
    return _instance._refreshToken;
  }

  static Future<void> setRefreshToken(String? token) async {
    _instance._refreshToken = token;
    if (token == null) {
      await _secureStorage.delete(key: 'neptun_refresh_token');
    } else {
      await _secureStorage.write(key: 'neptun_refresh_token', value: token);
    }
  }

  static Future<String?> getDeviceCookie(String username) async {
    return await _secureStorage.read(key: 'devicecookie_${username.toUpperCase()}');
  }

  static String? getDeviceCookieSync() => _instance._cachedDeviceCookie;

  static String? getStickyServerId() => _instance._stickyServerId;
  static Future<void> setStickyServerId(String? id) async {
    _instance._stickyServerId = id;
    if (id == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('StickyServerId');
    } else {
      await saveString('StickyServerId', id);
    }
  }

  static Future<void> setDeviceCookie(String username, String? cookieValue) async {
    _instance._cachedDeviceCookie = cookieValue;
    if (cookieValue == null) {
      await _secureStorage.delete(key: 'devicecookie_${username.toUpperCase()}');
    } else {
      await _secureStorage.write(key: 'devicecookie_${username.toUpperCase()}', value: cookieValue);
    }
  }

// --- SECURE DATA clear ---
  static Future<void> clearSecureData() async {
    _instance._password = null;
    _instance._accessToken = null;
    _instance._refreshToken = null;
    _instance._sessionCookieName = null;
    _instance._cachedPersonalDataRaw = null;
    _instance._cachedPersonalContactsRaw = null;
    _instance._cachedPersonalDocumentsRaw = null;
    _instance._cachedStudentCardRaw = null;
    _instance._cachedBankAccountRaw = null;
    await _secureStorage.deleteAll();
  }

  static String? getSessionCookieName() {
    return _instance._sessionCookieName;
  }

  static Future<void> setSessionCookieName(String? name) async {
    _instance._sessionCookieName = name;
    if (name == null) {
      await _secureStorage.delete(key: 'neptun_session_cookie_name');
    } else {
      await _secureStorage.write(key: 'neptun_session_cookie_name', value: name);
    }
  }

  static bool getHasNetwork(){return _instance._hasNetwork;}

  static Future<bool> checkAndRefreshNetwork() async {
    try {
      final connResults = await Connectivity().checkConnectivity();
      _instance._hasNetwork = connResults.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _instance._hasNetwork = true;
    }
    return _instance._hasNetwork;
  }

  static bool? getHasLogin(){return _instance._hasLogin;}
  static Future<void> setHasLogin(int? value) async {
    _instance._hasLogin = value != null && value != 0;
    await saveInt('HasLogin', value ?? 0);
  }

  static bool? getHasCachedCalendar(){return _instance._hasCachedCalendar;}
  static Future<void> setHasCachedCalendar(int? value) async {
    _instance._hasCachedCalendar = value != null && value != 0;
    await saveInt('HasCachedCalendar', value ?? 0);
  }

  static bool? getHasCachedMarkbook(){return _instance._hasCachedMarkbook;}
  static Future<void> setHasCachedMarkbook(int? value) async {
    _instance._hasCachedMarkbook = value != null && value != 0;
    await saveInt('HasCachedMarkbook', value ?? 0);
  }

  static bool? getHasCachedPayments(){return _instance._hasCachedPayments;}
  static Future<void> setHasCachedPayments(int? value) async{
    _instance._hasCachedPayments = value != null && value != 0;
    await saveInt('HasCachedPayments', value ?? 0);
  }

  static bool? getHasCachedPeriods(){return _instance._hasCachedPeriods;}
  static Future<void> setHasCachedPeriods(int? value) async{
    _instance._hasCachedPeriods = value != null && value != 0;
    await saveInt('HasCachedPeriods', value ?? 0);
  }

  static bool? getHasCachedMail(){return _instance._hasCachedMail;}
  static Future<void> setHasCachedMail(int? value) async{
    _instance._hasCachedMail = value != null && value != 0;
    await saveInt('HasCachedMail', value ?? 0);
  }

  static double? getAccountBalance() => _instance._accountBalance;
  static String getAccountBalanceCurrency() => _instance._accountBalanceCurrency ?? 'HUF';
  static Future<void> setAccountBalance(double? value, {String currency = 'HUF'}) async {
    _instance._accountBalance = value;
    _instance._accountBalanceCurrency = currency;
    if (value != null) {
      await saveDouble('ACCOUNT_Balance', value);
      await saveString('ACCOUNT_BalanceCurrency', currency);
    }
  }

  static int getUnreadMailCount() => _instance._unreadMailCount;
  static Future<void> setUnreadMailCount(int value) async {
    _instance._unreadMailCount = value;
    await saveInt('CachedMailsUnread', value);
  }

  static bool? getHasCachedFirstWeekEpoch(){return _instance._hasCachedFirstWeekEpoch;}
  static Future<void> setHasCachedFirstWeekEpoch(int? value) async{
    _instance._hasCachedFirstWeekEpoch = value != null && value != 0;
    await saveInt('HasCachedFirstWeekEpoch', value ?? 0);
  }

  static int? getFirstWeekEpoch(){return _instance._firstweekOfSemesterEpoch;}
  static Future<void> setFirstWeekEpoch(int? value) async{
    _instance._firstweekOfSemesterEpoch = value ?? 0;
    await saveInt('FirstWeekOfSemesterEpoch', value ?? 0);
  }

  static bool? getIsDemoAccount(){return _instance._isDemoAccount;}
  static Future<void> setIsDemoAccount(int? value) async{
    _instance._isDemoAccount = value != null && value != 0;
    await saveInt('IsDemoAccount', value ?? 0);
  }

  static bool? getNeedFamilyFriendlyComments(){return _instance._persistentSetting_familyFriendlyLoadingComments;}
  static Future<void> setNeedFamilyFriendlyComments(int? value) async{
    _instance._persistentSetting_familyFriendlyLoadingComments = value != null && value != 0;
    await saveInt('SETTING_IsFamilyFriendlyLoading', value ?? 0);
  }

  static bool? getNeedExamNotifications(){return _instance._persistentSetting_showExamNotifications;}
  static Future<void> setNeedExamNotifications(int? value) async{
    _instance._persistentSetting_showExamNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedExamNotifications', value ?? 1);
  }

  static bool? getNeedClassNotifications(){return _instance._persistentSetting_showClassNotifications;}
  static Future<void> setNeedClassNotifications(int? value) async{
    _instance._persistentSetting_showClassNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedClassNotifications', value ?? 1);
  }

  static bool? getNeedPaymentsNotifications(){return _instance._persistentSetting_showPaymentsNotifications;}
  static Future<void> setNeedPaymentsNotifications(int? value) async{
    _instance._persistentSetting_showPaymentsNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedPaymentsNotifications', value ?? 1);
  }

  static bool? getNeedPeriodsNotifications(){return _instance._persistentSetting_showPeriodsNotifications;}
  static Future<void> setNeedPeriodsNotifications(int? value) async{
    _instance._persistentSetting_showPeriodsNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedPeriodsNotifications', value ?? 1);
  }

  static bool? getNeedMessageNotifications(){return _instance._persistentSetting_showMessageNotifications;}
  static Future<void> setNeedMessageNotifications(int? value) async{
    _instance._persistentSetting_showMessageNotifications = value != null && value != 0;
    await saveInt('SETTING_IsNeedMessageNotifications', value ?? 1);
  }

  static int getBackgroundSyncInterval() => _instance._backgroundSyncIntervalMinutes;
  static Future<void> setBackgroundSyncInterval(int minutes) async {
    _instance._backgroundSyncIntervalMinutes = minutes;
    await saveInt('SETTING_BackgroundSyncInterval', minutes);
  }

  static bool getBackgroundSyncWifiOnly() => _instance._backgroundSyncWifiOnly;
  static Future<void> setBackgroundSyncWifiOnly(bool value) async {
    _instance._backgroundSyncWifiOnly = value;
    await saveInt('SETTING_BackgroundSyncWifiOnly', value ? 1 : 0);
  }

  static bool getBackgroundSyncEnabled() => _instance._backgroundSyncEnabled;
  static Future<void> setBackgroundSyncEnabled(bool value) async {
    _instance._backgroundSyncEnabled = value;
    await saveInt('SETTING_BackgroundSyncEnabled', value ? 1 : 0);
  }

  static Future<void> clearLocalCachePreservingLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final keysToClear = [
      'CachedMarkbook', 'CachedCalendar', 'CachedPayments', 'CachedPeriods', 'CachedMails',
      'HasCachedMarkbook', 'HasCachedCalendar', 'HasCachedPayments', 'HasCachedPeriods', 'HasCachedMail',
      'CachedTermsList', 'CachedMailsUnread',
    ];
    for (final k in keysToClear) {
      await prefs.remove(k);
    }
    _instance._hasCachedCalendar = false;
    _instance._hasCachedMarkbook = false;
    _instance._hasCachedPayments = false;
    _instance._hasCachedPeriods = false;
    _instance._hasCachedMail = false;
    _instance._cachedTermsList = [];
    _instance._unreadMailCount = 0;
  }

  static bool getEnableToOfficeToggler() => _instance._persistentSetting_enableToOfficeToggler ?? true;
  static Future<void> setEnableToOfficeToggler(bool value) async {
    _instance._persistentSetting_enableToOfficeToggler = value;
    await saveInt('SETTING_EnableToOfficeToggler', value ? 1 : 0);
  }

  static bool getShowToOfficeSchedule() {
    if (!getEnableToOfficeToggler()) return false;
    return _instance._persistentSetting_showToOfficeSchedule ?? true;
  }
  static Future<void> setShowToOfficeSchedule(bool value) async {
    _instance._persistentSetting_showToOfficeSchedule = value;
    await saveInt('SETTING_ShowToOfficeSchedule', value ? 1 : 0);
  }

  static bool getShowPeriodsInCalendar() => _instance._persistentSetting_showPeriodsInCalendar ?? true;
  static Future<void> setShowPeriodsInCalendar(bool value) async {
    _instance._persistentSetting_showPeriodsInCalendar = value;
    await saveInt('SETTING_ShowPeriodsInCalendar', value ? 1 : 0);
  }

  static int? getUserWeekOffset(){return _instance._persistentSetting_weekOffset;}
  static Future<void> setUserWeekOffset(int? value)async{
    _instance._persistentSetting_weekOffset = value ?? 0;
    await saveInt('SETTING_UserWeekOffset', value ?? 0);
  }

  static int? getUserSelectedLanguage(){return _instance._persistentSetting_userSelectedLanguage;}
  static Future<void> setUserSelectedLanguage(int? value)async{
    _instance._persistentSetting_userSelectedLanguage = value ?? -1;
    await saveInt('SETTING_UserSelectedLanguage', value ?? -1);
  }

  static String? getUserSelectedLanguageCode() => _instance._persistentSetting_userSelectedLanguageCode;
  static Future<void> setUserSelectedLanguageCode(String? value) async {
    _instance._persistentSetting_userSelectedLanguageCode = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('SETTING_UserSelectedLanguageCode');
    } else {
      await saveString('SETTING_UserSelectedLanguageCode', value);
    }
  }

  static String? getSelectedTermId() => _instance._selectedTermId;
  static Future<void> setSelectedTermId(String? value) async {
    _instance._selectedTermId = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('SELECTED_TermId');
    } else {
      await saveString('SELECTED_TermId', value);
    }
  }

  static String? getSelectedTermName() => _instance._selectedTermName;
  static Future<void> setSelectedTermName(String? value) async {
    _instance._selectedTermName = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('SELECTED_TermName');
    } else {
      await saveString('SELECTED_TermName', value);
    }
  }

  static List<String> getCachedTermsRaw() => _instance._cachedTermsList;
  static Future<void> setCachedTermsRaw(List<String> value) async {
    _instance._cachedTermsList = value;
    await saveStringList('CACHED_TermsList', value);
  }

  static List<String> getCachedPetitionTemplatesRaw() => _instance._cachedPetitionTemplatesRaw;
  static Future<void> setCachedPetitionTemplatesRaw(List<String> value) async {
    _instance._cachedPetitionTemplatesRaw = value;
    await saveStringList('CACHED_PetitionTemplates', value);
  }

  static List<String> getCachedSubmittedPetitionsRaw() => _instance._cachedSubmittedPetitionsRaw;
  static Future<void> setCachedSubmittedPetitionsRaw(List<String> value) async {
    _instance._cachedSubmittedPetitionsRaw = value;
    await saveStringList('CACHED_SubmittedPetitions', value);
  }

  static List<String> getCachedStartedPetitionsRaw() => _instance._cachedStartedPetitionsRaw;
  static Future<void> setCachedStartedPetitionsRaw(List<String> value) async {
    _instance._cachedStartedPetitionsRaw = value;
    await saveStringList('CACHED_StartedPetitions', value);
  }

  static String? getStudentTrainingId() => _instance._studentTrainingId;
  static Future<void> setStudentTrainingId(String? value) async {
    _instance._studentTrainingId = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('STUDENT_TrainingId');
    } else {
      await saveString('STUDENT_TrainingId', value);
    }
  }

  static bool? getNeedsHaptics(){return _instance._persistentSetting_needBetterHaptics;}
  static Future<void> setNeedsHaptics(int? value)async{
    _instance._persistentSetting_needBetterHaptics =  value != null && value != 0;
    await saveInt('SETTING_NeedHaptics', value ?? 1);
  }

  static int? getIsInstalledFromGPlay({bool excludeDefaultState = true}){return _instance._permanentConfiguration_isInstalledFromGooglePlay! - (excludeDefaultState ? 1 : 0);}
  static Future<void> setIsInstalledFromGPlay(int? value)async{
    _instance._permanentConfiguration_isInstalledFromGooglePlay = value ?? 0;
    await saveInt('CONFIG_IsInstalledFromGPlay', value ?? 0);
  }

  static List<String> getDownloadedSupportedLanguages(){return _instance._languageJsonSupportedLangs;}
  static Future<void> setDownloadedSupportedLanguages(List<String>? value)async{
    _instance._languageJsonSupportedLangs = value ?? [];
    await saveStringList('LANGUAGE_DownloadedSupportedLangs', value ?? []);
  }

  static List<String> getDownloadedSupportedLanguagesData(){return _instance._languageJsonBatch;}
  static Future<void> setDownloadedSupportedLanguagesData(List<String>? value)async{
    _instance._languageJsonBatch = value ?? [];
    await saveStringList('LANGUAGE_DownloadedLanguagesJsonBatch', value ?? []);
  }

  static String? getPreferredAppTheme(){return _instance._themePreference;}
  static Future<void> setPreferredAppTheme(String? value)async{
    _instance._themePreference = value ?? 'Dark';
    await saveString('THEME_AppTheme', value ?? 'Dark');
  }

  static List<String> getAllDownloadedAppThemes(){return _instance._themesJsonBatch;}
  static Future<void> setAllDownloadedAppThemes(List<String>? value)async{
    _instance._themesJsonBatch = value ?? [];
    await saveStringList('THEME_ThemesJsonBatch', value ?? []);
  }

  static String? getICSFileLocation(){return _instance._icsLocationPath;}
  static Future<void> setICSFileLocation(String? value)async{
    _instance._icsLocationPath = value ?? '';
    await saveString('ICS_FileLocation', value ?? '');
  }

  static bool? getHasICSFile(){return _instance._icsIsUploaded;}
  static Future<void> setHasICSFile(bool? value)async{
    _instance._icsIsUploaded = value ?? false;
    await saveInt('ICS_HasIcsUpload', value == true ? 1 : 0);
  }
  // Saját memóriaváltozók, hogy ne kelljen a _prefs-re támaszkodni
  static bool? _displayClasses = true;
  static bool? _displayExams = true;
  static bool? _displayPeriods = true;

  static bool? getDisplayClasses() => _displayClasses;
  static Future<void> setDisplayClasses(bool? value) async {
    _displayClasses = value ?? true;
    // Saját mentés közvetlenül a SharedPreferences-be (nem kell hozzá saveBool)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayClasses', _displayClasses!);
  }

  static bool? getDisplayExams() => _displayExams;
  static Future<void> setDisplayExams(bool? value) async {
    _displayExams = value ?? true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayExams', _displayExams!);
  }

  static bool? getDisplayPeriods() => _displayPeriods;
  static Future<void> setDisplayPeriods(bool? value) async {
    _displayPeriods = value ?? true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('CALENDAR_DisplayPeriods', _displayPeriods!);
  }

  // --- Profil és Avatar gyorsítótár ---
  static String? getCachedUserAvatarBase64() => _instance._cachedUserAvatarBase64;
  static Uint8List? getCachedAvatarBytes() => _instance._cachedAvatarBytes;
  static Future<void> setCachedUserAvatarBase64(String? value) async {
    _instance._cachedUserAvatarBase64 = value;
    if (value != null && value.isNotEmpty) {
      try {
        _instance._cachedAvatarBytes = conv.base64Decode(value);
      } catch (_) {
        _instance._cachedAvatarBytes = null;
      }
    } else {
      _instance._cachedAvatarBytes = null;
    }
    if (value == null || value.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('USER_CachedAvatarBase64');
    } else {
      await saveString('USER_CachedAvatarBase64', value);
    }
  }

  static String? getCachedFallbackColor() => _instance._cachedFallbackColor;
  static Future<void> setCachedFallbackColor(String? value) async {
    _instance._cachedFallbackColor = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('USER_FallbackAvatarColor');
    } else {
      await saveString('USER_FallbackAvatarColor', value);
    }
  }

  static String? getCachedPersonalDataRaw() => _instance._cachedPersonalDataRaw;
  static Future<void> setCachedPersonalDataRaw(String? value) async {
    _instance._cachedPersonalDataRaw = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('USER_PersonalDataRaw'); // SEC-03: Nem tárolunk titkosítatlan személyes adatot
    if (value == null) {
      await _secureStorage.delete(key: 'sec_USER_PersonalDataRaw');
    } else {
      await _secureStorage.write(key: 'sec_USER_PersonalDataRaw', value: value);
    }
  }

  static String? getCachedPersonalContactsRaw() => _instance._cachedPersonalContactsRaw;
  static Future<void> setCachedPersonalContactsRaw(String? value) async {
    _instance._cachedPersonalContactsRaw = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('USER_PersonalContactsRaw');
    if (value == null) {
      await _secureStorage.delete(key: 'sec_USER_PersonalContactsRaw');
    } else {
      await _secureStorage.write(key: 'sec_USER_PersonalContactsRaw', value: value);
    }
  }

  static String? getCachedPersonalDocumentsRaw() => _instance._cachedPersonalDocumentsRaw;
  static Future<void> setCachedPersonalDocumentsRaw(String? value) async {
    _instance._cachedPersonalDocumentsRaw = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('USER_PersonalDocumentsRaw');
    if (value == null) {
      await _secureStorage.delete(key: 'sec_USER_PersonalDocumentsRaw');
    } else {
      await _secureStorage.write(key: 'sec_USER_PersonalDocumentsRaw', value: value);
    }
  }

  static String? getCachedStudentCardRaw() => _instance._cachedStudentCardRaw;
  static Future<void> setCachedStudentCardRaw(String? value) async {
    _instance._cachedStudentCardRaw = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('USER_StudentCardRaw');
    if (value == null) {
      await _secureStorage.delete(key: 'sec_USER_StudentCardRaw');
    } else {
      await _secureStorage.write(key: 'sec_USER_StudentCardRaw', value: value);
    }
  }

  static String? getCachedBankAccountRaw() => _instance._cachedBankAccountRaw;
  static Future<void> setCachedBankAccountRaw(String? value) async {
    _instance._cachedBankAccountRaw = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('USER_BankAccountRaw'); // SEC-03: Bankszámlaszám azonnali törlése sima prefs-ből
    if (value == null) {
      await _secureStorage.delete(key: 'sec_USER_BankAccountRaw');
    } else {
      await _secureStorage.write(key: 'sec_USER_BankAccountRaw', value: value);
    }
  }

  static String? getCachedProfileSettingsRaw() => _instance._cachedProfileSettingsRaw;
  static Future<void> setCachedProfileSettingsRaw(String? value) async {
    _instance._cachedProfileSettingsRaw = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('USER_ProfileSettingsRaw');
    } else {
      await saveString('USER_ProfileSettingsRaw', value);
    }
  }

  static String? getCachedStorageDashboardRaw() => _instance._cachedStorageDashboardRaw;
  static Future<void> setCachedStorageDashboardRaw(String? value) async {
    _instance._cachedStorageDashboardRaw = value;
    if (value == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('STORAGE_DashboardRaw');
    } else {
      await saveString('STORAGE_DashboardRaw', value);
    }
  }

  static List<String> getCachedStorageForStudentDocsRaw() => _instance._cachedStorageForStudentDocsRaw;
  static Future<void> setCachedStorageForStudentDocsRaw(List<String> value) async {
    _instance._cachedStorageForStudentDocsRaw = value;
    await saveStringList('STORAGE_ForStudentDocs', value);
  }

  static List<String> getCachedStorageByStudentDocsRaw() => _instance._cachedStorageByStudentDocsRaw;
  static Future<void> setCachedStorageByStudentDocsRaw(List<String> value) async {
    _instance._cachedStorageByStudentDocsRaw = value;
    await saveStringList('STORAGE_ByStudentDocs', value);
  }

  static List<String> getCachedStorageTrDocsRaw() => _instance._cachedStorageTrDocsRaw;
  static Future<void> setCachedStorageTrDocsRaw(List<String> value) async {
    _instance._cachedStorageTrDocsRaw = value;
    await saveStringList('STORAGE_TrDocs', value);
  }

  static String? getUserNickname() => _instance._userNickname;
  static Future<void> setUserNickname(String? value) async {
    _instance._userNickname = value;
    if (value == null || value.trim().isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('USER_Nickname');
    } else {
      await saveString('USER_Nickname', value.trim());
    }
  }

  static bool getIsNicknameVisible() => _instance._isNicknameVisible;
  static Future<void> setIsNicknameVisible(bool value) async {
    _instance._isNicknameVisible = value;
    await saveInt('USER_IsNicknameVisible', value ? 1 : 0);
  }

  static bool getIsLoginNameVisible() => _instance._isLoginNameVisible;
  static Future<void> setIsLoginNameVisible(bool value) async {
    _instance._isLoginNameVisible = value;
    await saveInt('USER_IsLoginNameVisible', value ? 1 : 0);
  }

  static String getEffectiveDisplayName() {
    if (_instance._isNicknameVisible && _instance._userNickname != null && _instance._userNickname!.trim().isNotEmpty) {
      return _instance._userNickname!.trim();
    }
    return _instance._username ?? '';
  }

}

