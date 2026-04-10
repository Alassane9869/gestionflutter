import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../application/rule_manager.dart';
import '../application/rule_engine.dart';

class RuleManagementScreen extends ConsumerWidget {
  const RuleManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(ruleManagerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Centre d'Automation Titan"),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.add_24_regular),
            onPressed: () => _showAddRuleDialog(context, ref),
          ),
        ],
      ),
      body: rules.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return _RuleCard(rule: rule);
              },
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.bot_sparkle_48_regular, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text("Aucune règle active", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Dites à l'IA : 'Si le stock est bas, préviens-moi'", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, WidgetRef ref) {
    // Basic implementation for now
  }
}

class _RuleCard extends ConsumerWidget {
  final BusinessRule rule;
  const _RuleCard({required this.rule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getIconForTrigger(rule.trigger), color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    "Condition: ${rule.conditions.entries.map((e) => '${e.key} ${e.value}').join(', ')}",
                    style: TextStyle(color: theme.hintColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: rule.isActive,
              onChanged: (_) => ref.read(ruleManagerProvider.notifier).toggleRule(rule.id),
            ),
            IconButton(
              icon: const Icon(FluentIcons.delete_24_regular, color: Colors.redAccent),
              onPressed: () => ref.read(ruleManagerProvider.notifier).removeRule(rule.id),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForTrigger(RuleTriggerType trigger) {
    switch (trigger) {
      case RuleTriggerType.stockLow: return FluentIcons.box_24_regular;
      case RuleTriggerType.saleLarge: return FluentIcons.money_24_regular;
      case RuleTriggerType.customerDebtExceeded: return FluentIcons.person_warning_24_regular;
      default: return FluentIcons.alert_24_regular;
    }
  }
}
