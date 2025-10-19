import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';
import 'Util/knows_game_size.dart';

class LottieEnemy extends SpriteComponent with KnowsGameSize {
  final GameController gameController;
  bool isDead = false;

  LottieEnemy(
    this.gameController, {
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
  }) : super(sprite: sprite, position: position, size: size) {
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;
    super.render(canvas);
  }
}
