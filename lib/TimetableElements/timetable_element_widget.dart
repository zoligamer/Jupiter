import '../storage.dart' as storage;
import 'package:flutter/material.dart';
import 'package:jupiter/language.dart';
import '../API/api_coms.dart' as api;
import '../Misc/emojirich_text.dart';
import '../Misc/popup.dart';
import '../Pages/main_page.dart';
import '../colors.dart';
import '../haptics.dart';
import '../Misc/to_office_service.dart';
import 'to_office_widget.dart';

typedef Callback = Future<void> Function();

class TimetableCurrentlySelected{
  static api.CalendarEntry? entry;
}

class TimetableElementWidget extends StatelessWidget {

  late final String title;
  late final String location;
  late final String displayStartTime;
  late final String displayEndTime;
  late final bool isExam;
  final bool isCurrent;

  late final DateTime endDateNormalized;

  late final bool currentOverride;

  late final bool isTask;
  final bool fullWidthMargin;

  TimetableElementWidget(
      {super.key, required this.entry, required this.position, required this.isCurrent, this.fullWidthMargin = true}) {
    isExam = entry.isExam;
    isTask = entry.isTask;
    title = entry.title;
    location = entry.location;

    // start date
    var startDate = DateTime.fromMillisecondsSinceEpoch(entry.startEpoch);
    var startHour = startDate.hour.toString().padLeft(2, '0');
    var startMinute = startDate.minute.toString().padLeft(2, '0');
    displayStartTime = "$startHour:$startMinute";

    // actual end date calc, not mathing
    var endDate = DateTime.fromMillisecondsSinceEpoch(entry.endEpoch);
    var endHour = endDate.hour.toString().padLeft(2, '0');
    var endMinute = endDate.minute.toString().padLeft(2, '0');
    displayEndTime = "$endHour:$endMinute";

    // --- 3. actual enddate
    endDateNormalized = endDate;

    // --- 4. active status ---
    if (endDateNormalized.millisecondsSinceEpoch < DateTime.now().millisecondsSinceEpoch) {
      currentOverride = false;
    } else {
      currentOverride = isCurrent;
    }
  }

  final api.CalendarEntry entry;
  final int position;

