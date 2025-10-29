import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';

class Player extends SpriteComponent with KnowsGameSize {
  final GameController gameController;
  double currentHealth = 100;
  // isDead değişkenini tamamen kaldırdık

  Player({
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
    GameController? gameController,
  })  : gameController = gameController ?? GameController(),
        super(sprite: sprite, position: position, size: size) {
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    if (sprite == null) return;
    if (parent == null) return;

    // Aktif power-up efektlerini göster
    _renderActivePowerUps(canvas);

    super.render(canvas);
  }

  void _renderActivePowerUps(Canvas canvas) {
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final pulse = (sin(time * 4.0) + 1) / 2;
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;

    // Shield efekti - mavi aura
    if (gameController.shieldActive) {
      final shieldPaint = Paint()
        ..color = Colors.cyan.withOpacity(0.4 * pulse)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 15);
      canvas.drawCircle(center, radius + 15 * pulse, shieldPaint);

      final shieldRing = Paint()
        ..color = Colors.cyan.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(center, radius + 10, shieldRing);
    }

    // Speed efekti - mavi hız çizgileri
    if (gameController.tapRadiusMultiplier > 1.0) {
      final speedPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3 * pulse)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
      canvas.drawCircle(center, radius + 20 * pulse, speedPaint);

      // Hız çizgileri
      for (int i = 0; i < 8; i++) {
        final angle = (i * 45.0 * 3.14159) / 180.0;
        final startX = center.dx + (radius - 5) * cos(angle);
        final startY = center.dy + (radius - 5) * sin(angle);
        final endX = center.dx + (radius + 15) * cos(angle);
        final endY = center.dy + (radius + 15) * sin(angle);

        final linePaint = Paint()
          ..color = Colors.blue.withOpacity(0.6)
          ..strokeWidth = 3.0;
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), linePaint);
      }
    }

    // MultiHit efekti - mor parçacıklar
    if (gameController.scoreMultiplier > 1.0) {
      final multiHitPaint = Paint()
        ..color = Colors.purple.withOpacity(0.3 * pulse)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);
      canvas.drawCircle(center, radius + 18 * pulse, multiHitPaint);

      // Parçacık efektleri (çevrede küçük daireler)
      for (int i = 0; i < 12; i++) {
        final angle = (i * 30.0 * 3.14159) / 180.0;
        final particleX = center.dx + (radius + 25) * cos(angle);
        final particleY = center.dy + (radius + 25) * sin(angle);

        final particlePaint = Paint()
          ..color = Colors.purple.withOpacity(0.8 * pulse);
        canvas.drawCircle(
            Offset(particleX, particleY), 4 * pulse, particlePaint);
      }
    }
  }

  void updatePosition(Vector2 newPosition) {
    position = newPosition;
  }

  void takeDamage(double damage) {
    currentHealth -= damage;
    if (currentHealth <= 0) {
      currentHealth = 0;
    }
  }

  // Canı yenileme metodu
  void heal(double amount) {
    currentHealth += amount;
    if (currentHealth > 100) {
      currentHealth = 100;
    }
  }

  // Canı sıfırlama metodu
  void resetHealth() {
    currentHealth = 100;
  }
}
