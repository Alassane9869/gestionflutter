
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/assistant/application/assistant_notification_service.dart';
import 'package:danaya_plus/features/assistant/domain/assistant_notification.dart';

// ─── Notification Type Detection ─────────────────────────────────────────────

enum _NotifType { alert, insight, report, info }

_NotifType _detectType(AssistantNotification n) {
  final t = '${n.title} ${n.message}'.toLowerCase();
  if (t.contains('alerte') || t.contains('rupture') || t.contains('urgent') || t.contains('critique') || t.contains('erreur')) return _NotifType.alert;
  if (t.contains('insight') || t.contains('opportunité') || t.contains('tendance') || t.contains('conseil') || t.contains('recommand')) return _NotifType.insight;
  if (t.contains('rapport') || t.contains('activité') || t.contains('résumé') || t.contains('clôture')) return _NotifType.report;
  return _NotifType.info;
}

IconData _typeIcon(_NotifType type) {
  return switch (type) {
    _NotifType.alert   => FluentIcons.warning_24_filled,
    _NotifType.insight => FluentIcons.lightbulb_24_filled,
    _NotifType.report  => FluentIcons.data_bar_vertical_24_filled,
    _NotifType.info    => FluentIcons.bot_sparkle_24_filled,
  };
}

Color _typeColor(_NotifType type) {
  return switch (type) {
    _NotifType.alert   => const Color(0xFFEF4444),
    _NotifType.insight => const Color(0xFFF59E0B),
    _NotifType.report  => const Color(0xFF6366F1),
    _NotifType.info    => const Color(0xFF3B82F6),
  };
}

String _typeLabel(_NotifType type) {
  return switch (type) {
    _NotifType.alert   => 'ALERTE',
    _NotifType.insight => 'INSIGHT',
    _NotifType.report  => 'RAPPORT',
    _NotifType.info    => 'MESSAGE',
  };
}

// ─── Main Dropdown ────────────────────────────────────────────────────────────

class AssistantNotificationDropdown extends ConsumerStatefulWidget {
  final VoidCallback onAction;

  const AssistantNotificationDropdown({super.key, required this.onAction});

  @override
  ConsumerState<AssistantNotificationDropdown> createState() => _AssistantNotificationDropdownState();
}

class _AssistantNotificationDropdownState extends ConsumerState<AssistantNotificationDropdown> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(assistantNotificationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unread = notifications.where((n) => !n.isRead).length;

    return Container(
      width: 420,
      constraints: const BoxConstraints(maxHeight: 560),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111318) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              _buildHeader(isDark, unread, notifications.length),

              // ── Body ──
              if (notifications.isEmpty)
                _buildEmptyState(isDark)
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      final isExpanded = _expandedId == n.id;
                      return _buildNotificationItem(n, index, isDark, isExpanded);
                    },
                  ),
                ),

              // ── Footer ──
              if (notifications.isNotEmpty)
                _buildFooter(isDark),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(
      begin: -0.02,
      end: 0,
      duration: 180.ms,
      curve: Curves.easeOut,
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, int unread, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(FluentIcons.bot_sparkle_20_filled, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Botifi',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '$total notification${total > 1 ? "s" : ""} • $unread non lu${unread > 1 ? "s" : ""}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0)
            _miniActionBtn(
              icon: FluentIcons.checkmark_circle_20_regular,
              tooltip: 'Tout marquer comme lu',
              color: const Color(0xFF3B82F6),
              isDark: isDark,
              onTap: () => ref.read(assistantNotificationProvider.notifier).markAllAsRead(),
            ),
        ],
      ),
    );
  }

  // ── Notification Item ───────────────────────────────────────────────────────

  Widget _buildNotificationItem(AssistantNotification n, int index, bool isDark, bool isExpanded) {
    final type = _detectType(n);
    final color = _typeColor(type);
    final icon = _typeIcon(type);
    final label = _typeLabel(type);

    return InkWell(
      onTap: () {
        // Mark as read + expand/collapse
        if (!n.isRead) {
          ref.read(assistantNotificationProvider.notifier).markAsRead(n.id);
        }
        setState(() {
          _expandedId = isExpanded ? null : n.id;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isExpanded
              ? color.withValues(alpha: isDark ? 0.08 : 0.04)
              : (n.isRead
                  ? Colors.transparent
                  : color.withValues(alpha: isDark ? 0.04 : 0.02)),
          borderRadius: BorderRadius.circular(10),
          border: isExpanded
              ? Border.all(color: color.withValues(alpha: 0.2), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(n.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!n.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700,
                          fontSize: 12.5,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2937),
                          height: 1.3,
                        ),
                        maxLines: isExpanded ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      AnimatedCrossFade(
                        firstChild: Text(
                          n.message,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondChild: Text(
                          n.message,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            height: 1.5,
                          ),
                        ),
                        crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        sizeCurve: Curves.easeOut,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Expanded action row
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _chipBtn(
                    label: 'Ouvrir dans Copilot',
                    icon: FluentIcons.bot_sparkle_16_regular,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                    onTap: () {
                      ref.read(assistantNotificationProvider.notifier).markAsRead(n.id);
                      widget.onAction();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(
      duration: 200.ms,
      delay: Duration(milliseconds: index * 30),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2028) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              FluentIcons.checkmark_circle_24_regular,
              size: 24,
              color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Botifi vous notifiera quand\nun événement important survient.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _footerBtn(
              label: 'Tout lire',
              icon: FluentIcons.checkmark_circle_16_regular,
              color: const Color(0xFF3B82F6),
              isDark: isDark,
              onTap: () => ref.read(assistantNotificationProvider.notifier).markAllAsRead(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _footerBtn(
              label: 'Effacer tout',
              icon: FluentIcons.delete_16_regular,
              color: const Color(0xFFEF4444),
              isDark: isDark,
              onTap: () => ref.read(assistantNotificationProvider.notifier).clearAll(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _miniActionBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  Widget _chipBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }
}