  @override
  Widget build(BuildContext context) {
    double fontScale = storage.DataCache.getFontScale();
    final theme = AppColors.getTheme();
    final isPast = endDateNormalized.millisecondsSinceEpoch < DateTime.now().millisecondsSinceEpoch;

    // Card highlight styling
    final Color cardBg;
    final Color cardBorder;
    final double borderWidth;

    if (isExam) {
      cardBg = theme.errorRed.withValues(alpha: 0.10);
      cardBorder = theme.errorRed.withValues(alpha: 0.45);
      borderWidth = 1.0;
    } else if (isTask) {
      cardBg = Colors.amber.shade600.withValues(alpha: 0.10);
      cardBorder = Colors.amber.shade600.withValues(alpha: 0.45);
      borderWidth = 1.0;
    } else if (currentOverride) {
      cardBg = const Color(0xFF00F0FF).withValues(alpha: 0.08);
      cardBorder = const Color(0xFF00F0FF);
      borderWidth = 2.0;
    } else {
      cardBg = AppColors.isDarktheme()
          ? theme.secondary.withValues(alpha: 0.35)
          : theme.secondary.withValues(alpha: 0.10);
      cardBorder = AppColors.isDarktheme()
          ? theme.secondary.withValues(alpha: 0.60)
          : theme.secondary.withValues(alpha: 0.25);
      borderWidth = 1.0;
    }

    final Color cardTimeColor;
    if (isExam) {
      cardTimeColor = theme.errorRed;
    } else if (isTask) {
      cardTimeColor = Colors.amber.shade600;
    } else if (currentOverride) {
      cardTimeColor = const Color(0xFF00F0FF);
    } else {
      cardTimeColor = const Color(0xFFFF2A85);
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: fullWidthMargin ? 14 : 0,
        vertical: 4,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- LEFT TIMELINE TRACK (Width: 46px) ---
            SizedBox(
              width: 46,
              child: Column(
                children: [
                  Text(
                    displayStartTime,
                    style: TextStyle(
                      color: currentOverride
                          ? const Color(0xFF00F0FF)
                          : (isPast
                              ? theme.textColor.withValues(alpha: 0.35)
                              : theme.textColor.withValues(alpha: 0.70)),
                      fontWeight: currentOverride ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11.5 * fontScale,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (currentOverride) ...[
                        Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00F0FF),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F0FF).withValues(alpha: 0.65),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.rootBackground,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_right_rounded,
                          size: 16,
                          color: const Color(0xFF00F0FF),
                        ),
                      ] else if (isPast) ...[
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.textColor.withValues(alpha: 0.22),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.check,
                              size: 9,
                              color: theme.rootBackground,
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.rootBackground,
                            border: Border.all(
                              color: theme.primary.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // --- RIGHT LESSON CARD ---
            Expanded(
              child: GestureDetector(
                onTap: () => _handleTap(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: cardBorder,
                      width: borderWidth,
                    ),
                    boxShadow: currentOverride
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.30),
                              blurRadius: 16,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. SOR: Idősáv a bal oldalon, Terem kártya a jobb oldalon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "$displayStartTime - $displayEndTime",
                            style: TextStyle(
                              color: cardTimeColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.0 * fontScale,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (location.trim().isNotEmpty && location != "NULL" && location != "Nincs megadva")
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isExam
                                    ? theme.errorRed
                                    : theme.roomHighlightColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                location,
                                style: TextStyle(
                                  color: isExam
                                      ? Colors.white
                                      : theme.onRoomHighlightColor,
                                  fontSize: 11.5 * fontScale,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 2. SOR: Tárgynév kiemelve nagy fehér betűkkel
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5 * fontScale,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),

                      // 3. SOR: Típus • Oktató + visszaszámláló aktív óránál
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _buildSubtitle(),
                              style: TextStyle(
                                color: isExam
                                    ? theme.errorRed.withValues(alpha: 0.8)
                                    : theme.textColor.withValues(alpha: 0.65),
                                fontSize: 11.5 * fontScale,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (currentOverride) ...[
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timelapse_rounded,
                                  color: const Color(0xFF00F0FF),
                                  size: 14 * fontScale,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${(Duration(milliseconds: endDateNormalized.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch)).inHours.remainder(60).toString().padLeft(2, '0')}:${((Duration(milliseconds: endDateNormalized.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch)).inMinutes.remainder(60)).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: const Color(0xFF00F0FF),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.0 * fontScale,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (isExam) {
      TimetableCurrentlySelected.entry = entry;
      PopupWidgetHandler(mode: 5, callback: (_) {});
      PopupWidgetHandler.doPopup(context);
      return;
    }
    if (isTask && entry.taskId != null && entry.taskId!.isNotEmpty) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.getTheme().rootBackground,
              title: Text(title, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
              content: FutureBuilder<String?>(
                future: storage.getString('task_type_${entry.taskId}'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                  }

                  return FutureBuilder<String?>(
                      future: storage.getString('task_res_${entry.taskId}'),
                      builder: (context, resSnapshot) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📚 Tárgy: ${entry.location}", style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 16)),
                            const SizedBox(height: 10),
                            Text("📝 Típus: ${snapshot.data ?? 'Ismeretlen'}", style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 16)),
                            const SizedBox(height: 10),
                            Text("🎯 Eredmény: ${resSnapshot.data ?? 'Nincs még kiírva'}", style: TextStyle(color: AppColors.getTheme().currentClassGreen, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        );
                      }
                  );
                },
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Bezárás", style: TextStyle(color: AppColors.getTheme().textColor))
                )
              ],
            );
          }
      );
      return;
    }
    // HA VAN CLASSINSTANCE ID (Modern API), Akkor a mi új ablakunk jön be!
    if (entry.classInstanceId != null && entry.classInstanceId!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.getTheme().rootBackground,
            title: Text(title, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
            content: FutureBuilder<Map<String, String>>(
              future: api.CalendarRequest.getCourseDetails(entry.classInstanceId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator())
                  );
                }
                final data = snapshot.data ?? {};
                final room = (data['room'] != null && data['room']!.isNotEmpty && data['room'] != 'Nincs terem') ? data['room']! : entry.location;
                final teacher = (data['teacher'] != null && data['teacher']!.isNotEmpty && data['teacher'] != 'Nincs tanár') ? data['teacher']! : entry.teacher;
                final courseType = (data['type'] != null && data['type']!.isNotEmpty) ? data['type']! : (entry.courseType ?? '');
                final subjectCode = (data['code'] != null && data['code']!.isNotEmpty && data['code'] != '-') ? data['code']! : entry.subjectCode;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subjectCode.isNotEmpty && subjectCode != '-') ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("🏷️ Tárgykód: ", style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                          Expanded(child: SelectableText(subjectCode, style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 15))),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (courseType.isNotEmpty && courseType != '-') ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("📖 Típus: ", style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                          Expanded(child: SelectableText(courseType, style: TextStyle(color: AppColors.getTheme().currentClassGreen, fontWeight: FontWeight.bold, fontSize: 15))),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("👨‍🏫 Tanár: ", style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                        Expanded(child: SelectableText(teacher, style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 15))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📍 Terem: ", style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                        Expanded(child: SelectableText(room, style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 15))),
                      ],
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Bezárás", style: TextStyle(color: AppColors.getTheme().textColor))
              )
            ],
          );
        }
      );
      return;
    } else {
      TimetableCurrentlySelected.entry = entry;
      PopupWidgetHandler(mode: 4, callback: (_) {});
      PopupWidgetHandler.doPopup(context);
    }
  }

  String _buildSubtitle() {
    if (isExam) return 'Vizsga';
    if (isTask) return 'Feladat';
    final parts = <String>[];
    if (entry.courseType != null && entry.courseType!.trim().isNotEmpty && entry.courseType != '-') {
      parts.add(entry.courseType!.trim());
    }
    if (entry.teacher.trim().isNotEmpty && entry.teacher != 'Nincs megadva' && entry.teacher != 'Nincs tanár') {
      parts.add(entry.teacher.trim());
    }
    if (parts.isEmpty) {
      if (entry.subjectCode.trim().isNotEmpty && entry.subjectCode != '-') {
        return entry.subjectCode.trim();
      }
      return 'Óra';
    }
    return parts.join(' • ');
  }
}

