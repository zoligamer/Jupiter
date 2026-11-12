import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../API/api_coms.dart' as api;
import '../storage.dart' as storage;

class WidgetDataService {
  static bool _hasInitDeepLink = false;

  /// Beállítja a widget-kattintás figyelőt, és átnavigál a megfelelő fülre
  static void initDeepLinking(void Function(String tab) onNavigate) {
    if (_hasInitDeepLink) return;
    _hasInitDeepLink = true;

    // Ha a widget indította az appot háttérből/leállított állapotból
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        _handleUri(uri, onNavigate);
      }
    }).catchError((e) {
      debugPrint("Widget initiallyLaunched hiba: $e");
    });

    // Ha az app már fut a háttérben és a widgetre kattintanak
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleUri(uri, onNavigate);
      }
    }).onError((e) {
      debugPrint("Widget clicked hiba: $e");
    });
  }

  static void _handleUri(Uri uri, void Function(String tab) onNavigate) {
    final tab = uri.queryParameters['tab'];
    if (tab != null && tab.isNotEmpty) {
      onNavigate(tab);
    }
  }

  /// Frissíti az összes kezdőképernyő widget adatait a helyi cache-ből
  static Future<void> updateAllWidgets({
    List<api.CalendarEntry>? calendarEntries,
    List<api.PeriodEntry>? periods,
    List<api.Subject>? markbook,
  }) async {
    try {
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // Ha nincs megadva naptár, próbáljuk betölteni a helyi tárolóból
      if (calendarEntries == null || calendarEntries.isEmpty) {
        final len = await storage.getInt('PermanentCalendar_w1_len') ??
            await storage.getInt('CachedCalendarLength');
        if (len != null && len > 0) {
          final list = <api.CalendarEntry>[];
          for (int i = 0; i < len; i++) {
            final raw = await storage.getString('PermanentCalendar_w1_$i') ??
                await storage.getString('CachedCalendar_$i');
            if (raw != null) {
              list.add(api.CalendarEntry('0', '0', 'NULL', 'NULL', false).fillWithExisting(raw));
            }
          }
          if (list.isNotEmpty) {
            calendarEntries = list;
          }
        }
      }

      // Ha nincs megadva időszak, próbáljuk betölteni a helyi tárolóból
      if (periods == null || periods.isEmpty) {
        final len = await storage.getInt('CachedPeriodsLength');
        if (len != null && len > 0) {
          final list = <api.PeriodEntry>[];
          for (int i = 0; i < len; i++) {
            final raw = await storage.getString('CachedPeriods_$i');
            if (raw != null) {
              list.add(api.PeriodEntry('NULL', 0, 0, 0).fillWithExisting(raw));
            }
          }
          if (list.isNotEmpty) {
            periods = list;
          }
        }
      }

      // Ha nincs megadva leckekönyv, próbáljuk betölteni a helyi tárolóból
      if (markbook == null || markbook.isEmpty) {
        final len = await storage.getInt('CachedMarkbookLength');
        if (len != null && len > 0) {
          final list = <api.Subject>[];
          for (int i = 0; i < len; i++) {
            final raw = await storage.getString('CachedMarkbook_$i');
            if (raw != null) {
              list.add(api.Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(raw));
            }
          }
          if (list.isNotEmpty) {
            markbook = list;
          }
        }
      }

      // 1. KÖVETKEZŐ ÓRA SZÁMÍTÁSA
      String classTitle = "Nincs több órád mára! 🎉";
      String classRoom = "";
      String classTime = "--:-- - --:--";
      String classCountdown = "Órarend";

      if (calendarEntries != null && calendarEntries.isNotEmpty) {
        // Keressük meg a mai nap óráit
        final todayEntries = calendarEntries.where((e) {
          final start = DateTime.fromMillisecondsSinceEpoch(e.startEpoch);
          return start.year == now.year && start.month == now.month && start.day == now.day;
        }).toList();

        todayEntries.sort((a, b) => a.startEpoch.compareTo(b.startEpoch));

        api.CalendarEntry? activeClass;
        api.CalendarEntry? nextClass;

        for (var e in todayEntries) {
          if (nowMs >= e.startEpoch && nowMs < e.endEpoch) {
            activeClass = e;
            break;
          } else if (e.startEpoch > nowMs) {
            nextClass = e;
            break;
          }
        }

        final target = activeClass ?? nextClass;
        if (target != null) {
          classTitle = target.title;
          final rawRoom = target.location.isNotEmpty ? target.location : "Nincs terem";
          classRoom = rawRoom.startsWith("📍") ? rawRoom : "📍 $rawRoom";
          final sTime = DateTime.fromMillisecondsSinceEpoch(target.startEpoch);
          final eTime = DateTime.fromMillisecondsSinceEpoch(target.endEpoch);
          classTime = "${sTime.hour.toString().padLeft(2, '0')}:${sTime.minute.toString().padLeft(2, '0')} - ${eTime.hour.toString().padLeft(2, '0')}:${eTime.minute.toString().padLeft(2, '0')}";

          if (activeClass != null) {
            final leftMin = ((activeClass.endEpoch - nowMs) / 60000).ceil();
            classCountdown = "Most zajlik ($leftMin p)";
          } else {
            final untilMin = ((target.startEpoch - nowMs) / 60000).ceil();
            if (untilMin < 60) {
              classCountdown = "$untilMin p múlva";
            } else {
              final hours = untilMin ~/ 60;
              final mins = untilMin % 60;
              classCountdown = "$hours óra $mins p";
            }
          }
        }
      }

      await HomeWidget.saveWidgetData<String>('class_title', classTitle);
      await HomeWidget.saveWidgetData<String>('class_room', classRoom);
      await HomeWidget.saveWidgetData<String>('class_time', classTime);
      await HomeWidget.saveWidgetData<String>('class_countdown', classCountdown);

      // 2. PÉNZÜGYEK & GYŰJTŐSZÁMLA
      final balance = storage.DataCache.getAccountBalance();
      final currency = storage.DataCache.getAccountBalanceCurrency();
      final rawAccount = storage.DataCache.getAccountCollectiveBankAccount();

      final formattedBalance = balance != null
          ? "${balance.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} $currency"
          : "0 $currency";

      String formattedAccount = "Számlaszám másolása";
      if (rawAccount != null && rawAccount.isNotEmpty) {
        final digits = rawAccount.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length == 24) {
          formattedAccount = "${digits.substring(0, 8)}-${digits.substring(8, 16)}-${digits.substring(16, 24)}";
        } else if (digits.length == 16) {
          formattedAccount = "${digits.substring(0, 8)}-${digits.substring(8, 16)}";
        } else {
          formattedAccount = rawAccount;
        }
      }

      await HomeWidget.saveWidgetData<String>('finances_balance', formattedBalance);
      await HomeWidget.saveWidgetData<String>('finances_account', formattedAccount);

      // 3. ÜZENETEK
      final unreadCount = storage.DataCache.getUnreadMailCount();
      final previewText = unreadCount > 0
          ? "$unreadCount új olvasatlan Neptun üzenet"
          : "Nincs új olvasatlan üzenet! ✅";
      final senderText = unreadCount > 0 ? "Koppints az olvasáshoz" : "Üzenetközpont";
      final countBadge = unreadCount > 0 ? "$unreadCount új ✉️" : "0 új ✅";

      await HomeWidget.saveWidgetData<int>('messages_count', unreadCount);
      await HomeWidget.saveWidgetData<String>('messages_count_badge', countBadge);
      await HomeWidget.saveWidgetData<String>('messages_preview', previewText);
      await HomeWidget.saveWidgetData<String>('messages_sender', senderText);

      // 4. KREDITEK & TANULMÁNYOK
      int earnedCredits = 0;
      int completedSubjects = 0;
      double creditWeightedGradeSum = 0;

      if (markbook != null && markbook.isNotEmpty) {
        for (var s in markbook) {
          final credit = s.credit;
          final grade = s.grade;
          if (grade >= 2) {
            earnedCredits += credit;
            creditWeightedGradeSum += (grade * credit);
            completedSubjects++;
          }
        }
      }

      final avg = completedSubjects > 0 && earnedCredits > 0
          ? (creditWeightedGradeSum / earnedCredits).toStringAsFixed(2)
          : "--";

      await HomeWidget.saveWidgetData<int>('credits_earned', earnedCredits);
      await HomeWidget.saveWidgetData<int>('credits_total', 0);
      await HomeWidget.saveWidgetData<String>('credits_main', "$earnedCredits kredit");
      await HomeWidget.saveWidgetData<String>('credits_percent', "$earnedCredits felvéve");
      await HomeWidget.saveWidgetData<String>('credits_average', avg != "--" ? "Átlag: $avg" : "Átlag: --");
      await HomeWidget.saveWidgetData<String>('credits_scholarship', avg != "--" ? "Ösztöndíj: $avg" : "Ösztöndíj: --");

      // 5. IDŐSZAKOK (Csak aktív és jövőbeli időszakok, lezártak elrejtve)
      String periodTitle = "Nincs aktív időszak";
      String periodRemaining = "Időszakok megtekintése";
      String periodBadge = "Infó";

      if (periods != null && periods.isNotEmpty) {
        // Kiszűrjük a múltbeli lezárt időszakokat
        final relevantPeriods = periods.where((p) => p.endEpoch > nowMs).toList();
        relevantPeriods.sort((a, b) => a.startEpoch.compareTo(b.startEpoch));

        api.PeriodEntry? activePeriod;
        api.PeriodEntry? upcomingPeriod;

        for (var p in relevantPeriods) {
          if (nowMs >= p.startEpoch && nowMs <= p.endEpoch) {
            activePeriod = p;
            break;
          } else if (p.startEpoch > nowMs) {
            upcomingPeriod = p;
            break;
          }
        }

        if (activePeriod != null) {
          periodTitle = activePeriod.name;
          final daysLeft = ((activePeriod.endEpoch - nowMs) / (1000 * 60 * 60 * 24)).ceil();
          periodRemaining = daysLeft > 0 ? "Még $daysLeft nap van hátra" : "Ma jár le!";
          periodBadge = "Aktív ⚡";
        } else if (upcomingPeriod != null) {
          periodTitle = upcomingPeriod.name;
          final daysUntil = ((upcomingPeriod.startEpoch - nowMs) / (1000 * 60 * 60 * 24)).ceil();
          periodRemaining = "Indul $daysUntil nap múlva";
          periodBadge = "Hamarosan";
        }
      }

      await HomeWidget.saveWidgetData<String>('period_title', periodTitle);
      await HomeWidget.saveWidgetData<String>('period_remaining', periodRemaining);
      await HomeWidget.saveWidgetData<String>('period_badge', periodBadge);

      // 6. TEENDŐK & KÉRDŐÍVEK
      final cachedTaskCount = await storage.getInt('CachedTasksCount') ?? 0;
      final cachedTaskTitle = await storage.getString('CachedTasksTopTitle') ??
          (cachedTaskCount > 0 ? "$cachedTaskCount kitöltendő kérdőív" : "Minden teendő elvégezve! ✅");
      final cachedTaskDeadline = await storage.getString('CachedTasksTopDeadline') ?? "Kérdőívek és feladatok";
      final cachedTaskBadge = cachedTaskCount > 0 ? "$cachedTaskCount teendő" : "0 teendő";

      await HomeWidget.saveWidgetData<int>('tasks_count', cachedTaskCount);
      await HomeWidget.saveWidgetData<String>('tasks_count_badge', cachedTaskBadge);
      await HomeWidget.saveWidgetData<String>('tasks_title', cachedTaskTitle);
      await HomeWidget.saveWidgetData<String>('tasks_deadline', cachedTaskDeadline);

      // 7. WIDGETEK FRISSÍTÉSÉNEK KIKÜLDÉSE AZ ANDROID RENDSZERNEK
      final providers = [
        'NextClassWidgetProvider',
        'FinancesWidgetProvider',
        'MessagesWidgetProvider',
        'CreditsWidgetProvider',
        'PeriodsWidgetProvider',
        'TasksWidgetProvider',
        'MasterHubWidgetProvider',
      ];

      for (var provider in providers) {
        await HomeWidget.updateWidget(
          name: provider,
          androidName: provider,
        );
      }
    } catch (e) {
      debugPrint("WidgetDataService frissítési hiba: $e");
    }
  }

  /// Kijelentkezéskor törli az összes kezdőképernyő widget adatot és frissíti őket üres állapotra
  static Future<void> clearAllWidgets() async {
    try {
      await HomeWidget.saveWidgetData<String>('class_title', 'Jelentkezz be!');
      await HomeWidget.saveWidgetData<String>('class_room', '');
      await HomeWidget.saveWidgetData<String>('class_time', '--:-- - --:--');
      await HomeWidget.saveWidgetData<String>('class_countdown', 'Órarend');

      await HomeWidget.saveWidgetData<String>('finances_balance', '-- Ft');
      await HomeWidget.saveWidgetData<String>('finances_account', 'Nincs fiók');

      await HomeWidget.saveWidgetData<int>('messages_count', 0);
      await HomeWidget.saveWidgetData<String>('messages_count_badge', '0 új');
      await HomeWidget.saveWidgetData<String>('messages_preview', 'Nincs bejelentkezve');
      await HomeWidget.saveWidgetData<String>('messages_sender', 'Üzenetközpont');

      await HomeWidget.saveWidgetData<int>('credits_earned', 0);
      await HomeWidget.saveWidgetData<int>('credits_total', 0);
      await HomeWidget.saveWidgetData<String>('credits_main', '0 kredit');
      await HomeWidget.saveWidgetData<String>('credits_percent', '0 felvéve');
      await HomeWidget.saveWidgetData<String>('credits_average', 'Átlag: --');
      await HomeWidget.saveWidgetData<String>('credits_scholarship', 'Ösztöndíj: --');

      await HomeWidget.saveWidgetData<String>('period_title', 'Nincs aktív időszak');
      await HomeWidget.saveWidgetData<String>('period_remaining', 'Időszakok');
      await HomeWidget.saveWidgetData<String>('period_badge', 'Infó');

      await HomeWidget.saveWidgetData<int>('tasks_count', 0);
      await HomeWidget.saveWidgetData<String>('tasks_count_badge', '0 teendő');
      await HomeWidget.saveWidgetData<String>('tasks_title', 'Nincs aktív feladat');
      await HomeWidget.saveWidgetData<String>('tasks_deadline', 'Teendők');

      final providers = [
        'NextClassWidgetProvider',
        'FinancesWidgetProvider',
        'MessagesWidgetProvider',
        'CreditsWidgetProvider',
        'PeriodsWidgetProvider',
        'TasksWidgetProvider',
        'MasterHubWidgetProvider',
      ];

      for (var provider in providers) {
        await HomeWidget.updateWidget(
          name: provider,
          androidName: provider,
        );
      }
    } catch (e) {
      debugPrint("WidgetDataService ürítési hiba: $e");
    }
  }
}
