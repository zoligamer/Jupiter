import 'dart:convert' as conv;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';
import '../storage.dart' as storage;
import 'petition_fill_page.dart';

class PetitionsPage extends StatefulWidget {
  const PetitionsPage({super.key});

  @override
  State<PetitionsPage> createState() => _PetitionsPageState();
}

class _PetitionsPageState extends State<PetitionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<PetitionTemplate> _templates = [];
  List<PetitionTemplate> _filteredTemplates = [];
  List<SubmittedPetition> _submitted = [];
  List<StartedPetition> _started = [];
  List<StartedPetition> _filteredStarted = [];
  PetitionCounts? _counts;

  bool _isLoadingTemplates = true;
  bool _isLoadingSubmitted = true;
  bool _isLoadingStarted = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
          _applySearchFilter();
        });
      }
    });

    // 1. Instant paint from cache
    _loadFromCache();

    // 2. Fetch fresh data from network
    _fetchFreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadFromCache() {
    try {
      final rawTemplates = storage.DataCache.getCachedPetitionTemplatesRaw();
      if (rawTemplates.isNotEmpty) {
        _templates = rawTemplates.map((raw) => PetitionTemplate.fromJson(conv.jsonDecode(raw))).toList();
        _applySearchFilter();
        _isLoadingTemplates = false;
      }

      final rawSubmitted = storage.DataCache.getCachedSubmittedPetitionsRaw();
      if (rawSubmitted.isNotEmpty) {
        _submitted = rawSubmitted.map((raw) => SubmittedPetition.fromJson(conv.jsonDecode(raw))).toList();
        _isLoadingSubmitted = false;
      }

      final rawStarted = storage.DataCache.getCachedStartedPetitionsRaw();
      if (rawStarted.isNotEmpty) {
        _started = rawStarted.map((raw) => StartedPetition.fromJson(conv.jsonDecode(raw))).toList();
        _applySearchFilter();
        _isLoadingStarted = false;
      }
    } catch (_) {}
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredTemplates = List.from(_templates);
      _filteredStarted = List.from(_started);
    } else {
      _filteredTemplates = _templates.where((t) {
        return t.templateName.toLowerCase().contains(_searchQuery);
      }).toList();
      _filteredStarted = _started.where((t) {
        return t.templateName.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _fetchFreshData({bool isRefresh = false}) async {
    if (!mounted) return;

    if (isRefresh) {
      AppHaptics.lightImpact();
    }

    // Parallel background fetch
    Future.microtask(() async {
      final counts = await PetitionsRequest.getPetitionCounts();
      if (counts != null && mounted) {
        setState(() {
          _counts = counts;
        });
      }
    });

    Future.microtask(() async {
      final freshTemplates = await PetitionsRequest.getAvailableTemplates();
      if (freshTemplates.isNotEmpty && mounted) {
        setState(() {
          _templates = freshTemplates;
          _applySearchFilter();
          _isLoadingTemplates = false;
        });
        // Cache them
        final rawList = freshTemplates.map((t) => conv.jsonEncode(t.toJson())).toList();
        await storage.DataCache.setCachedPetitionTemplatesRaw(rawList);
      } else if (mounted) {
        setState(() {
          if (freshTemplates.isEmpty) {
            _templates = [];
            _applySearchFilter();
          }
          _isLoadingTemplates = false;
        });
        if (freshTemplates.isEmpty) {
          await storage.DataCache.setCachedPetitionTemplatesRaw([]);
        }
      }
    });

    Future.microtask(() async {
      final freshSubmitted = await PetitionsRequest.getSubmittedPetitions();
      if (freshSubmitted.isNotEmpty && mounted) {
        setState(() {
          _submitted = freshSubmitted;
          _isLoadingSubmitted = false;
        });
        // Cache them
        final rawList = freshSubmitted.map((s) => conv.jsonEncode(s.toJson())).toList();
        await storage.DataCache.setCachedSubmittedPetitionsRaw(rawList);
      } else if (mounted) {
        setState(() {
          if (freshSubmitted.isEmpty) {
            _submitted = [];
          }
          _isLoadingSubmitted = false;
        });
        if (freshSubmitted.isEmpty) {
          await storage.DataCache.setCachedSubmittedPetitionsRaw([]);
        }
      }
    });

    Future.microtask(() async {
      final freshStarted = await PetitionsRequest.getStartedPetitions();
      if (freshStarted.isNotEmpty && mounted) {
        setState(() {
          _started = freshStarted;
          _applySearchFilter();
          _isLoadingStarted = false;
        });
        // Cache them
        final rawList = freshStarted.map((s) => conv.jsonEncode(s.toJson())).toList();
        await storage.DataCache.setCachedStartedPetitionsRaw(rawList);
      } else if (mounted) {
        setState(() {
          if (freshStarted.isEmpty) {
            _started = [];
            _applySearchFilter();
          }
          _isLoadingStarted = false;
        });
        if (freshStarted.isEmpty) {
          await storage.DataCache.setCachedStartedPetitionsRaw([]);
        }
      }
    });
  }

  Color _getStatusColor(String statusText, int statusType) {
    final lower = statusText.toLowerCase();
    if (lower.contains('elfogadva') || lower.contains('approved') || lower.contains('accepted')) {
      return AppColors.getTheme().currentClassGreen;
    }
    if (lower.contains('elutasítva') || lower.contains('rejected') || lower.contains('denied')) {
      return AppColors.getTheme().errorRed;
    }
    return AppColors.getTheme().primary;
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppStrings.getLanguagePack();

    final availableCount = _counts?.availableCount ?? _templates.length;
    final submittedCount = _counts?.submittedCount ?? _submitted.length;
    final startedCount = _counts?.startedCount ?? _started.length;

    return Scaffold(
      backgroundColor: AppColors.getTheme().rootBackground,
      appBar: AppBar(
        backgroundColor: AppColors.getTheme().rootBackground,
        elevation: 0,
        title: Text(
          lang.petitions_Header,
          style: TextStyle(
            color: AppColors.getTheme().textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.getTheme().primary),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.getTheme().primary),
            onPressed: () => _fetchFreshData(isRefresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.getTheme().primary,
          indicatorWeight: 3,
          labelColor: AppColors.getTheme().primary,
          unselectedLabelColor: AppColors.getTheme().textColor.withValues(alpha: 0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(lang.petitions_TabAvailable.split(' ').first),
                  if (availableCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.getTheme().primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$availableCount',
                        style: TextStyle(color: AppColors.getTheme().primary, fontSize: 10, fontWeight: FontWeight.bold),
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
                  Text(lang.petitions_TabSubmitted.split(' ').first),
                  if (submittedCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.getTheme().textColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$submittedCount',
                        style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 10, fontWeight: FontWeight.bold),
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
                  Text(lang.petitions_TabStarted),
                  if (startedCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$startedCount',
                        style: TextStyle(color: Colors.amber.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableTab(lang),
          _buildSubmittedTab(lang),
          _buildStartedTab(lang),
        ],
      ),
    );
  }

  Widget _buildAvailableTab(LanguagePack lang) {
    return Column(
      children: [
        // Search Box
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: lang.petitions_SearchHint,
                hintStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.getTheme().primary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.5), size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            color: AppColors.getTheme().primary,
            onRefresh: () => _fetchFreshData(isRefresh: true),
            child: _isLoadingTemplates && _templates.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.getTheme().primary),
                  )
                : _filteredTemplates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_late_outlined, size: 48, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? "Nincs találat a keresésre." : lang.petitions_NoAvailable,
                              style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredTemplates.length,
                        itemBuilder: (context, index) {
                          final item = _filteredTemplates[index];
                          return _buildTemplateCard(item);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(PetitionTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            AppHaptics.lightImpact();
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => PetitionFillPage(template: template),
              ),
            );
            if (result == true) {
              // Switch to submitted tab
              _tabController.animateTo(1);
            }
            _fetchFreshData(isRefresh: true);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.getTheme().primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: AppColors.getTheme().primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.templateName,
                        style: TextStyle(
                          color: AppColors.getTheme().textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (template.feeInformation != null && template.feeInformation!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: template.feeInformation == 'Ingyenes'
                                ? AppColors.getTheme().currentClassGreen.withValues(alpha: 0.12)
                                : Colors.amber.shade700.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: template.feeInformation == 'Ingyenes'
                                  ? AppColors.getTheme().currentClassGreen.withValues(alpha: 0.3)
                                  : Colors.amber.shade700.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            template.feeInformation!,
                            style: TextStyle(
                              color: template.feeInformation == 'Ingyenes'
                                  ? AppColors.getTheme().currentClassGreen
                                  : Colors.amber.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (template.validFrom != null && template.validFrom!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Érvényes: ${_formatDate(template.validFrom)}",
                            style: TextStyle(
                              color: AppColors.getTheme().textColor.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.3),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmittedTab(LanguagePack lang) {
    return RefreshIndicator(
      color: AppColors.getTheme().primary,
      onRefresh: () => _fetchFreshData(isRefresh: true),
      child: _isLoadingSubmitted && _submitted.isEmpty
          ? Center(
              child: CircularProgressIndicator(color: AppColors.getTheme().primary),
            )
          : _submitted.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 48, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        lang.petitions_NoSubmitted,
                        style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _submitted.length,
                  itemBuilder: (context, index) {
                    final item = _submitted[index];
                    return _buildSubmittedCard(item);
                  },
                ),
    );
  }

  Widget _buildSubmittedCard(SubmittedPetition petition) {
    final statusColor = _getStatusColor(petition.statusText, petition.statusType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Identifier badge
              if (petition.requestFormIdentifier.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.getTheme().primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    petition.requestFormIdentifier,
                    style: TextStyle(
                      color: AppColors.getTheme().primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Status badge
              if (petition.statusText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        petition.statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            petition.templateName,
            style: TextStyle(
              color: AppColors.getTheme().textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          if (petition.submissionDate != null && petition.submissionDate!.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  "Leadva: ${_formatDate(petition.submissionDate)}",
                  style: TextStyle(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStartedTab(LanguagePack lang) {
    return Column(
      children: [
        // Search Box
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: lang.petitions_SearchHint,
                hintStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.getTheme().primary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: AppColors.getTheme().textColor.withValues(alpha: 0.5), size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            color: AppColors.getTheme().primary,
            onRefresh: () => _fetchFreshData(isRefresh: true),
            child: _isLoadingStarted && _started.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.getTheme().primary),
                  )
                : _filteredStarted.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 48, color: AppColors.getTheme().textColor.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? "Nincs találat a keresésre." : lang.petitions_NoStarted,
                              style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredStarted.length,
                        itemBuilder: (context, index) {
                          final item = _filteredStarted[index];
                          return _buildStartedCard(item, lang);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartedCard(StartedPetition item, LanguagePack lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_document,
                    color: Colors.amber.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.templateName,
                              style: TextStyle(
                                color: AppColors.getTheme().textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              lang.petitions_TabStarted,
                              style: TextStyle(
                                color: Colors.amber.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (item.feeInformation != null && item.feeInformation!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2, bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.feeInformation == 'Ingyenes'
                                ? AppColors.getTheme().currentClassGreen.withValues(alpha: 0.12)
                                : Colors.amber.shade700.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: item.feeInformation == 'Ingyenes'
                                  ? AppColors.getTheme().currentClassGreen.withValues(alpha: 0.3)
                                  : Colors.amber.shade700.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            item.feeInformation!,
                            style: TextStyle(
                              color: item.feeInformation == 'Ingyenes'
                                  ? AppColors.getTheme().currentClassGreen
                                  : Colors.amber.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (item.lastModified != null && item.lastModified!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: AppColors.getTheme().textColor.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Módosítva: ${_formatDate(item.lastModified)}",
                              style: TextStyle(
                                color: AppColors.getTheme().textColor.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Visszaállítás (Reset / Discard)
                OutlinedButton.icon(
                  onPressed: () => _confirmResetStartedPetition(item, lang),
                  icon: Icon(Icons.restart_alt_rounded, size: 16, color: AppColors.getTheme().errorRed),
                  label: Text(
                    lang.petitions_Reset,
                    style: TextStyle(color: AppColors.getTheme().errorRed, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.getTheme().errorRed.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 10),
                // Folytatás (Continue)
                ElevatedButton.icon(
                  onPressed: () => _continueStartedPetition(item),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(
                    lang.petitions_Continue,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getTheme().primary,
                    foregroundColor: AppColors.getTheme().onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continueStartedPetition(StartedPetition item) async {
    AppHaptics.lightImpact();
    final existing = _templates.where((t) => t.requestFormTemplateId == item.requestFormTemplateId).firstOrNull;
    final templateToUse = existing ?? PetitionTemplate(
      requestFormTemplateId: item.requestFormTemplateId,
      templateName: item.templateName,
      validFrom: item.validFrom,
      validTo: item.validTo,
      feeInformation: item.feeInformation,
    );

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PetitionFillPage(template: templateToUse),
      ),
    );

    _fetchFreshData(isRefresh: true);
    if (result == true) {
      _tabController.animateTo(1);
    }
  }

  Future<void> _confirmResetStartedPetition(StartedPetition item, LanguagePack lang) async {
    AppHaptics.attentionImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getTheme().rootBackground,
        title: Text(
          lang.petitions_Reset,
          style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          lang.petitions_ResetConfirm,
          style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.any_setupPage_GoBack,
              style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getTheme().errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.petitions_Reset),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    AppHaptics.attentionImpact();
    final success = await PetitionsRequest.resetStartedPetition(item.requestFormTemplateId);
    if (!mounted) return;

    if (success) {
      Fluttertoast.showToast(
        msg: lang.petitions_ResetSuccess,
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: AppColors.getTheme().rootBackground,
        textColor: AppColors.getTheme().textColor,
      );
      // Refresh fresh counts and lists
      await _fetchFreshData(isRefresh: true);
    } else {
      Fluttertoast.showToast(
        msg: "Nem sikerült a kérvény visszaállítása.",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: AppColors.getTheme().errorRed,
        textColor: Colors.white,
      );
    }
  }
}