class BreakElementWidget extends StatelessWidget {
  final int startEpoch;
  final int endEpoch;
  final bool isCurrent;
  final String nextClassTitle;
  final ToOfficeSlot? toOfficeSlot;

  const BreakElementWidget({
    super.key,
    required this.startEpoch,
    required this.endEpoch,
    required this.isCurrent,
    this.nextClassTitle = '',
    this.toOfficeSlot,
  });

  String _formatDuration(int ms) {
    final dur = Duration(milliseconds: ms);
    if (dur.inMinutes < 60) {
      return "${dur.inMinutes} perc";
    }
    final hours = dur.inHours;
    final mins = dur.inMinutes.remainder(60);
    return mins > 0 ? "$hours óra $mins perc" : "$hours óra";
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = storage.DataCache.getFontScale();
    final theme = AppColors.getTheme();
    final startDate = DateTime.fromMillisecondsSinceEpoch(startEpoch);
    final endDate = DateTime.fromMillisecondsSinceEpoch(endEpoch);
    final startHour = startDate.hour.toString().padLeft(2, '0');
    final startMin = startDate.minute.toString().padLeft(2, '0');
    final endHour = endDate.hour.toString().padLeft(2, '0');
    final endMin = endDate.minute.toString().padLeft(2, '0');
    final timeRange = "$startHour:$startMin - $endHour:$endMin";
    final breakDurationText = _formatDuration(endEpoch - startEpoch);

    final spineColor = theme.primary.withValues(alpha: 0.18);

    // Timeline column for break: 46px wide, spine running from top to bottom
    Widget timelineTrack = SizedBox(
      width: 46,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 2,
              color: spineColor,
            ),
          ),
          if (isCurrent) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.currentClassGreen,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_right_rounded,
                    size: 16,
                    color: theme.currentClassGreen,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: 2,
                color: spineColor,
              ),
            ),
          ],
        ],
      ),
    );

    // Break card / capsule content:
    Widget breakContent;

    if (isCurrent) {
      // 1. Active break: highlight capsule with countdown
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = endEpoch - nowMs;
      final remainingDur = Duration(milliseconds: remainingMs > 0 ? remainingMs : 0);
      final remainingFormatted = "${remainingDur.inHours.toString().padLeft(2, '0')}:${(remainingDur.inMinutes.remainder(60)).toString().padLeft(2, '0')}";

      breakContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.currentClassGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.currentClassGreen.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.currentClassGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.coffee_rounded,
                color: theme.currentClassGreen,
                size: 15 * fontScale,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Szünet most • $breakDurationText",
                    style: TextStyle(
                      color: theme.currentClassGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5 * fontScale,
                    ),
                  ),
                  Text(
                    "$timeRange ${nextClassTitle.isNotEmpty ? '• Köv: $nextClassTitle' : ''}",
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.7),
                      fontSize: 11.0 * fontScale,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timelapse_rounded,
                  color: theme.currentClassGreen,
                  size: 14 * fontScale,
                ),
                const SizedBox(width: 3),
                Text(
                  remainingFormatted,
                  style: TextStyle(
                    color: theme.currentClassGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.0 * fontScale,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      final room = toOfficeSlot != null
          ? ToOfficeOverlayWidget.extractRoomNumber(toOfficeSlot!.location)
          : '';
      final toText = toOfficeSlot != null
          ? (room.isNotEmpty ? "TO: ${toOfficeSlot!.timeFormatted} ($room)" : "TO: ${toOfficeSlot!.timeFormatted}")
          : '';

      breakContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.textColor.withValues(alpha: 0.09),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("☕", style: TextStyle(fontSize: 11.5 * fontScale)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "$breakDurationText szünet • $timeRange",
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.65),
                        fontSize: 11.5 * fontScale,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (toOfficeSlot != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  onTap: () => ToOfficeOverlayWidget.showDetailsDialog(context, toOfficeSlot!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      toText,
                      style: TextStyle(
                        color: Colors.orange.shade400,
                        fontSize: 10.5 * fontScale,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            timelineTrack,
            const SizedBox(width: 8),
            Expanded(child: breakContent),
          ],
        ),
      ),
    );
  }
}

