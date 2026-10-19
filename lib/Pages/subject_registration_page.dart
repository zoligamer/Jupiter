import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../colors.dart';
import '../haptics.dart';

class CourseInstance {
  final String id;
  final String code;
  final String type; // Elmélet, Labor, Gyakorlat, Testnevelés, Szakdolgozat
  final int day; // 0: Mon, 1: Tue, 2: Wed, 3: Thu, 4: Fri, -1: Időpont nélküli (e-learning, szakdolgozat)
  final TimeOfDay? start;
  final TimeOfDay? end;
  final String room;
  final String tutor;
  final String slots;
  final bool isMandatory;
  final bool isAlternate;
  final String groupKey;
  final String language;

  const CourseInstance({
    required this.id,
    required this.code,
    required this.type,
    required this.day,
    this.start,
    this.end,
    required this.room,
    required this.tutor,
    required this.slots,
    this.isMandatory = true,
    this.isAlternate = false,
    required this.groupKey,
    this.language = 'Magyar',
  });

  bool get hasTimetable => day >= 0 && start != null && end != null;
  int get startMinutes => start != null ? start!.hour * 60 + start!.minute : 0;
  int get endMinutes => end != null ? end!.hour * 60 + end!.minute : 0;
  int get durationMinutes => endMinutes - startMinutes;

  String formatTimeRange() {
    if (!hasTimetable) return 'Időpont nélküli / Konzulensi';
    final sh = start!.hour.toString().padLeft(2, '0');
    final sm = start!.minute.toString().padLeft(2, '0');
    final eh = end!.hour.toString().padLeft(2, '0');
    final em = end!.minute.toString().padLeft(2, '0');
    return '$sh:$sm - $eh:$em';
  }
}

class SubjectData {
  final String id;
  final String code;
  final String name;
  final int credits;
  final int semester; // Ajánlott tantervi félév (1..7)
  final String requirementType; // Évközi jegy, Vizsga, Kollokvium
  final String subjectType; // Kötelező törzsanyag, Szabadon választható
  final bool isRequired;
  final bool isRegistered; // Zöld pipa a képen
  final bool isCompleted;
  final bool hasFailedBefore; // Bukott vagy letiltott tárgy -> Csúszás jelölés
  final List<String> prerequisites; // Előkövetelmények
  final bool arePrerequisitesMet;
  final List<CourseInstance> courses;

  const SubjectData({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
    required this.semester,
    required this.requirementType,
    required this.subjectType,
    required this.isRequired,
    this.isRegistered = false,
    this.isCompleted = false,
    this.hasFailedBefore = false,
    this.prerequisites = const [],
    this.arePrerequisitesMet = true,
    required this.courses,
  });
}

class _CourseLayoutItem {
  final CourseInstance course;
  final SubjectData subject;
  int columnIndex = 0;
  int totalColumns = 1;

  _CourseLayoutItem(this.course, this.subject);
}

enum SubjectClassification {
  suggested, // StudentCurrentTerm == SuggestedTerm
  delayed,   // StudentCurrentTerm > SuggestedTerm || hasFailedBefore
  future,    // StudentCurrentTerm < SuggestedTerm
}

enum SubjectFilterCategory {
  all,
  suggested,
  delayed,
  future,
}

class SubjectRegistrationPage extends StatefulWidget {
  const SubjectRegistrationPage({super.key});

  @override
  State<SubjectRegistrationPage> createState() => _SubjectRegistrationPageState();
}

class _SubjectRegistrationPageState extends State<SubjectRegistrationPage> {
  static const int _startHour = 6;
  static const int _endHour = 22;
  static const double _hourHeight = 56.0;

  // Aktuális félév a hallgatónál
  static const int _studentCurrentSemester = 3;

  // Nézetváltók
  bool _isListView = true; // true: Neptun akkordeon lista, false: Heti órarendi rács
  bool _isWeekView = true;
  bool _isExclusiveFullscreen = false; // 1. B opció: gombra kapcsolható teljes képernyő

  int _selectedDayIndex = 0; // 0 = Hétfő
  int? _filterSemester = 3; // null = Összes félév, egyébként 1..maxCurriculumSemester
  SubjectFilterCategory _filterCategory = SubjectFilterCategory.all;
  String _searchQuery = '';
  String _selectedSubjectType = 'Mintatantervi'; // Mintatantervi, Szabadon választható, Összes

  final Set<String> _selectedCourseIds = {'c-101', 'c-201', 'c-301', 'c-302'};
  final Set<String> _expandedSubjectIds = {'sub-szakd'}; // alapértelmezetten nyitott tárgyak

