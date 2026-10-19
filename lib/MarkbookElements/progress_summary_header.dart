import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../colors.dart';
import '../storage.dart';
import 'package:jupiter/API/api_coms.dart' as api;

class CreditProgressModel {
  final int completedCredit;
  final int requiredCredit;
  final int completedRequiredSubjectCredit;
  final int completedRequiredOptionalSubjectCredit;
  final int? completedOptionalSubjectCredit;
  final int completedCurriculumCount;
  final int allCurriculumCount;
  final bool hasCompletedCourseRequirements;

  const CreditProgressModel({
    required this.completedCredit,
    required this.requiredCredit,
    this.completedRequiredSubjectCredit = 0,
    this.completedRequiredOptionalSubjectCredit = 0,
    this.completedOptionalSubjectCredit,
    this.completedCurriculumCount = 0,
    this.allCurriculumCount = 0,
    this.hasCompletedCourseRequirements = false,
  });

  double get progressRatio => requiredCredit > 0 ? (completedCredit / requiredCredit).clamp(0.0, 1.0) : 0.0;
  double get percentage => progressRatio * 100.0;
}

class ProgressSummaryHeader extends StatelessWidget {
  final CreditProgressModel? creditProgress;
  final double semesterWeightedAvg;
  final double semesterScholarshipIndex;
  final double? semesterCreditIndex;
  final int semesterCredits;
  final int semesterCompletedCredits;
  final String? termName;
  final VoidCallback? onTapDetails;

  const ProgressSummaryHeader({
    super.key,
    this.creditProgress,
    required this.semesterWeightedAvg,
    required this.semesterScholarshipIndex,
    this.semesterCreditIndex,
    required this.semesterCredits,
    required this.semesterCompletedCredits,
    this.termName,
    this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    final fontScale = DataCache.getFontScale();

    final prog = creditProgress ??
        CreditProgressModel(
          completedCredit: semesterCompletedCredits > 0 ? semesterCompletedCredits : 40,
          requiredCredit: 210,
          completedRequiredSubjectCredit: 40,
          completedCurriculumCount: 1,
          allCurriculumCount: 2,
        );

    final cardBg = isDark
        ? theme.secondary.withValues(alpha: 0.35)
        : theme.secondary.withValues(alpha: 0.12);
    final cardBorder = isDark
        ? theme.secondary.withValues(alpha: 0.60)
        : theme.secondary.withValues(alpha: 0.28);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- 1. KÁRTYA: ÖSSZESÍTETT KÉPZÉSI ELŐREHALADÁS ---
        Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: cardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fejléc sáv
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: 16,
                          color: theme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'KÉPZÉSI ELŐREHALADÁS',
                        style: TextStyle(
                          color: isDark ? Colors.white : theme.textColor,
                          fontSize: 12.5 * fontScale,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.currentClassGreen.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.currentClassGreen.withValues(alpha: 0.40),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${prog.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: theme.currentClassGreen,
                        fontSize: 11 * fontScale,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tartalom: Balra köríves mutató, jobbra modul/kredit adatok
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Köríves folyamatjelző (Circular Progress Ring)
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(100, 100),
                          painter: _CircularProgressRingPainter(
                            progress: prog.progressRatio,
                            trackColor: theme.textColor.withValues(alpha: isDark ? 0.08 : 0.07),
                            progressColor: theme.currentClassGreen,
                            strokeWidth: 9.0,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${prog.completedCredit}',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : theme.textColor,
                                      fontSize: 19 * fontScale,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n/${prog.requiredCredit}',
                                    style: TextStyle(
                                      color: theme.textColor.withValues(alpha: 0.55),
                                      fontSize: 12 * fontScale,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'kredit',
                              style: TextStyle(
                                color: theme.textColor.withValues(alpha: 0.50),
                                fontSize: 9.5 * fontScale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Jobb oldali részletek
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressInfoRow(
                          title: 'Szabadon választható kredit',
                          value: prog.completedOptionalSubjectCredit != null
                              ? '${prog.completedOptionalSubjectCredit} kredit teljesítve'
                              : '- kredit teljesített',
                          theme: theme,
                          isDark: isDark,
                          fontScale: fontScale,
                        ),
                        const SizedBox(height: 8),
                        _buildProgressInfoRow(
                          title: 'Teljesített mintatanterv',
                          value: '${prog.completedCurriculumCount}/${prog.allCurriculumCount} db teljesített',
                          theme: theme,
                          isDark: isDark,
                          fontScale: fontScale,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- 2. KÁRTYA: AKTUÁLIS FÉLÉVES HALADÁS ÉS ÁTLAGOK ---
        Container(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: cardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          size: 15,
                          color: theme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FÉLÉVES EREDMÉNYEK',
                        style: TextStyle(
                          color: isDark ? Colors.white : theme.textColor,
                          fontSize: 12 * fontScale,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  if (termName != null && termName!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.textColor.withValues(alpha: isDark ? 0.08 : 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        termName!,
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.70),
                          fontSize: 10 * fontScale,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Súlyozott átlag
                  Expanded(
                    child: _buildMetricTile(
                      value: semesterWeightedAvg.isNaN || semesterWeightedAvg <= 0
                          ? '-'
                          : semesterWeightedAvg.toStringAsFixed(2),
                      label: 'SÚLYOZOTT ÁTLAG',
                      reaction: api.Generic.reactionForAvg(semesterWeightedAvg),
                      theme: theme,
                      isDark: isDark,
                      fontScale: fontScale,
                    ),
                  ),
                  _buildDivider(theme, isDark),
                  // Ösztöndíjindex
                  Expanded(
                    child: _buildMetricTile(
                      value: semesterScholarshipIndex.isNaN || semesterScholarshipIndex <= 0
                          ? '-'
                          : semesterScholarshipIndex.toStringAsFixed(2),
                      label: 'ÖSZTÖNDÍJINDEX',
                      reaction: api.Generic.reactionForAvg(semesterScholarshipIndex),
                      theme: theme,
                      isDark: isDark,
                      fontScale: fontScale,
                    ),
                  ),
                  _buildDivider(theme, isDark),
                  // Féléves kredit
                  Expanded(
                    child: _buildMetricTile(
                      value: '$semesterCredits',
                      label: 'FÉLÉVES KREDIT',
                      badgeColor: theme.roomHighlightColor,
                      theme: theme,
                      isDark: isDark,
                      fontScale: fontScale,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildDivider(AppPalette theme, bool isDark) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: theme.textColor.withValues(alpha: isDark ? 0.10 : 0.08),
    );
  }

  static Widget _buildMetricTile({
    required String value,
    required String label,
    String? reaction,
    Color? badgeColor,
    required AppPalette theme,
    required bool isDark,
    required double fontScale,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 17 * fontScale,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                  ),
                ),
              )
            else
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18 * fontScale,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : theme.textColor,
                ),
              ),
            if (reaction != null && reaction.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                reaction,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Noto Color Emoji',
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9.5 * fontScale,
            fontWeight: FontWeight.w700,
            color: theme.textColor.withValues(alpha: isDark ? 0.55 : 0.75),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  static Widget _buildProgressInfoRow({
    required String title,
    required String value,
    required AppPalette theme,
    required bool isDark,
    required double fontScale,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.textColor.withValues(alpha: isDark ? 0.60 : 0.75),
            fontSize: 11 * fontScale,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : theme.textColor,
            fontSize: 13.5 * fontScale,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CircularProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 .. 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Háttér gyűrű
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Aktív készültségi ív
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // -90 foktól (tetejétől) indítjuk óramutató járásával megegyezően
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.01, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
