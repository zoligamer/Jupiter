import 'package:flutter/material.dart';
import '../colors.dart';
import '../storage.dart';

class TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  const TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });
}

class AppTutorialModal {
  static final List<TutorialStep> _steps = [
    TutorialStep(
      icon: Icons.calendar_month_rounded,
      title: 'Órarend & Naptár',
      description:
          'A naptáradban nyomon követheted az óráidat, a hivatalos egyetemi időszakokat és a Tanulmányi Osztály (T.O.) nyitvatartását is. Könnyedén válthatsz hetek között, áttekintheted mind a 7 napot, az app pedig automatikusan a soron következő órádra fókuszál.',
      accentColor: const Color(0xFF4A90E2),
    ),
    TutorialStep(
      icon: Icons.school_rounded,
      title: 'Tárgyak & Eredmények',
      description:
          'Ellenőrizd az aktuálisan felvett tantárgyaidat, a szakodhoz tartozó maximális és eddig megszerzett krediteket. Tekintsd meg a féléves és súlyozott átlagaidat, és használd a szellemjegy funkciót a várható jegyeid megtervezéséhez!',
      accentColor: const Color(0xFF6C5CE7),
    ),
    TutorialStep(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Pénzügyek & Tranzakciók',
      description:
          'Kövesd figyelemmel az összes befizetést és jóváírást, és lásd pontosan, mennyi pénzt fordítottál az egyetemre. Az intelligens színezés kapcsolóval a kiadásaid és az ösztöndíjaid automatikusan különülnek el.',
      accentColor: const Color(0xFF00B894),
    ),
    TutorialStep(
      icon: Icons.hourglass_bottom_rounded,
      title: 'Időszakok & Határidők',
      description:
          'Tartsd számon a félév legfontosabb dátumait (tárgyfelvétel, vizsgajelentkezés, regisztráció), hogy ne maradj le semmiről! Értesítést kapsz az időszakok kezdete és lezárása előtt is.',
      accentColor: const Color(0xFFE17055),
    ),
    TutorialStep(
      icon: Icons.mark_email_unread_rounded,
      title: 'Üzenetek & Értesítések',
      description:
          'Kezeld Neptun üzeneteidet szinkronizált olvasatlan számlálóval és azonnali jelvénnyel. Olvasd el az oktatók sürgős üzeneteit, és szükség esetén egyetlen koppintással jelöld az összeset olvasottnak.',
      accentColor: const Color(0xFFE84393),
    ),
    TutorialStep(
      icon: Icons.menu_rounded,
      title: 'Oldalsó Menü (App Drawer)',
      description:
          'A bal oldali menüből gyorsan válthatsz félévet, megnézheted a gyűjtőszámla egyenlegedet és a profilodat, kezelheted a beállításokat és kérvényeket, valamint egyetlen kattintással frissíthetsz vagy küldhetsz visszajelzést.',
      accentColor: const Color(0xFF0984E3),
    ),
  ];

  /// Ellenőrzi a mentett állapotot, és ha szükséges, felugró ablakban ajánlja fel a bemutatót
  static Future<void> checkAndShow(BuildContext context) async {
    final status = DataCache.getTutorialStatus();
    if (status == 'completed' || status == 'never') {
      return;
    }

    if (!context.mounted) return;

    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SafeArea(
        child: AlertDialog(
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
                child: Icon(Icons.auto_awesome_rounded, color: theme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Üdvözöl a Jupiter!',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Szeretnél egy gyors, 1 perces bemutatót az alkalmazás leghasznosabb funkcióiról és felületeiről?',
            style: TextStyle(
              color: theme.textColor.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    DataCache.setTutorialStatus('never');
                    Navigator.pop(ctx, 'never');
                  },
                  child: Text(
                    'Soha többé',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    DataCache.setTutorialStatus('later');
                    Navigator.pop(ctx, 'later');
                  },
                  child: Text(
                    'Nem most',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.70),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx, 'show');
                  },
                  child: const Text(
                    'Igen, mutasd!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == 'show' && context.mounted) {
      await showTutorial(context);
    }
  }

  /// Megnyitja a lépésről lépésre követhető bemutató lapot
  static Future<void> showTutorial(BuildContext context) async {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TutorialSheet(theme: theme, isDark: isDark),
    );

    await DataCache.setTutorialStatus('completed');
  }
}

class _TutorialSheet extends StatefulWidget {
  final dynamic theme;
  final bool isDark;

  const _TutorialSheet({required this.theme, required this.isDark});

  @override
  State<_TutorialSheet> createState() => _TutorialSheetState();
}

class _TutorialSheetState extends State<_TutorialSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = AppTutorialModal._steps;
    final theme = widget.theme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.rootBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Fejléc
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.explore_rounded, color: theme.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Jupiter funkciók áttekintése',
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Kihagyás',
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.50),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 0.5),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: steps.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (ctx, index) {
                  final s = steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: s.accentColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: s.accentColor.withValues(alpha: 0.35),
                                  width: 2,
                                ),
                              ),
                              child: Icon(s.icon, color: s.accentColor, size: 44),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              s.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.textColor.withValues(alpha: 0.80),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Alsó sáv lapozó indikátorral és gombokkal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Vissza gomb (vagy üres hely)
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Text(
                        'Vissza',
                        style: TextStyle(color: theme.textColor.withValues(alpha: 0.70)),
                      ),
                    )
                  else
                    const SizedBox(width: 60),

                  // Lapozó pontok
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(steps.length, (idx) {
                      final isSel = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSel ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSel ? theme.primary : theme.textColor.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Következő / Befejezés gomb
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_currentPage < steps.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      _currentPage == steps.length - 1 ? 'Kész' : 'Tovább',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
