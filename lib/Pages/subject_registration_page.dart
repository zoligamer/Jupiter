import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../colors.dart';
import '../haptics.dart';
import '../Widgets/led_marquee_text.dart';

class CourseInstance {
  final String id;
  final String code;
  final String type; // Elmélet, Labor, Gyakorlat, Testnevelés
  final int day; // 0: Mon, 1: Tue, 2: Wed, 3: Thu, 4: Fri
  final TimeOfDay start;
  final TimeOfDay end;
  final String room;
  final String tutor;
  final String slots;
  final bool isMandatory;
  final bool isAlternate;
  final String groupKey;

  const CourseInstance({
    required this.id,
    required this.code,
    required this.type,
    required this.day,
    required this.start,
    required this.end,
    required this.room,
    required this.tutor,
    required this.slots,
    this.isMandatory = true,
    this.isAlternate = false,
    required this.groupKey,
  });

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes => end.hour * 60 + end.minute;
  int get durationMinutes => endMinutes - startMinutes;

  String formatTimeRange() {
    final sh = start.hour.toString().padLeft(2, '0');
    final sm = start.minute.toString().padLeft(2, '0');
    final eh = end.hour.toString().padLeft(2, '0');
    final em = end.minute.toString().padLeft(2, '0');
    return '$sh:$sm - $eh:$em';
  }
}

class SubjectData {
  final String id;
  final String code;
  final String name;
  final int credits;
  final bool isRequired;
  final List<CourseInstance> courses;

  const SubjectData({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
    required this.isRequired,
    required this.courses,
  });
}

class PeSubcourse {
  final String id;
  final String name;
  final int day;
  final String dayName;
  final String timeRange;
  final String room;
  final String tutor;
  final String slots;

  const PeSubcourse({
    required this.id,
    required this.name,
    required this.day,
    required this.dayName,
    required this.timeRange,
    required this.room,
    required this.tutor,
    required this.slots,
  });
}

class _CourseLayoutItem {
  final CourseInstance course;
  final SubjectData subject;
  int columnIndex = 0;
  int totalColumns = 1;

  _CourseLayoutItem(this.course, this.subject);
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

  bool _isWeekView = true;
  int _selectedDayIndex = 0; // 0 = Hétfő
  final Set<String> _selectedCourseIds = {'c-101', 'c-201', 'c-301', 'c-302'};
  PeSubcourse? _selectedPe;

