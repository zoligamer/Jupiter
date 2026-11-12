import 'dart:io';
import 'dart:convert';
import 'dart:ffi';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Pages/main_page.dart';
import '../storage.dart';
import '../colors.dart';

class AppUpdater {
  static const String repoOwner = "zoligamer";
  static const String repoName = "Jupiter";

  /// Reaktív értesítők a felület számára
  static final ValueNotifier<bool> hasUpdateNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> latestVersionNotifier = ValueNotifier<String?>(null);
  static String installedVersion = "1.0.5";
  static String latestAvailableVersion = "";
  static Map<String, dynamic>? latestReleaseData;

  /// Inicializálás (verzió betöltése és gyorsított gyorsítótár-ellenőrzés)
  static Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      installedVersion = packageInfo.version;
    } catch (_) {
      installedVersion = "1.0.5";
    }

    try {
      final cachedLatest = await getString('CachedLatestReleaseTag');
      if (cachedLatest != null && cachedLatest.isNotEmpty) {
        latestAvailableVersion = cachedLatest;
        if (_isNewerVersion(installedVersion, cachedLatest)) {
          hasUpdateNotifier.value = true;
          latestVersionNotifier.value = cachedLatest;
        }
      }
    } catch (_) {}
  }

  /// Csendes háttérbeli lekérdezés a GitHub API-ról értesítési sávokhoz és jelvényekhez
  static Future<void> checkSilentUpdate() async {
    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none) && !conn.any((c) => c != ConnectivityResult.none)) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("https://api.github.com/repos/$repoOwner/$repoName/releases/latest"),
        headers: {
          'User-Agent': 'Neptun2-App',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final latestTag = data['tag_name']?.toString() ?? '';
      if (latestTag.isEmpty) return;

      latestReleaseData = data;
      latestAvailableVersion = latestTag;
      await saveString('CachedLatestReleaseTag', latestTag);
      await saveInt('ObsoleteAppVerUpdateCacheTime', DateTime.now().millisecondsSinceEpoch);

      if (installedVersion.isEmpty) {
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          installedVersion = packageInfo.version;
        } catch (_) {
          installedVersion = "1.0.5";
        }
      }

      if (_isNewerVersion(installedVersion, latestTag)) {
        hasUpdateNotifier.value = true;
        latestVersionNotifier.value = latestTag;
      } else {
        hasUpdateNotifier.value = false;
        latestVersionNotifier.value = null;
      }
    } catch (e) {
      debugPrint("Silent update check error: $e");
    }
  }

  /// Fő belépési pont.
  static Future<void> checkAndInstallUpdate(BuildContext? context, {bool force = false}) async {
    // 1. Internet ellenőrzés
    final conn = await Connectivity().checkConnectivity();
    if (conn.contains(ConnectivityResult.none) && !conn.any((c) => c != ConnectivityResult.none)) {
      if (force && Platform.isAndroid) {
        Fluttertoast.showToast(
          msg: "Nincs internetkapcsolat!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: AppColors.getTheme().rootBackground,
          textColor: AppColors.getTheme().textColor,
        );
      }
      return;
    }

    // 2. 24 órás Cache ellenőrzés (csak naponta egyszer, kivéve ha manuális lekérés)
    if (!force) {
      final cacheTime = await getInt('ObsoleteAppVerUpdateCacheTime') ?? -1;
      if ((DateTime.now().millisecondsSinceEpoch - cacheTime) < const Duration(hours: 24).inMilliseconds) {
        return;
      }
    }

    if (force && Platform.isAndroid) {
      Fluttertoast.showToast(
        msg: "Frissítések keresése...",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: AppColors.getTheme().rootBackground,
        textColor: AppColors.getTheme().textColor,
      );
    }

    try {
      // 3. GitHub API hívás a 'latest' kiadásért megfelelő fejlécekkel
      final response = await http.get(
        Uri.parse("https://api.github.com/repos/$repoOwner/$repoName/releases/latest"),
        headers: {
          'User-Agent': 'Neptun2-App',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode != 200) {
        if (force && Platform.isAndroid) {
          Fluttertoast.showToast(
            msg: "Nem sikerült lekérni a GitHub kiadásokat (${response.statusCode})",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: AppColors.getTheme().rootBackground,
            textColor: AppColors.getTheme().textColor,
          );
        }
        return;
      }

      final data = json.decode(response.body);
      final latestTag = data['tag_name']?.toString() ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // pl. 1.0.4 vagy 1.0.4+16
      installedVersion = currentVersion;
      latestAvailableVersion = latestTag;

      // Elmentjük a sikeres ellenőrzés idejét és tagjét
      await saveString('CachedLatestReleaseTag', latestTag);
      await saveInt('ObsoleteAppVerUpdateCacheTime', DateTime.now().millisecondsSinceEpoch);

      if (_isNewerVersion(currentVersion, latestTag)) {
        hasUpdateNotifier.value = true;
        latestVersionNotifier.value = latestTag;
        BuildContext? activeContext = (context != null && context.mounted) ? context : HomePageState.getContext();
        if (activeContext == null || !activeContext.mounted) {
          debugPrint("Nem található érvényes BuildContext az update dialog megjelenítéséhez.");
          return;
        }

        bool shouldUpdate = await _showUpdateDialog(activeContext, latestTag);
        if (shouldUpdate) {
          BuildContext? downloadContext = activeContext.mounted ? activeContext : HomePageState.getContext();
          if (downloadContext != null && downloadContext.mounted) {
            await _downloadAndInstall(downloadContext, data['assets'] ?? []);
          }
        }
      } else {
        hasUpdateNotifier.value = false;
        latestVersionNotifier.value = null;
        if (force && Platform.isAndroid) {
          Fluttertoast.showToast(
            msg: "Az alkalmazás naprakész! (v$currentVersion)",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.SNACKBAR,
            backgroundColor: AppColors.getTheme().rootBackground,
            textColor: AppColors.getTheme().textColor,
          );
        }
      }
    } catch (e) {
      debugPrint("Hiba az auto-update során: $e");
      if (force && Platform.isAndroid) {
        Fluttertoast.showToast(
          msg: "Hiba történt a frissítés ellenőrzésekor.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: AppColors.getTheme().rootBackground,
          textColor: AppColors.getTheme().textColor,
        );
      }
    }
  }

  /// Egyszerű Igen / Később ablak
  static Future<bool> _showUpdateDialog(BuildContext context, String version) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getTheme().rootBackground,
        title: Text(
          "Frissítés elérhető!",
          style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Az alkalmazás új verziója ($version) elérhető. Szeretnéd most letölteni és telepíteni?",
          style: TextStyle(color: AppColors.getTheme().textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Később", style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getTheme().currentClassGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Igen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Megjeleníti a kiadási megjegyzéseket frissítés után (csak egyszer verziónként)
  static Future<void> showPostUpdateChangelogIfNeeded(BuildContext context) async {
    if (installedVersion.isEmpty) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        installedVersion = packageInfo.version;
      } catch (_) {
        installedVersion = "1.0.5";
      }
    }

    final lastSeen = DataCache.getLastSeenChangelogVersion();
    if (lastSeen == null) {
      // Első telepítés: elmentjük a verziót, nem zavarjuk a felhasználót régebbi jegyzetekkel
      await DataCache.setLastSeenChangelogVersion(installedVersion);
      return;
    }

    if (lastSeen != installedVersion) {
      await DataCache.setLastSeenChangelogVersion(installedVersion);
      if (context.mounted) {
        await showReleaseChangelog(context, version: installedVersion);
      }
    }
  }

  /// Megjeleníti a megadott (vagy legújabb) verzió kiadási jegyzeteit
  static Future<void> showReleaseChangelog(BuildContext context, {String? version}) async {
    final theme = AppColors.getTheme();
    final targetVer = version ?? (installedVersion.isNotEmpty ? installedVersion : "legújabb");

    String releaseNotes = "Kiadási megjegyzések betöltése...";
    try {
      final response = await http.get(
        Uri.parse("https://api.github.com/repos/$repoOwner/$repoName/releases/latest"),
        headers: {
          'User-Agent': 'Neptun2-App',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final body = data['body']?.toString();
        if (body != null && body.trim().isNotEmpty) {
          releaseNotes = body.trim();
        } else {
          releaseNotes = "Nincsenek részletes kiadási megjegyzések ehhez a verzióhoz.";
        }
      }
    } catch (_) {
      releaseNotes = "A kiadási megjegyzések eléréséhez internetkapcsolat szükséges.";
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.rootBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.celebration_rounded, color: theme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Újdonságok a Jupiterben",
                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "Verzió: $targetVer",
                    style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: releaseNotes,
              selectable: true,
              onTapLink: (text, href, title) async {
                if (href != null && href.isNotEmpty) {
                  final uri = Uri.tryParse(href);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: theme.textColor.withValues(alpha: 0.9), fontSize: 13, height: 1.45),
                h1: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 17),
                h2: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 15),
                h3: TextStyle(color: theme.primary, fontWeight: FontWeight.w600, fontSize: 13.5),
                strong: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                em: TextStyle(color: theme.textColor.withValues(alpha: 0.85), fontStyle: FontStyle.italic),
                code: TextStyle(
                  color: theme.primary,
                  backgroundColor: theme.textColor.withValues(alpha: 0.08),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                ),
                blockquote: TextStyle(color: theme.textColor.withValues(alpha: 0.85), fontStyle: FontStyle.italic, fontSize: 12.5),
                blockquoteDecoration: BoxDecoration(
                  border: Border(left: BorderSide(color: theme.primary, width: 3)),
                ),
                blockquotePadding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
                listBullet: TextStyle(color: theme.primary, fontSize: 13),
                a: TextStyle(color: theme.primary, decoration: TextDecoration.underline),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.textColor.withValues(alpha: 0.12), width: 1)),
                ),
              ),
              sizedImageBuilder: (config) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      config.uri.toString(),
                      width: config.width,
                      height: config.height,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.textColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded, size: 16, color: theme.textColor.withValues(alpha: 0.5)),
                            const SizedBox(width: 6),
                            Text(config.alt ?? "Kép betöltése sikertelen", style: TextStyle(color: theme.textColor.withValues(alpha: 0.5), fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Bezárás", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Detektálja, hogy 64-bites (ARM8) vagy 32-bites (ARM7) környezetben futunk
  static Future<bool> _detectIs64Bit() async {
    // 1. Android eszköz ABI lekérdezése
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.supported64BitAbis.isNotEmpty) {
          return true;
        }
        final abis = androidInfo.supportedAbis.map((e) => e.toLowerCase()).toList();
        if (abis.any((a) => a.contains('arm64') || a.contains('v8a') || a.contains('x86_64') || a.contains('aarch64'))) {
          return true;
        }
        if (abis.any((a) => a.contains('arm') || a.contains('v7a') || a.contains('armeabi') || a.contains('x86'))) {
          return false;
        }
      }
    } catch (e) {
      debugPrint("DeviceInfo architektúra hiba: $e");
    }

    // 2. Tartalék: a futó app saját futtatókörnyezetének (Abi.current) vizsgálata
    try {
      final currentAbi = Abi.current();
      if (currentAbi == Abi.androidArm64 || currentAbi == Abi.androidX64 || currentAbi == Abi.linuxArm64 || currentAbi == Abi.linuxX64 || currentAbi == Abi.windowsX64 || currentAbi == Abi.windowsArm64) {
        return true;
      }
      if (currentAbi == Abi.androidArm || currentAbi == Abi.androidIA32 || currentAbi == Abi.linuxArm || currentAbi == Abi.linuxIA32 || currentAbi == Abi.windowsIA32) {
        return false;
      }
    } catch (e) {
      debugPrint("Abi.current() hiba: $e");
    }

    // Alapértelmezett: 64-bit (ARM8) a modern telefonokhoz
    return true;
  }

  static bool _isArm64Asset(String name) {
    final n = name.toLowerCase();
    return n.contains('arm8') || n.contains('arm-8') || n.contains('arm_8') ||
           n.contains('arm64') || n.contains('arm-64') || n.contains('v8a') ||
           n.contains('aarch64');
  }

  static bool _isArm32Asset(String name) {
    final n = name.toLowerCase();
    return n.contains('arm7') || n.contains('arm-7') || n.contains('arm_7') ||
           n.contains('armv7') || n.contains('v7a') || n.contains('armeabi');
  }

  /// Kiválasztja a CPU architektúrához leginkább illeszkedő APK-t a GitHub assets listából
  static Future<Map<String, dynamic>?> _selectBestAsset(List assets) async {
    final apkAssets = assets.where((a) {
      if (a is! Map) return false;
      final name = a['name']?.toString().toLowerCase() ?? '';
      return name.endsWith('.apk') && !name.endsWith('.sha1') && !name.endsWith('.sha256') && !name.endsWith('.md5') && !name.endsWith('.sig');
    }).cast<Map<String, dynamic>>().toList();

    if (apkAssets.isEmpty) return null;

    // 0. Elsődleges: Univerzális APK csomag (így az Android csomagkezelő maga választhat a megfelelő binárisokból)
    for (final a in apkAssets) {
      final name = a['name']?.toString().toLowerCase() ?? '';
      if (name.contains('universal')) {
        return a;
      }
    }

    final is64Bit = await _detectIs64Bit();

    if (is64Bit) {
      // 1. Elsődleges: ARM8 / arm64 / v8a (pl. NeptunMobile_ARM8-v1.0.5.apk, app-arm64-v8a-release.apk)
      for (final a in apkAssets) {
        final name = a['name']?.toString() ?? '';
        if (_isArm64Asset(name)) {
          return a;
        }
      }
      // 2. Univerzális (nem ARM7-specifikus)
      for (final a in apkAssets) {
        final name = a['name']?.toString() ?? '';
        if (!_isArm32Asset(name)) {
          return a;
        }
      }
      // 3. Fallback
      return apkAssets.first;
    } else {
      // 32-bites eszköz (ARM7)
      // 1. Elsődleges: ARM7 / v7a / armeabi (pl. NeptunMobile_ARM7-v1.0.5.apk, app-armeabi-v7a-release.apk)
      for (final a in apkAssets) {
        final name = a['name']?.toString() ?? '';
        if (_isArm32Asset(name)) {
          return a;
        }
      }
      // 2. Univerzális (nem 64-bites specifikus)
      for (final a in apkAssets) {
        final name = a['name']?.toString() ?? '';
        if (!_isArm64Asset(name)) {
          return a;
        }
      }
      // 3. Fallback
      return apkAssets.first;
    }
  }

  /// Letöltés sávval és automatikus megnyitás
  static Future<void> _downloadAndInstall(BuildContext context, List assets) async {
    final asset = await _selectBestAsset(assets);
    if (asset == null) {
      debugPrint("Nem található megfelelő APK fájl a kiadásban.");
      if (Platform.isAndroid) {
        Fluttertoast.showToast(
          msg: "Nem található kompatibilis telepítőcsomag (.apk) a kiadásban.",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: AppColors.getTheme().rootBackground,
          textColor: AppColors.getTheme().textColor,
        );
      }
      return;
    }

    final downloadUrl = asset['browser_download_url']?.toString() ?? '';
    // Only this repo's release assets, safe file name, digest check when GitHub provides one.
    final releasePrefix = 'https://github.com/$repoOwner/$repoName/releases/download/';
    if (!downloadUrl.startsWith(releasePrefix)) return;
    final rawName = asset['name']?.toString() ?? 'Neptun_Update.apk';
    final assetFileName = rawName.split('/').last.split('\\').last.replaceAll('..', '_');
    final expectedDigest = asset['digest']?.toString() ?? '';

    String targetSha256 = '';
    if (expectedDigest.toLowerCase().startsWith('sha256:')) {
      targetSha256 = expectedDigest.substring(7).trim().toLowerCase();
    } else {
      // Keresünk azonos nevű .sha256 kiadási assetet (mind az .apk.sha256, mind a .sha256 formátum támogatva)
      final shaNameWithApk = '${rawName.toLowerCase()}.sha256';
      final shaNameWithoutApk = '${rawName.toLowerCase().replaceAll(RegExp(r'\.apk$'), '')}.sha256';
      final shaAsset = assets.firstWhere(
        (a) {
          if (a is! Map) return false;
          final aname = a['name']?.toString().toLowerCase();
          return aname == shaNameWithApk || aname == shaNameWithoutApk;
        },
        orElse: () => null,
      );
      if (shaAsset != null && shaAsset['browser_download_url'] != null) {
        try {
          final shaUrl = shaAsset['browser_download_url'].toString();
          if (shaUrl.startsWith(releasePrefix)) {
            final res = await http.get(Uri.parse(shaUrl)).timeout(const Duration(seconds: 5));
            if (res.statusCode == 200) {
              final hashMatch = RegExp(r'[a-fA-F0-9]{64}').firstMatch(res.body);
              if (hashMatch != null) {
                targetSha256 = hashMatch.group(0)!.toLowerCase();
              }
            }
          }
        } catch (_) {}
      }
    }

    final tempDir = await getTemporaryDirectory();
    final savePath = "${tempDir.path}/$assetFileName";

    // Takarítás: töröljük az esetleges korábbi ideiglenes telepítőt
    if (File(savePath).existsSync()) {
      try {
        File(savePath).deleteSync();
      } catch (_) {}
    }

    if (!context.mounted) return;

    // Letöltés folyamatjelző
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DownloadProgressDialog(),
    );

    try {
      final dio = Dio();
      await dio.download(downloadUrl, savePath);
      if (targetSha256.isNotEmpty) {
        final actual = (await sha256.bind(File(savePath).openRead()).first).toString().toLowerCase();
        if (actual != targetSha256) {
          try { File(savePath).deleteSync(); } catch (_) {}
          throw Exception('APK digest mismatch');
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // Töltés ablak bezárása
      }

      // Telepítés indítása
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        debugPrint("APK megnyitási státusz: ${result.message}");
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
      }
      debugPrint("Hálózati hiba a letöltés során: $e");
      if (Platform.isAndroid) {
        Fluttertoast.showToast(
          msg: "Hiba történt a letöltés során!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.SNACKBAR,
          backgroundColor: AppColors.getTheme().rootBackground,
          textColor: AppColors.getTheme().textColor,
        );
      }
    }
  }

  /// Kinyeri a numerikus és szemantikus verzió szegmenseket (pl. 1.0.5, 1.0.5R, 1.0.5-Hotfix, 1.0.5F, 1.0.5+20)
  static List<int> _parseVersionNumbers(String raw) {
    if (raw.trim().isEmpty) return [0];

    String cleaned = raw.trim();
    if (cleaned.toLowerCase().startsWith('v')) {
      cleaned = cleaned.substring(1);
    }

    final segments = cleaned.split(RegExp(r'[.\-+_]'));
    List<int> numbers = [];

    for (final seg in segments) {
      if (seg.isEmpty) continue;
      final matches = RegExp(r'\d+').allMatches(seg);
      for (final m in matches) {
        numbers.add(int.tryParse(m.group(0)!) ?? 0);
      }
      final letterMatches = RegExp(r'[a-zA-Z]+').allMatches(seg);
      for (final lm in letterMatches) {
        final str = lm.group(0)!.toUpperCase();
        int charSum = 0;
        for (int i = 0; i < str.length; i++) {
          charSum = (charSum * 26) + (str.codeUnitAt(i) - 64);
        }
        numbers.add(charSum);
      }
    }

    if (numbers.isEmpty) return [0];
    return numbers;
  }

  /// Összehasonlítja a jelenlegi és a GitHubos verziószámot
  static bool _isNewerVersion(String current, String latest) {
    List<int> currParts = _parseVersionNumbers(current);
    List<int> latestParts = _parseVersionNumbers(latest);

    int maxLen = currParts.length > latestParts.length ? currParts.length : latestParts.length;
    for (int i = 0; i < maxLen; i++) {
      int c = i < currParts.length ? currParts[i] : 0;
      int l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true;  // A GitHub verzió újabb
      if (l < c) return false; // A telepített verzió újabb vagy megegyezik
    }
    return false; // Pontosan megegyeznek
  }
}

/// Belső Widget a letöltési folyamatjelzőhöz
class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.getTheme().rootBackground,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.getTheme().currentClassGreen),
          const SizedBox(height: 20),
          Text("Frissítés letöltése folyamatban...", style: TextStyle(color: AppColors.getTheme().textColor)),
          const SizedBox(height: 10),
          Text(
            "Kérlek, ne zárd be az alkalmazást.",
            style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}