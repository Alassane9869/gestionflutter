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
  late List<_Point3D> _points;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // 🌌 Initialisation des points 3D pour la constellation
    final random = math.Random();
    _points = List.generate(70, (index) {
      return _Point3D(
        x: (random.nextDouble() - 0.5) * 800,
        y: (random.nextDouble() - 0.5) * 600,
        z: (random.nextDouble() - 0.5) * 400,
        vx: (random.nextDouble() - 0.5) * 1.0,
        vy: (random.nextDouble() - 0.5) * 1.0,
        vz: (random.nextDouble() - 0.5) * 1.0,
        radius: random.nextDouble() * 2.5 + 1.2,
      );
    });
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
        // ── BASE BACKGROUND GRADIENT ──
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF020203), const Color(0xFF06070B)]
                      : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        
        // ── SMOOTH GLOWING ORBS (Compositor-friendly) ──
        _AnimatedOrb(
          controller: _animationController,
          color: theme.colorScheme.primary,
          isDark: isDark,
          baseOffset: const Offset(0.15, 0.2),
          radius: 700,
          movementParams: [0.0, 50.0, 1.0, 40.0],
        ),
        _AnimatedOrb(
          controller: _animationController,
          color: Colors.indigoAccent,
          isDark: isDark,
          baseOffset: const Offset(0.85, 0.75),
          radius: 900,
          movementParams: [1.5, 60.0, 0.5, 50.0],
        ),
        _AnimatedOrb(
          controller: _animationController,
          color: Colors.purpleAccent,
          isDark: isDark,
          baseOffset: const Offset(0.5, 0.45),
          radius: 600,
          movementParams: [3.0, 40.0, 2.0, 60.0],
        ),

        // ── INTERACTIVE 3D CONSTELLATION LAYER ──
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final val = _animationController.value;
              final angleY = val * 2 * math.pi;
              final angleX = math.sin(val * 2 * math.pi) * 0.25;

              // Mettre à jour la physique des points
              for (final p in _points) {
                p.x += p.vx;
                p.y += p.vy;
                p.z += p.vz;
                if (p.x.abs() > 400) p.vx *= -1;
                if (p.y.abs() > 300) p.vy *= -1;
                if (p.z.abs() > 200) p.vz *= -1;
              }

              return CustomPaint(
                painter: _Constellation3DPainter(
                  angleX: angleX,
                  angleY: angleY,
                  points: _points,
                  primaryColor: theme.colorScheme.primary,
                  accentColor: Colors.indigoAccent,
                  isDark: isDark,
                ),
              );
            },
          ),
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
                    color.withValues(alpha: isDark ? 0.08 : 0.04),
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

class _Constellation3DPainter extends CustomPainter {
  final double angleX;
  final double angleY;
  final List<_Point3D> points;
  final Color primaryColor;
  final Color accentColor;
  final bool isDark;

  _Constellation3DPainter({
    required this.angleX,
    required this.angleY,
    required this.points,
    required this.primaryColor,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const fov = 350.0;

    final cosX = math.cos(angleX);
    final sinX = math.sin(angleX);
    final cosY = math.cos(angleY * 0.15); // Rotation lente
    final sinY = math.sin(angleY * 0.15);

    final projected = <Offset>[];
    final alphas = <double>[];
    final radiuses = <double>[];

    // ── ROTATION 3D ET PERSPECTIVE ──
    for (final p in points) {
      // Rotation Y (Horizontal)
      double x1 = p.x * cosY - p.z * sinY;
      double z1 = p.x * sinY + p.z * cosY;

      // Rotation X (Verticale)
      double y2 = p.y * cosX - z1 * sinX;
      double z2 = p.y * sinX + z1 * cosX;

      // Projection perspective
      final scale = fov / (fov + z2);
      final px = cx + x1 * scale;
      final py = cy + y2 * scale;

      projected.add(Offset(px, py));
      alphas.add(((fov - z2) / fov).clamp(0.1, 1.0));
      radiuses.add(p.radius * scale);
    }

    final paintPoint = Paint()..style = PaintingStyle.fill;
    final paintLine = Paint()..style = PaintingStyle.stroke;

    // ── LIAISONS DE CONSTELLATION 3D ──
    for (int i = 0; i < points.length; i++) {
      final pA = points[i];
      final projA = projected[i];
      if (projA.dx < 0 || projA.dx > size.width || projA.dy < 0 || projA.dy > size.height) continue;

      for (int j = i + 1; j < points.length; j++) {
        final pB = points[j];
        final projB = projected[j];

        // Distance dans l'espace 3D réel
        final dx = pA.x - pB.x;
        final dy = pA.y - pB.y;
        final dz = pA.z - pB.z;
        final dist3d = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (dist3d < 140) {
          final alphaLine = (1.0 - dist3d / 140) * math.min(alphas[i], alphas[j]) * (isDark ? 0.14 : 0.08);
          if (alphaLine > 0.01) {
            paintLine.color = accentColor.withValues(alpha: alphaLine);
            paintLine.strokeWidth = 0.7 * math.min(alphas[i], alphas[j]);
            canvas.drawLine(projA, projB, paintLine);
          }
        }
      }
    }

    // ── DESSIN DES NŒUDS LUMINEUX ──
    for (int i = 0; i < projected.length; i++) {
      final proj = projected[i];
      if (proj.dx < 0 || proj.dx > size.width || proj.dy < 0 || proj.dy > size.height) continue;

      final alpha = alphas[i] * (isDark ? 0.35 : 0.18);
      if (alpha > 0.01) {
        paintPoint.color = primaryColor.withValues(alpha: alpha);
        canvas.drawCircle(proj, radiuses[i], paintPoint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Constellation3DPainter oldDelegate) {
    return true; // Animation constante
  }
}

class _Point3D {
  double x, y, z;
  double vx, vy, vz;
  final double radius;

  _Point3D({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.radius,
  });
}
