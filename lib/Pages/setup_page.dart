import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:jupiter/colors.dart';
import 'package:jupiter/haptics.dart';
import 'package:jupiter/language.dart';
import '../API/api_coms.dart' as api;
import '../Misc/custom_snackbar.dart';
import '../storage.dart' as storage;
import '../storage.dart';
import 'main_page.dart' as main_page;
import 'language_select_page.dart';
import '../Misc/popup.dart';
import '../Misc/to_office_service.dart';

class UniversityLogoWidget extends StatelessWidget {
  final String name;
  final String url;
  final double size;

  const UniversityLogoWidget({
    super.key,
    required this.name,
    required this.url,
    this.size = 44,
  });

  static String getAcronym(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('műszaki és gazdaság') || lower.contains('bme')) return 'BME';
    if (lower.contains('eötvös loránd') || lower.contains('elte')) return 'ELTE';
    if (lower.contains('óbudai') || lower.contains('obuda')) return 'ÓE';
    if (lower.contains('semmelweis')) return 'SE';
    if (lower.contains('debreceni egyetem')) return 'DE';
    if (lower.contains('pécsi')) return 'PTE';
    if (lower.contains('szegedi')) return 'SZTE';
    if (lower.contains('corvinus')) return 'BCE';
    if (lower.contains('gazdasági egyetem') || lower.contains('bge')) return 'BGE';
    if (lower.contains('pázmány')) return 'PPKE';
    if (lower.contains('széchenyi istván') || lower.contains('sze')) return 'SZE';
    if (lower.contains('miskolci')) return 'ME';
    if (lower.contains('pannon')) return 'PE';
    if (lower.contains('állatorvos') || lower.contains('univet')) return 'ÁTE';
    if (lower.contains('dunaújváros') || lower.contains('duf')) return 'DUE';
    if (lower.contains('metropolitan')) return 'METU';
    if (lower.contains('edutus')) return 'EDUTUS';
    if (lower.contains('eszterházy')) return 'EKKE';
    if (lower.contains('kodolányi')) return 'KJE';
    if (lower.contains('károli')) return 'KRE';
    if (lower.contains('soproni')) return 'SOE';
    if (lower.contains('színház')) return 'SZFE';
    if (lower.contains('képzőművészeti')) return 'MKE';
    if (lower.contains('zeneművészeti') || lower.contains('liszt')) return 'LFZE';
    if (lower.contains('iparművészeti') || lower.contains('moholy')) return 'MOME';
    if (lower.contains('mate') || lower.contains('agrár- és élettudományi')) return 'MATE';
    if (lower.contains('nemzeti közszolgálati')) return 'NKE';
    if (lower.contains('testnevelési')) return 'TF';
    if (lower.contains('neumann jános')) return 'NJE';
    if (lower.contains('nyíregyházi')) return 'NYE';
    if (lower.contains('milton')) return 'MF';

    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w[0] == w[0].toUpperCase()).toList();
    if (words.length >= 2) {
      return words.take(3).map((w) => w[0]).join();
    }
    return name.substring(0, min(name.length, 3)).toUpperCase();
  }

  static String? getFaviconUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      if (uri.host.isNotEmpty) {
        return "https://www.google.com/s2/favicons?domain=${uri.host}&sz=128";
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final favicon = getFaviconUrl(url);
    final acronym = getAcronym(name);

    Widget fallbackBadge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        acronym,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.primary,
          fontSize: (size * 0.32).clamp(10.0, 16.0),
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: -0.5,
        ),
      ),
    );

    if (favicon == null) {
      return fallbackBadge;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: theme.textColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: Image.network(
            favicon,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallbackBadge,
          ),
        ),
      ),
    );
  }
}

class SetupPageInstitudeSelection extends StatefulWidget{
  final bool fetchData;
  final Function(bool)? callback;

  const SetupPageInstitudeSelection({super.key, this.fetchData = true, this.callback});

  @override
  State<StatefulWidget> createState() => _SetupPageInstitudeSelectionState();
}

