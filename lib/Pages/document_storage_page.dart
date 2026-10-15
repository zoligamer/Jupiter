import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';
import '../storage.dart' as storage;
import '../language.dart';
import 'dart:convert' as conv;

class DocumentStoragePage extends StatefulWidget {
  const DocumentStoragePage({super.key});

  @override
  State<DocumentStoragePage> createState() => _DocumentStoragePageState();
}

class _DocumentStoragePageState extends State<DocumentStoragePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  DocumentStorageDashboard? _dashboard;
  List<StorageDocumentItem> _forStudentDocs = [];
  List<StorageDocumentItem> _byStudentDocs = [];
  List<StorageDocumentItem> _trDocs = [];

  List<StorageDocumentItem> _filteredForStudentDocs = [];
  List<StorageDocumentItem> _filteredByStudentDocs = [];
  List<StorageDocumentItem> _filteredTrDocs = [];

  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
          _applyFilter();
        });
      }
    });

    _loadFromCache();
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
      final rawDash = storage.DataCache.getCachedStorageDashboardRaw();
      if (rawDash != null && rawDash.isNotEmpty) {
        final dec = conv.jsonDecode(rawDash);
        if (dec['data'] != null) {
          _dashboard = DocumentStorageDashboard.fromJson(dec['data']);
        }
      }

      final rawForStudent = storage.DataCache.getCachedStorageForStudentDocsRaw();
      if (rawForStudent.isNotEmpty) {
        _forStudentDocs = rawForStudent.map((s) => StorageDocumentItem.fromJson(conv.jsonDecode(s))).toList();
      }

      final rawByStudent = storage.DataCache.getCachedStorageByStudentDocsRaw();
      if (rawByStudent.isNotEmpty) {
        _byStudentDocs = rawByStudent.map((s) => StorageDocumentItem.fromJson(conv.jsonDecode(s))).toList();
      }

      final rawTr = storage.DataCache.getCachedStorageTrDocsRaw();
      if (rawTr.isNotEmpty) {
        _trDocs = rawTr.map((s) => StorageDocumentItem.fromJson(conv.jsonDecode(s))).toList();
      }

      _applyFilter();
      if (_forStudentDocs.isNotEmpty || _trDocs.isNotEmpty) {
        _isLoading = false;
      }
    } catch (_) {}
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredForStudentDocs = List.from(_forStudentDocs);
      _filteredByStudentDocs = List.from(_byStudentDocs);
      _filteredTrDocs = List.from(_trDocs);
    } else {
      _filteredForStudentDocs = _forStudentDocs.where((d) =>
          d.name.toLowerCase().contains(_searchQuery) ||
          d.type.toLowerCase().contains(_searchQuery) ||
          (d.registrationNumber?.toLowerCase().contains(_searchQuery) ?? false)).toList();

      _filteredByStudentDocs = _byStudentDocs.where((d) =>
          d.name.toLowerCase().contains(_searchQuery) ||
          d.type.toLowerCase().contains(_searchQuery) ||
          (d.registrationNumber?.toLowerCase().contains(_searchQuery) ?? false)).toList();

      _filteredTrDocs = _trDocs.where((d) =>
          d.name.toLowerCase().contains(_searchQuery) ||
          d.type.toLowerCase().contains(_searchQuery) ||
          (d.registrationNumber?.toLowerCase().contains(_searchQuery) ?? false)).toList();
    }
  }

  Future<void> _fetchFreshData() async {
    try {
      final dashFuture = DocumentStorageRequest.getDashboardData();
      final forStudentFuture = DocumentStorageRequest.getDocumentsUploadedForStudent();
      final byStudentFuture = DocumentStorageRequest.getDocumentsUploadedByStudent();
      final trFuture = DocumentStorageRequest.getTrDocuments();

      final results = await Future.wait([
        dashFuture,
        forStudentFuture,
        byStudentFuture,
        trFuture,
      ]);

      if (!mounted) return;

      setState(() {
        _dashboard = results[0] as DocumentStorageDashboard?;
        _forStudentDocs = (results[1] as List<StorageDocumentItem>?) ?? [];
        _byStudentDocs = (results[2] as List<StorageDocumentItem>?) ?? [];
        _trDocs = (results[3] as List<StorageDocumentItem>?) ?? [];
        _applyFilter();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAndOpenDocument(StorageDocumentItem doc) async {
    if (_downloadingIds.contains(doc.id)) return;

    AppHaptics.mediumImpact();
    setState(() {
      _downloadingIds.add(doc.id);
    });

    try {
      Fluttertoast.showToast(msg: 'Dokumentum letöltése folyamatban...');
      final bytes = await DocumentStorageRequest.downloadDocumentPdf(doc.id);

      if (bytes != null && bytes.isNotEmpty) {
        // Save to temporary directory
        final tempDir = await getTemporaryDirectory();
        String safeName = doc.name.replaceAll(RegExp(r'[^\w\s\.-]', unicode: true), '_').trim();
        if (!safeName.toLowerCase().endsWith('.pdf')) {
          safeName = '$safeName.pdf';
        }
        final filePath = '${tempDir.path}/$safeName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        AppHaptics.attentionLightImpact();
        Fluttertoast.showToast(msg: 'Megnyitás: $safeName');

        // Open with default system app (handles view, print, and save to files)
        final openResult = await OpenFilex.open(filePath);
        if (openResult.type != ResultType.done) {
          Fluttertoast.showToast(msg: 'Fájl mentve: ${file.path}');
        }
      } else {
        Fluttertoast.showToast(msg: 'Nem sikerült letölteni a dokumentumot');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Hiba a letöltéskor: $e');
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(doc.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = math.max(
      MediaQuery.of(context).padding.bottom,
      MediaQuery.of(context).viewPadding.bottom,
    );

    return Scaffold(
      backgroundColor: AppColors.getTheme().rootBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getTheme().rootBackground,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: AppColors.getTheme().textColor),
                    onPressed: () {
                      AppHaptics.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.getLanguagePack().documents_Header,
                          style: TextStyle(
                            color: AppColors.getTheme().textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          AppStrings.getLanguagePack().documents_Subheader,
                          style: TextStyle(
                            color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Top Summary Cards (Dashboard)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _buildDashboardStatCard(
                    title: AppStrings.getLanguagePack().documents_TabOfficial,
                    count: _dashboard?.documentsUploadedForStudentCount ?? _forStudentDocs.length,
                    icon: Icons.mark_email_read_rounded,
                    color: AppColors.getTheme().primary,
                  ),
                  const SizedBox(width: 8),
                  _buildDashboardStatCard(
                    title: AppStrings.getLanguagePack().documents_TabSubmitted,
                    count: _dashboard?.documentsUploadedByStudentCount ?? _byStudentDocs.length,
                    icon: Icons.upload_file_rounded,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildDashboardStatCard(
                    title: AppStrings.getLanguagePack().documents_TabTr,
                    count: _dashboard?.trDocumentsCount ?? _trDocs.length,
                    icon: Icons.article_rounded,
                    color: Colors.purpleAccent,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Dokumentum keresése név vagy típus szerint...',
                    hintStyle: TextStyle(
                      color: AppColors.getTheme().textColor.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.getTheme().textColor.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, size: 18, color: AppColors.getTheme().textColor.withValues(alpha: 0.5)),
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

            // 3-Tab Segment Selector
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.getTheme().primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.getTheme().rootBackground,
                unselectedLabelColor: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                onTap: (_) => AppHaptics.lightImpact(),
                tabs: [
                  Tab(text: '${AppStrings.getLanguagePack().documents_TabOfficial} (${_filteredForStudentDocs.length})'),
                  Tab(text: '${AppStrings.getLanguagePack().documents_TabSubmitted} (${_filteredByStudentDocs.length})'),
                  Tab(text: '${AppStrings.getLanguagePack().documents_TabTr} (${_filteredTrDocs.length})'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: _isLoading && _forStudentDocs.isEmpty && _trDocs.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.getTheme().primary),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDocumentsList(_filteredForStudentDocs, bottomSafePadding, isOfficial: true),
                        _buildDocumentsList(_filteredByStudentDocs, bottomSafePadding, isStudentUpload: true),
                        _buildDocumentsList(_filteredTrDocs, bottomSafePadding, isTr: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList(
    List<StorageDocumentItem> docs,
    double bottomSafePadding, {
    bool isOfficial = false,
    bool isStudentUpload = false,
    bool isTr = false,
  }) {
    if (docs.isEmpty) {
      return RefreshIndicator(
        color: AppColors.getTheme().primary,
        backgroundColor: AppColors.getTheme().rootBackground,
        onRefresh: _fetchFreshData,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 40, 16, bottomSafePadding + 24),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 48,
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty ? 'Nincs találat a keresésre' : 'Nincs elérhető dokumentum',
                    style: TextStyle(
                      color: AppColors.getTheme().textColor.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.getTheme().primary,
      backgroundColor: AppColors.getTheme().rootBackground,
      onRefresh: _fetchFreshData,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafePadding + 24),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final isDownloading = _downloadingIds.contains(doc.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.getTheme().textColor.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isOfficial
                            ? AppColors.getTheme().errorRed.withValues(alpha: 0.12)
                            : isStudentUpload
                                ? Colors.blueAccent.withValues(alpha: 0.12)
                                : Colors.purpleAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOfficial
                              ? AppColors.getTheme().errorRed.withValues(alpha: 0.3)
                              : isStudentUpload
                                  ? Colors.blueAccent.withValues(alpha: 0.3)
                                  : Colors.purpleAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isTr ? 'TR' : 'PDF',
                        style: TextStyle(
                          color: isOfficial
                              ? AppColors.getTheme().errorRed
                              : isStudentUpload
                                  ? Colors.blueAccent
                                  : Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.name,
                            style: TextStyle(
                              color: AppColors.getTheme().textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.getTheme().primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  doc.type,
                                  style: TextStyle(
                                    color: AppColors.getTheme().primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (doc.uploadDate.isNotEmpty)
                                Text(
                                  doc.uploadDate.split('T')[0],
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

                const SizedBox(height: 10),
                Divider(color: AppColors.getTheme().textColor.withValues(alpha: 0.06), height: 1),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (doc.certificationStatus != null && doc.certificationStatus!.isNotEmpty && doc.certificationStatus != 'IsNotVisibleOnWeb')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.getTheme().currentClassGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doc.certificationStatus!,
                          style: TextStyle(
                            color: AppColors.getTheme().currentClassGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Text(
                        'Hivatalos okirat',
                        style: TextStyle(
                          color: AppColors.getTheme().textColor.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),

                    ElevatedButton.icon(
                      onPressed: isDownloading ? null : () => _downloadAndOpenDocument(doc),
                      icon: isDownloading
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTheme().primary),
                            )
                          : Icon(Icons.download_rounded, size: 14, color: AppColors.getTheme().primary),
                      label: Text(
                        isDownloading ? 'Letöltés...' : 'Letöltés / Nyomtatás',
                        style: TextStyle(
                          color: AppColors.getTheme().primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getTheme().primary.withValues(alpha: 0.12),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AppColors.getTheme().primary.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
