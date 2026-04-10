import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../features/inventory/presentation/widgets/dashboard_widgets.dart';

/// Composants Premium pour les écrans de paramètres (Design "Bento" / Compact)
class PremiumSettingsWidgets {
  
  // ── 1. CARTES ET SECTIONS ──

  /// Carte principale avec effet de flou optionnel
  static Widget buildCard(BuildContext context, {required Widget child}) {
    final c = DashColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: c.isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Carte très décorée (Glassmorphism + Bordure lumineuse)
  static Widget buildGlassCard(BuildContext context, {required Widget child, Color? glowColor}) {
    final c = DashColors.of(context);
    final glow = glowColor ?? c.blue;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: glow.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: -5),
        ],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  /// En-tête de section Premium avec icône colorée
  static Widget buildSectionHeader(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, Widget? trailing}) {
    final c = DashColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: c.textPrimary)),
                Text(subtitle, style: TextStyle(fontSize: 9.5, color: c.textMuted)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Pastille d'icône pour l'intérieur des cartes
  static Widget buildIconBadge({required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, spreadRadius: -2)],
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  /// Pastille de statut "Actif/Inactif" ou "Configuré/Errone"
  static Widget buildStatusDot({required bool active, required String activeLabel, required String inactiveLabel}) {
    final color = active ? const Color(0xFF10b981) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF10b981).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? const Color(0xFF10b981).withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(
            active ? activeLabel : inactiveLabel,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  // ── 2. CONTRÔLES DE SAISIE COMPACTS ──

  /// Champ de texte universel compact
  static Widget buildCompactField(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required Color color,
    required VoidCallback onChanged,
    bool isPassword = false,
    bool isNumber = false,
    bool? showPassword,
    VoidCallback? onTogglePassword,
    int maxLines = 1,
  }) {
    final c = DashColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c.textSecondary, letterSpacing: 0.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: 1,
            obscureText: isPassword && !(showPassword ?? false),
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 10, color: c.textMuted.withValues(alpha: 0.5)),
              prefixIcon: Icon(icon, color: color.withValues(alpha: 0.7), size: 14),
              suffixIcon: isPassword && onTogglePassword != null
                  ? IconButton(
                      icon: Icon(
                        (showPassword ?? false) ? FluentIcons.eye_off_16_regular : FluentIcons.eye_16_regular,
                        size: 14, color: c.textMuted,
                      ),
                      onPressed: onTogglePassword,
                      splashRadius: 16,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: InputBorder.none,
              isDense: true,
            ),
            style: TextStyle(fontSize: 11, color: c.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// Bouton Interrupteur Compact et stylisé
  static Widget buildCompactSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
    required IconData icon,
  }) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: value ? activeColor.withValues(alpha: 0.05) : (c.isDark ? Colors.black.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value ? activeColor.withValues(alpha: 0.2) : (c.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: value ? activeColor.withValues(alpha: 0.15) : c.textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: value ? activeColor : c.textMuted, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: value ? c.textPrimary : c.textSecondary)),
                Text(subtitle, style: TextStyle(fontSize: 8.5, color: c.textMuted)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: activeColor),
        ],
      ),
    );
  }

  /// Menu déroulant Compact
  static Widget buildCompactDropdown<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color color,
  }) {
    final c = DashColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c.textSecondary, letterSpacing: 0.2)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: c.surfaceElev,
              borderRadius: BorderRadius.circular(8),
              icon: Icon(FluentIcons.chevron_down_16_regular, size: 14, color: color),
            ),
          ),
        ),
      ],
    );
  }

  /// Bouton Gradient premium
  static Widget buildGradientBtn({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required List<Color> colors,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3), spreadRadius: -2)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          splashColor: Colors.white.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Boîte d'information thématique
  static Widget buildInfoBox(BuildContext context, {required String text, required Color color, IconData icon = FluentIcons.info_16_regular}) {
    final c = DashColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 9, color: c.textSecondary, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
