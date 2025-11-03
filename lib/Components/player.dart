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

    // Shield efekti - Koruyucu kalkan animasyonu (dönen halkalar)
    if (gameController.shieldActive) {
      // Dış glow efekti - nefes alıyor gibi
      final outerGlow = Paint()
        ..color = Colors.cyan.withOpacity(0.3 * pulse)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 20);
      canvas.drawCircle(center, radius + 20 * pulse, outerGlow);

      // İç kalkan - dönen halkalar (koruma hissi veriyor)
      for (int i = 0; i < 3; i++) {
        final rotation = (time * 60 + i * 120) * 3.14159 / 180.0;
        final ringRadius = radius + 12 + (i * 4);
        final ringOpacity = 0.6 - (i * 0.15);
        
        final shieldRing = Paint()
          ..color = Colors.cyan.withOpacity(ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 - (i * 0.5);
        
        // Kısmi halka çizimi (koruma hissi)
        final path = Path();
        for (int j = 0; j < 8; j++) {
          final angle = rotation + (j * 45.0 * 3.14159) / 180.0;
          final x = center.dx + ringRadius * cos(angle);
          final y = center.dy + ringRadius * sin(angle);
          if (j == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, shieldRing);
      }
    }

    // Speed efekti - Hız çizgileri (hareket hissi veriyor)
    if (gameController.tapRadiusMultiplier > 1.0) {
      // Dış aura - mavi enerji
      final speedAura = Paint()
        ..color = Colors.blue.withOpacity(0.25 * pulse)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 15);
      canvas.drawCircle(center, radius + 25 * pulse, speedAura);

      // Dönen hız çizgileri (hareket yönü gösteriyor)
      final rotationSpeed = time * 180.0; // Dakikada 180 derece dönüş
      for (int i = 0; i < 12; i++) {
        final baseAngle = (i * 30.0 * 3.14159) / 180.0;
        final angle = baseAngle + (rotationSpeed * 3.14159 / 180.0);
        final startRadius = radius + 5;
        final endRadius = radius + 22;
        
        final startX = center.dx + startRadius * cos(angle);
        final startY = center.dy + startRadius * sin(angle);
        final endX = center.dx + endRadius * cos(angle);
        final endY = center.dy + endRadius * sin(angle);

        // Çizgi kalınlığı merkezden uzaklaştıkça azalıyor
        final linePaint = Paint()
          ..color = Colors.blue.withOpacity(0.7 - (i % 3) * 0.2)
          ..strokeWidth = 4.0 - (i % 2) * 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), linePaint);
      }
    }

    // MultiHit efekti - Çarpı işaretleri ve parçacıklar (güçlü vuruş hissi)
    if (gameController.scoreMultiplier > 1.0) {
      // Mor aura - güçlü vuruş enerjisi
      final multiHitAura = Paint()
        ..color = Colors.purple.withOpacity(0.35 * pulse)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18);
      canvas.drawCircle(center, radius + 22 * pulse, multiHitAura);

      // Dönen çarpı işaretleri (güçlü vuruş göstergesi)
      final crossRotation = time * 120.0;
      for (int i = 0; i < 4; i++) {
        final angle = (crossRotation + i * 90.0) * 3.14159 / 180.0;
        final crossRadius = radius + 15;
        final crossSize = 8.0 + (pulse * 4);
        
        final crossX = center.dx + crossRadius * cos(angle);
        final crossY = center.dy + crossRadius * sin(angle);
        
        final crossPaint = Paint()
          ..color = Colors.purple.withOpacity(0.9)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;
        
        // Çarpı çizimi (X)
        final crossAngle = angle + 3.14159 / 4;
        canvas.drawLine(
          Offset(crossX - crossSize * cos(crossAngle), crossY - crossSize * sin(crossAngle)),
          Offset(crossX + crossSize * cos(crossAngle), crossY + crossSize * sin(crossAngle)),
          crossPaint,
        );
        canvas.drawLine(
          Offset(crossX - crossSize * cos(crossAngle + 3.14159 / 2), crossY - crossSize * sin(crossAngle + 3.14159 / 2)),
          Offset(crossX + crossSize * cos(crossAngle + 3.14159 / 2), crossY + crossSize * sin(crossAngle + 3.14159 / 2)),
          crossPaint,
        );
      }

      // Parçacık efektleri (çevrede küçük parıltılar)
      for (int i = 0; i < 16; i++) {
        final angle = (i * 22.5 * 3.14159) / 180.0 + (time * 90.0 * 3.14159 / 180.0);
        final particleRadius = radius + 28 + (pulse * 5);
        final particleX = center.dx + particleRadius * cos(angle);
        final particleY = center.dy + particleRadius * sin(angle);

        final particlePaint = Paint()
          ..color = Colors.purple.withOpacity(0.9 * pulse);
        canvas.drawCircle(Offset(particleX, particleY), 3 + (pulse * 2), particlePaint);
      }
    }

    // Freeze efekti - Dondurma animasyonu (buz kristalleri)
    if (gameController.freezeActive) {
      // Mavi-beyaz aura - soğuk hissi
      final freezeAura = Paint()
        ..color = Colors.lightBlue.withOpacity(0.3 * pulse)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18);
      canvas.drawCircle(center, radius + 18 * pulse, freezeAura);

      // Buz kristalleri (dönen altıgen desenler)
      final crystalRotation = time * 60.0;
      for (int i = 0; i < 6; i++) {
        final angle = (crystalRotation + i * 60.0) * 3.14159 / 180.0;
        final crystalRadius = radius + 12;
        final crystalX = center.dx + crystalRadius * cos(angle);
        final crystalY = center.dy + crystalRadius * sin(angle);
        
        final crystalPaint = Paint()
          ..color = Colors.cyan.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        
        // Altıgen buz kristali çizimi
        final crystalSize = 6.0 + (pulse * 3);
        final path = Path();
        for (int j = 0; j < 6; j++) {
          final crystalAngle = (j * 60.0 * 3.14159) / 180.0 + angle;
          final x = crystalX + crystalSize * cos(crystalAngle);
          final y = crystalY + crystalSize * sin(crystalAngle);
          if (j == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, crystalPaint);
      }

      // Merkezdeki buz pulu efekti
      final snowFlakePaint = Paint()
        ..color = Colors.white.withOpacity(0.9 * pulse)
        ..strokeWidth = 2.0;
      
      for (int i = 0; i < 4; i++) {
        final angle = (i * 45.0 * 3.14159) / 180.0;
        final lineLength = 8.0 + (pulse * 4);
        canvas.drawLine(
          Offset(center.dx - lineLength * cos(angle), center.dy - lineLength * sin(angle)),
          Offset(center.dx + lineLength * cos(angle), center.dy + lineLength * sin(angle)),
          snowFlakePaint,
        );
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
