import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';

class Enemy extends SpriteComponent with KnowsGameSize {
  final GameController gameController;
  bool isDead = false;
  double speed = 50.0; // Hareket hızı
  bool isComboEnemy = false; // Büyük kombo düşman mı?
  int comboMultiplier = 1; // Kombo çarpanı

  // Kombo düşman için rastgele hareket
  Vector2? randomTarget;
  Timer? targetChangeTimer;
  final Random _random = Random();

  // Kombo düşman yaşam süresi ve çıkış davranışı
  Timer? lifeTimer; // Belirli süre sonra ekrandan çıkışa başla
  bool isExiting = false; // Ekrandan çıkış modunda mı?
  Vector2? exitTarget; // Ekran dışı hedef

  Enemy({
    required this.gameController,
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
    this.isComboEnemy = false,
    this.comboMultiplier = 1,
  }) : super(sprite: sprite, position: position, size: size) {
    anchor = Anchor.center;

    // Kombo düşman ise daha büyük ve yavaş olacak
    if (isComboEnemy) {
      // Size zaten constructor'da ayarlandı, burada sadece hızı ayarla
      speed = 30.0; // Yavaş hareket

      // Rastgele hedef için timer oluştur
      targetChangeTimer =
          Timer(3.0, onTick: () => _pickNewRandomTarget(), repeat: true);

      // Yaşam süresi: 8-12 saniye arası rastgele, sonra ekrandan çıkışa başlasın
      final lifeSeconds = 8.0 + _random.nextDouble() * 4.0;
      lifeTimer = Timer(lifeSeconds, onTick: _startExiting, repeat: false);
    }
  }

  void _pickNewRandomTarget() {
    // Ekranda rastgele bir nokta seç
    final gameSize = gameController.size;
    final x = _random.nextDouble() * gameSize.x;
    final y = _random.nextDouble() * gameSize.y;
    randomTarget = Vector2(x, y);
    if (kDebugMode) {
      print("🎯 Yeni hedef seçildi: $randomTarget (gameSize: $gameSize)");
    }
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Kombo düşmanlar için timer'ı başlat ve ilk hedefi seç
    if (isComboEnemy) {
      if (kDebugMode) {
        print("🎯 Kombo düşman oluşturuldu - size: $size");
      }
      targetChangeTimer?.start();
      _pickNewRandomTarget(); // İlk hedefi seç
      if (kDebugMode) {
        print("🎯 Kombo düşman ilk hedef: $randomTarget");
      }
      lifeTimer?.start();
    }
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    // Kombo düşman için özel efekti önce render et (arka plan)
    if (isComboEnemy) {
      final center = Offset(size.x / 2, size.y / 2);

      // Altın renkli kalın kenarlık (önce)
      final borderPaint = Paint()
        ..color = const Color.fromRGBO(255, 215, 0, 1.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;

      canvas.drawCircle(
        center,
        size.x / 2 - 5,
        borderPaint,
      );
    }

    // Sprite'ı render et
    super.render(canvas);

    // Kombo düşman için glow efekti (sprite'dan sonra, üstte)
    if (isComboEnemy) {
      final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final pulse = (sin(time * 3.0) + 1) / 2;

      final center = Offset(size.x / 2, size.y / 2);

      // Arka plan glow efekti
      final glowPaint = Paint()
        ..color = Color.fromRGBO(255, 215, 0, 0.4 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      canvas.drawCircle(
        center,
        size.x / 2 + 15 * pulse,
        glowPaint,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isDead) return;

    // Timer güncelle
    targetChangeTimer?.update(dt);
    lifeTimer?.update(dt);

    // Freeze aktifse hareket etme
    if (gameController.freezeActive) {
      return;
    }

    if (isComboEnemy) {
      // Çıkış modundaysa ekran dışı hedefe ilerle
      if (isExiting && exitTarget != null) {
        final direction = (exitTarget! - position).normalized();
        position += direction * speed * 1.2 * dt; // çıkarken biraz hızlan

        // Ekran sınırlarının yeterince dışına çıktıysa kendini sil
        final margin = 80.0;
        if (position.x < -margin ||
            position.y < -margin ||
            position.x > gameController.size.x + margin ||
            position.y > gameController.size.y + margin) {
          isDead = true;
          removeFromParent();
        }
      } else {
        // Kombo düşmanlar rastgele hareket etsin
        if (randomTarget != null) {
          final direction = (randomTarget! - position).normalized();
          position += direction * speed * dt;

          // Hedefe yaklaştıysa yeni hedef seç
          if (position.distanceTo(randomTarget!) < 5.0) {
            _pickNewRandomTarget();
          }
        }
      }
    } else {
      // Normal düşmanlar pastaya doğru hareket et (level hızı ile)
      final direction =
          (gameController.player.position - position).normalized();
      final currentSpeed = speed * gameController.enemySpeedMultiplier;
      position += direction * currentSpeed * dt;
    }
  }

  void _startExiting() {
    if (isDead) return;
    isExiting = true;
    // Mevcut pozisyona göre en yakın kenarı seç ve ekran dışı bir hedef belirle
    final gs = gameController.size;
    final distances = <String, double>{
      'top': position.y,
      'bottom': gs.y - position.y,
      'left': position.x,
      'right': gs.x - position.x,
    };
    // En küçük mesafeli kenarı seç
    String nearest = 'top';
    double minDist = distances[nearest]!;
    distances.forEach((key, value) {
      if (value < minDist) {
        nearest = key;
        minDist = value;
      }
    });

    final margin = 100.0;
    switch (nearest) {
      case 'top':
        exitTarget = Vector2(position.x, -margin);
        break;
      case 'bottom':
        exitTarget = Vector2(position.x, gs.y + margin);
        break;
      case 'left':
        exitTarget = Vector2(-margin, position.y);
        break;
      case 'right':
        exitTarget = Vector2(gs.x + margin, position.y);
        break;
    }
  }
}
