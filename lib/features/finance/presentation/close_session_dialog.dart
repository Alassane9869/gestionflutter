import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/features/finance/domain/models/cash_session.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';

class CloseSessionDialog extends ConsumerStatefulWidget {
  final CashSession session;

  const CloseSessionDialog({super.key, required this.session});

  @override
  ConsumerState<CloseSessionDialog> createState() => _CloseSessionDialogState();
}

class _CloseSessionDialogState extends ConsumerState<CloseSessionDialog> {
  final _amountCtrl = TextEditingController();
  bool _isLoading = false;
  double? _expectedBalance;
  Map<String, double>? _sessionStats;

  @override
  void initState() {
    super.initState();
    _loadExpectedBalance();
  }

  void _loadExpectedBalance() async {
    final expected = await ref.read(sessionServiceProvider).getExpectedBalance(widget.session);
    final stats = await ref.read(sessionServiceProvider).getSessionStats(widget.session);
    if (mounted) {
      setState(() {
        _expectedBalance = expected;
        _sessionStats = stats;
      });
    }
  }

  void _closeSession() async {
    final actual = double.tryParse(_amountCtrl.text);
    if (actual == null || actual < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez saisir le montant physique compté.")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(sessionServiceProvider).closeSession(widget.session, actual);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(shopSettingsProvider).value?.currency ?? 'FCFA';

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Clôturer la Caisse",
      icon: FluentIcons.savings_24_regular,
      width: 450,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.info_24_regular, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Comptez l'argent physique dans le tiroir et saisissez le montant total. Tout écart sera enregistré.",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (_expectedBalance == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_sessionStats != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildSummaryItem("Total Ventes", _sessionStats!['totalSales']!, Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSummaryItem("Espèces", _sessionStats!['totalCash']!, Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSummaryItem("Crédits", _sessionStats!['totalCredit']!, Colors.orange)),
                ],
              ),
              const SizedBox(height: 16),
            ],

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16181D) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Théorique attendu (Cash)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    DateFormatter.formatCurrency(_expectedBalance!, currency),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: "Montant Physique Compté*",
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                prefixIcon: const Icon(FluentIcons.money_calculator_24_regular, size: 28),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: isDark ? const Color(0xFF111318) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              ),
            ),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          child: const Text("Annuler")
        ),
        FilledButton.icon(
          onPressed: _isLoading || _expectedBalance == null ? null : _closeSession,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorClr,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(FluentIcons.lock_closed_24_filled, size: 20),
          label: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("Fermer la session", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              DateFormatter.formatCurrency(value, ''),
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
