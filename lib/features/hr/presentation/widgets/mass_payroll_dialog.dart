import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/auth/providers/user_providers.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/hr/data/hr_repository.dart';
import 'package:danaya_plus/features/hr/domain/models/employee_contract.dart';
import 'package:danaya_plus/features/hr/domain/models/payroll.dart';
import 'package:danaya_plus/features/hr/services/hr_pdf_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/utils/printing_helper.dart';

class MassPayrollDialog extends ConsumerStatefulWidget {
  const MassPayrollDialog({super.key});

  @override
  ConsumerState<MassPayrollDialog> createState() => _MassPayrollDialogState();
}

class _MassPayrollDialogState extends ConsumerState<MassPayrollDialog> {
  DateTime _selectedDate = DateTime.now();
  bool _isProcessing = false;
  double _progress = 0;
  String _statusMessage = "";

  bool _printAll = false;
  bool _sendWhatsapp = false;

  void _generateMassPayrolls() async {
    setState(() {
      _isProcessing = true;
      _progress = 0;
      _statusMessage = "Récupération des employés et contrats...";
    });

    try {
      final hrRepo = ref.read(hrRepositoryProvider);
      final users = ref.read(userListProvider).value ?? [];
      final activeUsers = users.where((u) => u.isActive && u.role != UserRole.admin).toList();
      final settings = ref.read(shopSettingsProvider).value;

      if (activeUsers.isEmpty) {
        throw Exception("Aucun employé actif trouvé.");
      }

      int processed = 0;
      int total = activeUsers.length;

      // To store the PDF byte arrays if we want to print them sequentially or combine them
      List<Uint8List> generatedPdfBytes = [];
      final hrPdfService = HrPdfService();

      for (final user in activeUsers) {
        setState(() {
          _progress = processed / total;
          _statusMessage = "Traitement de ${user.fullName}...";
        });

        // Check if contract exists
        final contracts = await hrRepo.getContractsForUser(user.id);
        final activeContract = contracts.where((c) => c.status == ContractStatus.active).firstOrNull;

        if (activeContract == null) {
          processed++;
          continue; // Skip if no active contract
        }

        // Check if a payroll already exists for this exact period
        final allPayrolls = await hrRepo.getPayrollsForUser(user.id);
        final existingPayroll = allPayrolls.where((p) => p.month == _selectedDate.month && p.year == _selectedDate.year).firstOrNull;

        Payroll payrollToUse;

        if (existingPayroll == null) {
          // Generate new payroll object
          payrollToUse = Payroll(
            id: DateTime.now().millisecondsSinceEpoch.toString() + processed.toString(),
            userId: user.id,
            month: _selectedDate.month,
            year: _selectedDate.year,
            baseSalary: activeContract.baseSalary,
            extraLines: [],
            status: PayrollStatus.draft,
            createdAt: DateTime.now(),
          );
          // Save payroll to DB
          await hrRepo.savePayroll(payrollToUse);
        } else {
          payrollToUse = existingPayroll;
        }

        if (_printAll && settings != null) {
          // Generate PDF document bytes
          final bytes = await hrPdfService.generatePayrollPdfBytes(user, payrollToUse, PdfTemplateStyle.standard, settings);
          generatedPdfBytes.add(bytes);
        }

        if (_sendWhatsapp) {
           // Wait 200ms to mimic sending / avoid API rate limits if we implemented a real sender
           await Future.delayed(const Duration(milliseconds: 200));
        }

        processed++;
      }

      setState(() {
        _progress = 1.0;
        _statusMessage = "Terminé ! $processed bulletins traités.";
      });

      if (_printAll && generatedPdfBytes.isNotEmpty && settings != null) {
        setState(() {
          _statusMessage = "Impression en cours...";
        });
        
        await Future.delayed(const Duration(milliseconds: 500));

        // For direct printing, we can print them sequentially using the payroll printer
        String? targetPrinter = settings.payrollPrinterName ?? settings.thermalPrinterName;
        
        if (settings.directPhysicalPrinting && targetPrinter != null && targetPrinter.isNotEmpty) {
           for (int i = 0; i < generatedPdfBytes.length; i++) {
             setState(() => _statusMessage = "Impression ${i+1}/${generatedPdfBytes.length}...");
             await PrintingHelper.printBytesWithFallback(
                bytes: generatedPdfBytes[i],
                targetPrinterName: targetPrinter,
                directPrint: true,
                jobName: "Bulletin_Paie_Masse_${i+1}",
             );
             await Future.delayed(const Duration(milliseconds: 1000)); // Sleep 1s between prints to not overwhelm the spooler
           }
        } else {
           // Fallback to system dialog, but printing them all might be annoying.
           // However, if not direct physical printing, we'll just open the dialog for the first one for safety.
           if (generatedPdfBytes.isNotEmpty) {
              setState(() => _statusMessage = "Ouverture de la fenêtre d'impression...");
              await PrintingHelper.printBytesWithFallback(
                bytes: generatedPdfBytes.first,
                targetPrinterName: targetPrinter,
                directPrint: false,
                jobName: "Bulletin_Paie_Masse",
             );
           }
        }
      }

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = "Erreur: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1E) : Colors.white;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final border = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200;
    final surface = isDark ? const Color(0xFF222226) : Colors.grey.shade50;
    final emerald = Colors.green;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: bg,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(FluentIcons.layer_24_filled, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Génération de Masse", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                      Text("Créer les bulletins pour tous les employés", style: TextStyle(fontSize: 13, color: textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  icon: const Icon(FluentIcons.dismiss_24_regular),
                  color: textSecondary,
                )
              ],
            ),
            const SizedBox(height: 24),

            if (_isProcessing) ...[
              const SizedBox(height: 32),
              LinearProgressIndicator(value: _progress, color: theme.colorScheme.primary, backgroundColor: border),
              const SizedBox(height: 16),
              Center(child: Text(_statusMessage, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500))),
              const SizedBox(height: 32),
            ] else ...[
              Text("Mois concerné", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(8),
                    color: surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${DateFormatter.formatMonth(_selectedDate)} ${_selectedDate.year}", style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
                      Icon(FluentIcons.calendar_20_regular, color: textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Text("Actions supplémentaires", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 8),
              
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildActionToggle(
                      icon: FluentIcons.print_20_regular,
                      title: "Imprimer tous les bulletins",
                      subtitle: "Imprime tous les bulletins consécutivement",
                      value: _printAll,
                      onChanged: (v) => setState(() => _printAll = v),
                      color: emerald,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    Divider(height: 1, color: border),
                    _buildActionToggle(
                      icon: FluentIcons.mail_20_regular,
                      title: "Envoyer par WhatsApp",
                      subtitle: "Pour le moment, simulé automatiquement.",
                      value: _sendWhatsapp,
                      onChanged: (v) => setState(() => _sendWhatsapp = v),
                      color: emerald,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Annuler", style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _generateMassPayrolls(),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Lancer la génération"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: color.withValues(alpha: 0.5),
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }
}
