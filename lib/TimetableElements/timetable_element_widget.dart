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
  final bool isOverlapping;
  late final bool isLongLesson;
  final List<api.CalendarEntry>? embeddedEntries;
  final bool hasToOfficeOverlay;

  TimetableElementWidget(
      {super.key,
      required this.entry,
      required this.position,
      required this.isCurrent,
      this.fullWidthMargin = true,
      this.isOverlapping = false,
      this.embeddedEntries,
      this.hasToOfficeOverlay = false}) {
    isExam = entry.isExam;
    isTask = entry.isTask;
    title = entry.title;
    location = entry.location;
    isLongLesson = (entry.endEpoch - entry.startEpoch) >= (3 * 3600 * 1000);

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
      cardTimeColor = theme.primary; // Theme based primary colors as requested
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: fullWidthMargin ? 14 : 0,
        vertical: 0, // No vertical margin on outer container so left spine connects seamlessly
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- LEFT SOLID TIMELINE TRACK (Width: 48px) ---
            SizedBox(
              width: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Folytonos, töretlen gerincvonal tetőtől talpig (0px gap a szomszédos kártyákhoz)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 2,
                        color: theme.primary.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  // Tartalom a vonalon: Időpont címkék és állapotcsomópontok
                  if (embeddedEntries != null && embeddedEntries!.isNotEmpty) ...[
                    // 1+3 Hybrid: Tömbóra teteje, beágyazott óra(ák) és a tömbóra zárópontja a vonalon
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Kezdőpont (pl. 08:55)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.rootBackground,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  displayStartTime,
                                  style: TextStyle(
                                    color: currentOverride ? const Color(0xFF00F0FF) : theme.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.0 * fontScale,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.rootBackground,
                                  border: Border.all(color: theme.primary, width: 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Beágyazott átfedő órák időpontjai a vonalon
                        for (var emb in embeddedEntries!) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.rootBackground,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: theme.errorRed.withValues(alpha: 0.4), width: 0.8),
                                  ),
                                  child: Text(
                                    "${DateTime.fromMillisecondsSinceEpoch(emb.startEpoch).hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(emb.startEpoch).minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      color: theme.errorRed,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5 * fontScale,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.errorRed,
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.errorRed.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Zárópont (pl. 17:00)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.rootBackground,
                                  border: Border.all(color: theme.primary.withValues(alpha: 0.7), width: 2),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.rootBackground,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  displayEndTime,
                                  style: TextStyle(
                                    color: theme.textColor.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5 * fontScale,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Normál idősáv megjelenítés
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.rootBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
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
                        ),
                        const SizedBox(height: 4),
                        if (currentOverride) ...[
                          // Élő haladási nyíl az épp zajló óránál
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F0FF),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F0FF).withValues(alpha: 0.65),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14,
                                  color: theme.rootBackground,
                                ),
                              ],
                            ),
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
                                color: theme.primary.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // --- RIGHT LESSON CARD ---
            Expanded(
              child: GestureDetector(
                onTap: () => _handleTap(context),
                child: Container(
                  margin: EdgeInsets.only(
                    top: 4,
                    bottom: 4,
                    left: isOverlapping ? 14 : 0, // Vizuális eltolás párhuzamos óráknál
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: (embeddedEntries != null && embeddedEntries!.isNotEmpty) ? 14 : (isLongLesson ? 20 : 11),
                    horizontal: hasToOfficeOverlay ? 9 : 13,
                  ),
                  decoration: BoxDecoration(
                    color: isOverlapping
                        ? cardBg.withValues(alpha: AppColors.isDarktheme() ? 0.45 : 0.18)
                        : cardBg,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isOverlapping ? theme.secondary : cardBorder,
                      width: isOverlapping ? 1.5 : borderWidth,
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
                      // 1. SOR: Idősáv balra, opcionális tömbóra/párhuzamos badge és terem jobbra
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 5,
                              runSpacing: 3,
                              children: [
                                Text(
                                  "$displayStartTime - $displayEndTime",
                                  style: TextStyle(
                                    color: cardTimeColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: (hasToOfficeOverlay ? 11.5 : 12.0) * fontScale,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (isLongLesson)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: theme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      AppStrings.getLanguagePack().timetable_badge_long_lesson,
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontSize: (hasToOfficeOverlay ? 9.5 : 10.0) * fontScale,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (isOverlapping)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      AppStrings.getLanguagePack().timetable_badge_overlapping,
                                      style: TextStyle(
                                        color: Colors.amber.shade700,
                                        fontSize: (hasToOfficeOverlay ? 9.5 : 10.0) * fontScale,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (location.trim().isNotEmpty && location != "NULL" && location != "Nincs megadva")
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: EdgeInsets.symmetric(
                                horizontal: hasToOfficeOverlay ? 5 : 7,
                                vertical: hasToOfficeOverlay ? 2 : 3,
                              ),
                              decoration: BoxDecoration(
                                color: isExam
                                    ? theme.errorRed
                                    : theme.roomHighlightColor,
                                borderRadius: BorderRadius.circular(hasToOfficeOverlay ? 6 : 8),
                                boxShadow: hasToOfficeOverlay ? null : [
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
                                  fontSize: (hasToOfficeOverlay ? 10.5 : 11.5) * fontScale,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 2. SOR: Tárgynév kiemelve félkövér (bold) betűkkel — témához igazodó tiszta kontraszttal
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.isDarktheme() ? Colors.white : theme.textColor,
                          fontSize: 16.5 * fontScale,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),

                      // 3. SOR: Típus • Oktató (neutrális/finomított) + visszaszámláló aktív óránál
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _buildSubtitle(),
                              style: TextStyle(
                                color: isExam
                                    ? theme.errorRed.withValues(alpha: 0.8)
                                    : (AppColors.isDarktheme()
                                        ? theme.textColor.withValues(alpha: 0.55)
                                        : theme.textColor.withValues(alpha: 0.80)),
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

                      // --- 1+3 HYBRID: Egymásba ágyazott átfedő órák szekciója ---
                      if (embeddedEntries != null && embeddedEntries!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: Divider(color: theme.textColor.withValues(alpha: 0.15), thickness: 1, endIndent: 8)),
                            Text(
                              '• • •  ⚡ ÁTFEDŐ ÓRA  • • •',
                              style: TextStyle(
                                color: theme.errorRed,
                                fontSize: 9.5 * fontScale,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Expanded(child: Divider(color: theme.textColor.withValues(alpha: 0.15), thickness: 1, indent: 8)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final emb in embeddedEntries!)
                          _buildEmbeddedCard(context, emb, theme, fontScale),
                        const SizedBox(height: 6),
                        _buildContinuationFooter(theme, fontScale),
                      ] else if (isLongLesson) ...[
                        const SizedBox(height: 8),
                        _buildContinuationFooter(theme, fontScale),
                      ],
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

  Widget _buildEmbeddedCard(BuildContext context, api.CalendarEntry emb, AppPalette theme, double fontScale) {
    final embStart = DateTime.fromMillisecondsSinceEpoch(emb.startEpoch);
    final embEnd = DateTime.fromMillisecondsSinceEpoch(emb.endEpoch);
    final embStartStr = "${embStart.hour.toString().padLeft(2, '0')}:${embStart.minute.toString().padLeft(2, '0')}";
    final embEndStr = "${embEnd.hour.toString().padLeft(2, '0')}:${embEnd.minute.toString().padLeft(2, '0')}";

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleEntryTap(context, emb),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.isDarktheme() ? const Color(0xFF191211) : theme.rootBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.errorRed,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.errorRed.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    runSpacing: 3,
                    children: [
                      Text(
                        "$embStartStr - $embEndStr",
                        style: TextStyle(
                          color: theme.errorRed,
                          fontWeight: FontWeight.w800,
                          fontSize: (hasToOfficeOverlay ? 11.0 : 12.0) * fontScale,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: theme.errorRed.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.errorRed, width: 0.8),
                        ),
                        child: Text(
                          AppStrings.getLanguagePack().timetable_badge_overlapping,
                          style: TextStyle(
                            color: theme.errorRed,
                            fontSize: (hasToOfficeOverlay ? 9.0 : 10.0) * fontScale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: EdgeInsets.symmetric(
                    horizontal: hasToOfficeOverlay ? 5 : 8,
                    vertical: hasToOfficeOverlay ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: (emb.location.isNotEmpty && emb.location != "NULL" && emb.location != "Nincs megadva")
                        ? theme.roomHighlightColor
                        : theme.roomHighlightColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(hasToOfficeOverlay ? 6 : 8),
                  ),
                  child: Text(
                    (emb.location.isNotEmpty && emb.location != "NULL") ? emb.location : "Nincs terem",
                    style: TextStyle(
                      color: theme.onRoomHighlightColor,
                      fontSize: (hasToOfficeOverlay ? 10.0 : 11.0) * fontScale,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              emb.title,
              style: TextStyle(
                color: AppColors.isDarktheme() ? Colors.white : theme.textColor,
                fontSize: 14.5 * fontScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${(emb.courseType != null && emb.courseType!.trim().isNotEmpty && emb.courseType != "-") ? emb.courseType!.trim() : "Óra"} • ${emb.teacher}',
              style: TextStyle(
                color: AppColors.isDarktheme()
                    ? theme.textColor.withValues(alpha: 0.65)
                    : theme.textColor.withValues(alpha: 0.80),
                fontSize: 11.5 * fontScale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinuationFooter(AppPalette theme, double fontScale) {
    final diffMs = entry.endEpoch - entry.startEpoch;
    final hours = (diffMs / (3600 * 1000)).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: EdgeInsets.symmetric(horizontal: hasToOfficeOverlay ? 8 : 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: AppColors.isDarktheme() ? 0.04 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: theme.primary, width: 2.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Text(
            'Délutáni zárás: $displayEndTime',
            style: TextStyle(
              color: AppColors.isDarktheme()
                  ? theme.textColor.withValues(alpha: 0.7)
                  : theme.textColor.withValues(alpha: 0.85),
              fontSize: (hasToOfficeOverlay ? 10.5 : 11.0) * fontScale,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Összesen: $hours óra',
            style: TextStyle(
              color: theme.primary,
              fontSize: (hasToOfficeOverlay ? 10.5 : 11.0) * fontScale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context) {
    _handleEntryTap(context, entry);
  }

  void _handleEntryTap(BuildContext context, api.CalendarEntry target) {
    AppHaptics.lightImpact();
    if (target.isExam) {
      TimetableCurrentlySelected.entry = target;
      PopupWidgetHandler(mode: 5, callback: (_) {});
      PopupWidgetHandler.doPopup(context);
      return;
    }
    if (target.isTask && target.taskId != null && target.taskId!.isNotEmpty) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.getTheme().rootBackground,
              title: Text(target.title, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
              content: FutureBuilder<String?>(
                future: storage.getString('task_type_${target.taskId}'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                  }

                  return FutureBuilder<String?>(
                      future: storage.getString('task_res_${target.taskId}'),
                      builder: (context, resSnapshot) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📚 Tárgy: ${target.location}", style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 16)),
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
    if (target.classInstanceId != null && target.classInstanceId!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.getTheme().rootBackground,
            title: Text(target.title, style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold)),
            content: FutureBuilder<Map<String, String>>(
              future: api.CalendarRequest.getCourseDetails(target.classInstanceId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator())
                  );
                }
                final data = snapshot.data ?? {};
                final room = (data['room'] != null && data['room']!.isNotEmpty && data['room'] != 'Nincs terem') ? data['room']! : target.location;
                final teacher = (data['teacher'] != null && data['teacher']!.isNotEmpty && data['teacher'] != 'Nincs tanár') ? data['teacher']! : target.teacher;
                final courseType = (data['type'] != null && data['type']!.isNotEmpty) ? data['type']! : (target.courseType ?? '');
                final subjectCode = (data['code'] != null && data['code']!.isNotEmpty && data['code'] != '-') ? data['code']! : target.subjectCode;

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
      TimetableCurrentlySelected.entry = target;
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

    final spineColor = theme.primary.withValues(alpha: 0.20);

    // Folytonos, töretlen bal oldali idővonal a szünet elemhez (48px széles)
    Widget timelineTrack = SizedBox(
      width: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: 2,
                color: spineColor,
              ),
            ),
          ),
          if (isCurrent)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.currentClassGreen,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: theme.currentClassGreen.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 14,
                  color: theme.rootBackground,
                ),
              ),
            ),
        ],
      ),
    );

    // Break card / capsule content:
    Widget breakContent;

    if (isCurrent) {
      // 1. Aktív szünet: visszaszámláló óra helyett százalékos készültségi kijelzés
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final totalBreakMs = endEpoch - startEpoch;
      final elapsedMs = nowMs - startEpoch;
      final progress = totalBreakMs > 0 ? (elapsedMs / totalBreakMs).clamp(0.0, 1.0) : 0.0;
      final percentInt = (progress * 100).toInt();

      breakContent = Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: theme.currentClassGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.currentClassGreen.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                        "${AppStrings.getLanguagePack().timetable_break_title} • $breakDurationText",
                        style: TextStyle(
                          color: theme.currentClassGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5 * fontScale,
                        ),
                      ),
                      Text(
                        "$timeRange ${nextClassTitle.isNotEmpty ? '• ${AppStrings.getLanguagePack().timetable_next_class_prefix} $nextClassTitle' : ''}",
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
                // Százalékos készültség kijelzése
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.currentClassGreen.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.currentClassGreen.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timelapse_rounded,
                        color: theme.currentClassGreen,
                        size: 13 * fontScale,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$percentInt%",
                        style: TextStyle(
                          color: theme.currentClassGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.0 * fontScale,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.currentClassGreen.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(theme.currentClassGreen),
                minHeight: 4,
              ),
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
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              onPressed: !canDoPaging ? null : onBackPressed,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              color: canDoPaging ? AppColors.getTheme().textColor : AppColors.getTheme().textColor.withValues(alpha: 0.25),
              visualDensity: VisualDensity.compact,
              splashRadius: 20,
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
                          fontSize: 14.5,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: homePage.isCalendarOffline
                            ? AppStrings.getLanguagePack().calendar_status_offline
                            : AppStrings.getLanguagePack().calendar_status_online,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: (homePage.isCalendarOffline ? Colors.orange : AppColors.getTheme().primary).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            homePage.isCalendarOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                            size: 13,
                            color: homePage.isCalendarOffline ? Colors.orange : AppColors.getTheme().primary,
                          ),
                        ),
                      ),
                      if (homePage.currentWeekOffset != 1) ...[
                        const SizedBox(width: 7),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              await homePage.jumpToCurrentWeekAndToday();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.getTheme().primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.getTheme().primary.withValues(alpha: 0.8),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.today_rounded,
                                    size: 11,
                                    color: AppColors.getTheme().primary,
                                  ),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    AppStrings.getLanguagePack().calendarPage_weekNav_JumpToCurrentWeek,
                                    style: TextStyle(
                                      color: AppColors.getTheme().primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  EmojiRichText(
                    text: displayString2,
                    defaultStyle: TextStyle(
                      color: AppColors.getTheme().textColor.withValues(alpha: .55),
                      fontWeight: FontWeight.w400,
                      fontSize: 11.5,
                    ),
                    emojiStyle: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: "Noto Color Emoji",
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: !canDoPaging ? null : onForwardPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              color: canDoPaging ? AppColors.getTheme().textColor : AppColors.getTheme().textColor.withValues(alpha: 0.25),
              visualDensity: VisualDensity.compact,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}