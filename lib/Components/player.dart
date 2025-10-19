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
    // Debug mesajları - her render'da çalışsın
    print("=== PLAYER RENDER ===");
    print("Sprite: ${sprite != null}");
    print("Position: $position");
    print("Size: $size");
    print("Health: $currentHealth");
    print("Anchor: $anchor");
    print("Parent: ${parent != null}");

    if (sprite == null) {
      print("SPRITE NULL! Pasta render edilemiyor!");
      return;
    }

    if (parent == null) {
      print("PARENT NULL! Pasta parent'tan ayrılmış!");
      return;
    }

    print("Pasta render ediliyor...");
    super.render(canvas);
    print("Pasta render tamamlandı");
  }

  void updatePosition(Vector2 newPosition) {
    position = newPosition;
  }

  void takeDamage(double damage) {
    print("=== PLAYER TAKE DAMAGE ===");
    print("Hasar öncesi can: $currentHealth");
    print("Alınan hasar: $damage");

    currentHealth -= damage;
    if (currentHealth <= 0) {
      currentHealth = 0;
      print("CAN BİTTİ! Oyun bitecek!");
    }

    print("Hasar sonrası can: $currentHealth");

    // Hasar efekti kaldırıldı - pasta kaybolmasını önlemek için
    print("Hasar efekti kaldırıldı - pasta kaybolmasını önlemek için");
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
