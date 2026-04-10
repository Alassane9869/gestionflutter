import 'dart:math' as math;
import 'package:flutter/material.dart';

class PremiumAnimatedBackground extends StatefulWidget {
  final Widget? child;

  const PremiumAnimatedBackground({super.key, this.child});

  @override
  State<PremiumAnimatedBackground> createState() => _PremiumAnimatedBackgroundState();
}

class _PremiumAnimatedBackgroundState extends State<PremiumAnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Base Background
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F1115), const Color(0xFF16181D)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        
        // Animated Orbs (Compositor-friendly)
        _AnimatedOrb(
          controller: _animationController,
          color: theme.colorScheme.primary,
          isDark: isDark,
          baseOffset: const Offset(0.2, 0.2),
          radius: 600,
          movementParams: [0.0, 40.0, 1.0, 30.0],
        ),
        _AnimatedOrb(
          controller: _animationController,
          color: Colors.indigoAccent,
          isDark: isDark,
          baseOffset: const Offset(0.8, 0.7),
          radius: 800,
          movementParams: [1.5, 50.0, 0.5, 40.0],
        ),
        _AnimatedOrb(
          controller: _animationController,
          color: Colors.purpleAccent,
          isDark: isDark,
          baseOffset: const Offset(0.5, 0.4),
          radius: 500,
          movementParams: [3.0, 30.0, 2.0, 50.0],
        ),

        if (widget.child != null) Positioned.fill(child: widget.child!),
      ],
    );
  }
}

class _AnimatedOrb extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final bool isDark;
  final Offset baseOffset;
  final double radius;
  final List<double> movementParams;

  const _AnimatedOrb({
    required this.controller,
    required this.color,
    required this.isDark,
    required this.baseOffset,
    required this.radius,
    required this.movementParams,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animationValue = controller.value;
        final offsetX = math.sin(animationValue * 2 * math.pi + movementParams[0]) * movementParams[1];
        final offsetY = math.cos(animationValue * 2 * math.pi + movementParams[2]) * movementParams[3];

        return Positioned(
          left: (MediaQuery.of(context).size.width * baseOffset.dx) + offsetX - (radius / 2),
          top: (MediaQuery.of(context).size.height * baseOffset.dy) + offsetY - (radius / 2),
          child: RepaintBoundary(
            child: Container(
              width: radius,
              height: radius,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: isDark ? 0.12 : 0.06),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