class FreedayElementWidget extends StatelessWidget{
  const FreedayElementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Center(
            child: EmojiRichText(
              text: AppStrings.getLanguagePack().calendarPage_FreeDay,
              defaultStyle: TextStyle(
                color: AppColors.getTheme().onPrimaryContainer,
                fontWeight: FontWeight.w900,
                fontSize: 34.0,
              ),
              emojiStyle: TextStyle(
                  color: AppColors.getTheme().onPrimaryContainer,
                  fontSize: 34.0,
                  fontFamily: "Noto Color Emoji"
              ),
            ),
        ),
      )
    );
  }
}
class WeekoffseterElementWidget extends StatelessWidget{
  final HomePageState homePage;

  WeekoffseterElementWidget({super.key, required this.week, required this.from, required this.to, required this.onBackPressed, required this.onForwardPressed, required this.canDoPaging, required this.homePage, required this.isLoading}){
    final startMonth = from != null ? api.Generic.monthToText(from!.month) : "_";
    final startDay = from != null ? from!.day : "";

    final endMonth = api.Generic.monthToText(to.month);
    final endDay = to.day;

    displayString = AppStrings.getStringWithParams(AppStrings.getLanguagePack().calendarPage_weekNav_StudyWeek, [week]);

    if(isLoading){
      displayString2 = AppStrings.getLanguagePack().calendarPage_weekNav_ClassesThisWeekLoading;
      return;
    }

    if(startMonth == "_"){
      displayString2 = AppStrings.getLanguagePack().calendarPage_weekNav_ClassesThisWeekEmpty;
      return;
    }
    if("$startMonth $startDay" == "$endMonth $endDay"){
      displayString2 = AppStrings.getStringWithParams(AppStrings.getLanguagePack().calendarPage_weekNav_ClassesThisWeekOneDay, [endMonth, endDay, api.Generic.dayToText(to.weekday)]);
    }
    else{
      displayString2 = AppStrings.getStringWithParams(AppStrings.getLanguagePack().calendarPage_weekNav_ClassesThisWeekFull, [startMonth, startDay, endMonth, endDay]);
    }
  }

