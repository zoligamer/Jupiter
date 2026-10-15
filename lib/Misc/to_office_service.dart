import 'dart:convert' as conv;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../API/api_coms.dart' as api;
import '../storage.dart' as storage;

class ToOfficeSlot {
  final int weekday; // 1 = Hétfő, ..., 7 = Vasárnap
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String location;
  final String note;

  const ToOfficeSlot({
    required this.weekday,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.location = 'Tanulmányi Osztály',
    this.note = '',
  });

  String get timeFormatted {
    final sh = startHour.toString().padLeft(2, '0');
    final sm = startMinute.toString().padLeft(2, '0');
    final eh = endHour.toString().padLeft(2, '0');
    final em = endMinute.toString().padLeft(2, '0');
    return '$sh:$sm - $eh:$em';
  }

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'startHour': startHour,
    'startMinute': startMinute,
    'endHour': endHour,
    'endMinute': endMinute,
    'location': location,
    'note': note,
  };

  factory ToOfficeSlot.fromJson(Map<String, dynamic> json) => ToOfficeSlot(
    weekday: json['weekday'] is int ? json['weekday'] : int.tryParse(json['weekday']?.toString() ?? '1') ?? 1,
    startHour: json['startHour'] is int ? json['startHour'] : int.tryParse(json['startHour']?.toString() ?? '8') ?? 8,
    startMinute: json['startMinute'] is int ? json['startMinute'] : int.tryParse(json['startMinute']?.toString() ?? '0') ?? 0,
    endHour: json['endHour'] is int ? json['endHour'] : int.tryParse(json['endHour']?.toString() ?? '11') ?? 11,
    endMinute: json['endMinute'] is int ? json['endMinute'] : int.tryParse(json['endMinute']?.toString() ?? '30') ?? 30,
    location: json['location']?.toString() ?? 'Tanulmányi Osztály',
    note: json['note']?.toString() ?? '',
  );
}

class ToOfficeService {
  static const String CACHE_KEY = 'CACHED_TO_OFFICE_SCHEDULE';
  static const String URL_CACHE_KEY = 'CACHED_TO_URL';
  static const String FACULTY_CACHE_KEY = 'CACHED_TO_FACULTY_NAME';

  static String currentToUrl = '';
  static String currentFacultyName = '';

  // Alapértelmezett beépített nyitvatartás tartalék esetére
  static final List<ToOfficeSlot> _defaultSchedule = [
    const ToOfficeSlot(weekday: 1, startHour: 8, startMinute: 45, endHour: 11, endMinute: 45, location: 'J.52-53 / FR.210'),
    const ToOfficeSlot(weekday: 3, startHour: 8, startMinute: 45, endHour: 11, endMinute: 45, location: 'J.52-53 / FR.210', note: 'I. idősáv'),
    const ToOfficeSlot(weekday: 3, startHour: 13, startMinute: 15, endHour: 14, endMinute: 30, location: 'J.52-53 / FR.210', note: 'II. idősáv'),
    const ToOfficeSlot(weekday: 5, startHour: 8, startMinute: 45, endHour: 11, endMinute: 45, location: 'J.52-53 / FR.210'),
  ];

  static List<ToOfficeSlot> _activeSchedule = List.from(_defaultSchedule);
  static bool _hasLoadedFromCache = false;
  static bool _isResolving = false;

