import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';

class AppearanceSettingsSection extends ConsumerWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeNotifierProvider);
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. MODE D'AFFICHAGE ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.eye_tracking_24_filled,
          title: "Expérience Visuelle",
          subtitle: "Basculez entre les thèmes clair et sombre",
          color: c.blue,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Row(
            children: [
              _buildModeCard(
                context,
                ref,
                ThemeMode.light,
                FluentIcons.weather_sunny_24_filled,
                "Mode Clair",
                currentTheme.mode == ThemeMode.light,
                c.amber,
                c,
              ),
              const SizedBox(width: 16),
              _buildModeCard(
                context,
                ref,
                ThemeMode.dark,
                FluentIcons.weather_moon_24_filled,
                "Mode Sombre",
                currentTheme.mode == ThemeMode.dark,
                c.violet,
                c,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 2. PALETTE D'ACCENTUATION ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.color_24_filled,
          title: "Identité Colorimétrique",
          subtitle: "Personnalisez la couleur d'accentuation principale",
          color: c.emerald,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.8,
            ),
            itemCount: AppThemeColor.values.length,
            itemBuilder: (ctx, i) {
              final colorOption = AppThemeColor.values[i];
              final isSelected = currentTheme.color == colorOption;
              return _buildColorCard(ref, colorOption, isSelected, c);
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildModeCard(BuildContext context, WidgetRef ref, ThemeMode mode, IconData icon, String label, bool active, Color color, DashColors c) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeNotifierProvider.notifier).setThemeMode(mode),
        child: AnimatedContainer(
          duration: 300.ms,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.1) : c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? color : c.border.withValues(alpha: 0.5), width: active ? 2 : 1),
            boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))] : null,
          ),
          child: Column(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: icon, color: active ? color : c.textMuted),
              const SizedBox(height: 12),
              Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: active ? color : c.textSecondary)),
              const SizedBox(height: 6),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: const Text("ACTIF", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorCard(WidgetRef ref, AppThemeColor option, bool isSelected, DashColors c) {
    final color = option.color;
    return GestureDetector(
      onTap: () => ref.read(themeNotifierProvider.notifier).setThemeColor(option),
      child: AnimatedContainer(
        duration: 200.ms,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : c.isDark ? Colors.black.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : c.border.withValues(alpha: 0.5), width: isSelected ? 2 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color, 
                shape: BoxShape.circle, 
                border: Border.all(color: Colors.white, width: 2), 
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)]
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.name.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isSelected ? color : c.textSecondary, letterSpacing: 0.5),
              ),
            ),
            if (isSelected) Icon(FluentIcons.checkmark_circle_16_filled, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