  final bool canDoPaging;
  final int week;
  final DateTime? from;
  final DateTime to;

  final Callback onBackPressed;
  final Callback onForwardPressed;

  late final String displayString;
  late final String displayString2;

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (_){
        homePage.calendarWeekCanNavigate = true;
        homePage.calendarWeekSwitchValue = 0.0;
      },
      onHorizontalDragEnd: (_){
        homePage.calendarWeekCanNavigate = false;
        homePage.calendarWeekSwitchValue = 0.0;
      },
      onHorizontalDragUpdate: (e){
        if(!homePage.calendarWeekCanNavigate || !canDoPaging){
          return;
        }
        if(homePage.calendarWeekSwitchValue < -20){
          homePage.calendarWeekSwitchValue = -5.0;
          onForwardPressed();
          return;
        }
        else if(homePage.calendarWeekSwitchValue > 20){
          homePage.calendarWeekSwitchValue = 5.0;
          onBackPressed();
          return;
        }
        homePage.calendarWeekSwitchValue += e.delta.dx;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 2),
        color: Colors.black.withValues(alpha: 0.01),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: !canDoPaging ? null : onBackPressed,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayString,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.getTheme().textColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16.0,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: homePage.isCalendarOffline ? 'Offline / Cache' : 'Online / Szinkronizálva',
                                child: Icon(
                                  homePage.isCalendarOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                                  size: 16,
                                  color: AppColors.getTheme().primary.withValues(alpha: homePage.isCalendarOffline ? 0.65 : 0.95),
                                ),
                              ),
                            ],
                          ),
                          if (homePage.currentWeekOffset != 1) ...[
                            const SizedBox(height: 4),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                AppHaptics.lightImpact();
                                homePage.currentWeekOffset = 1;
                                await homePage.onCalendarRefresh(false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.getTheme().primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.getTheme().primary, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.today_rounded,
                                      size: 13,
                                      color: AppColors.getTheme().primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppStrings.getLanguagePack().calendarPage_weekNav_JumpToCurrentWeek,
                                      style: TextStyle(
                                        color: AppColors.getTheme().primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                        onPressed: !canDoPaging ? null : onForwardPressed,
                        icon: const Icon(Icons.arrow_forward_rounded)
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(12), bottomLeft: Radius.circular(12)),
                ),
                child: EmojiRichText(
                  text: displayString2,
                  defaultStyle: TextStyle(
                    color: AppColors.getTheme().textColor.withValues(alpha: .6),
                    fontWeight: FontWeight.w300,
                    fontSize: 12.0,
                  ),
                  emojiStyle: TextStyle(
                      color: AppColors.getTheme().textColor,
                      fontSize: 12.0,
                      fontFamily: "Noto Color Emoji"
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}