  /// Inicializálás a helyi perzisztens cache-ből vagy az intézményi alapértelmezett JSON-ből
  static Future<void> initialize() async {
    if (_hasLoadedFromCache) return;
    try {
      final cachedUrl = await storage.getString(URL_CACHE_KEY);
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        currentToUrl = cachedUrl;
      }

      final cachedFaculty = await storage.getString(FACULTY_CACHE_KEY);
      if (cachedFaculty != null && cachedFaculty.isNotEmpty) {
        currentFacultyName = cachedFaculty;
      }

      final cachedSchedule = await storage.getString(CACHE_KEY);
      if (cachedSchedule != null && cachedSchedule.isNotEmpty) {
        final decoded = conv.jsonDecode(cachedSchedule) as List<dynamic>;
        _activeSchedule = decoded.map((e) => ToOfficeSlot.fromJson(e as Map<String, dynamic>)).toList();
      }

      // Ha még nincs mentett órarend a cache-ben, betöltjük az intézmény alapértelmezettjét
      if (_activeSchedule.isEmpty) {
        final inst = await findCurrentInstitute();
        if (inst != null) {
          if (inst['ToUrl'] != null && currentToUrl.isEmpty) {
            currentToUrl = inst['ToUrl'].toString();
          }
          final faculties = inst['Faculties'] as List<dynamic>?;
          if (faculties != null && faculties.isNotEmpty) {
            final firstFac = faculties.first as Map<String, dynamic>;
            if (currentToUrl.isEmpty) currentToUrl = (firstFac['ToUrl'] ?? '').toString();
            if (currentFacultyName.isEmpty) currentFacultyName = (firstFac['FacultyName'] ?? '').toString();
            if (firstFac['ToSchedule'] is List) {
              _activeSchedule = (firstFac['ToSchedule'] as List).map((e) => ToOfficeSlot.fromJson(e as Map<String, dynamic>)).toList();
            }
          } else if (inst['ToSchedule'] is List) {
            _activeSchedule = (inst['ToSchedule'] as List).map((e) => ToOfficeSlot.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
        if (_activeSchedule.isEmpty) {
          _activeSchedule = List.from(_defaultSchedule);
        }
      }
    } catch (e) {
      debugPrint('[ToOfficeService] Hiba az inicializáláskor: $e');
    }
    _hasLoadedFromCache = true;
  }

  /// Keresés az intézmény JSON listában a bejelentkezett egyetem URL-je alapján
  static Future<Map<String, dynamic>?> findCurrentInstitute() async {
    try {
      final rawList = await api.InstitutesRequest.getRawJsonWithNameUrlPairs();
      if (rawList == null || rawList.isEmpty) return null;

      final baseInstUrl = storage.DataCache.getInstituteUrl() ?? '';
      final cleanBase = _cleanHost(baseInstUrl);

      for (var item in rawList) {
        if (item is Map<String, dynamic>) {
          final itemUrl = (item['Url'] ?? '').toString();
          final cleanItem = _cleanHost(itemUrl);

          if (cleanBase.isNotEmpty && cleanItem.isNotEmpty &&
              (cleanBase == cleanItem || cleanBase.contains(cleanItem) || cleanItem.contains(cleanBase))) {
            return item;
          }
        }
      }
    } catch (e) {
      debugPrint('[ToOfficeService] Hiba az egyetem megkeresésekor: $e');
    }
    return null;
  }

  /// Aszinkron kar ellenőrző és automatikus beállítás a bejelentkezett felhasználóhoz
  static Future<void> checkAndResolveFacultyAsync({bool forceRefresh = false}) async {
    if (_isResolving) return;
    _isResolving = true;

    try {
      final hasLogin = storage.DataCache.getHasLogin();
      if (hasLogin == null || !hasLogin) {
        _isResolving = false;
        return;
      }

      final inst = await findCurrentInstitute();
      if (inst == null) {
        _isResolving = false;
        return;
      }

      final faculties = inst['Faculties'] as List<dynamic>?;
      if (faculties == null || faculties.isEmpty) {
        // Központi TO-val rendelkező egyetem
        final toUrl = (inst['ToUrl'] ?? '').toString();
        if (toUrl.isNotEmpty) currentToUrl = toUrl;
        if (inst['ToSchedule'] is List) {
          _activeSchedule = (inst['ToSchedule'] as List).map((e) => ToOfficeSlot.fromJson(e as Map<String, dynamic>)).toList();
          await _saveScheduleToCache();
        }
        _isResolving = false;
        return;
      }

      // Ha már sikeresen felismertük a kart és nem kértünk kényszerített újratöltést
      if (!forceRefresh && currentFacultyName.isNotEmpty && _activeSchedule.isNotEmpty) {
        _isResolving = false;
        return;
      }

      // Képzés/kar adatok lekérése a Neptunból
      final trainingInfo = await api.InstitutesRequest.getStudentGeneralTrainingData();
      if (trainingInfo == null) {
        _isResolving = false;
        return;
      }

      Map<String, dynamic>? bestFaculty;
      int highestScore = -1;

      for (var f in faculties) {
        if (f is Map<String, dynamic>) {
          final score = calculateFacultyScore(
            f,
            trainingInfo.description,
            trainingInfo.trainingCode,
            trainingInfo.trainingName,
          );
          if (score > highestScore) {
            highestScore = score;
            bestFaculty = f;
          }
        }
      }

      if (bestFaculty != null && highestScore > 0) {
        currentFacultyName = (bestFaculty['FacultyName'] ?? '').toString();
        currentToUrl = (bestFaculty['ToUrl'] ?? '').toString();
        if (bestFaculty['ToSchedule'] is List) {
          _activeSchedule = (bestFaculty['ToSchedule'] as List).map((e) => ToOfficeSlot.fromJson(e as Map<String, dynamic>)).toList();
        }
        await _saveScheduleToCache();
      } else {
        // Ha nem sikerült egyértelmű egyezést találni, használjuk az intézmény alapértelmezettjét
        if (inst['ToUrl'] != null) currentToUrl = inst['ToUrl'].toString();
        if (inst['ToSchedule'] is List) {
          _activeSchedule = (inst['ToSchedule'] as List).map((e) => ToOfficeSlot.fromJson(e as Map<String, dynamic>)).toList();
          await _saveScheduleToCache();
        }
      }
    } catch (e) {
      debugPrint('[ToOfficeService] Hiba a kar ellenőrzése során: $e');
    } finally {
      _isResolving = false;
    }
  }

  /// Intelligens egyezési pontszám számítása a kar és a hallgatói adatok között
  static int calculateFacultyScore(
    Map<String, dynamic> faculty,
    String description,
    String trainingCode,
    String trainingName,
  ) {
    int score = 0;
    final facultyName = (faculty['FacultyName'] ?? '').toString();
    final facNorm = _normalize(facultyName);
    final descNorm = _normalize(description);
    final codeNorm = trainingCode.toUpperCase().trim();
    final nameNorm = _normalize(trainingName);

    // 1. Zárójeles rövidítés egyezése, pl: "(BGK)" -> "BGK", "(NIK)" -> "NIK"
    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(facultyName);
    if (parenMatch != null) {
      final abbr = parenMatch.group(1)!.toUpperCase().trim();
      if (abbr.isNotEmpty) {
        if (codeNorm.contains(abbr)) score += 80;
        if (codeNorm.startsWith(abbr)) score += 50;
        if (descNorm.contains(abbr.toLowerCase())) score += 60;
        // Prefix egyezés (pl: BBNFKM képzéskód kezdete "BB", "BGK"-ból "B")
        if (abbr.length >= 2 && codeNorm.startsWith(abbr.substring(0, 2))) {
          score += 35;
        } else if (abbr.isNotEmpty && codeNorm.startsWith(abbr[0])) {
          score += 15;
        }
      }
    }

    // 2. Szóegyezések súlyozása
    final stopWords = {
      'kar', 'kara', 'es', 'és', 'a', 'az', 'egyetem', 'foiskola', 'főiskola',
      'muszaki', 'műszaki', 'tudomanyi', 'tudományi', 'intezet', 'intézet',
      'iroda', 'tanulmanyi', 'tanulmányi', 'osztaly', 'osztály'
    };

    final facWords = facNorm
        .split(RegExp(r'[\s,\.\(\)\/\-_]+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();

    for (var word in facWords) {
      if (descNorm.contains(word)) score += 35;
      if (nameNorm.contains(word)) score += 15;
    }

    // 3. Teljes vagy részleges szöveges egyezés
    if (descNorm.isNotEmpty && (descNorm.contains(facNorm) || facNorm.contains(descNorm))) {
      score += 100;
    }

    return score;
  }

  static String _normalize(String input) {
    var s = input.toLowerCase();
    const accents = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ö': 'o', 'ő': 'o',
      'ú': 'u', 'ü': 'u', 'ű': 'u',
    };
    accents.forEach((key, value) {
      s = s.replaceAll(key, value);
    });
    return s;
  }

  static String _cleanHost(String url) {
    var s = url.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'^https?:\/\/'), '');
    s = s.replaceAll(RegExp(r'/.*$'), '');
    return s;
  }

  static Future<void> _saveScheduleToCache() async {
    try {
      if (_activeSchedule.isNotEmpty) {
        await storage.saveString(CACHE_KEY, conv.jsonEncode(_activeSchedule.map((e) => e.toJson()).toList()));
      }
      if (currentToUrl.isNotEmpty) {
        await storage.saveString(URL_CACHE_KEY, currentToUrl);
      }
      if (currentFacultyName.isNotEmpty) {
        await storage.saveString(FACULTY_CACHE_KEY, currentFacultyName);
      }
    } catch (e) {
      debugPrint('[ToOfficeService] Hiba a cache mentésekor: $e');
    }
  }

  /// Adott napra érvényes TO idősávok lekérése (1 = Hétfő, ..., 7 = Vasárnap)
  static List<ToOfficeSlot> getSlotsForDay(int weekday) {
    return _activeSchedule.where((s) => s.weekday == weekday).toList();
  }

  /// Éppen most nyitva van-e a Tanulmányi Iroda
  static bool isCurrentlyOpen() {
    final now = DateTime.now();
    final todaySlots = getSlotsForDay(now.weekday);
    final nowMinutes = now.hour * 60 + now.minute;
    for (var slot in todaySlots) {
      final startMin = slot.startHour * 60 + slot.startMinute;
      final endMin = slot.endHour * 60 + slot.endMinute;
      if (nowMinutes >= startMin && nowMinutes <= endMin) {
        return true;
      }
    }
    return false;
  }

  /// Adott TO idősáv jelenleg éppen nyitva van-e
  static bool isSlotCurrentlyOpen(ToOfficeSlot slot) {
    final now = DateTime.now();
    if (now.weekday != slot.weekday) return false;
    final nowMinutes = now.hour * 60 + now.minute;
    final startMin = slot.startHour * 60 + slot.startMinute;
    final endMin = slot.endHour * 60 + slot.endMinute;
    return nowMinutes >= startMin && nowMinutes <= endMin;
  }

  /// Weboldal lekérdezése és a nyitvatartás dinamikus frissítése a weboldalról
  static Future<bool> fetchAndRefreshSchedule() async {
    try {
      if (currentToUrl.isEmpty) return false;
      final response = await http.get(Uri.parse(currentToUrl)).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return false;
      }

      final html = response.body;
      final List<ToOfficeSlot> parsedSlots = [];

      final dayMap = {
        'Hétfő': 1,
        'Kedd': 2,
        'Szerda': 3,
        'Csütörtök': 4,
        'Péntek': 5,
        'Szombat': 6,
        'Vasárnap': 7,
      };

      dayMap.forEach((dayName, weekdayNum) {
        final regExp = RegExp('$dayName:?\\s*<\\/b>\\s*<\\/div>\\s*<div[^>]*>([\\s\\S]*?)<\\/div>', caseSensitive: false);
        final match = regExp.firstMatch(html);
        if (match != null) {
          final content = match.group(1)?.trim() ?? '';
          if (!content.toUpperCase().contains('ZÁRVA') && !content.toUpperCase().contains('ZARVA')) {
            final timeRangeExp = RegExp(r'(\d{1,2})[\.:](\d{2})\s*-\s*(\d{1,2})[\.:](\d{2})');
            final timeMatches = timeRangeExp.allMatches(content);
            for (var tm in timeMatches) {
              final sh = int.tryParse(tm.group(1) ?? '') ?? 8;
              final sm = int.tryParse(tm.group(2) ?? '') ?? 0;
              final eh = int.tryParse(tm.group(3) ?? '') ?? 11;
              final em = int.tryParse(tm.group(4) ?? '') ?? 45;

              parsedSlots.add(ToOfficeSlot(
                weekday: weekdayNum,
                startHour: sh,
                startMinute: sm,
                endHour: eh,
                endMinute: em,
                location: '',
                note: timeMatches.length > 1 ? (sh < 12 ? 'I. sáv' : 'II. sáv') : '',
              ));
            }
          }
        }
      });

      if (parsedSlots.isNotEmpty) {
        _activeSchedule = parsedSlots;
        await _saveScheduleToCache();
        return true;
      }
    } catch (e) {
      debugPrint('[ToOfficeService] Nem sikerült a dinamikus frissítés weboldalról: $e');
    }
    return false;
  }

  /// Memória állapot alaphelyzetbe állítása (pl. kijelentkezéskor)
  static void reset() {
    currentToUrl = '';
    currentFacultyName = '';
    _activeSchedule = List.from(_defaultSchedule);
    _hasLoadedFromCache = false;
    _isResolving = false;
  }
}
