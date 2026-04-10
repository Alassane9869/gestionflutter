import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

class OpenSessionScreen extends ConsumerStatefulWidget {
  const OpenSessionScreen({super.key});

  @override
  ConsumerState<OpenSessionScreen> createState() => _OpenSessionScreenState();
}

class _OpenSessionScreenState extends ConsumerState<OpenSessionScreen> {
  final _amountCtrl = TextEditingController();
  bool _isLoading = false;

  void _openSession() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez saisir un montant valide.")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(sessionServiceProvider).openSession(amount);
      // activeSessionProvider is invalidated, UI will automatically navigate away
    } on SessionConflictException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      final user = ref.read(authServiceProvider).value;
      final canForce = user?.isAdmin == true || user?.isManager == true || user?.role == UserRole.adminPlus;

      if (canForce) {
        _showForceCloseDialog(e.ownerName, amount);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("La caisse est déjà ouverte par ${e.ownerName}. Seul un administrateur peut forcer la fermeture."),
          backgroundColor: Colors.amber.shade900,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  void _showForceCloseDialog(String ownerName, double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Caisse occupée"),
        content: Text("$ownerName n'a pas fermé sa session. Voulez-vous forcer la fermeture pour ouvrir votre propre session sur cette machine ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await ref.read(sessionServiceProvider).openSession(amount, forceClose: true);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                setState(() => _isLoading = false);
              }
            },
            child: const Text("Forcer la Fermeture"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(48),
          decoration: AppTheme.strictBorder(isDark).copyWith(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(FluentIcons.wallet_48_regular, color: theme.colorScheme.primary, size: 40),
              ),
              const SizedBox(height: 24),
              Text("Ouverture de Caisse", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                "Vous devez déclarer le fond de tiroir initial avant de commencer vos ventes.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: "Fond de Caisse (DA)",
                  labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  prefixIcon: const Icon(FluentIcons.money_24_regular),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF16181D) : const Color(0xFFF9FAFB),
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _openSession,
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Ouvrir la Session", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.read(authServiceProvider.notifier).logout(),
                icon: const Icon(FluentIcons.sign_out_20_regular, size: 18),
                label: const Text("Se Déconnecter", style: TextStyle(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
