import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/assistant/application/assistant_notification_service.dart';
import 'package:danaya_plus/features/assistant/domain/assistant_notification.dart';

class AssistantNotificationDropdown extends ConsumerWidget {
  final VoidCallback onAction;

  const AssistantNotificationDropdown({super.key, required this.onAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(assistantNotificationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 380,
      constraints: const BoxConstraints(maxHeight: 500),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2128).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
                ),
                child: Row(
                  children: [
                    const Icon(FluentIcons.bot_sparkle_20_filled, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      "Botifi - Danaya Intelligence",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    const Spacer(),
                    if (notifications.any((n) => !n.isRead))
                      TextButton(
                        onPressed: () => ref.read(assistantNotificationProvider.notifier).markAllAsRead(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text("Tout lire", style: TextStyle(fontSize: 11, color: Colors.blue)),
                      ),
                  ],
                ),
              ),
              
              // List
              if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(FluentIcons.archive_24_regular, size: 40, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("Aucune notification pour le moment.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return _NotificationItem(notification: n, onAction: onAction);
                    },
                  ),
                ),
              
              // Footer
              if (notifications.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
                  ),
                  child: TextButton(
                    onPressed: () => ref.read(assistantNotificationProvider.notifier).clearAll(),
                    child: const Text("Effacer l'historique", style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  final AssistantNotification notification;
  final VoidCallback onAction;

  const _NotificationItem({required this.notification, required this.onAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        ref.read(assistantNotificationProvider.notifier).markAsRead(notification.id);
        onAction();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : Colors.blue.withValues(alpha: 0.05),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: notification.isRead ? Colors.transparent : Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatTime(notification.timestamp),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                ],
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
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${dt.day}/${dt.month}";
  }
}
