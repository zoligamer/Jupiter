import 'dart:convert' as conv;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage.dart' as storage;

class ToOfficeSlot {
  final int weekday; // 1 = Monday, ..., 7 = Sunday
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
    this.location = 'J.52-53 / FR.210',
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
    weekday: json['weekday'] ?? 1,
    startHour: json['startHour'] ?? 8,
    startMinute: json['startMinute'] ?? 45,
    endHour: json['endHour'] ?? 11,
    endMinute: json['endMinute'] ?? 45,
    location: json['location'] ?? 'J.52-53 / FR.210',
    note: json['note'] ?? '',
  );
}

class ToOfficeService {
  static const String TO_URL = 'https://bgk.uni-obuda.hu/tanulmanyi-iroda/';
  static const String CACHE_KEY = 'CACHED_TO_OFFICE_SCHEDULE';

  // Alapértelmezett beépített nyitvatartás (a weboldal aktuális táblázata alapján)
  static final List<ToOfficeSlot> _defaultSchedule = [
    // Hétfő
    const ToOfficeSlot(weekday: 1, startHour: 8, startMinute: 45, endHour: 11, endMinute: 45, location: 'J.52-53 / FR.210'),
    // Kedd: ZÁRVA
    // Szerda délelőtt
    const ToOfficeSlot(weekday: 3, startHour: 8, startMinute: 45, endHour: 11, endMinute: 45, location: 'J.52-53 / FR.210', note: 'I. idősáv'),
    // Szerda délután (ebédszünet után)
    const ToOfficeSlot(weekday: 3, startHour: 13, startMinute: 15, endHour: 14, endMinute: 30, location: 'J.52-53 / FR.210', note: 'II. idősáv'),
    // Csütörtök: ZÁRVA
    // Péntek
    const ToOfficeSlot(weekday: 5, startHour: 8, startMinute: 45, endHour: 11, endMinute: 45, location: 'J.52-53 / FR.210'),
  ];

  static List<ToOfficeSlot> _activeSchedule = List.from(_defaultSchedule);
  static bool _hasLoadedFromCache = false;

  /// Inicializálás a cache-ből vagy alapértelmezettből
  static Future<void> initialize() async {
    if (_hasLoadedFromCache) return;
    try {
      final cached = await storage.getString(CACHE_KEY);
      if (cached != null && cached.isNotEmpty) {
        final decoded = conv.jsonDecode(cached) as List<dynamic>;
        _activeSchedule = decoded.map((e) => ToOfficeSlot.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Hiba a mentett TO menetrend betöltésekor: $e');
    }
    _hasLoadedFromCache = true;
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

  /// Weboldal lekérdezése és a nyitvatartás dinamikus frissítése
  static Future<bool> fetchAndRefreshSchedule() async {
    try {
      final response = await http.get(Uri.parse(TO_URL)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return false;
      }

      final html = response.body;
      final List<ToOfficeSlot> parsedSlots = [];

      // Napok keresése reguláris kifejezéssel a weboldal táblázatából
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
        // Keressük a pl: <b>Hétfő: </b></div>\s*<div class="col-md-8">\s*8.45-11.45
        final regExp = RegExp('$dayName:?\\s*<\\/b>\\s*<\\/div>\\s*<div[^>]*>([\\s\\S]*?)<\\/div>', caseSensitive: false);
        final match = regExp.firstMatch(html);
        if (match != null) {
          final content = match.group(1)?.trim() ?? '';
          if (!content.toUpperCase().contains('ZÁRVA') && !content.toUpperCase().contains('ZARVA')) {
            // Idősávok keresése: pl. "8.45-11.45" vagy "8.45-11.45 és 13.15-14.30"
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
                location: 'J.52-53 / FR.210',
                note: timeMatches.length > 1 ? (sh < 12 ? 'I. sáv' : 'II. sáv') : '',
              ));
            }
          }
        }
      });

      if (parsedSlots.isNotEmpty) {
        _activeSchedule = parsedSlots;
        await storage.saveString(CACHE_KEY, conv.jsonEncode(parsedSlots.map((e) => e.toJson()).toList()));
        return true;
      }
    } catch (e) {
      debugPrint('Nem sikerült frissíteni a TO menetrendet az internetről: $e');
    }
    return false;
  }
}
