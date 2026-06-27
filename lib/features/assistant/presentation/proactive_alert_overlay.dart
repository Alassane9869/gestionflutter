import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/assistant/application/assistant_service.dart';

class ProactiveAlertOverlay extends StatefulWidget {
  final String title;
  final String message;
  final AlertLevel level;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;

  const ProactiveAlertOverlay({
    super.key,
    required this.title,
    required this.message,
    this.level = AlertLevel.info,
    required this.onDismiss,
    this.onAction,
  });

  @override
  State<ProactiveAlertOverlay> createState() => _ProactiveAlertOverlayState();
}

class _ProactiveAlertOverlayState extends State<ProactiveAlertOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color accentColor;
    final IconData iconData;
    final Color? textTint;

    switch (widget.level) {
      case AlertLevel.error:
        accentColor = Colors.redAccent;
        iconData = FluentIcons.error_circle_24_filled;
        textTint = Colors.red.withValues(alpha: 0.05);
        break;
      case AlertLevel.warning:
        accentColor = Colors.orangeAccent;
        iconData = FluentIcons.warning_24_filled;
        textTint = Colors.orange.withValues(alpha: 0.05);
        break;
      case AlertLevel.success:
        accentColor = Colors.green;
        iconData = FluentIcons.checkmark_circle_24_filled;
        textTint = Colors.green.withValues(alpha: 0.05);
        break;
      case AlertLevel.info:
        accentColor = theme.colorScheme.primary;
        iconData = FluentIcons.bot_sparkle_24_filled;
        textTint = null;
        break;
    }

    final backgroundColor = isDark 
        ? const Color(0xFF1E1E1E)
        : Colors.white;
        
    final borderColor = isDark
        ? accentColor.withValues(alpha: 0.3)
        : accentColor.withValues(alpha: 0.15);

    return SafeArea(
      child: Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, left: 20, right: 20),
          constraints: const BoxConstraints(maxWidth: 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: textTint != null 
                    ? Color.alphaBlend(textTint, backgroundColor)
                    : backgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: isDark ? 0.2 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Row(
                      children: [
                        // Icône premium avec petit effet d'apparition
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconData, 
                            color: accentColor, 
                            size: 20,
                          ),
                        ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                        const SizedBox(width: 14),
                        // Textes
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title, 
                                style: TextStyle(
                                  fontWeight: FontWeight.w800, 
                                  fontSize: 13.5,
                                  letterSpacing: -0.2,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.message, 
                                style: TextStyle(
                                  fontSize: 11.5, 
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Action button (optionnel) ou dismiss
                        if (widget.onAction != null) ...[
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: accentColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: widget.onAction,
                            child: const Text("Voir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          icon: const Icon(FluentIcons.dismiss_16_regular, size: 16),
                          onPressed: widget.onDismiss,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar indicator (durée de vie du toast)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 3,
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: 1.0 - _progressController.value,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      accentColor.withValues(alpha: 0.8),
                                      accentColor.withValues(alpha: 0.3),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate()
     .slideY(begin: -0.4, end: 0, duration: 450.ms, curve: Curves.easeOutCubic)
     .fadeIn(duration: 300.ms);
  }
}
