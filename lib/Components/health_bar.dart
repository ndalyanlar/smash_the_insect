import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game_controller.dart';

class HealthBar extends Component {
  final GameController gameController;
  late Rect healthBarRect;
  late Rect remaingHealtRect;
  double? percentage;
  late double barWidht;
  HealthBar({required this.gameController}) {
    barWidht = gameController.size.x / 1.75;

    healthBarRect = Rect.fromLTWH(gameController.size.x / 2 - barWidht / 2,
        gameController.size.y * 0.8, barWidht, gameController.size.y * 0.008);
  }

  @override
  void render(Canvas canvas) {
    Paint healhtBarColor = Paint()..color = Colors.red;
    Paint remainingBarColor = Paint()..color = Colors.green;
    percentage = gameController.player.currentHealth / 100;
    remaingHealtRect = Rect.fromLTWH(
        gameController.size.x / 2 - barWidht / 2,
        gameController.size.y * 0.8,
        barWidht * percentage!,
        gameController.size.y * 0.008);
    canvas.drawRect(healthBarRect, healhtBarColor);
    canvas.drawRect(remaingHealtRect, remainingBarColor);
  }
}
