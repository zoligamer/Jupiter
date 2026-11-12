import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';

class QuestionnairesPage extends StatefulWidget {
  const QuestionnairesPage({super.key});

  @override
  State<QuestionnairesPage> createState() => _QuestionnairesPageState();
}

class _QuestionnairesPageState extends State<QuestionnairesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<QuestionnaireItem> _activeQuestionnaires = [];
  List<QuestionnaireItem> _filteredActive = [];
  List<QuestionnaireItem> _finishedQuestionnaires = [];
  List<QuestionnaireItem> _filteredFinished = [];

  bool _isLoadingActive = true;
  bool _isLoadingFinished = true;
  String? _loadingFillId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
          _applySearchFilter();
        });
      }
    });

    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredActive = List.from(_activeQuestionnaires);
      _filteredFinished = List.from(_finishedQuestionnaires);
    } else {
      _filteredActive = _activeQuestionnaires.where((q) {
        return q.subjectName.toLowerCase().contains(_searchQuery) ||
            q.title.toLowerCase().contains(_searchQuery) ||
            q.subjectCode.toLowerCase().contains(_searchQuery);
      }).toList();

      _filteredFinished = _finishedQuestionnaires.where((q) {
        return q.subjectName.toLowerCase().contains(_searchQuery) ||
            q.title.toLowerCase().contains(_searchQuery) ||
            q.subjectCode.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (isRefresh) {
      AppHaptics.lightImpact();
    }

    setState(() {
      _isLoadingActive = true;
      _isLoadingFinished = true;
    });

    // 1. Kitöltendő kérdőívek
    try {
      final active = await TasksRequest.getQuestionnaires();
      if (mounted) {
        setState(() {
          _activeQuestionnaires = active;
          _isLoadingActive = false;
          _applySearchFilter();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingActive = false);
    }

    // 2. Kitöltött kérdőívek
    try {
      final finished = await TasksRequest.getFinishedQuestionnaires();
      if (mounted) {
        setState(() {
          _finishedQuestionnaires = finished;
          _isLoadingFinished = false;
          _applySearchFilter();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFinished = false);
    }
  }

  Future<void> _startFilling(QuestionnaireItem item) async {
    AppHaptics.mediumImpact();
    setState(() => _loadingFillId = item.unipollReportId);

    try {
      final fillUrl = await TasksRequest.getUnipollFillUrl(
        termId: item.termId,
        subjectId: item.subjectId,
        unipollSurveyId: item.unipollSurveyId,
        unipollReportId: item.unipollReportId,
      );

      if (fillUrl != null && fillUrl.isNotEmpty) {
        final uri = Uri.tryParse(fillUrl);
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          Fluttertoast.showToast(msg: "Érvénytelen vagy nem támogatott link.");
        }
      } else {
        Fluttertoast.showToast(msg: "A kitöltőlink nem elérhető.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Hiba a kitöltési link lekérésekor: $e");
    } finally {
      if (mounted) {
        setState(() => _loadingFillId = null);
      }
    }
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '--';
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final activeCount = _activeQuestionnaires.length;
    final finishedCount = _finishedQuestionnaires.length;

    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: AppBar(
        backgroundColor: theme.rootBackground,
        elevation: 0,
        title: Text(
          "Kérdőívek & Teendők",
          style: TextStyle(
            color: theme.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.primary),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.primary),
            onPressed: () => _fetchData(isRefresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.primary,
          indicatorWeight: 3,
          labelColor: theme.primary,
          unselectedLabelColor: theme.textColor.withValues(alpha: 0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Kitöltendő"),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Kitöltött"),
                  if (finishedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$finishedCount',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Keresőmező
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.textColor, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: theme.textColor.withValues(alpha: 0.5), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: theme.textColor.withValues(alpha: 0.5), size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applySearchFilter();
                            },
                          )
                        : null,
                    hintText: "Keresés tárgy vagy kérdőív szerint...",
                    hintStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.4), fontSize: 12.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // Tab nézetek
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. Kitöltendő kérdőívek
                  _buildQuestionnaireList(
                    items: _filteredActive,
                    isLoading: _isLoadingActive,
                    isActiveTab: true,
                    emptyTitle: "Nincs kitöltendő kérdőíved! 🎉",
                    emptySubtitle: "Minden kötelező oktatói és tantárgyi véleményezést elvégeztél.",
                  ),

                  // 2. Kitöltött kérdőívek
                  _buildQuestionnaireList(
                    items: _filteredFinished,
                    isLoading: _isLoadingFinished,
                    isActiveTab: false,
                    emptyTitle: "Nincs korábbi kitöltött kérdőív",
                    emptySubtitle: "A beküldött kérdőívek és lezárt visszajelzések itt jelennek meg.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionnaireList({
    required List<QuestionnaireItem> items,
    required bool isLoading,
    required bool isActiveTab,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.getTheme().primary),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActiveTab ? Icons.check_circle_outline_rounded : Icons.archive_outlined,
                size: 56,
                color: AppColors.getTheme().textColor.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 14),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.getTheme().textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.getTheme().primary,
      backgroundColor: AppColors.getTheme().rootBackground,
      onRefresh: () => _fetchData(isRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildQuestionnaireCard(item, isActiveTab);
        },
      ),
    );
  }

  Widget _buildQuestionnaireCard(QuestionnaireItem item, bool isActiveTab) {
    final theme = AppColors.getTheme();
    final daysLeft = item.remainingDays;
    final isUrgent = isActiveTab && daysLeft <= 3 && daysLeft >= 0;
    final isExpired = isActiveTab && daysLeft < 0;
    final isFillingThis = _loadingFillId == item.unipollReportId;

    return Container(
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : theme.textColor.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Felső sáv: Tárgykód, kurzus és státusz badge-ek
          Row(
            children: [
              if (item.subjectCode.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.subjectCode,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (item.courseCode.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.courseCode,
                    style: const TextStyle(
                      color: Color(0xFFA855F7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Státusz jelvény
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isActiveTab
                      ? (isUrgent
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.12))
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActiveTab
                      ? (isExpired
                          ? "Lejárt"
                          : (isUrgent ? "Még $daysLeft nap" : (item.statusReason ?? "Kitöltendő")))
                      : "Kitöltve ✅",
                  style: TextStyle(
                    color: isActiveTab
                        ? (isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6))
                        : const Color(0xFF10B981),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Tantárgy neve (védve túlcsordulás ellen: maxLines 2, ellipsis)
          Text(
            item.subjectName.isNotEmpty ? item.subjectName : item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),

          // Kérdőív pontos típusa / megnevezése
          if (item.subjectName.isNotEmpty && item.title.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.65),
                fontSize: 11.5,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Alsó sor: Határidő és Kitöltés gomb
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: theme.textColor.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Határidő: ${_formatDate(item.toDate)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ),
              if (isActiveTab)
                ElevatedButton(
                  onPressed: isFillingThis ? null : () => _startFilling(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isFillingThis
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "KITÖLTÉS",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new_rounded, size: 12),
                          ],
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
