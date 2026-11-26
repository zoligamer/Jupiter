import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Pages/main_page.dart';
import '../storage.dart';
import '../colors.dart';

class AppUpdater {
  static const String repoOwner = "zoligamer";
  static const String repoName = "Jupiter";
  static const String websiteUrl = "https://zoligamer.github.io/Jupiter/";

  /// Reaktív értesítők a felület számára
  static final ValueNotifier<bool> hasUpdateNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> latestVersionNotifier = ValueNotifier<String?>(null);
  static String installedVersion = "2.3.1";
  static String latestAvailableVersion = "";
  static Map<String, dynamic>? latestReleaseData;

  /// Átirányítás a hivatalos letöltési weboldalra a telefon alapértelmezett böngészőjében
  static Future<void> redirectToDownloadPage() async {
    try {
      final uri = Uri.parse(websiteUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint("Hiba a letöltési oldal megnyitásakor: $e");
    }
  }

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

  /// Fő belépési pont frissítés ellenőrzéséhez és a hivatalos weboldalra irányításhoz
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
      // 3. GitHub API hívás a 'latest' kiadásért
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
      final currentVersion = packageInfo.version;
      installedVersion = currentVersion;
      latestAvailableVersion = latestTag;

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

        bool shouldRedirect = await _showUpdateDialog(activeContext, latestTag);
        if (shouldRedirect) {
          await redirectToDownloadPage();
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
      debugPrint("Hiba az update ellenőrzése során: $e");
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

  /// Frissítési ablak: tájékoztatja a felhasználót az új verzióról és átirányít a weboldalra
  static Future<bool> _showUpdateDialog(BuildContext context, String version) async {
    final theme = AppColors.getTheme();
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
              child: Icon(Icons.system_update_rounded, color: theme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Frissítés elérhető!",
                style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          "Az alkalmazás új verziója ($version) elérhető a hivatalos weboldalon. Szeretnéd megnyitni a letöltési oldalt a böngésződben?",
          style: TextStyle(color: theme.textColor, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Később", style: TextStyle(color: theme.textColor.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Megnyitás", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