  late final List<SubjectData> _subjects;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _headerHorizontalController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSampleData();
    _horizontalScrollController.addListener(_syncHeaderHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showInteractiveSimulationDisclaimer();
      }
    });
  }

  void _syncHeaderHorizontalScroll() {
    if (_headerHorizontalController.hasClients &&
        _headerHorizontalController.offset != _horizontalScrollController.offset) {
      _headerHorizontalController.jumpTo(_horizontalScrollController.offset);
    }
  }

  @override
  void dispose() {
    if (_isExclusiveFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _horizontalScrollController.removeListener(_syncHeaderHorizontalScroll);
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _headerHorizontalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExclusiveFullscreen() {
    AppHaptics.mediumImpact();
    setState(() {
      _isExclusiveFullscreen = !_isExclusiveFullscreen;
    });
    if (_isExclusiveFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      Fluttertoast.showToast(
        msg: "⛶ Exkluzív teljes képernyő aktív (érintsd meg a széleket a sávokhoz)",
        toastLength: Toast.LENGTH_SHORT,
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _initSampleData() {
    _subjects = [
      // 1. Féléves tárgy — CSÚSZÁS PÉLDA (Nem teljesítve, korábban bukott)
      const SubjectData(
        id: "sub-elektro",
        code: "BBXED11BNF",
        name: "Elektrotechnika, digitális technika",
        credits: 5,
        semester: 1,
        requirementType: "Évközi jegy",
        subjectType: "Kötelező törzsanyag",
        isRequired: true,
        isRegistered: false,
        isCompleted: false,
        hasFailedBefore: true, // Korábban nem sikerült -> Csúszás kiemelés!
        prerequisites: [],
        arePrerequisitesMet: true,
        courses: [
          CourseInstance(
            id: "c-ed-1",
            code: "BBXED11A",
            type: "Elmélet",
            day: 0, // Hétfő
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 9, minute: 40),
            room: "FR.1.101",
            tutor: "Dr. Kovács Béla",
            slots: "42/60",
            isMandatory: true,
            groupKey: "ed-elm",
          ),
          CourseInstance(
            id: "c-ed-2",
            code: "BBXED11L",
            type: "Labor",
            day: 2, // Szerda
            start: TimeOfDay(hour: 10, minute: 0),
            end: TimeOfDay(hour: 11, minute: 40),
            room: "FR.L.08",
            tutor: "Dr. Kovács Béla",
            slots: "18/20",
            isMandatory: true,
            groupKey: "ed-lab",
          ),
        ],
      ),

      // 3. Féléves tárgyak (Aktuális félév — Pont mint a képen)
      const SubjectData(
        id: "sub-infobizt",
        code: "BBXCZ13BNF",
        name: "Információbiztonsági kockázatok kezelése",
        credits: 5,
        semester: 3,
        requirementType: "Évközi jegy",
        subjectType: "Kötelező törzsanyag",
        isRequired: true,
        isRegistered: true, // Zöld pipa mint a képen
        isCompleted: false,
        prerequisites: ["Informatika I."],
        arePrerequisitesMet: true,
        courses: [
          CourseInstance(
            id: "c-201",
            code: "BBCZEA",
            type: "Elmélet",
            day: 0, // Hétfő
            start: TimeOfDay(hour: 11, minute: 40),
            end: TimeOfDay(hour: 13, minute: 20),
            room: "FR.1.101",
            tutor: "Dr. Szabó Péter",
            slots: "32/45",
            isMandatory: true,
            isAlternate: false,
            groupKey: "dok-elm",
          ),
          CourseInstance(
            id: "c-202",
            code: "BBCZL1",
            type: "Labor",
            day: 0, // Hétfő
            start: TimeOfDay(hour: 13, minute: 30),
            end: TimeOfDay(hour: 15, minute: 10),
            room: "FR.L.05",
            tutor: "Dr. Szabó Péter",
            slots: "19/22",
            isMandatory: true,
            isAlternate: false,
            groupKey: "dok-lab",
          ),
        ],
      ),

      const SubjectData(
        id: "sub-matek2",
        code: "BTXMAK3BNF",
        name: "Matematika II.",
        credits: 5,
        semester: 2,
        requirementType: "Vizsga",
        subjectType: "Kötelező törzsanyag",
        isRequired: true,
        isRegistered: true, // Zöld pipa mint a képen
        isCompleted: false,
        prerequisites: ["Matematika I."],
        arePrerequisitesMet: true,
        courses: [
          CourseInstance(
            id: "c-301",
            code: "BT_K_MAEA",
            type: "Elmélet",
            day: 1, // Kedd
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 9, minute: 40),
            room: "FR.2.102",
            tutor: "Dr. Tóth Ágnes",
            slots: "40/50",
            isMandatory: true,
            isAlternate: false,
            groupKey: "mat-elm",
          ),
          CourseInstance(
            id: "c-302",
            code: "BT_K_MAGY",
            type: "Gyakorlat",
            day: 1, // Kedd
            start: TimeOfDay(hour: 13, minute: 30),
            end: TimeOfDay(hour: 15, minute: 10),
            room: "FR.2.102",
            tutor: "Dr. Tóth Ágnes",
            slots: "22/25",
            isMandatory: true,
            isAlternate: false,
            groupKey: "mat-gyak",
          ),
        ],
      ),

      // 7. Féléves tárgy: Szakdolgozat (Pontosan mint a media_1792434251711_9aed7e52.png képen!)
      const SubjectData(
        id: "sub-szakd",
        code: "BBDSD17BNF",
        name: "Szakdolgozat",
        credits: 15,
        semester: 7,
        requirementType: "Évközi jegy",
        subjectType: "Kötelező törzsanyag",
        isRequired: true,
        isRegistered: false,
        isCompleted: false,
        prerequisites: ["Szakdolgozat I.", "120 teljesített kredit"],
        arePrerequisitesMet: false, // Hiányzó előkövetelmény példa!
        courses: [
          CourseInstance(
            id: "c-szd-elm",
            code: "BBSDEA",
            type: "Elmélet",
            day: -1, // Időpont nélküli mint a képen!
            room: "Konzulensi",
            tutor: "Dr. Rajnai Zoltán",
            slots: "17 fő / 30 limit",
            isMandatory: true,
            groupKey: "szd-elm",
          ),
          CourseInstance(
            id: "c-szd-t1",
            code: "Dr. Farkas Tibor",
            type: "Szakdolgozat konzulens",
            day: -1,
            room: "Témavezetői",
            tutor: "Dr. Farkas Tibor",
            slots: "1 fő / 10 limit",
            isMandatory: true,
            isAlternate: true,
            groupKey: "szd-konz",
          ),
          CourseInstance(
            id: "c-szd-t2",
            code: "Dr. Kiss Gábor",
            type: "Szakdolgozat konzulens",
            day: -1,
            room: "Témavezetői",
            tutor: "Dr. Kiss Gábor",
            slots: "8 fő / 10 limit",
            isMandatory: true,
            isAlternate: true,
            groupKey: "szd-konz",
          ),
          CourseInstance(
            id: "c-szd-t3",
            code: "Dr. Kollár Csaba",
            type: "Szakdolgozat konzulens",
            day: -1,
            room: "Témavezetői",
            tutor: "Dr. Kollár Csaba",
            slots: "5 fő / 10 limit",
            isMandatory: true,
            isAlternate: true,
            groupKey: "szd-konz",
          ),
          CourseInstance(
            id: "c-szd-t4",
            code: "Dr. Michelberger Pál",
            type: "Szakdolgozat konzulens",
            day: -1,
            room: "Témavezetői",
            tutor: "Dr. Michelberger Pál",
            slots: "1 fő / 10 limit",
            isMandatory: true,
            isAlternate: true,
            groupKey: "szd-konz",
          ),
          CourseInstance(
            id: "c-szd-t5",
            code: "Dr. Rajnai Zoltán",
            type: "Szakdolgozat konzulens",
            day: -1,
            room: "Témavezetői",
            tutor: "Dr. Rajnai Zoltán",
            slots: "2 fő / 10 limit",
            isMandatory: true,
            isAlternate: true,
            groupKey: "szd-konz",
          ),
        ],
      ),

      // Szabadon választható tárgyak (4. félév)
      const SubjectData(
        id: "sub-jarmu1",
        code: "BMVJPR1BNF",
        name: "Járműépítési projekt I.",
        credits: 5,
        semester: 4,
        requirementType: "Évközi jegy",
        subjectType: "Szabadon választható",
        isRequired: false,
        courses: [
          CourseInstance(
            id: "c-jarmu-1",
            code: "BMVJPR1",
            type: "Projektgyakorlat",
            day: 4, // Péntek
            start: TimeOfDay(hour: 10, minute: 0),
            end: TimeOfDay(hour: 13, minute: 20),
            room: "Járműlab",
            tutor: "Dr. Németh István",
            slots: "12/20",
            groupKey: "jarmu-lab",
          ),
        ],
      ),
    ];
  }

  // Hallgatói besorolás a megadott Python logika alapján:
  // StudentCurrentTerm == SuggestedTerm -> Ajánlott
  // StudentCurrentTerm > SuggestedTerm || hasFailedBefore -> Csúszás / Bukott
  // StudentCurrentTerm < SuggestedTerm -> Előrehozott / Hardcore
  SubjectClassification _classifySubject(SubjectData s) {
    if (s.hasFailedBefore || (s.semester < _studentCurrentSemester && !s.isCompleted)) {
      return SubjectClassification.delayed;
    }
    if (s.semester == _studentCurrentSemester) {
      return SubjectClassification.suggested;
    }
    return SubjectClassification.future;
  }

  // Dinamikus mintatantervi félév szám a képzésből / tantárgyakból kinyerve (nem fix 7 félév!)
  int get _maxCurriculumSemester {
    int maxSem = 7;
    for (final s in _subjects) {
      if (s.semester > maxSem) maxSem = s.semester;
    }
    return maxSem;
  }

  // Csúszás / elmaradt kötelező tárgyak szűrése
  List<SubjectData> _getDelayedMandatorySubjects() {
    return _subjects.where((s) => _classifySubject(s) == SubjectClassification.delayed).toList();
  }

  // Szűrt tantárgylista (Kategória + Félév + Keresés)
  List<SubjectData> _getFilteredSubjects() {
    return _subjects.where((s) {
      final classification = _classifySubject(s);
      if (_filterCategory == SubjectFilterCategory.suggested && classification != SubjectClassification.suggested) {
        return false;
      }
      if (_filterCategory == SubjectFilterCategory.delayed && classification != SubjectClassification.delayed) {
        return false;
      }
      if (_filterCategory == SubjectFilterCategory.future && classification != SubjectClassification.future) {
        return false;
      }
      if (_filterSemester != null && s.semester != _filterSemester) {
        return false;
      }
      if (_selectedSubjectType != 'Összes' && s.subjectType != _selectedSubjectType) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = s.name.toLowerCase().contains(q);
        final matchCode = s.code.toLowerCase().contains(q);
        if (!matchName && !matchCode) return false;
      }
      return true;
    }).toList();
  }

  // Interaktív próba figyelmeztető felugró ablak belépéskor
  void _showInteractiveSimulationDisclaimer() {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: theme.textColor.withValues(alpha: 0.15), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F47D0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.science_rounded, color: Color(0xFF0F47D0), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Tárgyfelvétel Tervező',
                          style: TextStyle(
                            color: isDark ? Colors.white : theme.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F47D0),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('TEST', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Interaktív próba & szimuláció',
                      style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5),
                    ),
                  ],
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
                  color: theme.textColor.withValues(alpha: isDark ? 0.06 : 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.textColor.withValues(alpha: 0.08)),
                ),
                child: Text(
                  'Ez a felület jelenleg egy interaktív próba és tesztkörnyezet! Szabadon kattintgathatsz, válogathatsz kurzusokat, és tesztelheted az órarendi rácsot és az ütközésvizsgálatot.',
                  style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 12.5, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: theme.currentClassGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biztonságos mód: semmilyen művelet nem küld éles módosítást a valódi Neptun szerverre.',
                      style: TextStyle(color: theme.textColor.withValues(alpha: 0.75), fontSize: 11.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.touch_app_outlined, size: 18, color: const Color(0xFF0F47D0)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tipp: Bármelyik kurzust hosszan nyomva tartva (Long-press) megnyílik a részletes adatlapja!',
                      style: TextStyle(color: theme.textColor.withValues(alpha: 0.75), fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F47D0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Értem, kipróbálom', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Részletes adatlap segéd sor
  Widget _buildDetailRow(IconData icon, String label, String value, AppPalette theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.textColor.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : theme.textColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hosszan nyomásra (Long-press) megjelenő kurzus részletek modal
  void _showCourseDetailsDialog(CourseInstance course, SubjectData subject) {
    AppHaptics.mediumImpact();
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    final isSelected = _selectedCourseIds.contains(course.id);
    final classification = _classifySubject(subject);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: theme.textColor.withValues(alpha: 0.15), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F47D0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFF0F47D0), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.code,
                      style: TextStyle(
                        color: isDark ? Colors.white : theme.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subject.name,
                      style: TextStyle(color: theme.textColor.withValues(alpha: 0.65), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (classification == SubjectClassification.delayed) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.errorRed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: theme.errorRed, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subject.hasFailedBefore
                                ? '🚨 BUKOTT TÁRGY: Újrafelvétel szükséges!'
                                : '🚨 CSÚSZÁS: ${subject.semester}. félévi elmaradt kötelező tárgy!',
                            style: TextStyle(color: theme.errorRed, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (classification == SubjectClassification.future) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.purple, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '⚡ ELŐREHOZOTT: Felsőbb féléves tárgy felvétele',
                            style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                _buildDetailRow(Icons.category_rounded, 'Típus', course.type, theme, isDark),
                _buildDetailRow(Icons.person_outline_rounded, 'Oktató', course.tutor, theme, isDark),
                _buildDetailRow(Icons.location_on_outlined, 'Terem / Hely', course.room, theme, isDark),
                _buildDetailRow(Icons.access_time_rounded, 'Időpont', course.formatTimeRange(), theme, isDark),
                _buildDetailRow(Icons.groups_outlined, 'Létszám', course.slots, theme, isDark),
                _buildDetailRow(Icons.translate_rounded, 'Nyelv', course.language, theme, isDark),
                _buildDetailRow(Icons.hub_outlined, 'Csoport', course.groupKey, theme, isDark),
                _buildDetailRow(Icons.star_outline_rounded, 'Kredit', '${subject.credits} kredit', theme, isDark),
                _buildDetailRow(Icons.calendar_today_outlined, 'Ajánlott félév', '${subject.semester}. félév', theme, isDark),
                _buildDetailRow(Icons.fact_check_outlined, 'Követelmény', subject.requirementType, theme, isDark),
                if (subject.prerequisites.isNotEmpty)
                  _buildDetailRow(Icons.layers_outlined, 'Előkövetelmény', subject.prerequisites.join(', '), theme, isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Bezárás', style: TextStyle(color: theme.textColor.withValues(alpha: 0.7))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? theme.errorRed : const Color(0xFF0F47D0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _toggleCourse(course, subject);
              },
              child: Text(
                isSelected ? 'Kivétel a tervezőből' : 'Hozzáadás a tervezőhöz',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Tárgy részletes adatlap modal
  void _showSubjectDetailsDialog(SubjectData subject) {
    AppHaptics.mediumImpact();
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    final classification = _classifySubject(subject);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: theme.textColor.withValues(alpha: 0.15), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.article_outlined, color: theme.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subject.code,
                      style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (classification == SubjectClassification.delayed) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.errorRed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: theme.errorRed, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subject.hasFailedBefore
                                ? '🚨 BUKOTT TÁRGY: Újrafelvétel szükséges!'
                                : '🚨 CSÚSZÁS: ${subject.semester}. félévi elmaradt kötelező tárgy!',
                            style: TextStyle(color: theme.errorRed, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildDetailRow(Icons.calendar_month_rounded, 'Ajánlott félév', '${subject.semester}. félév', theme, isDark),
                _buildDetailRow(Icons.star_outline_rounded, 'Kredit érték', '${subject.credits} kredit', theme, isDark),
                _buildDetailRow(Icons.assignment_outlined, 'Tantervi típus', subject.subjectType, theme, isDark),
                _buildDetailRow(Icons.grade_outlined, 'Követelmény', subject.requirementType, theme, isDark),
                _buildDetailRow(Icons.class_outlined, 'Kurzusok száma', '${subject.courses.length} db elérhető kurzus', theme, isDark),
                if (subject.prerequisites.isNotEmpty)
                  _buildDetailRow(Icons.layers_rounded, 'Előkövetelmény', subject.prerequisites.join(', '), theme, isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Bezárás', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Detect collisions among selected courses
  Set<String> _getCollidingCourseIds() {
    final colliding = <String>{};
    final allSelected = <CourseInstance>[];

    for (final s in _subjects) {
      for (final c in s.courses) {
        if (_selectedCourseIds.contains(c.id) && c.hasTimetable) {
          allSelected.add(c);
        }
      }
    }

    for (int i = 0; i < allSelected.length; i++) {
      for (int j = i + 1; j < allSelected.length; j++) {
        final a = allSelected[i];
        final b = allSelected[j];
        if (a.day == b.day) {
          final maxStart = max(a.startMinutes, b.startMinutes);
          final minEnd = min(a.endMinutes, b.endMinutes);
          if (maxStart < minEnd) {
            colliding.add(a.id);
            colliding.add(b.id);
          }
        }
      }
    }
    return colliding;
  }

  void _toggleCourse(CourseInstance course, SubjectData subject) {
    AppHaptics.lightImpact();
    setState(() {
      if (_selectedCourseIds.contains(course.id)) {
        _selectedCourseIds.remove(course.id);
      } else {
        // Mutex: azonos csoportú alternatív kurzus felülírása
        for (final c in subject.courses) {
          if (c.groupKey == course.groupKey && c.id != course.id) {
            _selectedCourseIds.remove(c.id);
          }
        }
        _selectedCourseIds.add(course.id);
      }
    });
  }

  void _showPrerequisitesDialog(SubjectData subject) {
    AppHaptics.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = AppColors.getTheme();
        final isDark = AppColors.isDarktheme();
        return AlertDialog(
          backgroundColor: theme.rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: theme.textColor.withValues(alpha: 0.15), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: subject.arePrerequisitesMet
                      ? theme.currentClassGreen.withValues(alpha: 0.15)
                      : theme.errorRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  subject.arePrerequisitesMet ? Icons.layers_rounded : Icons.warning_amber_rounded,
                  color: subject.arePrerequisitesMet ? theme.currentClassGreen : theme.errorRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tárgy Előkövetelmények',
                      style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subject.name,
                      style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subject.prerequisites.isEmpty)
                Text(
                  'Ennek a tantárgynak nincsen előkövetelménye.',
                  style: TextStyle(color: theme.textColor.withValues(alpha: 0.8), fontSize: 13),
                )
              else ...[
                Text(
                  'A tantárgy felvételéhez szükséges teljesíteni:',
                  style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final prereq in subject.prerequisites)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: subject.arePrerequisitesMet
                          ? theme.currentClassGreen.withValues(alpha: 0.08)
                          : theme.errorRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: subject.arePrerequisitesMet
                            ? theme.currentClassGreen.withValues(alpha: 0.3)
                            : theme.errorRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          subject.arePrerequisitesMet ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: subject.arePrerequisitesMet ? theme.currentClassGreen : theme.errorRed,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            prereq,
                            style: TextStyle(
                              color: isDark ? Colors.white : theme.textColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          subject.arePrerequisitesMet ? 'Teljesítve' : 'HIÁNYZIK',
                          style: TextStyle(
                            color: subject.arePrerequisitesMet ? theme.currentClassGreen : theme.errorRed,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Bezárás', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showCommitDialog() {
    AppHaptics.mediumImpact();
    final colliding = _getCollidingCourseIds();
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: theme.textColor.withValues(alpha: 0.15), width: 1.2),
          ),
          title: Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: theme.currentClassGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tárgyfelvétel megerősítése',
                  style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (colliding.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.errorRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.errorRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${colliding.length} db kurzus ütközik az órarendben! Kérjük ellenőrizd a kiválasztott idősávokat.',
                          style: TextStyle(color: theme.errorRed, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'A kiválasztott ${_selectedCourseIds.length} db kurzus helyi tervezőben van rögzítve.',
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.8), fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: theme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Biztonsági szimulációs mód aktív: az éles szerver nem módosul, amíg a hivatalos API végpontok nincsenek jóváhagyva.',
                        style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Mégsem', style: TextStyle(color: theme.textColor.withValues(alpha: 0.7))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.currentClassGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Fluttertoast.showToast(
                  msg: "🎉 Tárgyfelvételi köteg szimuláció sikeresen véglegesítve!",
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: theme.rootBackground,
                  textColor: theme.textColor,
                );
              },
              child: Text(
                'Igen, véglegesítés',
                style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();
    final collidingIds = _getCollidingCourseIds();
    final delayedSubjects = _getDelayedMandatorySubjects();
    final filteredSubjects = _getFilteredSubjects();

    int totalCredits = 0;
    for (final s in _subjects) {
      if (s.courses.any((c) => _selectedCourseIds.contains(c.id))) {
        totalCredits += s.credits;
      }
    }

    final shouldCollapseTopBar = _isExclusiveFullscreen && !_isListView;

    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: shouldCollapseTopBar
          ? null
          : AppBar(
              backgroundColor: theme.rootBackground,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F47D0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TEST',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tárgyfelvétel',
                        style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    'Ajánlott félév: $_studentCurrentSemester. félév • Mintatanterv',
                    style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11),
                  ),
                ],
              ),
              actions: [
                // Teljes képernyő gomb
                IconButton(
                  tooltip: _isExclusiveFullscreen ? 'Kilépés a teljes képernyőből' : 'Exkluzív teljes képernyő',
                  icon: Icon(
                    _isExclusiveFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: _isExclusiveFullscreen ? theme.currentClassGreen : theme.textColor,
                    size: 24,
                  ),
                  onPressed: _toggleExclusiveFullscreen,
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            // --- FELSŐ VEZÉRLŐSÁV: Normál nézetben teljes panel, teljes képernyős naptárban kompakt lebegő sáv ---
            if (shouldCollapseTopBar)
              _buildFullscreenFloatingPill(theme, isDark)
            else
              _buildTopControls(theme, isDark),

            // --- TARTALOM ---
            Expanded(
              child: _isListView
                  ? _buildListView(delayedSubjects, filteredSubjects, theme, isDark)
                  : _buildGridView(collidingIds, theme, isDark),
            ),

            // --- LEBEGŐ ALSÓ STAGING SÁV (KOSÁR) ---
            _buildBottomStagingBar(totalCredits, collidingIds.length, theme, isDark),
          ],
        ),
      ),
    );
  }

  // --- LEBEGŐ MINIMÁL SÁV TELJES KÉPERNYŐS NAPTÁRHOZ ---
  Widget _buildFullscreenFloatingPill(AppPalette theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: theme.rootBackground.withValues(alpha: isDark ? 0.90 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Vissza gomb + Cím
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: theme.textColor),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F47D0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('TEST', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Text(
                'Tárgyfelvétel',
                style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),

          // Félév címke + Nézetváltó + Kilépés a teljes képernyőből
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F47D0).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _filterSemester == null ? 'Összes félév' : '$_filterSemester. félév',
                  style: const TextStyle(color: Color(0xFF0F47D0), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              // Váltás lista nézetre
              InkWell(
                onTap: () {
                  AppHaptics.lightImpact();
                  setState(() => _isListView = true);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt_rounded, size: 14, color: theme.textColor),
                      const SizedBox(width: 4),
                      Text('Lista', style: TextStyle(color: theme.textColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Kilépés a teljes képernyőből
              InkWell(
                onTap: _toggleExclusiveFullscreen,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: theme.currentClassGreen.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fullscreen_exit_rounded, size: 18, color: theme.currentClassGreen),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- FELSŐ VEZÉRLŐK: NÉZETVÁLTÓ + FÉLÉVEK + KERESŐ ---
  Widget _buildTopControls(AppPalette theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        color: theme.rootBackground,
        border: Border(bottom: BorderSide(color: theme.textColor.withValues(alpha: 0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Nézetválasztó tabok (Neptun Lista vs Heti Rács)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      AppHaptics.lightImpact();
                      setState(() => _isListView = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isListView
                            ? (isDark ? theme.secondary : const Color(0xFF0F47D0))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _isListView
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            size: 16,
                            color: _isListView ? Colors.white : theme.textColor.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Neptun Lista nézet',
                            style: TextStyle(
                              color: _isListView ? Colors.white : theme.textColor.withValues(alpha: 0.7),
                              fontSize: 12.5,
                              fontWeight: _isListView ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      AppHaptics.lightImpact();
                      setState(() => _isListView = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isListView
                            ? (isDark ? theme.secondary : const Color(0xFF0F47D0))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_isListView
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 16,
                            color: !_isListView ? Colors.white : theme.textColor.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Heti Órarendi rács',
                            style: TextStyle(
                              color: !_isListView ? Colors.white : theme.textColor.withValues(alpha: 0.7),
                              fontSize: 12.5,
                              fontWeight: !_isListView ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. Dinamikus Tantervi Félév Legördülő + Típus választó
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: isDark ? 0.06 : 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _filterSemester,
                      isExpanded: true,
                      dropdownColor: theme.rootBackground,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: theme.textColor.withValues(alpha: 0.7)),
                      style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 12, fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('📅 Minden félév', style: TextStyle(color: isDark ? Colors.white : theme.textColor)),
                        ),
                        for (int s = 1; s <= _maxCurriculumSemester; s++)
                          DropdownMenuItem<int?>(
                            value: s,
                            child: Text(
                              s == _studentCurrentSemester ? '⭐ $s. félév (Aktuális)' : '$s. félév',
                              style: TextStyle(
                                color: s == _studentCurrentSemester
                                    ? (isDark ? const Color(0xFF58A6FF) : const Color(0xFF0F47D0))
                                    : (isDark ? Colors.white : theme.textColor),
                                fontWeight: s == _studentCurrentSemester ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        AppHaptics.lightImpact();
                        setState(() => _filterSemester = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: isDark ? 0.06 : 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSubjectType,
                    dropdownColor: theme.rootBackground,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: theme.textColor.withValues(alpha: 0.7)),
                    style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 12, fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'Mintatantervi', child: Text('Mintatantervi')),
                      DropdownMenuItem(value: 'Szabadon választható', child: Text('Szabadon vál.')),
                      DropdownMenuItem(value: 'Összes', child: Text('Összes típus')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        AppHaptics.lightImpact();
                        setState(() => _selectedSubjectType = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Hallgatói Tárgykategória szűrő kapszulák (Python logika szerint)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryFilterChip(
                  SubjectFilterCategory.all,
                  'Mind (${_subjects.length})',
                  theme,
                  isDark,
                ),
                _buildCategoryFilterChip(
                  SubjectFilterCategory.suggested,
                  '⭐ Ajánlott (${_subjects.where((s) => _classifySubject(s) == SubjectClassification.suggested).length})',
                  theme,
                  isDark,
                ),
                _buildCategoryFilterChip(
                  SubjectFilterCategory.delayed,
                  '🚨 Elmaradt / Bukott (${_subjects.where((s) => _classifySubject(s) == SubjectClassification.delayed).length})',
                  theme,
                  isDark,
                  isWarning: true,
                ),
                _buildCategoryFilterChip(
                  SubjectFilterCategory.future,
                  '⚡ Előrehozható (${_subjects.where((s) => _classifySubject(s) == SubjectClassification.future).length})',
                  theme,
                  isDark,
                  isFuture: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(
    SubjectFilterCategory category,
    String label,
    AppPalette theme,
    bool isDark, {
    bool isWarning = false,
    bool isFuture = false,
  }) {
    final isSelected = _filterCategory == category;
    Color activeColor = const Color(0xFF0F47D0);
    if (isWarning) activeColor = theme.errorRed;
    if (isFuture) activeColor = Colors.purple;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isWarning ? theme.errorRed : (isFuture ? Colors.purple : theme.textColor.withValues(alpha: 0.8))),
          ),
        ),
        selectedColor: activeColor,
        backgroundColor: isWarning
            ? theme.errorRed.withValues(alpha: isDark ? 0.12 : 0.06)
            : (isFuture ? Colors.purple.withValues(alpha: isDark ? 0.12 : 0.06) : theme.textColor.withValues(alpha: isDark ? 0.06 : 0.04)),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isWarning ? theme.errorRed.withValues(alpha: 0.3) : theme.textColor.withValues(alpha: 0.1)),
          width: 1.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onSelected: (_) {
          AppHaptics.lightImpact();
          setState(() {
            _filterCategory = category;
          });
        },
      ),
    );
  }

  // --- 1. NÉZET: NEPTUN LISTA (Pontosan mint a feltöltött képeken) ---
  Widget _buildListView(List<SubjectData> delayedSubjects, List<SubjectData> subjects, AppPalette theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      children: [
        // Keresőmező
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.textColor.withValues(alpha: isDark ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tárgykód / Tárgynév keresése...',
              hintStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.4), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: theme.textColor.withValues(alpha: 0.5)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // 2. A OPCIÓ: Kiemelt "CSÚSZÁS / ELMARADT TÁRGYAK" doboz a tetején!
        if (delayedSubjects.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.errorRed.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.errorRed.withValues(alpha: 0.4), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: theme.errorRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ELMARADT KÖTELEZŐ TÁRGYAK (CSÚSZÁS VESZÉLY!)',
                        style: TextStyle(
                          color: theme.errorRed,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.errorRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${delayedSubjects.length} db',
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Az alábbi tárgyak korábbi félévből maradtak el vagy újrafelvételt igényelnek. A mintatanterv szerint prioritást élveznek:',
                  style: TextStyle(color: theme.textColor.withValues(alpha: 0.75), fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                for (final delayedSub in delayedSubjects) _buildSubjectCard(delayedSub, theme, isDark, isDelayedHighlight: true),
              ],
            ),
          ),
        ],

        // Rendszeres tantárgyak listája (Akkordeon nézet)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TANTÁRGYAK (${subjects.length})',
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            Row(
              children: [
                Icon(Icons.sort_rounded, size: 14, color: theme.textColor.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  'Kredit szerint csökkenő',
                  style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (subjects.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Nincs a megadott szűrésnek megfelelő tantárgy.',
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.5), fontSize: 13),
              ),
            ),
          )
        else
          for (final sub in subjects) _buildSubjectCard(sub, theme, isDark),
      ],
    );
  }

  // Tantárgy kártya akkordeon (Pontosan a media_1792434239894_d76f0856.png szerint)
  Widget _buildSubjectCard(SubjectData subject, AppPalette theme, bool isDark, {bool isDelayedHighlight = false}) {
    final isExpanded = _expandedSubjectIds.contains(subject.id);
    final isRegistered = subject.isRegistered || subject.courses.any((c) => _selectedCourseIds.contains(c.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? theme.secondary.withValues(alpha: 0.35) : theme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDelayedHighlight
              ? theme.errorRed.withValues(alpha: 0.6)
              : (isExpanded ? theme.primary : theme.textColor.withValues(alpha: 0.08)),
          width: isDelayedHighlight ? 1.4 : (isExpanded ? 1.2 : 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fejléc sor (mindig látható)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              AppHaptics.lightImpact();
              setState(() {
                if (isExpanded) {
                  _expandedSubjectIds.remove(subject.id);
                } else {
                  _expandedSubjectIds.add(subject.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                subject.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : theme.textColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final classification = _classifySubject(subject);
                                if (isDelayedHighlight || classification == SubjectClassification.delayed) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.errorRed,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        subject.hasFailedBefore ? '❌ BUKOTT!' : '🚨 CSÚSZÁS!',
                                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  );
                                } else if (classification == SubjectClassification.future) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '⚡ ELŐREHOZOTT (${subject.semester}. félév)',
                                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${subject.subjectType} • ${subject.credits} kredit • Ajánlott félév: ${subject.semester} • ${subject.requirementType} • ${subject.code}',
                          style: TextStyle(
                            color: theme.textColor.withValues(alpha: isDark ? 0.65 : 0.75),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Zöld pipa ikon ha már fel van véve
                  if (isRegistered) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00D285),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Lenítás nyíl
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: theme.textColor.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Lenyitott kurzustartalom (Pontosan mint a media_1792434251711_9aed7e52.png képen!)
          if (isExpanded) ...[
            Divider(height: 1, color: theme.textColor.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Akciógombok sáv: Tárgy felvétele (kék gomb), Tárgy előkövetelmények, Részletek
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F47D0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          AppHaptics.mediumImpact();
                          Fluttertoast.showToast(msg: "Tárgy kurzusai hozzáadva a tervezőhöz");
                        },
                        child: const Text('Tárgy felvétele', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: theme.textColor.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: Icon(Icons.layers_rounded, size: 14, color: theme.textColor),
                        label: Text('Tárgy előkövetelmények', style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 11.5)),
                        onPressed: () => _showPrerequisitesDialog(subject),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: theme.textColor.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: Icon(Icons.article_outlined, size: 14, color: theme.textColor),
                        label: Text('Tárgy részletek', style: TextStyle(color: isDark ? Colors.white : theme.textColor, fontSize: 11.5)),
                        onPressed: () => _showSubjectDetailsDialog(subject),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Kurzusok csoportosítása
                  _buildCourseGroupSection('Elmélet - Egy kurzus választása kötelező.', subject, 'Elmélet', theme, isDark),
                  const SizedBox(height: 8),
                  _buildCourseGroupSection(
                    subject.name == 'Szakdolgozat'
                        ? 'Szakdolgozat konzulens - Egy témavezető választása kötelező.'
                        : 'Labor / Gyakorlat - Egy kurzus választása kötelező.',
                    subject,
                    subject.name == 'Szakdolgozat' ? 'Szakdolgozat konzulens' : 'Labor',
                    theme,
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseGroupSection(String headerTitle, SubjectData subject, String targetType, AppPalette theme, bool isDark) {
    final matchedCourses = subject.courses.where((c) => c.type.contains(targetType) || targetType == 'Labor' && c.type.contains('Gyakorlat')).toList();
    if (matchedCourses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerTitle,
          style: TextStyle(
            color: isDark ? Colors.white : theme.textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        for (final course in matchedCourses) _buildCourseRow(course, subject, theme, isDark),
      ],
    );
  }

  // Kurzussor Switch kapcsolóval + Long-press részletekkel
  Widget _buildCourseRow(CourseInstance course, SubjectData subject, AppPalette theme, bool isDark) {
    final isSelected = _selectedCourseIds.contains(course.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.primary.withValues(alpha: isDark ? 0.18 : 0.08)
            : theme.textColor.withValues(alpha: isDark ? 0.04 : 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? theme.primary : theme.textColor.withValues(alpha: 0.06),
          width: isSelected ? 1.2 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _toggleCourse(course, subject),
          onLongPress: () => _showCourseDetailsDialog(course, subject),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Jelölőnégyzet / rádiógomb ikon
                Icon(
                  isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: isSelected ? theme.primary : theme.textColor.withValues(alpha: 0.4),
                  size: 20,
                ),
                const SizedBox(width: 10),

                // Kurzus adatok
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            course.code,
                            style: TextStyle(
                              color: isDark ? Colors.white : theme.textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: theme.textColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              course.formatTimeRange(),
                              style: TextStyle(
                                color: theme.textColor.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${course.type} • ${course.tutor} • ${course.room} • ${course.slots}',
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: isDark ? 0.6 : 0.75),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Info gomb
                IconButton(
                  tooltip: 'Kurzus részletek (vagy hosszan nyomva)',
                  icon: Icon(Icons.info_outline_rounded, size: 18, color: theme.textColor.withValues(alpha: 0.5)),
                  onPressed: () => _showCourseDetailsDialog(course, subject),
                ),

                // Jobb oldal: Tervezőhöz adás kapcsoló
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isSelected,
                    activeThumbColor: const Color(0xFF0F47D0),
                    onChanged: (_) => _toggleCourse(course, subject),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 2. NÉZET: HETI ÓRARENDI RÁCS ---
  Widget _buildGridView(Set<String> collidingIds, AppPalette theme, bool isDark) {
    final dayNames = ['Hétfő', 'Kedd', 'Szerda', 'Csütörtök', 'Péntek'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = _isWeekView ? max(constraints.maxWidth - 48, 520.0) : constraints.maxWidth - 48;

        return Column(
          children: [
            // 1. RÖGZÍTETT (STICKY) FEJLÉC SÁV: Nézetváltó sarok + Napok (Hétfő-Péntek)
            Container(
              decoration: BoxDecoration(
                color: theme.rootBackground,
                border: Border(bottom: BorderSide(color: theme.textColor.withValues(alpha: 0.12))),
              ),
              child: Row(
                children: [
                  // Bal felső sarokgomb: Heti / Napi nézet gyorsváltó
                  InkWell(
                    onTap: () {
                      AppHaptics.lightImpact();
                      setState(() => _isWeekView = !_isWeekView);
                    },
                    child: Container(
                      width: 48,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: theme.textColor.withValues(alpha: 0.08))),
                      ),
                      child: Tooltip(
                        message: _isWeekView ? 'Váltás napi nézetre' : 'Váltás heti nézetre',
                        child: Icon(
                          _isWeekView ? Icons.calendar_view_week_rounded : Icons.calendar_view_day_rounded,
                          size: 16,
                          color: const Color(0xFF0F47D0),
                        ),
                      ),
                    ),
                  ),

                  // Görgethető napfejléc sáv (szinkronban a ráccsal!)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _headerHorizontalController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(), // a rács görgeti automatikusan
                      child: SizedBox(
                        width: contentWidth,
                        child: Row(
                          children: [
                            for (int day = 0; day < 5; day++)
                              if (_isWeekView || day == _selectedDayIndex)
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: theme.textColor.withValues(alpha: isDark ? 0.06 : 0.035),
                                      border: Border(left: BorderSide(color: theme.textColor.withValues(alpha: 0.08))),
                                    ),
                                    child: Text(
                                      dayNames[day],
                                      style: TextStyle(
                                        color: isDark ? Colors.white : theme.textColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Napi nézet esetén vízszintes napválasztó kapszulák
            if (!_isWeekView)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                color: theme.rootBackground,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(dayNames[i], style: const TextStyle(fontSize: 11)),
                          selected: _selectedDayIndex == i,
                          onSelected: (_) {
                            AppHaptics.lightImpact();
                            setState(() => _selectedDayIndex = i);
                          },
                        ),
                      ),
                  ],
                ),
              ),

            // 2. FÜGGŐLEGESEN GÖRGETHETŐ IDŐSÁV ÉS KURZUSOK
            Expanded(
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bal oldali időoszlop (06:00 - 22:00)
                    SizedBox(
                      width: 48,
                      child: Column(
                        children: [
                          for (int hour = _startHour; hour <= _endHour; hour++)
                            SizedBox(
                              height: _hourHeight,
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.textColor.withValues(alpha: 0.45),
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Kurzuskártyák oszlopai
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: contentWidth,
                          child: Row(
                            children: [
                              for (int day = 0; day < 5; day++)
                                if (_isWeekView || day == _selectedDayIndex)
                                  Expanded(child: _buildDayColumn(day, dayNames[day], collidingIds, theme, isDark)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayColumn(int day, String dayName, Set<String> collidingIds, AppPalette theme, bool isDark) {
    // Csak a fix időponttal rendelkező kurzusokat helyezzük el a rácsra
    final dayCourses = <_CourseLayoutItem>[];
    for (final s in _subjects) {
      for (final c in s.courses) {
        if (c.day == day && c.hasTimetable) {
          dayCourses.add(_CourseLayoutItem(c, s));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.textColor.withValues(alpha: 0.08))),
      ),
      child: SizedBox(
            height: (_endHour - _startHour + 1) * _hourHeight,
            child: Stack(
              children: [
                // Óravonalak
                for (int hour = _startHour; hour <= _endHour; hour++)
                  Positioned(
                    top: (hour - _startHour) * _hourHeight,
                    left: 0,
                    right: 0,
                    child: Divider(height: 1, color: theme.textColor.withValues(alpha: 0.06)),
                  ),

                // Kurzus kártyák
                for (final item in dayCourses) _buildCourseGridBlock(item, collidingIds, theme, isDark),
              ],
            ),
          ),
    );
  }

  Widget _buildCourseGridBlock(_CourseLayoutItem item, Set<String> collidingIds, AppPalette theme, bool isDark) {
    final c = item.course;
    final isSelected = _selectedCourseIds.contains(c.id);
    final isColliding = collidingIds.contains(c.id);

    final startMin = c.startMinutes - (_startHour * 60);
    final top = (startMin / 60.0) * _hourHeight;
    final height = max(48.0, (c.durationMinutes / 60.0) * _hourHeight);

    Color blockBg;
    Color blockBorder;
    if (isColliding && isSelected) {
      blockBg = theme.errorRed.withValues(alpha: isDark ? 0.35 : 0.20);
      blockBorder = theme.errorRed;
    } else if (isSelected) {
      blockBg = const Color(0xFF0F47D0).withValues(alpha: isDark ? 0.40 : 0.25);
      blockBorder = const Color(0xFF0F47D0);
    } else {
      blockBg = theme.textColor.withValues(alpha: isDark ? 0.06 : 0.04);
      blockBorder = theme.textColor.withValues(alpha: 0.12);
    }

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: GestureDetector(
        onTap: () => _toggleCourse(c, item.subject),
        onLongPress: () => _showCourseDetailsDialog(c, item.subject),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: blockBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: blockBorder, width: isSelected ? 1.4 : 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.subject.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : theme.textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isColliding && isSelected)
                    const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 12),
                ],
              ),
              Text(
                '${c.type} • ${c.room}',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.7),
                  fontSize: 8.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LEBEGŐ ALSÓ STAGING SÁV (KOSÁR) ---
  Widget _buildBottomStagingBar(int totalCredits, int collisions, AppPalette theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.rootBackground,
        border: Border(top: BorderSide(color: theme.textColor.withValues(alpha: 0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Statisztikák
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '$totalCredits',
                    style: TextStyle(
                      color: isDark ? Colors.white : theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    ' / 30 kredit felvéve',
                    style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${_selectedCourseIds.length} kurzus',
                    style: TextStyle(color: theme.textColor.withValues(alpha: 0.55), fontSize: 11),
                  ),
                  if (collisions > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• ⚡ $collisions ütközés',
                      style: TextStyle(color: theme.errorRed, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    Text(
                      '• ✓ 0 ütközés',
                      style: TextStyle(color: theme.currentClassGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Véglegesítés gomb
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F47D0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
            label: const Text(
              'Véglegesítés',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: _showCommitDialog,
          ),
        ],
      ),
    );
  }
}