  late final List<SubjectData> _subjects;
  late final List<PeSubcourse> _peSubcourses;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initSampleData();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _initSampleData() {
    _subjects = [
      SubjectData(
        id: "sub-1",
        code: "BBPREA",
        name: "Programozás",
        credits: 5,
        isRequired: true,
        courses: const [
          CourseInstance(
            id: "c-101",
            code: "BBPREA2",
            type: "Elmélet",
            day: 1, // Kedd
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 8, minute: 45),
            room: "FR.2.207",
            tutor: "Dér Attila Tibor",
            slots: "28/38",
            isMandatory: true,
            isAlternate: false,
            groupKey: "prog-elm",
          ),
          CourseInstance(
            id: "c-102",
            code: "BBPRL2",
            type: "Labor 1",
            day: 1, // Kedd
            start: TimeOfDay(hour: 14, minute: 25),
            end: TimeOfDay(hour: 17, minute: 0),
            room: "FR.2.208",
            tutor: "Dér Attila Tibor",
            slots: "18/20",
            isMandatory: true,
            isAlternate: true,
            groupKey: "prog-lab",
          ),
          CourseInstance(
            id: "c-103",
            code: "BBPRL2-B",
            type: "Labor 2 (Alternatív)",
            day: 2, // Szerda
            start: TimeOfDay(hour: 14, minute: 25),
            end: TimeOfDay(hour: 17, minute: 0),
            room: "FR.2.209",
            tutor: "Kovács László",
            slots: "14/20",
            isMandatory: true,
            isAlternate: true,
            groupKey: "prog-lab",
          ),
        ],
      ),
      SubjectData(
        id: "sub-2",
        code: "BBDVEA",
        name: "Dokumentumvédelem és admin. biztonság",
        credits: 4,
        isRequired: true,
        courses: const [
          CourseInstance(
            id: "c-201",
            code: "BBDVEA",
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
            code: "BBDVL1",
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
      SubjectData(
        id: "sub-3",
        code: "BBVNEA",
        name: "Vezetékes és vezetéknélküli hálózatok",
        credits: 5,
        isRequired: true,
        courses: const [
          CourseInstance(
            id: "c-301",
            code: "BBVNEA",
            type: "Elmélet",
            day: 3, // Csütörtök
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 8, minute: 45),
            room: "FR.2.102",
            tutor: "Molnár Tamás",
            slots: "40/50",
            isMandatory: true,
            isAlternate: false,
            groupKey: "hal-elm",
          ),
          CourseInstance(
            id: "c-302",
            code: "BBVNGY2",
            type: "Gyakorlat",
            day: 3, // Csütörtök
            start: TimeOfDay(hour: 8, minute: 55),
            end: TimeOfDay(hour: 9, minute: 40),
            room: "FR.2.102",
            tutor: "Molnár Tamás",
            slots: "22/25",
            isMandatory: true,
            isAlternate: false,
            groupKey: "hal-gyak",
          ),
          CourseInstance(
            id: "c-303",
            code: "BBVNL2",
            type: "Labor",
            day: 3, // Csütörtök
            start: TimeOfDay(hour: 9, minute: 50),
            end: TimeOfDay(hour: 11, minute: 30),
            room: "FR.L.12",
            tutor: "Molnár Tamás",
            slots: "17/20",
            isMandatory: true,
            isAlternate: false,
            groupKey: "hal-lab",
          ),
        ],
      ),
      SubjectData(
        id: "sub-4",
        code: "BBINEA",
        name: "Informatika II. (laborgyak)",
        credits: 4,
        isRequired: false,
        courses: const [
          CourseInstance(
            id: "c-401",
            code: "BBINEA",
            type: "Elmélet",
            day: 2, // Szerda
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 9, minute: 40),
            room: "FR.1.205",
            tutor: "Nagy Zoltán",
            slots: "35/40",
            isMandatory: false,
            isAlternate: false,
            groupKey: "inf-elm",
          ),
          CourseInstance(
            id: "c-402",
            code: "BBINL1",
            type: "Labor",
            day: 1, // Kedd
            start: TimeOfDay(hour: 8, minute: 55),
            end: TimeOfDay(hour: 12, minute: 25),
            room: "FR.L.02",
            tutor: "Nagy Zoltán",
            slots: "20/22",
            isMandatory: false,
            isAlternate: false,
            groupKey: "inf-lab",
          ),
        ],
      ),
      SubjectData(
        id: "sub-5",
        code: "BBVDEA",
        name: "Adatvédelem, adatbiztonság",
        credits: 3,
        isRequired: false,
        courses: const [
          CourseInstance(
            id: "c-501",
            code: "BBVDEA",
            type: "Elmélet (Ütközés minta)",
            day: 3, // Csütörtök
            start: TimeOfDay(hour: 8, minute: 55),
            end: TimeOfDay(hour: 10, minute: 30),
            room: "FR.2.204",
            tutor: "Varga Béla",
            slots: "25/30",
            isMandatory: false,
            isAlternate: false,
            groupKey: "adat-elm",
          ),
        ],
      ),
    ];

    _peSubcourses = const [
      PeSubcourse(
        id: "pe-1",
        name: "Futsal",
        day: 3,
        dayName: "Csütörtök",
        timeRange: "13:30 - 15:10",
        room: "Sportcsarnok",
        tutor: "Horváth Ferenc",
        slots: "18/25",
      ),
      PeSubcourse(
        id: "pe-2",
        name: "Úszás",
        day: 1,
        dayName: "Kedd",
        timeRange: "17:15 - 18:45",
        room: "Uszoda",
        tutor: "Kelemen Anna",
        slots: "22/25",
      ),
      PeSubcourse(
        id: "pe-3",
        name: "Konditerem / Fitnesz",
        day: 2,
        dayName: "Szerda",
        timeRange: "10:00 - 11:30",
        room: "Fitness Terem",
        tutor: "Tóth Gábor",
        slots: "15/20",
      ),
      PeSubcourse(
        id: "pe-4",
        name: "Kosárlabda",
        day: 4,
        dayName: "Péntek",
        timeRange: "14:00 - 15:30",
        room: "Kistornaterem",
        tutor: "Horváth Ferenc",
        slots: "12/20",
      ),
    ];
  }