class _SetupPageInstitudeSelectionState extends State<SetupPageInstitudeSelection>{
  final TextEditingController _searchController = TextEditingController();
  List<api.Institute> _allInstitutes = [];
  List<api.Institute> _filteredInstitutes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.getTheme().rootBackground,
      statusBarColor: AppColors.getTheme().rootBackground,
    ));

    _loadInstitutes();

    AppColors.subThemeChangeCallback((){
      if(mounted) setState(() {});
    });

    FlutterNativeSplash.remove();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstitutes() async {
    try {
      final rawData = await api.InstitutesRequest.fetchInstitudesJSON();
      if (rawData != null && rawData.isNotEmpty && mounted) {
        final list = api.InstitutesRequest.getDataFromInstitudesJSON(rawData);
        setState(() {
          _allInstitutes = list;
          _filteredInstitutes = list;
          _isLoading = false;
        });
        PageDTO.institutes = list;
      }
    } catch (_) {}

    if (widget.callback != null) {
      widget.callback!(false);
    }
  }

  static String _normalize(String s) {
    return s.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ő', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ű', 'u');
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      if (_searchQuery.isEmpty) {
        _filteredInstitutes = _allInstitutes;
      } else {
        final normQ = _normalize(_searchQuery);
        _filteredInstitutes = _allInstitutes.where((inst) {
          final normName = _normalize(inst.Name);
          final acronym = _normalize(UniversityLogoWidget.getAcronym(inst.Name));
          final normUrl = _normalize(inst.URL);
          return normName.contains(normQ) || acronym.contains(normQ) || normUrl.contains(normQ);
        }).toList();
      }
    });
  }

  void _onSelectInstitute(api.Institute institute) {
    AppHaptics.lightImpact();
    PageDTO.selected = institute.Name;
    PageDTO.customURL = institute.URL;
    PageDTO.validatedURL = false;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SetupPageLogin()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();

    return Scaffold(
      backgroundColor: theme.rootBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.account_balance_rounded,
                          color: theme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.getLanguagePack().instituteSelection_setupPage_SelectInstitute,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                            ),
                          ),
                          Text(
                            "Válaszd ki az egyetemed a belépéshez",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Change language / Nyelvválasztás',
                    icon: Icon(Icons.language_rounded, color: theme.primary, size: 26),
                    onPressed: () async {
                      AppHaptics.lightImpact();
                      final changed = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LanguageSelectPage(isFromSetup: true)),
                      );
                      if (changed == true && mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: "${AppStrings.getLanguagePack().instituteSelection_setupPage_Search} (pl. BME, ELTE, Óbuda...)",
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: theme.textColor.withValues(alpha: 0.45),
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: theme.primary, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: theme.textColor.withValues(alpha: 0.5)),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? theme.textColor.withValues(alpha: 0.05)
                      : theme.textColor.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.textColor.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.textColor.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // List of Universities
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: theme.primary),
                    )
                  : _filteredInstitutes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 48,
                                  color: theme.textColor.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  AppStrings.getLanguagePack().instituteSelection_setupPage_SearchNotFound,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Próbálj más névre vagy rövidítésre keresni",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.textColor.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filteredInstitutes.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final institute = _filteredInstitutes[index];
                            final host = Uri.tryParse(institute.URL)?.host ?? '';

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onSelectInstitute(institute),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? theme.secondary.withValues(alpha: 0.35)
                                        : theme.secondary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? theme.secondary.withValues(alpha: 0.55)
                                          : theme.secondary.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      UniversityLogoWidget(
                                        name: institute.Name,
                                        url: institute.URL,
                                        size: 44,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              institute.Name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: theme.textColor,
                                              ),
                                            ),
                                            if (host.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                host,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                  color: theme.textColor.withValues(alpha: 0.5),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 14,
                                        color: theme.textColor.withValues(alpha: 0.35),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class SetupPageLogin extends StatefulWidget{
  const SetupPageLogin({super.key});
  @override
  State<StatefulWidget> createState() => _SetupPageLoginState();
}
class _SetupPageLoginState extends State<SetupPageLogin>{

  String _username = '';
  String _password = '';

  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  bool _obscureText = true;
  bool _canProceed = false;

  bool _isLoading = false;

  bool _paintRed = false;

  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: AppColors.isDarktheme() ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.getTheme().rootBackground, // navigation bar color
      statusBarColor: AppColors.getTheme().rootBackground, // status bar color
    ));

    AppColors.subThemeChangeCallback((){
      if(!mounted){
        return;
      }
      setState(() {

      });
    });

    FlutterNativeSplash.remove();

    _username = "";
    _password = "";

    _usernameController = TextEditingController(text: _username);
    _passwordController = TextEditingController(text: _password);

    _canProceed = _password.isNotEmpty && _username.isNotEmpty;
  }

  bool _showNeptunServerError = false;

  void finishLogin(){
    api.Institute selected = api.Institute('ERROR', '');
    if(PageDTO.validatedURL){
      if(PageDTO.customURL != null && PageDTO.customURL!.isNotEmpty){
        RegExp regex = RegExp(r'/hallgato/login\.aspx');
        var correctedURL = PageDTO.customURL!.trim().toLowerCase();

        if(correctedURL.contains(regex)){
          correctedURL = correctedURL.replaceAll(regex, '/hallgato/MobileService.svc');
          PageDTO.customURL = correctedURL;
        }
        // ÚJ: Óbudai Egyetem linkjének megtisztítása
        else if (correctedURL.contains("uni-obuda.hu/ujhallgato")) {
          correctedURL = correctedURL.replaceAll(RegExp(r'/login/?$'), '');
          PageDTO.customURL = correctedURL;
        }

        selected = api.Institute('URL', PageDTO.customURL!);
      }
    }
    else{
      for(var item in PageDTO.institutes!){
        if(item.Name == PageDTO.selected!){
          selected = item;
          break;
        }
      }
    }

    setState(() {
      _canProceed = false;
      _isLoading = true;
      _showNeptunServerError = false;
    });

    _loadingTimer?.cancel();

    _loadingTimer = Timer(const Duration(seconds: 7), (){
      if(!_isLoading || !mounted){
        return;
      }
      setState(() {
        _showNeptunServerError = true;
      });
    });

    api.InstitutesRequest.validateLoginCredentials(selected, _username.toUpperCase(), _password).then((value)
    {
      if(value == 1){ // 1: SIKERES BELÉPÉS
        storage.DataCache.setUsername(_username.toUpperCase());
        storage.DataCache.setPassword(_password);
        storage.DataCache.setHasLogin(1);
        unawaited(ToOfficeService.checkAndResolveFacultyAsync());
        unawaited(api.MailRequest.bypassRequiredToReadMessages());
        // proceed logic - pushAndRemoveUntil prevents stack destruction and black screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const main_page.HomePage()),
          (route) => false,
        );
        return;
      }
      else if(value == 2){ // 2: 2FA SZÜKSÉGES
        setState(() {
          _isLoading = false; // Kikapcsoljuk a töltőképernyőt a 2FA-hoz!
          _canProceed = true; // Készültségben tartjuk a beküldő gombot, ha a popup eltűnne
        });
        PopupWidgetHandler(
            mode: 9,
            onCloseCallback: () {
              if (mounted) {
                setState(() {
                  _canProceed = true;
                  _isLoading = false;
                });
              }
            },
            callback: (kod) async {
              setState(() {
                _isLoading = true;
              });
              bool isOk = await api.InstitutesRequest.submitTwoFactorCode(_username.toUpperCase(), _password, kod.toString());

              if (isOk) {
                PopupWidgetHandler.closePopup(context);

                // Mivel jó a kód, elmentjük az adatokat és beléptetjük
                storage.DataCache.setUsername(_username.toUpperCase());
                storage.DataCache.setPassword(_password);
                storage.DataCache.setHasLogin(1);
                unawaited(ToOfficeService.checkAndResolveFacultyAsync());
                unawaited(api.MailRequest.bypassRequiredToReadMessages());

                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const main_page.HomePage()),
                    (route) => false,
                  );
                }
              } else {
                AppHaptics.attentionLightImpact();
                _showSnackbar("Hibás kétlépcsős azonosítási kód! Kérjük, próbáld újra.", 5);
                setState(() {
                  _paintRed = true;
                  _canProceed = true;
                  _isLoading = false;
                  _showNeptunServerError = false;
                });
              }
            }
        );
        PopupWidgetHandler.doPopup(context, blur: (){}, closeBlur: (){
          if (mounted) {
            setState(() {
              _canProceed = true;
              _isLoading = false;
            });
          }
        });
        return;
      }
      else { // 0: HIBÁS JELSZÓ VAGY NEPTUN KÓD
        AppHaptics.attentionLightImpact();
        setState(() {
          _paintRed = true;
          _canProceed = true;
          _isLoading = false;
          _showNeptunServerError = false;
        });
        _showLoginErrorDialog(
          title: "Sikertelen bejelentkezés",
          message: "Hibás Neptun kód vagy jelszó!\n\nKérjük, ellenőrizd az adataidat, a kis- és nagybetűket, valamint a kiválasztott intézményt.",
        );
      }
    }).catchError((err) {
      if (!mounted) return;
      AppHaptics.attentionLightImpact();
      setState(() {
        _paintRed = true;
        _canProceed = true;
        _isLoading = false;
        _showNeptunServerError = false;
      });
      _showLoginErrorDialog(
        title: "Kapcsolódási hiba",
        message: "Nem sikerült elérni az egyetemi Neptun szervert!\n\nKérjük, ellenőrizd az internetkapcsolatodat, vagy próbáld meg később.",
      );
    });
  }

  void _showLoginErrorDialog({required String title, required String message}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getTheme().rootBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.getTheme().errorRed, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.getTheme().textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.9),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getTheme().primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Rendben", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _snackbarMessage = "";
  Duration _displayDuration = Duration.zero;
  bool _shouldShowSnackbar = false;

  void _showSnackbar(String text, int displayDurationSec){
    if(!mounted){
      return;
    }
    setState(() {
      _shouldShowSnackbar = true;
      _displayDuration = Duration(seconds: displayDurationSec);
      _snackbarMessage = text;
    });
  }

  double _horizontalDrag = 0;
  bool _dragDebounce = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onHorizontalDragStart: (_){
          _horizontalDrag = 0;
          _dragDebounce = false;
        },
        onHorizontalDragEnd: (_){
          _horizontalDrag = 0;
          _dragDebounce = false;
        },
        onHorizontalDragUpdate: (e){
          _horizontalDrag += e.delta.dx;
          if(_horizontalDrag <= -25 && !_dragDebounce){
            _horizontalDrag = 0;
            _dragDebounce = true;

            if(!_canProceed){
              _showSnackbar(AppStrings.getLanguagePack().loginPage_setupPage_InvalidCredentials, 5);
              AppHaptics.attentionLightImpact();
              return;
            }

            AppHaptics.lightImpact();
            finishLogin();
          }
          else if(_horizontalDrag >= 25 && !_dragDebounce){
            _horizontalDrag = 0;
            _dragDebounce = true;

            AppHaptics.lightImpact();
            Navigator.pop(context);
          }
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        AppStrings.getLanguagePack().loginPage_setupPage_LoginHeaderText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.getTheme().textColor
                        ),
                      ),
                      const SizedBox(height: 60),
                      // University Selection Banner
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.isDarktheme()
                              ? AppColors.getTheme().secondary.withValues(alpha: 0.35)
                              : AppColors.getTheme().secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.isDarktheme()
                                ? AppColors.getTheme().secondary.withValues(alpha: 0.55)
                                : AppColors.getTheme().secondary.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            UniversityLogoWidget(
                              name: PageDTO.selected ?? "Neptun",
                              url: PageDTO.customURL ?? "",
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    PageDTO.selected ?? "Kiválasztott Intézmény",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.getTheme().textColor,
                                    ),
                                  ),
                                  if (PageDTO.customURL != null && PageDTO.customURL!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      Uri.tryParse(PageDTO.customURL!)?.host ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.getTheme().textColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                AppHaptics.lightImpact();
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Váltás",
                                style: TextStyle(
                                  color: AppColors.getTheme().primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextField(
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.all(18),
                                suffixIcon: Icon(
                                    Icons.person_2_rounded,
                                    color: _paintRed ?AppColors.getTheme().errorRed : AppColors.getTheme().textColor),
                                labelText: AppStrings.getLanguagePack().loginPage_setupPage_NeptunCode,
                                labelStyle: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.getTheme().textColor.withValues(alpha: .6),
                                    fontWeight: FontWeight.w400
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide.none
                                ),
                                filled: true,
                                fillColor: AppColors.getTheme().textColor.withValues(alpha: .05)
                            ),
                              autofocus: true,
                              enableSuggestions: false,
                              autocorrect: false,
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(
                                color: _paintRed ? AppColors.getTheme().errorRed : AppColors.getTheme().textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              onChanged: (value) {
                                AppHaptics.textEditingImpact();
                                _username = value;
                                setState(() {
                                  _canProceed = _password.isNotEmpty && _username.isNotEmpty;
                                  _paintRed = false;
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextField(
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.all(18),
                                suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                        color: _paintRed ? AppColors.getTheme().errorRed : AppColors.getTheme().textColor),
                                    onPressed: () {
                                      AppHaptics.lightImpact();
                                      setState(() {
                                        _obscureText = !_obscureText; // Toggle the password visibility
                                      });
                                    }),
                                labelText: AppStrings.getLanguagePack().loginPage_setupPage_Password,
                                labelStyle: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.getTheme().textColor.withValues(alpha: .6),
                                    fontWeight: FontWeight.w400
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide.none
                                ),
                                filled: true,
                                fillColor: AppColors.getTheme().textColor.withValues(alpha: .05)
                              ),
                              controller: _passwordController,
                              obscureText: _obscureText,
                              enableSuggestions: false,
                              autocorrect: false,
                              style: TextStyle(
                                color: _paintRed ? AppColors.getTheme().errorRed : AppColors.getTheme().textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              onChanged: (value) {
                                AppHaptics.textEditingImpact();
                                _password = value;
                                setState(() {
                                  _canProceed = _password.isNotEmpty && _username.isNotEmpty;
                                  _paintRed = false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _paintRed ? AppStrings.getLanguagePack().loginPage_setupPage_InvalidCredentialsEntered : "",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _paintRed ? AppColors.getTheme().errorRed : AppColors.getTheme().textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12
                            ),
                          ),
                          const SizedBox(height: 35),
                          const SizedBox(height: 50),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                    onPressed: (){
                                      AppHaptics.lightImpact();
                                      Navigator.pop(context);
                                    },
                                    style: ButtonStyle(
                                        backgroundColor: WidgetStateProperty.all(AppColors.getTheme().buttonEnabled),
                                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 35, vertical: 20))
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.arrow_back_ios_rounded,
                                          color: AppColors.getTheme().textColor.withValues(alpha: .6),
                                        ),
                                        Text(
                                          AppStrings.getLanguagePack().any_setupPage_GoBack,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12,
                                              color: AppColors.getTheme().textColor
                                          ),
                                        )
                                      ],
                                    )
                                ),
                                SizedBox(width: MediaQuery.of(context).size.width / 11),
                                ElevatedButton(
                                    onPressed: _canProceed ? (){
                                      AppHaptics.lightImpact();
                                      finishLogin();
                                    } : (){
                                      _showSnackbar(AppStrings.getLanguagePack().loginPage_setupPage_InvalidCredentials, 5);
                                      AppHaptics.attentionLightImpact();
                                    },
                                    style: ButtonStyle(
                                        backgroundColor: _canProceed ? WidgetStateProperty.all(AppColors.getTheme().buttonEnabled) : WidgetStateProperty.all(AppColors.getTheme().buttonDisabled),
                                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 35, vertical: 20))
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppStrings.getLanguagePack().loginPage_setupPage_LogInButton,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12,
                                              color: AppColors.getTheme().textColor
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: AppColors.getTheme().textColor.withValues(alpha: .6),
                                        ),
                                      ],
                                    )
                                )
                              ],
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
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
            ),
            Visibility(
              visible: _isLoading,
              child: Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              AppStrings.getLanguagePack().loginPage_setupPage_LoginInProgress,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.getTheme().textColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),
                          Center(
                            child: CircularProgressIndicator(
                              color: AppColors.getTheme().textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              api.Generic.randomLoadingComment(DataCache.getNeedFamilyFriendlyComments()!),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.getTheme().textColor.withValues(alpha: .6),
                                  fontWeight: FontWeight.w300,
                                  fontSize: 10
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),
                          Visibility(
                            visible: _showNeptunServerError,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                AppStrings.getLanguagePack().loginPage_setupPage_LoginInProgressSlow,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppColors.getTheme().textColor.withValues(alpha: .3),
                                    fontWeight: FontWeight.w300,
                                    fontSize: 14
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageDTO{
  static List<api.Institute>? institutes;
  static String? selected;
  static String? customURL;
  static bool validatedURL = false;
}