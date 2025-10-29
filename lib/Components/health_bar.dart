import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';

class HealthBar extends Component {
  final GameController gameController;
  HealthBar({required this.gameController});

  Color _getHealthColor(double healthRatio) {
    if (healthRatio < 0.3) {
      return const Color(0xFFFF4757); // Kırmızı - Kritik
    } else if (healthRatio < 0.5) {
      return const Color(0xFFFFA502); // Turuncu - Düşük
    } else {
      return const Color(0xFF2ED573); // Yeşil - Sağlıklı
    }
  }

  @override
  void render(Canvas canvas) {
    final healthRatio = gameController.player.currentHealth / 100.0;
    final isCriticalHealth = healthRatio < 0.15;
    final healthColor = _getHealthColor(healthRatio);

    final barHeight = gameController.size.y * 0.008;

    final barWidth = gameController.size.x / 1.75;
    // const margin = 20.0;
    // final barWidth = gameController.size.x - (2 * margin);
    final barY = gameController.size.y * 0.8; // Alt kısımdan 50px yukarı
    final barX = gameController.size.x / 2 - barWidth / 2;

    // Arka plan barı
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final backgroundRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barX, barY, barWidth, barHeight),
      const Radius.circular(4),
    );
    canvas.drawRRect(backgroundRect, backgroundPaint);

    // Kenarlık
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(backgroundRect, borderPaint);

    // Can barı
    final healthBarWidth = barWidth * healthRatio;
    if (healthBarWidth > 0) {
      final healthBarPaint = Paint()
        ..color = healthColor
        ..style = PaintingStyle.fill;

      final healthBarRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, healthBarWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(healthBarRect, healthBarPaint);

      // Can çok düşükse yanıp sönen efekt
      if (isCriticalHealth) {
        final pulseIntensity =
            (sin(gameController.pulseAnimationValue * 3) + 1) / 2;
        final glowPaint = Paint()
          ..color = healthColor.withOpacity(pulseIntensity * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

        final glowRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barX - 5, barY - 3, healthBarWidth + 10, barHeight + 6),
          const Radius.circular(6),
        );
        canvas.drawRRect(glowRect, glowPaint);
      }
    }

    // Can yüzdesi yazısı
    TextPaint healthText = TextPaint(
      style: TextStyle(
        color: healthColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 3,
            color: Colors.black.withOpacity(0.8),
          ),
        ],
      ),
    );

    healthText.render(
      canvas,
      "${gameController.player.currentHealth.toInt()} ❤️",
      Vector2(barX + barWidth - 5, barY - 20),
      anchor: Anchor.topRight,
    );
  }
}
