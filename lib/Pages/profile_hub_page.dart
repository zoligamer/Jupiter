import 'dart:convert' as conv;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';
import '../storage.dart' as storage;
import '../language.dart';

class ProfileHubPage extends StatefulWidget {
  const ProfileHubPage({super.key});

  @override
  State<ProfileHubPage> createState() => _ProfileHubPageState();
}

class _ProfileHubPageState extends State<ProfileHubPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Personal data
  GeneralUserData? _userData;
  List<StudentPersonalDocument> _documents = [];
  StudentCardDetails? _cardDetails;
  StudentContacts? _contacts;
  DefaultBankAccount? _bankAccount;
  bool _isLoadingDetails = true;

  // Settings
  UserProfileSettings? _profileSettings;
  String? _avatarBase64;
  String _selectedFallbackColor = '00DEA4';
  List<String> _fallbackColors = ['A62C2C', 'F2994A', '00DEA4', '0943D9', 'BDD910', 'FF2113', 'B605BA'];
  bool _isPasswordAllowed = true;
  bool _isLoginNameVisible = false;
  bool _isNicknameVisible = false;
  final TextEditingController _nicknameController = TextEditingController();
  bool _isSavingSettings = false;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _selectedFallbackColor = storage.DataCache.getCachedFallbackColor() ?? '00DEA4';
    _avatarBase64 = storage.DataCache.getCachedUserAvatarBase64();

    _loadFromCache();
    _fetchFreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _loadFromCache() {
    try {
      final rawUser = storage.DataCache.getCachedPersonalDataRaw();
      if (rawUser != null && rawUser.isNotEmpty) {
        final dec = conv.jsonDecode(rawUser);
        if (dec['data'] != null) {
          _userData = GeneralUserData.fromJson(dec['data']);
        }
      }

      final rawDocs = storage.DataCache.getCachedPersonalDocumentsRaw();
      if (rawDocs != null && rawDocs.isNotEmpty) {
        final dec = conv.jsonDecode(rawDocs);
        if (dec['data'] != null && dec['data']['studentPersonalDocuments'] != null) {
          _documents = (dec['data']['studentPersonalDocuments'] as List)
              .map((d) => StudentPersonalDocument.fromJson(d))
              .toList();
        }
      }

      final rawCard = storage.DataCache.getCachedStudentCardRaw();
      if (rawCard != null && rawCard.isNotEmpty) {
        final dec = conv.jsonDecode(rawCard);
        if (dec['data'] != null) {
          _cardDetails = StudentCardDetails.fromJson(dec['data']);
        }
      }

      final rawContacts = storage.DataCache.getCachedPersonalContactsRaw();
      if (rawContacts != null && rawContacts.isNotEmpty) {
        final dec = conv.jsonDecode(rawContacts);
        if (dec['data'] != null) {
          _contacts = StudentContacts.fromJson(dec['data']);
        }
      }

      final rawBank = storage.DataCache.getCachedBankAccountRaw();
      if (rawBank != null && rawBank.isNotEmpty) {
        final dec = conv.jsonDecode(rawBank);
        if (dec['data'] != null) {
          _bankAccount = DefaultBankAccount.fromJson(dec['data']);
        }
      }

      final rawSettings = storage.DataCache.getCachedProfileSettingsRaw();
      if (rawSettings != null && rawSettings.isNotEmpty) {
        final dec = conv.jsonDecode(rawSettings);
        if (dec['data'] != null) {
          _profileSettings = UserProfileSettings.fromJson(dec['data']);
          _isLoginNameVisible = _profileSettings!.isLoginNameVisible;
          _isNicknameVisible = _profileSettings!.isNicknameVisible;
          _nicknameController.text = _profileSettings!.nickname;
        }
      }

      final savedNick = storage.DataCache.getUserNickname();
      if (savedNick != null && savedNick.isNotEmpty) {
        _nicknameController.text = savedNick;
      }
      _isNicknameVisible = storage.DataCache.getIsNicknameVisible();
      _isLoginNameVisible = storage.DataCache.getIsLoginNameVisible();

      if (_userData != null || _contacts != null) {
        _isLoadingDetails = false;
        _isLoadingSettings = false;
      }
    } catch (_) {}
  }

  Future<void> _fetchFreshData() async {
    try {
      final userDataFuture = PersonalDataRequest.getGeneralUserData();
      final docsFuture = PersonalDataRequest.getStudentPersonalDocuments();
      final contactsFuture = PersonalDataRequest.getStudentPersonalDataContacts();
      final bankFuture = PersonalDataRequest.getDefaultBankAccount();
      final avatarFuture = UserProfileRequest.getUserAvatar(forceRefresh: true);
      final settingsFuture = UserProfileRequest.getUserProfileSettings();
      final colorsFuture = UserProfileRequest.getFallbackColorCodes();
      final passFuture = UserProfileRequest.isPasswordModificationAllowed();

      final results = await Future.wait([
        userDataFuture,
        docsFuture,
        contactsFuture,
        bankFuture,
        avatarFuture,
        settingsFuture,
        colorsFuture,
        passFuture,
      ]);

      if (!mounted) return;

      setState(() {
        _userData = results[0] as GeneralUserData?;
        _documents = (results[1] as List<StudentPersonalDocument>?) ?? [];
        _contacts = results[2] as StudentContacts?;
        _bankAccount = results[3] as DefaultBankAccount?;
        _avatarBase64 = results[4] as String?;
        _profileSettings = results[5] as UserProfileSettings?;
        if (_profileSettings != null) {
          _isLoginNameVisible = _profileSettings!.isLoginNameVisible;
          _isNicknameVisible = _profileSettings!.isNicknameVisible;
          _nicknameController.text = _profileSettings!.nickname;
        }
        final cList = results[6] as List<String>?;
        if (cList != null && cList.isNotEmpty) {
          _fallbackColors = cList;
        }
        _isPasswordAllowed = (results[7] as bool?) ?? true;

        _isLoadingDetails = false;
        _isLoadingSettings = false;
      });

      // Diákigazolvány részletek lekérése ha van kártya azonosító
      final studentCardDoc = _documents.firstWhere(
        (d) => d.typeString.toLowerCase().contains('diák') || d.identifier.contains('diak'),
        orElse: () => _documents.isNotEmpty ? _documents.first : StudentPersonalDocument(id: '', identifier: '', typeString: ''),
      );
      if (studentCardDoc.id.isNotEmpty) {
        final card = await PersonalDataRequest.getStudentCardDetails(studentCardDoc.id);
        if (mounted && card != null) {
          setState(() {
            _cardDetails = card;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _isLoadingSettings = false;
        });
      }
    }
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.getTheme().primary;
    }
  }

  Future<void> _pickNewAvatar() async {
    try {
      AppHaptics.lightImpact();
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final b64 = conv.base64Encode(bytes);
        setState(() {
          _avatarBase64 = b64;
        });
        await storage.DataCache.setCachedUserAvatarBase64(b64);
        Fluttertoast.showToast(msg: 'Profilkép kiválasztva. Mentsd el a beállításokat!');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Hiba a kép kiválasztásakor: $e');
    }
  }

  Future<void> _saveSettings() async {
    AppHaptics.mediumImpact();
    setState(() {
      _isSavingSettings = true;
    });

    final nick = _nicknameController.text.trim();
    await storage.DataCache.setUserNickname(nick);
    await storage.DataCache.setIsNicknameVisible(_isNicknameVisible);
    await storage.DataCache.setIsLoginNameVisible(_isLoginNameVisible);
    if (_avatarBase64 != null) {
      await storage.DataCache.setCachedUserAvatarBase64(_avatarBase64!);
    }
    await storage.DataCache.setCachedFallbackColor(_selectedFallbackColor);

    // Call API
    UserProfileRequest.saveUserProfileSettings(
      loginName: _isLoginNameVisible ? (storage.DataCache.getUsername() ?? '') : '',
      nickname: nick,
      avatarType: 0,
      base64EncodedProfilePicture: _avatarBase64,
    );

    if (mounted) {
      setState(() {
        _isSavingSettings = false;
      });
      Fluttertoast.showToast(msg: 'Beállítások sikeresen elmentve!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = math.max(
      MediaQuery.of(context).padding.bottom,
      MediaQuery.of(context).viewPadding.bottom,
    );

    return Scaffold(
      backgroundColor: AppColors.getTheme().rootBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getTheme().rootBackground,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: AppColors.getTheme().textColor),
                    onPressed: () {
                      AppHaptics.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.getLanguagePack().profile_Header,
                          style: TextStyle(
                            color: AppColors.getTheme().textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          AppStrings.getLanguagePack().profile_Subheader,
                          style: TextStyle(
                            color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.getTheme().primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.getTheme().rootBackground,
                unselectedLabelColor: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                onTap: (_) => AppHaptics.lightImpact(),
                tabs: [
                  Tab(
                    iconMargin: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.badge_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(AppStrings.getLanguagePack().profile_TabDetails),
                      ],
                    ),
                  ),
                  Tab(
                    iconMargin: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.tune_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(AppStrings.getLanguagePack().profile_TabSettings),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(bottomSafePadding),
                  _buildSettingsTab(bottomSafePadding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: SZEMÉLYES ADATOK (ADATLAP)
  // ==========================================
  Widget _buildDetailsTab(double bottomSafePadding) {
    if (_isLoadingDetails && _userData == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.getTheme().primary),
      );
    }

    final username = storage.DataCache.getUsername() ?? '';
    final initial = _userData?.firstName.isNotEmpty == true
        ? _userData!.firstName[0].toUpperCase()
        : (username.isNotEmpty ? username[0].toUpperCase() : '?');

    return RefreshIndicator(
      color: AppColors.getTheme().primary,
      backgroundColor: AppColors.getTheme().rootBackground,
      onRefresh: _fetchFreshData,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafePadding + 24),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                _buildAvatarWidget(size: 60, initial: initial),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_isNicknameVisible && _nicknameController.text.trim().isNotEmpty)
                                      ? _nicknameController.text.trim()
                                      : (_userData?.fullName.isNotEmpty == true ? _userData!.fullName : username),
                                  style: TextStyle(
                                    color: AppColors.getTheme().textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                if (_isNicknameVisible && _nicknameController.text.trim().isNotEmpty && _userData?.fullName.isNotEmpty == true)
                                  Text(
                                    _userData!.fullName,
                                    style: TextStyle(
                                      color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.getTheme().currentClassGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.getTheme().currentClassGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Aktív',
                              style: TextStyle(
                                color: AppColors.getTheme().currentClassGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_isLoginNameVisible) ...[
                            GestureDetector(
                              onTap: () {
                                AppHaptics.lightImpact();
                                Clipboard.setData(ClipboardData(text: username));
                                Fluttertoast.showToast(msg: 'Neptun kód vágólapra másolva!');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.getTheme().primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.getTheme().primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      username,
                                      style: TextStyle(
                                        color: AppColors.getTheme().primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.copy_rounded, size: 11, color: AppColors.getTheme().primary),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_cardDetails != null)
                            Text(
                              _cardDetails!.facultyString,
                              style: TextStyle(
                                color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Szekció 1: Alapadatok
          _buildSectionCard(
            title: 'Alapadatok',
            icon: Icons.person_rounded,
            badge: 'GDPR',
            children: [
              _buildDataRow('Születési név', _userData?.bornName ?? '-'),
              _buildDataRow('Születési idő', _userData?.bornDate.split('T')[0] ?? '-'),
              _buildDataRow('Születési hely', _userData?.bornPlace ?? '-'),
              _buildDataRow('Anyja neve', _userData?.motherName ?? '-'),
              _buildDataRow('Állampolgárság', _userData?.citizenship ?? 'Magyarország'),
              _buildDataRow('Nem', _userData?.sex ?? '-'),
            ],
          ),

          const SizedBox(height: 12),

          // Szekció 2: Hivatalos Azonosítók
          _buildSectionCard(
            title: 'Hivatalos Azonosítók',
            icon: Icons.verified_user_rounded,
            children: [
              _buildDataRow('Oktatási Azonosító (OM)', _userData?.educationalIdentifier ?? '-', copyable: true),
              _buildDataRow('Adóazonosító Jel', _userData?.taxIdentifier ?? '-', copyable: true),
              _buildDataRow('TAJ szám', _userData?.tajNumber ?? '-', copyable: true),
            ],
          ),

          const SizedBox(height: 12),

          // Szekció 3: Diákigazolvány & Matricák
          if (_cardDetails != null || _documents.isNotEmpty)
            _buildCardAndStickersSection(),

          const SizedBox(height: 12),

          // Szekció 4: Elérhetőségek & Címek
          if (_contacts != null)
            _buildContactsSection(),

          const SizedBox(height: 12),

          // Szekció 5: Ösztöndíj Bankszámla
          _buildBankAccountSection(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PROFIL BEÁLLÍTÁSOK & BIZTONSÁG
  // ==========================================
  Widget _buildSettingsTab(double bottomSafePadding) {
    if (_isLoadingSettings && _profileSettings == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.getTheme().primary),
      );
    }

    final username = storage.DataCache.getUsername() ?? '';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafePadding + 24),
      children: [
        // Profilkép & Avatár kártya
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatarWidget(size: 64, initial: initial),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profilkép és Avatár',
                          style: TextStyle(
                            color: AppColors.getTheme().textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Válassz fotót az eszközödről',
                          style: TextStyle(
                            color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickNewAvatar,
                              icon: const Icon(Icons.photo_camera_rounded, size: 14),
                              label: const Text('Kép csere', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.getTheme().primary,
                                foregroundColor: AppColors.getTheme().rootBackground,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                            if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  AppHaptics.lightImpact();
                                  setState(() {
                                    _avatarBase64 = null;
                                  });
                                  await storage.DataCache.setCachedUserAvatarBase64(null);
                                },
                                child: Text('Törlés', style: TextStyle(color: AppColors.getTheme().errorRed, fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: AppColors.getTheme().textColor.withValues(alpha: 0.08), height: 1),
              const SizedBox(height: 12),

              // Fallback színpaletta
              Text(
                'Fallback Kezdőbetű Színpaletta',
                style: TextStyle(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _fallbackColors.map((hex) {
                  final color = _parseHexColor(hex);
                  final isSelected = _selectedFallbackColor.toLowerCase() == hex.toLowerCase();
                  return GestureDetector(
                    onTap: () async {
                      AppHaptics.lightImpact();
                      setState(() {
                        _selectedFallbackColor = hex;
                      });
                      await storage.DataCache.setCachedFallbackColor(hex);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                            : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Megjelenési beállítások kártya
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Neptun Megjelenés',
                style: TextStyle(
                  color: AppColors.getTheme().primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.getTheme().primary,
                title: Text(
                  'Bejelentkezési név mutatása',
                  style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Neptun kód megjelenítése az app fejlécében',
                  style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 11),
                ),
                value: _isLoginNameVisible,
                onChanged: (val) {
                  AppHaptics.lightImpact();
                  setState(() => _isLoginNameVisible = val);
                },
              ),
              Divider(color: AppColors.getTheme().textColor.withValues(alpha: 0.08), height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.getTheme().primary,
                title: Text(
                  'Becenév használata',
                  style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Egyéni becenév az üdvözlő fejlécben',
                  style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 11),
                ),
                value: _isNicknameVisible,
                onChanged: (val) {
                  AppHaptics.lightImpact();
                  setState(() => _isNicknameVisible = val);
                },
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nicknameController,
                style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Becenév',
                  labelStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: AppColors.getTheme().textColor.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.getTheme().primary),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Biztonság & 2FA kártya
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Biztonság & Hitelesítés',
                style: TextStyle(
                  color: AppColors.getTheme().primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // 2FA Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.getTheme().currentClassGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.getTheme().currentClassGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_rounded, size: 20, color: AppColors.getTheme().currentClassGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kétlépcsős Azonosítás (2FA)',
                            style: TextStyle(
                              color: AppColors.getTheme().textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'A Neptun rendszerben aktív és védett',
                            style: TextStyle(
                              color: AppColors.getTheme().currentClassGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Password info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.key_rounded, size: 20, color: AppColors.getTheme().primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jelszó Módosítás',
                            style: TextStyle(
                              color: AppColors.getTheme().textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _isPasswordAllowed ? 'Jogosultság engedélyezve' : 'Központi adminisztrátor által tiltva',
                            style: TextStyle(
                              color: _isPasswordAllowed ? AppColors.getTheme().textColor.withValues(alpha: 0.6) : AppColors.getTheme().errorRed,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Save Button
        ElevatedButton(
          onPressed: _isSavingSettings ? null : _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.getTheme().primary,
            foregroundColor: AppColors.getTheme().rootBackground,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isSavingSettings
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTheme().rootBackground),
                )
              : const Text(
                  'Beállítások Mentése',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
        ),
      ],
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildAvatarWidget({required double size, required String initial}) {
    if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) {
      try {
        final bytes = conv.base64Decode(_avatarBase64!);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.getTheme().primary, width: 2),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {}
    }

    final fallbackColor = _parseHexColor(_selectedFallbackColor);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? badge,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.getTheme().primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: AppColors.getTheme().textColor.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: GestureDetector(
              onTap: copyable && value != '-'
                  ? () {
                      AppHaptics.lightImpact();
                      Clipboard.setData(ClipboardData(text: value));
                      Fluttertoast.showToast(msg: '$label másolva!');
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: copyable ? AppColors.getTheme().primary : AppColors.getTheme().textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (copyable && value != '-') ...[
                    const SizedBox(width: 4),
                    Icon(Icons.copy_rounded, size: 12, color: AppColors.getTheme().primary),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAndStickersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.getTheme().primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card_rounded, size: 18, color: AppColors.getTheme().primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diákigazolvány & Okmányok',
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_cardDetails != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.getTheme().currentClassGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _cardDetails!.statusString,
                    style: TextStyle(
                      color: AppColors.getTheme().currentClassGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_cardDetails != null) ...[
            _buildDataRow('Okmányazonosító', _cardDetails!.serial, copyable: true),
            _buildDataRow('Érvényesség lejárata', _cardDetails!.validityEnd.split(' ')[0]),
            _buildDataRow('Tagozat', _cardDetails!.facultyString),
            _buildDataRow('Intézmény Kar', _cardDetails!.primaryInstituteName),
          ],

          // Okmányok listája (pl. lakcímkártya, személyi)
          for (var doc in _documents)
            if (!doc.typeString.toLowerCase().contains('diák'))
              _buildDataRow(doc.typeString, doc.identifier, copyable: true),

          // Matricák
          if (_cardDetails != null && _cardDetails!.stickers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.getTheme().textColor.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 10),
            Text(
              'Féléves Érvényesítő Matricák',
              style: TextStyle(
                color: AppColors.getTheme().primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            ..._cardDetails!.stickers.map((s) {
              final isCurrent = s.statusString.toLowerCase().contains('kiadott') || s.statusString.toLowerCase().contains('aktív');
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.getTheme().currentClassGreen.withValues(alpha: 0.08)
                      : AppColors.getTheme().textColor.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.getTheme().currentClassGreen.withValues(alpha: 0.3)
                        : AppColors.getTheme().textColor.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent ? AppColors.getTheme().currentClassGreen : AppColors.getTheme().textColor.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.termString,
                          style: TextStyle(
                            color: AppColors.getTheme().textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '#${s.serialNumber}',
                      style: TextStyle(
                        color: isCurrent ? AppColors.getTheme().currentClassGreen : AppColors.getTheme().textColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildContactsSection() {
    return _buildSectionCard(
      title: 'Elérhetőségek & Címek',
      icon: Icons.contact_phone_rounded,
      children: [
        if (_contacts!.phones.isNotEmpty)
          for (var p in _contacts!.phones)
            _buildDataRow(p.typeName, p.number, copyable: true),
        if (_contacts!.addresses.isNotEmpty)
          for (var a in _contacts!.addresses)
            _buildDataRow(a.typeName, a.fullAddress, copyable: true),
        if (_contacts!.emails.isNotEmpty)
          for (var e in _contacts!.emails)
            _buildDataRow(e.typeName, e.email, copyable: true),
      ],
    );
  }

  Widget _buildBankAccountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded, size: 18, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ösztöndíj Folyósítási Bankszámla',
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'HUF',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDataRow(
            'Bankszámlaszám',
            _bankAccount?.accountNumber.isNotEmpty == true ? _bankAccount!.accountNumber : 'Nincs rögzítve',
            copyable: _bankAccount?.accountNumber.isNotEmpty == true,
          ),
          if (_bankAccount?.bankName.isNotEmpty == true)
            _buildDataRow('Bank', _bankAccount!.bankName),
        ],
      ),
    );
  }
}
