import 'package:flutter/material.dart';

class DribbbleWidgets {
  /// Un bloc d'information KPI ultra stylisé (Style Neo-Brutalisme doux / Apple)
  static Widget buildInfoBlock(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? badge,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF383838) : Colors.grey.shade200),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13)),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Text(badge, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(value, style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900, 
                  color: theme.textTheme.bodyLarge?.color,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Un filtre ou tag en haut de page (Ex: "Aujourd'hui", "En Ligne")
  static Widget buildTag(BuildContext context, String text, {IconData? icon, Color? iconColor}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF383838) : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor ?? theme.iconTheme.color),
            const SizedBox(width: 8),
          ],
          Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }

  /// Bouton IconButton customisé 
  static Widget buildIconBtn(BuildContext context, IconData icon, {bool isPrimary = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary ? theme.colorScheme.primary : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [],
      ),
      child: Icon(icon, color: isPrimary ? Colors.white : theme.iconTheme.color),
    );
  }
}