  // Detect collisions among selected courses
  Set<String> _getCollidingCourseIds() {
    final colliding = <String>{};
    final allSelected = <CourseInstance>[];

    for (final s in _subjects) {
      for (final c in s.courses) {
        if (_selectedCourseIds.contains(c.id)) {
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

  bool _isCourseGreyedOut(CourseInstance course, SubjectData subject) {
    if (_selectedCourseIds.contains(course.id)) return false;
    return subject.courses.any((c) =>
        c.groupKey == course.groupKey &&
        c.id != course.id &&
        _selectedCourseIds.contains(c.id));
  }

  void _toggleCourse(CourseInstance course, SubjectData subject) {
    AppHaptics.lightImpact();
    setState(() {
      if (_selectedCourseIds.contains(course.id)) {
        _selectedCourseIds.remove(course.id);
      } else {
        // Mutex: remove competing courses with same groupKey
        for (final c in subject.courses) {
          if (c.groupKey == course.groupKey && c.id != course.id) {
            _selectedCourseIds.remove(c.id);
          }
        }
        _selectedCourseIds.add(course.id);
      }
    });
  }

  void _showCourseDetailsDialog(CourseInstance course, SubjectData subject) {
    AppHaptics.mediumImpact();
    final isSelected = _selectedCourseIds.contains(course.id);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.getTheme().rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.getTheme().primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school_rounded, color: AppColors.getTheme().primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject.name,
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Tárgykód', subject.code),
              _buildDetailRow('Kurzuskód & Típus', '${course.code} (${course.type})'),
              _buildDetailRow('Oktató', course.tutor),
              _buildDetailRow('Terem', course.room, highlight: true),
              _buildDetailRow('Időpont', course.formatTimeRange()),
              _buildDetailRow('Férőhely & Létszám', '${course.slots} fő'),
              _buildDetailRow(
                'Követelmény',
                '${subject.isRequired ? "Kötelező" : "Választható"} (${subject.credits} kredit)',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Bezárás',
                style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? AppColors.getTheme().errorRed
                    : AppColors.getTheme().currentClassGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _toggleCourse(course, subject);
              },
              child: Text(
                isSelected ? 'Leadás / Eltávolítás' : 'Kiválasztás',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: highlight
                    ? AppColors.getTheme().roomHighlightColor
                    : AppColors.getTheme().textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPeDialog() {
    AppHaptics.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.getTheme().rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              const Text('🏋️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Testnevelés I. Sportágválasztás',
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _peSubcourses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pe = _peSubcourses[index];
                final isSelected = _selectedPe?.id == pe.id;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    AppHaptics.lightImpact();
                    setState(() {
                      _selectedPe = isSelected ? null : pe;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.getTheme().currentClassGreen.withValues(alpha: 0.12)
                          : AppColors.getTheme().textColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.getTheme().currentClassGreen
                            : AppColors.getTheme().textColor.withValues(alpha: 0.1),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                pe.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.getTheme().textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${pe.dayName} ${pe.timeRange}',
                              style: TextStyle(
                                color: AppColors.getTheme().primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '🏟️ ${pe.room} • 👨‍🏫 ${pe.tutor}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '👥 ${pe.slots}',
                              style: TextStyle(
                                color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Mégsem',
                style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSubmitConfirmationDialog() {
    AppHaptics.heavyImpact();
    final colliding = _getCollidingCourseIds();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.getTheme().rootBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: AppColors.getTheme().currentClassGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tárgyfelvétel megerősítése',
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                    color: AppColors.getTheme().errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getTheme().errorRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.getTheme().errorRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${colliding.length} db kurzus ütközik az órarendben! Ennek ellenére beküldhető, de ütközést okozhat.',
                          style: TextStyle(
                            color: AppColors.getTheme().errorRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'A kiválasztott ${_selectedCourseIds.length + (_selectedPe != null ? 1 : 0)} db kurzus azonnal elküldésre kerül a Neptun szervernek a helyfoglalásért.',
                style: TextStyle(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Mégsem',
                style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getTheme().currentClassGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Fluttertoast.showToast(
                  msg: "🎉 Tárgyfelvételi köteg sikeresen továbbítva a Neptunba!",
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: AppColors.getTheme().rootBackground,
                  textColor: AppColors.getTheme().textColor,
                );
              },
              child: const Text('Igen, véglegesítés', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final dayNames = ['Hétfő', 'Kedd', 'Szerda', 'Csütörtök', 'Péntek'];
    final collidingIds = _getCollidingCourseIds();

    int totalCredits = 0;
    final selectedSubjectsSet = <String>{};
    for (final s in _subjects) {
      if (s.courses.any((c) => _selectedCourseIds.contains(c.id))) {
        selectedSubjectsSet.add(s.id);
        totalCredits += s.credits;
      }
    }
    if (_selectedPe != null) {
      selectedSubjectsSet.add('pe-sub');
      totalCredits += 1;
    }

    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: AppBar(
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
                    color: const Color(0xFF7158E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'GHOST',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tárgyfelvétel Órarend',
                  style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              'Statikus 06:00–22:00 szimulációs nézet',
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.5), fontSize: 11),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- Controls (Week vs Day mode & Day selectors) ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.rootBackground,
                  border: Border(bottom: BorderSide(color: theme.textColor.withValues(alpha: 0.08))),
                ),
                child: Row(
                  children: [
                    // View Toggle
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: theme.textColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          _buildViewToggleBtn('Heti nézet', _isWeekView, () {
                            AppHaptics.lightImpact();
                            setState(() => _isWeekView = true);
                          }),
                          _buildViewToggleBtn('Napi nézet', !_isWeekView, () {
                            AppHaptics.lightImpact();
                            setState(() => _isWeekView = false);
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Day tabs when in Day view
                    if (!_isWeekView)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(5, (index) {
                              final isSel = _selectedDayIndex == index;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    AppHaptics.lightImpact();
                                    setState(() => _selectedDayIndex = index);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? theme.primary
                                          : theme.textColor.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      dayNames[index],
                                      style: TextStyle(
                                        color: isSel ? Colors.white : theme.textColor.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildLegendItem(theme.errorRed, '! Kötelező'),
                              const SizedBox(width: 8),
                              _buildLegendItem(const Color(0xFFFFA502), '⚠️ Alternatív'),
                              const SizedBox(width: 8),
                              _buildLegendItem(theme.currentClassGreen, '✓ Felvéve'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // --- PE Section Banner ---
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _showPeDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedPe != null
                          ? theme.currentClassGreen.withValues(alpha: 0.1)
                          : const Color(0xFFFF5252).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedPe != null
                            ? theme.currentClassGreen.withValues(alpha: 0.4)
                            : const Color(0xFFFF5252).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (_selectedPe != null ? theme.currentClassGreen : const Color(0xFFFF5252))
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('🏋️', style: TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Testnevelés I. (Félévenként 1 kurzus kötelező)',
                                style: TextStyle(
                                  color: _selectedPe != null ? theme.currentClassGreen : const Color(0xFFFF6B81),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedPe != null
                                    ? 'Kiválasztva: ${_selectedPe!.name} (${_selectedPe!.dayName} ${_selectedPe!.timeRange}, ${_selectedPe!.room})'
                                    : 'Kattints a felvehető sportágak és időpontok megtekintéséhez',
                                style: TextStyle(
                                  color: theme.textColor.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_selectedPe != null ? theme.currentClassGreen : const Color(0xFFFF5252))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedPe != null ? 'Módosítás ❯' : 'Választás ❯',
                            style: TextStyle(
                              color: _selectedPe != null ? theme.currentClassGreen : const Color(0xFFFF6B81),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- Timetable Grid Area ---
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dayCount = _isWeekView ? 5 : 1;
                    const timeColWidth = 50.0;
                    final availableWidth = constraints.maxWidth - timeColWidth;
                    final dayColWidth = _isWeekView
                        ? max(130.0, availableWidth / dayCount)
                        : availableWidth;

                    return SingleChildScrollView(
                      controller: _verticalScrollController,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: timeColWidth + (dayColWidth * dayCount),
                          height: (_endHour - _startHour) * _hourHeight + 36,
                          child: Stack(
                            children: [
                              // 1. Grid Background & Hour lines
                              Positioned.fill(
                                top: 36,
                                child: Row(
                                  children: [
                                    // Time sidebar
                                    SizedBox(
                                      width: timeColWidth,
                                      child: Column(
                                        children: List.generate(_endHour - _startHour, (h) {
                                          final hour = _startHour + h;
                                          return SizedBox(
                                            height: _hourHeight,
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: Text(
                                                '${hour.toString().padLeft(2, '0')}:00',
                                                style: TextStyle(
                                                  color: theme.textColor.withValues(alpha: 0.45),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                    // Day columns background
                                    Expanded(
                                      child: Row(
                                        children: List.generate(dayCount, (index) {
                                          return Container(
                                            width: dayColWidth,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: theme.textColor.withValues(alpha: 0.08),
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              children: List.generate(_endHour - _startHour, (h) {
                                                return Container(
                                                  height: _hourHeight,
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: theme.textColor.withValues(alpha: 0.05),
                                                        style: BorderStyle.solid,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 2. Day Header row
                              Positioned(
                                top: 0,
                                left: timeColWidth,
                                right: 0,
                                height: 36,
                                child: Row(
                                  children: List.generate(dayCount, (index) {
                                    final dIdx = _isWeekView ? index : _selectedDayIndex;
                                    return Container(
                                      width: dayColWidth,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: theme.rootBackground,
                                        border: Border(
                                          left: BorderSide(color: theme.textColor.withValues(alpha: 0.08)),
                                          bottom: BorderSide(color: theme.textColor.withValues(alpha: 0.08)),
                                        ),
                                      ),
                                      child: Text(
                                        dayNames[dIdx],
                                        style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),

                              // 3. Render lesson cards
                              ..._buildLessonCards(
                                timeColWidth: timeColWidth,
                                dayColWidth: dayColWidth,
                                collidingIds: collidingIds,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Padding for bottom staging bar
              const SizedBox(height: 72),
            ],
          ),

          // --- Floating Staging Cart & Submit Bar ---
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.rootBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${selectedSubjectsSet.length} tárgy • ${_selectedCourseIds.length + (_selectedPe != null ? 1 : 0)} kurzus',
                              style: TextStyle(
                                color: theme.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($totalCredits kredit)',
                              style: TextStyle(
                                color: theme.currentClassGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (collidingIds.isNotEmpty)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: theme.errorRed,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '⚡ ${collidingIds.length} ütközés',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Átfedés van a kijelölt órák között',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: theme.errorRed, fontSize: 11),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Ütközésmentes órarendi összeállítás',
                            style: TextStyle(
                              color: theme.textColor.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.currentClassGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _showSubmitConfirmationDialog,
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    label: const Text(
                      'Véglegesítés',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLessonCards({
    required double timeColWidth,
    required double dayColWidth,
    required Set<String> collidingIds,
  }) {
    final widgets = <Widget>[];

    // Group courses by day (0 to 4)
    final coursesByDay = <int, List<_CourseLayoutItem>>{};
    for (final subject in _subjects) {
      for (final course in subject.courses) {
        if (!_isWeekView && course.day != _selectedDayIndex) continue;
        coursesByDay.putIfAbsent(course.day, () => []).add(_CourseLayoutItem(course, subject));
      }
    }

    // For each day, compute overlapping clusters and assign columns
    for (final entry in coursesByDay.entries) {
      final dayCourses = entry.value;
      if (dayCourses.isEmpty) continue;

      // Sort by startMinutes, then longer duration first
      dayCourses.sort((a, b) {
        final cmp = a.course.startMinutes.compareTo(b.course.startMinutes);
        if (cmp != 0) return cmp;
        return (b.course.endMinutes - b.course.startMinutes).compareTo(a.course.endMinutes - a.course.startMinutes);
      });

      // Group into overlapping clusters
      final clusters = <List<_CourseLayoutItem>>[];
      List<_CourseLayoutItem> currentCluster = [];
      int clusterEnd = -1;

      for (final item in dayCourses) {
        if (currentCluster.isEmpty) {
          currentCluster.add(item);
          clusterEnd = item.course.endMinutes;
        } else {
          if (item.course.startMinutes < clusterEnd) {
            // Overlaps with current cluster
            currentCluster.add(item);
            if (item.course.endMinutes > clusterEnd) {
              clusterEnd = item.course.endMinutes;
            }
          } else {
            // New cluster
            clusters.add(currentCluster);
            currentCluster = [item];
            clusterEnd = item.course.endMinutes;
          }
        }
      }
      if (currentCluster.isNotEmpty) {
        clusters.add(currentCluster);
      }

      // In each cluster, assign columnIndex and totalColumns using track coloring
      for (final cluster in clusters) {
        final trackEnds = <int>[];
        for (final item in cluster) {
          int assignedTrack = -1;
          for (int t = 0; t < trackEnds.length; t++) {
            if (trackEnds[t] <= item.course.startMinutes) {
              assignedTrack = t;
              trackEnds[t] = item.course.endMinutes;
              break;
            }
          }
          if (assignedTrack == -1) {
            assignedTrack = trackEnds.length;
            trackEnds.add(item.course.endMinutes);
          }
          item.columnIndex = assignedTrack;
        }

        final numCols = max(1, trackEnds.length);
        for (final item in cluster) {
          item.totalColumns = numCols;
        }
      }
    }

    // Now render each layout item
    for (final entry in coursesByDay.entries) {
      for (final item in entry.value) {
        final course = item.course;
        final subject = item.subject;

        final dayColIndex = _isWeekView ? course.day : 0;
        final topOffset = 36.0 + ((course.startMinutes - (_startHour * 60)) / 60.0) * _hourHeight;
        // Ensure cardHeight is at least 48.0 px so 45-min lessons never overflow vertically
        final cardHeight = max(48.0, (course.durationMinutes / 60.0) * _hourHeight);

        final colWidth = (dayColWidth - 4) / item.totalColumns;
        final leftOffset = timeColWidth + (dayColIndex * dayColWidth) + (item.columnIndex * colWidth) + 2;
        final cardWidth = max(28.0, colWidth - 4);

        final isSelected = _selectedCourseIds.contains(course.id);
        final isGreyed = _isCourseGreyedOut(course, subject);
        final isColliding = collidingIds.contains(course.id) && isSelected;

        widgets.add(
          Positioned(
            top: topOffset,
            left: leftOffset,
            width: cardWidth,
            height: cardHeight,
            child: GestureDetector(
              onTap: isGreyed ? null : () => _toggleCourse(course, subject),
              onLongPress: () => _showCourseDetailsDialog(course, subject),
              child: Opacity(
                opacity: isGreyed ? 0.32 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isColliding
                            ? AppColors.getTheme().errorRed.withValues(alpha: 0.22)
                            : AppColors.getTheme().currentClassGreen.withValues(alpha: 0.18))
                        : AppColors.getTheme().textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isColliding
                          ? AppColors.getTheme().errorRed
                          : (isSelected
                              ? AppColors.getTheme().currentClassGreen
                              : (course.isAlternate
                                  ? const Color(0xFFFFA502)
                                  : (subject.isRequired
                                      ? AppColors.getTheme().errorRed
                                      : AppColors.getTheme().textColor.withValues(alpha: 0.12)))),
                      width: isSelected || isColliding ? 1.6 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LedMarqueeText(
                              text: subject.name,
                              style: TextStyle(
                                color: AppColors.getTheme().textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              onTap: isGreyed ? null : () => _toggleCourse(course, subject),
                              onLongPress: () => _showCourseDetailsDialog(course, subject),
                            ),
                          ),
                          const SizedBox(width: 2),
                          if (isColliding)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.getTheme().errorRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cardWidth > 75 ? '⚡ Ütközés' : '⚡',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            )
                          else if (isSelected)
                            Icon(Icons.check_circle_rounded, color: AppColors.getTheme().currentClassGreen, size: 13)
                          else if (course.isAlternate)
                            Icon(Icons.warning_amber_rounded, color: const Color(0xFFFFA502), size: 13)
                          else if (subject.isRequired)
                            Text('!', style: TextStyle(color: AppColors.getTheme().errorRed, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              course.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              course.room,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: AppColors.getTheme().roomHighlightColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildViewToggleBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.getTheme().primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.getTheme().textColor.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6), fontSize: 10),
        ),
      ],
    );
  }
}
