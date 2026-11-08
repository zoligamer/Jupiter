import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../API/api_coms.dart';
import '../colors.dart';
import '../haptics.dart';
import '../storage.dart';

class CollectiveAccountCard extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  const CollectiveAccountCard({
    super.key,
    this.onRefreshRequested,
  });

  /// Formázza a bankszámlaszámot magyar 3x8 vagy 2x8 formátumra kötőjelekkel.
  static String formatBankAccount(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 24) {
      return '${cleaned.substring(0, 8)}-${cleaned.substring(8, 16)}-${cleaned.substring(16, 24)}';
    } else if (cleaned.length == 16) {
      return '${cleaned.substring(0, 8)}-${cleaned.substring(8, 16)}';
    }
    return raw;
  }

  @override
  State<CollectiveAccountCard> createState() => _CollectiveAccountCardState();
}

class _CollectiveAccountCardState extends State<CollectiveAccountCard> {
  bool _isFetchingServerData = false;

  @override
  void initState() {
    super.initState();
    _checkAndFetchIfMissing();
  }

  /// Ha még nincs lementett gyűjtőszámla adat vagy egyenleg a helyi cache-ben,
  /// automatikusan lekéri a szervertől a háttérben.
  Future<void> _checkAndFetchIfMissing() async {
    final cachedAccount = DataCache.getAccountCollectiveBankAccount();
    final cachedBalance = DataCache.getAccountBalance();
    if (cachedAccount == null || cachedAccount.isEmpty || cachedBalance == null) {
      if (mounted) {
        setState(() => _isFetchingServerData = true);
      }
      try {
        await CashinRequest.getCollectiveInvoiceBalance();
      } catch (_) {}
      if (mounted) {
        setState(() => _isFetchingServerData = false);
      }
    }
  }

  void _copyToClipboard(String text, String successMessage) {
    Clipboard.setData(ClipboardData(text: text));
    AppHaptics.lightImpact();
    Fluttertoast.showToast(msg: successMessage);
  }

  void _showTopUpModal(BuildContext context) {
    final theme = AppColors.getTheme();
    final isDark = AppColors.isDarktheme();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.rootBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final rawBankAccount = DataCache.getAccountCollectiveBankAccount() ?? '';
            final formattedBankAccount = CollectiveAccountCard.formatBankAccount(rawBankAccount);
            final neptunCode = DataCache.getUsername() ?? '';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.textColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFFF59E0B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gyűjtőszámla feltöltése',
                            style: TextStyle(
                              color: theme.textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Utalj az egyetemed hivatalos gyűjtőszámlájára. A Neptun-kódodat feltétlenül írd a közleménybe!',
                      style: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.70),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dinamikus egyetemi számlaszám mező (nem hardkódolt, szerverről vagy mentett adatokból)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EGYETEMI GYŰJTŐSZÁMLA (SZERVERRŐL)',
                                  style: TextStyle(
                                    color: theme.textColor.withValues(alpha: 0.55),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_isFetchingServerData)
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.textColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Lekérés a szervertől...',
                                        style: TextStyle(
                                          color: theme.textColor.withValues(alpha: 0.6),
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    formattedBankAccount.isNotEmpty
                                        ? formattedBankAccount
                                        : 'Nincs rögzítve (frissíts a lekéréshez)',
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontSize: 13.5,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (formattedBankAccount.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              color: const Color(0xFFF59E0B),
                              tooltip: 'Számlaszám másolása',
                              onPressed: () => _copyToClipboard(
                                formattedBankAccount,
                                'Gyűjtőszámla számlaszám vágólapra másolva!',
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              color: const Color(0xFFF59E0B),
                              tooltip: 'Lekérés most',
                              onPressed: () async {
                                setModalState(() => _isFetchingServerData = true);
                                await CashinRequest.getCollectiveInvoiceBalance();
                                if (mounted) {
                                  setState(() {});
                                }
                                setModalState(() => _isFetchingServerData = false);
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Közlemény (Neptun kód) mező
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'KÖZLEMÉNY / MEGJEGYZÉS (KÖTELEZŐ!)',
                                  style: TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  neptunCode.isNotEmpty ? neptunCode : 'Neptun kód',
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 15,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (neptunCode.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              color: const Color(0xFFF59E0B),
                              tooltip: 'Közlemény másolása',
                              onPressed: () => _copyToClipboard(
                                neptunCode,
                                'Neptun kód másolva a közleményhez!',
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Info szöveg
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Az átutalt összeg banki munkanapokon általában 1-2 napon belül jóváírásra kerül a gyűjtőszámládon.',
                              style: TextStyle(
                                color: theme.textColor.withValues(alpha: 0.8),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Rendben',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Adatok betöltése a helyi mentett tárhelyből (DataCache)
    final balance = DataCache.getAccountBalance();
    final currency = DataCache.getAccountBalanceCurrency();
    final rawBankAccount = DataCache.getAccountCollectiveBankAccount();
    final formattedBankAccount = CollectiveAccountCard.formatBankAccount(rawBankAccount);
    final term = DataCache.getSelectedTermName();

    final formattedNum = balance != null
        ? balance.toInt().toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]} ',
            )
        : '0';

    final displayText = "$formattedNum $currency";
    final termStr = (term != null && term.isNotEmpty) ? "Aktív félév: $term • " : "";

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF59E0B), // amber-500
            Color(0xFFD97706), // amber-600
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. SOR: Felirat és Feltöltés gomb
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'GYŰJTŐSZÁMLA EGYENLEG',
                style: TextStyle(
                  color: Color(0xFFFFFBEB),
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  letterSpacing: 0.8,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    AppHaptics.lightImpact();
                    _showTopUpModal(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'FELTÖLTÉS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 2. SOR: Nagy egyenleg kiírás
          Text(
            displayText,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 6),

          // 3. SOR: Aktív félév és Számlaszám másolása
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                if (formattedBankAccount.isNotEmpty) {
                  _copyToClipboard(
                    formattedBankAccount,
                    'Gyűjtőszámla számlaszám vágólapra másolva!',
                  );
                } else {
                  // Ha még nincs lementve, kérje le a szervertől
                  AppHaptics.lightImpact();
                  Fluttertoast.showToast(msg: "Gyűjtőszámla lekérése a szervertől...");
                  await CashinRequest.getCollectiveInvoiceBalance();
                  if (mounted) {
                    setState(() {});
                  }
                  final updatedAccount = CollectiveAccountCard.formatBankAccount(
                    DataCache.getAccountCollectiveBankAccount(),
                  );
                  if (updatedAccount.isNotEmpty) {
                    _copyToClipboard(
                      updatedAccount,
                      'Gyűjtőszámla számlaszám vágólapra másolva!',
                    );
                  } else {
                    if (context.mounted) {
                      _showTopUpModal(context);
                    }
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${termStr}Számlaszám másolása",
                      style: const TextStyle(
                        color: Color(0xFFFEF3C7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.copy_rounded,
                      size: 11.5,
                      color: Color(0xFFFEF3C7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
