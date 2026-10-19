import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../API/api_coms.dart';
import '../Misc/petition_parser.dart';
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';

class PetitionFillPage extends StatefulWidget {
  final PetitionTemplate template;

  const PetitionFillPage({super.key, required this.template});

  @override
  State<PetitionFillPage> createState() => _PetitionFillPageState();
}

class _PetitionFillPageState extends State<PetitionFillPage> {
  int _currentStep = 0; // 0 = Fill Form, 1 = Preview & Submit
  bool _isLoading = true;
  String? _errorMessage;

  List<PetitionFormField> _fields = [];
  final Map<String, dynamic> _formData = {};
  final _formKey = GlobalKey<FormState>();

  String? _previewBase64;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await PetitionsRequest.getStudentRequestForm(widget.template.requestFormTemplateId);
      if (data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Nem sikerült betölteni a kérvény űrlapját.";
        });
        return;
      }

      final pageHtml = data['pageHTML']?.toString() ?? '';
      final parsed = PetitionParser.parseFields(pageHtml);

      // Initialize form data with default values
      for (var f in parsed) {
        _formData[f.name] = f.defaultValue;
      }

      setState(() {
        _fields = parsed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Hiba történt a kérvény betöltése közben: $e";
      });
    }
  }

  Future<void> _proceedToPreview() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      AppHaptics.attentionImpact();
      return;
    }
    _formKey.currentState?.save();

    AppHaptics.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Convert form data to format: [{"name": "D_1", "value": "..."}]
      final List<Map<String, String>> submitData = [];
      _formData.forEach((key, value) {
        submitData.add({'name': key, 'value': value.toString()});
      });

      // 2. Save page and step next on server
      final saved = await PetitionsRequest.savePageAndStepNext(submitData);
      if (!saved) {
        setState(() {
          _isLoading = false;
          _errorMessage = "A Neptun nem fogadta el a megadott adatokat.";
        });
        return;
      }

      // 3. Get current page with generated preview
      final previewData = await PetitionsRequest.getCurrentPage();
      final previewHtml = previewData?['pageHTML']?.toString() ?? '';
      final b64 = PetitionParser.extractPreviewBase64(previewHtml);

      setState(() {
        _previewBase64 = b64;
        _currentStep = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Hiba történt az előnézet generálásakor: $e";
      });
    }
  }

  Future<void> _submitPetition() async {
    final lang = AppStrings.getLanguagePack();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getTheme().rootBackground,
        title: Text(
          lang.petitions_SubmitButton,
          style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          lang.petitions_SubmitConfirm,
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
              backgroundColor: AppColors.getTheme().primary,
              foregroundColor: AppColors.getTheme().onPrimary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.petitions_SubmitButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    AppHaptics.attentionImpact();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final resultMessage = await PetitionsRequest.submitPetition();
      if (!mounted) return;

      Fluttertoast.showToast(
        msg: resultMessage ?? lang.petitions_SubmitSuccess,
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: AppColors.getTheme().rootBackground,
        textColor: AppColors.getTheme().textColor,
      );

      // Return true to indicate successful submission
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        Fluttertoast.showToast(
          msg: "Hiba a kérvény leadása során: $e",
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: AppColors.getTheme().errorRed,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _discardAndResetPetition() async {
    final lang = AppStrings.getLanguagePack();
    AppHaptics.attentionImpact();

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await PetitionsRequest.resetStartedPetition(widget.template.requestFormTemplateId);
      if (!mounted) return;

      if (success) {
        Fluttertoast.showToast(
          msg: lang.petitions_ResetSuccess,
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: AppColors.getTheme().rootBackground,
          textColor: AppColors.getTheme().textColor,
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "Nem sikerült a kérvény visszaállítása.",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: AppColors.getTheme().errorRed,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
          msg: "Hiba történt: $e",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: AppColors.getTheme().errorRed,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _showResetConfirmationDialog() async {
    final lang = AppStrings.getLanguagePack();
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

    if (confirmed == true && mounted) {
      await _discardAndResetPetition();
    }
  }

  Future<void> _showExitBottomSheet() async {
    final lang = AppStrings.getLanguagePack();
    AppHaptics.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getTheme().rootBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  lang.petitions_ExitOptionsTitle,
                  style: TextStyle(
                    color: AppColors.getTheme().textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.getTheme().primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bookmark_added_outlined, color: AppColors.getTheme().primary),
                  ),
                  title: Text(
                    lang.petitions_ExitKeepDraft,
                    style: TextStyle(color: AppColors.getTheme().textColor, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, false);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.getTheme().errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_sweep_outlined, color: AppColors.getTheme().errorRed),
                  ),
                  title: Text(
                    lang.petitions_ExitDiscard,
                    style: TextStyle(color: AppColors.getTheme().errorRed, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _discardAndResetPetition();
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      lang.any_setupPage_GoBack,
                      style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppStrings.getLanguagePack();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep == 1) {
          setState(() {
            _currentStep = 0;
          });
        } else {
          _showExitBottomSheet();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.getTheme().rootBackground,
        appBar: AppBar(
          backgroundColor: AppColors.getTheme().rootBackground,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.template.templateName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.getTheme().textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currentStep == 0 ? lang.petitions_StepFill : lang.petitions_StepPreview,
                style: TextStyle(
                  color: AppColors.getTheme().primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.getTheme().primary),
            onPressed: () {
              AppHaptics.lightImpact();
              if (_currentStep == 1) {
                setState(() {
                  _currentStep = 0;
                });
              } else {
                _showExitBottomSheet();
              }
            },
          ),
          actions: [
            if (!_isLoading)
              IconButton(
                icon: Icon(Icons.restart_alt_rounded, color: AppColors.getTheme().errorRed),
                tooltip: lang.petitions_Reset,
                onPressed: _showResetConfirmationDialog,
              ),
          ],
        ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.getTheme().primary),
                  const SizedBox(height: 16),
                  Text(
                    _currentStep == 0 ? "Űrlap betöltése..." : "Előnézet generálása...",
                    style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: AppColors.getTheme().errorRed),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.getTheme().textColor),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadForm,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Újrapróbálás"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getTheme().primary,
                            foregroundColor: AppColors.getTheme().onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _currentStep == 0
                  ? _buildFormView(lang)
                  : _buildPreviewView(lang),
      ),
    );
  }

  Widget _buildFormView(LanguagePack lang) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info header card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.getTheme().primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.getTheme().primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.getTheme().primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Kérjük, add meg a kérelemhez szükséges adatokat, majd kattints a tovább gombra az előnézet megtekintéséhez.",
                          style: TextStyle(
                            color: AppColors.getTheme().textColor.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_fields.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        "Ez a kérvény nem tartalmaz kitöltendő mezőket. Az előnézet megtekintéséhez nyomj a Tovább gombra.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
                      ),
                    ),
                  )
                else
                  ..._fields.map((field) => _buildFieldWidget(field)),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getTheme().rootBackground,
              border: Border(
                top: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _proceedToPreview,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    "Tovább az előnézethez",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getTheme().primary,
                    foregroundColor: AppColors.getTheme().onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWidget(PetitionFormField field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: TextStyle(
              color: AppColors.getTheme().textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),

          if (field.type == PetitionFieldType.dropdown)
            DropdownButtonFormField<String>(
              initialValue: (_formData[field.name] != null && field.options.any((o) => o.value == _formData[field.name]))
                  ? _formData[field.name]
                  : (field.options.isNotEmpty ? field.options.first.value : null),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.getTheme().rootBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.15)),
                ),
              ),
              dropdownColor: AppColors.getTheme().rootBackground,
              style: TextStyle(color: AppColors.getTheme().textColor, fontSize: 14),
              isExpanded: true,
              items: field.options.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt.value,
                  child: Text(
                    opt.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.getTheme().textColor),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _formData[field.name] = val;
                  });
                }
              },
              validator: (val) {
                if (field.isRequired && (val == null || val == '---' || val.isEmpty)) {
                  return 'Kérjük, válassz egy opciót!';
                }
                return null;
              },
            )
          else if (field.type == PetitionFieldType.multilineText)
            TextFormField(
              initialValue: _formData[field.name]?.toString() ?? '',
              maxLines: 4,
              style: TextStyle(color: AppColors.getTheme().textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.getTheme().rootBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.15)),
                ),
                hintText: "Írd be a szöveget...",
                hintStyle: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.4)),
              ),
              onSaved: (val) => _formData[field.name] = val ?? '',
              validator: (val) {
                if (field.isRequired && (val == null || val.trim().isEmpty)) {
                  return 'A mező kitöltése kötelező!';
                }
                return null;
              },
            )
          else if (field.type == PetitionFieldType.checkbox)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(field.label, style: TextStyle(color: AppColors.getTheme().textColor)),
              value: _formData[field.name] == 'true' || _formData[field.name] == true,
              activeColor: AppColors.getTheme().primary,
              onChanged: (val) {
                setState(() {
                  _formData[field.name] = val == true ? 'true' : 'false';
                });
              },
            )
          else
            TextFormField(
              initialValue: _formData[field.name]?.toString() ?? '',
              style: TextStyle(color: AppColors.getTheme().textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.getTheme().rootBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.15)),
                ),
              ),
              onSaved: (val) => _formData[field.name] = val ?? '',
              validator: (val) {
                if (field.isRequired && (val == null || val.trim().isEmpty)) {
                  return 'A mező kitöltése kötelező!';
                }
                return null;
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewView(LanguagePack lang) {
    return Column(
      children: [
        // Preview instructions banner
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.getTheme().textColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.zoom_in_rounded, size: 20, color: AppColors.getTheme().primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "A dokumentum két ujjal nagyítható és mozgatható.",
                  style: TextStyle(
                    color: AppColors.getTheme().textColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // A4 Document Preview Viewer
        Expanded(
          child: _previewBase64 != null
              ? Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.memory(
                        base64Decode(_previewBase64!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    "Nem érhető el képi előnézet ehhez a kérvényhez.",
                    style: TextStyle(color: AppColors.getTheme().textColor.withValues(alpha: 0.6)),
                  ),
                ),
        ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getTheme().rootBackground,
            border: Border(
              top: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.08)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        AppHaptics.lightImpact();
                        setState(() {
                          _currentStep = 0;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.getTheme().textColor.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        "Módosítás",
                        style: TextStyle(color: AppColors.getTheme().textColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitPetition,
                      icon: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTheme().onPrimary),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSubmitting ? "Leadás..." : lang.petitions_SubmitButton,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getTheme().currentClassGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  }
}
