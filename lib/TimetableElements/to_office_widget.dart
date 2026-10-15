import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Misc/to_office_service.dart';
import '../colors.dart';
import '../haptics.dart';

class ToOfficeOverlayWidget extends StatelessWidget {
  final ToOfficeSlot slot;
  final bool isCurrent;

  const ToOfficeOverlayWidget({
    super.key,
    required this.slot,
    this.isCurrent = false,
  });

  static String extractRoomNumber(String loc) {
    if (loc.isEmpty) return '';
    final trimmed = loc.trim();
    if (trimmed.contains('FR.210') || trimmed.contains('FR')) return 'FR.210';
    if (trimmed.contains('J.52') || trimmed.contains('J.53') || trimmed.contains('J.')) return 'J.52';

    // Ha kar vagy intézmény megnevezés, nem teremszám:
    final lower = trimmed.toLowerCase();
    if (lower.contains('kar') ||
        lower.contains('faculty') ||
        lower.contains('egyetem') ||
        lower.contains('tanulmányi') ||
        lower.contains('főiskola') ||
        lower.contains('campus')) {
      return '';
    }

    if (ToOfficeService.currentFacultyName.isNotEmpty &&
        lower.contains(ToOfficeService.currentFacultyName.toLowerCase())) {
      return '';
    }

    // Ha tényleges teremszám formátum:
    if (trimmed.length <= 10 && RegExp(r'\d').hasMatch(trimmed)) {
      return trimmed;
    }

    return '';
  }

  static void showDetailsDialog(BuildContext context, ToOfficeSlot slot) {
    AppHaptics.lightImpact();
    showDialog(
      context: context,
      builder: (context) {
        final allSlots = ToOfficeService.getSlotsForDay(slot.weekday);
        final room = extractRoomNumber(slot.location);
        return AlertDialog(
          backgroundColor: AppColors.getTheme().rootBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TO',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tanulmányi Iroda',
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Félfogadási idők erre a napra:',
                      style: TextStyle(
                        color: AppColors.getTheme().textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var s in allSlots) ...[
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            s.timeFormatted,
                            style: TextStyle(
                              color: AppColors.getTheme().textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (s.note.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${s.note})',
                              style: TextStyle(
                                color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              if (room.isNotEmpty || slot.location.contains('J.') || slot.location.contains('FR')) ...[
                const SizedBox(height: 14),
                Text(
                  '📍 Helyszínek / Terem:',
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  room.isNotEmpty ? '• $room' : '• József körút 6. J.52-53\n• Frangepán utca 50. FR.210',
                  style: TextStyle(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (ToOfficeService.currentToUrl.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: const Text('Weboldal'),
                onPressed: () async {
                  AppHaptics.lightImpact();
                  final uri = Uri.parse(ToOfficeService.currentToUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Bezárás',
                style: TextStyle(
                  color: AppColors.getTheme().primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentlyOpen = isCurrent || ToOfficeService.isSlotCurrentlyOpen(slot);
    final room = extractRoomNumber(slot.location);
    final isSecondSlot = slot.note.contains('II') || slot.startHour >= 13;
    final sh = slot.startHour.toString().padLeft(2, '0');
    final sm = slot.startMinute.toString().padLeft(2, '0');
    final eh = slot.endHour.toString().padLeft(2, '0');
    final em = slot.endMinute.toString().padLeft(2, '0');

    return GestureDetector(
      onTap: () => showDetailsDialog(context, slot),
      child: Container(
        width: 82,
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.isDarktheme()
              ? const Color(0xFF23160C)
              : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orange.withValues(alpha: currentlyOpen ? 0.9 : 0.6),
            width: currentlyOpen ? 1.4 : 1.0,
          ),
          boxShadow: currentlyOpen
              ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentlyOpen)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  isSecondSlot ? 'TO II.' : 'TO',
                  style: TextStyle(
                    color: AppColors.isDarktheme() ? Colors.orange.shade300 : Colors.orange.shade900,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              currentlyOpen ? 'Nyitva' : (isSecondSlot ? '$sh:$sm' : '$eh:$em-ig'),
              style: TextStyle(
                color: AppColors.isDarktheme() ? Colors.white : const Color(0xFF333333),
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isSecondSlot ? '-$eh:$em' : '$sh:$sm-$eh:$em',
              style: TextStyle(
                color: AppColors.isDarktheme() ? Colors.orange.shade200 : Colors.orange.shade800,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 9.0,
              ),
            ),
            if (room.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  room,
                  style: TextStyle(
                    color: AppColors.isDarktheme() ? Colors.orange.shade300 : Colors.orange.shade900,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ToOfficeStandaloneBanner extends StatelessWidget {
  final ToOfficeSlot slot;
  final bool isCurrent;

  const ToOfficeStandaloneBanner({
    super.key,
    required this.slot,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.isDarktheme()
            ? const Color(0xFFE65100).withValues(alpha: 0.18)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: isCurrent ? 0.8 : 0.4),
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'TO',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Tanulmányi Iroda Félfogadás',
                      style: TextStyle(
                        color: AppColors.getTheme().textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (slot.note.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${slot.note})',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
                Builder(
                  builder: (context) {
                    final room = ToOfficeOverlayWidget.extractRoomNumber(slot.location);
                    final sub = room.isNotEmpty ? '${slot.timeFormatted} • $room' : slot.timeFormatted;
                    return Text(
                      sub,
                      style: TextStyle(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green),
              ),
              child: const Text(
                'MOST',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }
}
