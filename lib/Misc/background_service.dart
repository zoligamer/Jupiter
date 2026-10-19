import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../storage.dart' as storage;
import '../API/api_coms.dart' as api;
import '../notifications.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == BackgroundService.messageCheckTaskName ||
          taskName == 'iOSBackgroundTask' ||
          taskName == Workmanager.iOSBackgroundTask) {
        await BackgroundService.performBackgroundMessageCheck();
      }
    } catch (_) {}
    return Future.value(true);
  });
}

class BackgroundService {
  static const String messageCheckTaskName = 'jupiter_periodic_message_check';
  static const String uniqueWorkName = 'jupiter_message_checker_unique';

  static Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );
    } catch (_) {}
  }

  static Future<void> registerPeriodicCheck({int? intervalMinutes, bool? wifiOnly}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final interval = intervalMinutes ?? (await storage.getInt('SETTING_BackgroundSyncInterval')) ?? 15;
    final isWifi = wifiOnly ?? ((await storage.getInt('SETTING_BackgroundSyncWifiOnly')) == 1);
    try {
      await Workmanager().registerPeriodicTask(
        uniqueWorkName,
        messageCheckTaskName,
        frequency: Duration(minutes: interval < 15 ? 15 : interval),
        constraints: Constraints(
          networkType: isWifi ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } catch (_) {}
  }

  static Future<void> cancelPeriodicCheck() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await Workmanager().cancelByUniqueName(uniqueWorkName);
    } catch (_) {}
  }

  static Future<void> performBackgroundMessageCheck() async {
    WidgetsFlutterBinding.ensureInitialized();
    await storage.DataCache.loadData();

    final hasLogin = storage.DataCache.getHasLogin() ?? false;
    final needNotifications = storage.DataCache.getNeedMessageNotifications() ?? true;

    if (!hasLogin || !needNotifications) {
      return;
    }

    try {
      final request = await api.MailRequest.getMails(1);
      if (request == null || request.isEmpty) return;

      final lastKnownTopId = await storage.getString('LastKnownTopMailId');
      if (lastKnownTopId != null && lastKnownTopId.isNotEmpty) {
        final newUnreadMails = <api.MailEntry>[];
        for (final mail in request) {
          if (mail.ID == lastKnownTopId) break;
          if (!mail.isRead) {
            newUnreadMails.add(mail);
          }
        }

        if (newUnreadMails.isNotEmpty) {
          await AppNotifications.initialize();
          if (newUnreadMails.length == 1) {
            final m = newUnreadMails.first;
            await AppNotifications.showNotification(
              "Új Neptun üzenet",
              "${m.senderName}: ${m.subject}",
            );
          } else {
            final m = newUnreadMails.first;
            await AppNotifications.showNotification(
              "Új Neptun üzenetek (${newUnreadMails.length})",
              "${m.senderName}: ${m.subject} és még ${newUnreadMails.length - 1} új üzenet",
            );
          }
        }
      }

      if (request.isNotEmpty) {
        await storage.saveString('LastKnownTopMailId', request.first.ID);
      }
    } catch (_) {}
  }
}
