import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

class AutoLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AutoLockWrapper({super.key, required this.child});

  @override
  ConsumerState<AutoLockWrapper> createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends ConsumerState<AutoLockWrapper> {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();

    // Check if user is logged in
    final user = ref.read(authServiceProvider).value;
    if (user == null) return;

    // Check settings
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null || !settings.isAutoLockEnabled) return;

    final int minutes = settings.autoLockMinutes;
    if (minutes <= 0) return;

    _inactivityTimer = Timer(Duration(minutes: minutes), _lockSession);
  }

  void _lockSession() {
    final user = ref.read(authServiceProvider).value;
    if (user != null) {
      ref.read(authServiceProvider.notifier).logout();
    }
  }

  void _handleInteraction(_) {
    _resetTimer();
  }

  @override
  Widget build(BuildContext context) {
    // Écoute les changements de settings et d'auth pour réagir dynamiquement
    ref.listen(authServiceProvider, (prev, next) {
      _resetTimer();
    });
    ref.listen(shopSettingsProvider, (prev, next) {
      _resetTimer();
    });

    return Listener(
      onPointerDown: _handleInteraction,
      onPointerMove: _handleInteraction,
      onPointerUp: _handleInteraction,
      behavior: HitTestBehavior.translucent,
      child: Focus(
        autofocus: true,
        canRequestFocus: false,
        onKeyEvent: (node, event) {
          _handleInteraction(null);
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}
