import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:smash_the_insect/Components/Util/state.dart';
import '../game_controller.dart';

class PauseMenu extends Component with HasGameRef<GameController> {
  late Rect _menuRect;
  late Rect _resumeButtonRect;
  late Rect _restartButtonRect;
  late Rect _mainMenuButtonRect;

  bool _isVisible = false;
  Color _backgroundColor = Colors.black.withOpacity(0.7);
  Color _buttonColor = const Color(0xFF4CAF50);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _calculateRects();
  }

  void _calculateRects() {
    final screenSize = gameRef.size;
    final centerX = screenSize.x / 2;
    final centerY = screenSize.y / 2;

    // Ana menü dikdörtgeni
    _menuRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: 300,
      height: 400,
    );

    // Butonlar
    final buttonWidth = 200.0;
    final buttonHeight = 50.0;
    final buttonSpacing = 70.0;

    _resumeButtonRect = Rect.fromCenter(
      center: Offset(centerX, centerY - buttonSpacing),
      width: buttonWidth,
      height: buttonHeight,
    );

    _restartButtonRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: buttonWidth,
      height: buttonHeight,
    );

    _mainMenuButtonRect = Rect.fromCenter(
      center: Offset(centerX, centerY + buttonSpacing),
      width: buttonWidth,
      height: buttonHeight,
    );
  }

  @override
  void render(Canvas canvas) {
    if (!_isVisible) return;

    // Arka plan
    canvas.drawRect(_menuRect, Paint()..color = _backgroundColor);

    // Menü başlığı
    final titlePaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );

    titlePaint.render(
      canvas,
      "OYUN DURAKLADI",
      Vector2(gameRef.size.x / 2, _menuRect.top + 60),
      anchor: Anchor.topCenter,
    );

    // Butonları çiz
    _drawButton(canvas, _resumeButtonRect, "DEVAM ET", Colors.white);
    _drawButton(canvas, _restartButtonRect, "YENİDEN BAŞLAT", Colors.white);
    _drawButton(canvas, _mainMenuButtonRect, "ANA MENÜ", Colors.white);
  }

  void _drawButton(Canvas canvas, Rect rect, String text, Color textColor) {
    // Buton arka planı
    final buttonPaint = Paint()..color = _buttonColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      buttonPaint,
    );

    // Buton metni
    final textPaint = TextPaint(
      style: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );

    textPaint.render(
      canvas,
      text,
      Vector2(rect.center.dx, rect.center.dy),
      anchor: Anchor.center,
    );
  }

  bool onTapDown(TapDownInfo info) {
    if (!_isVisible) return false;

    final tapPoint = info.eventPosition.global;

    if (_resumeButtonRect.contains(tapPoint.toOffset())) {
      _resumeGame();
      return true;
    } else if (_restartButtonRect.contains(tapPoint.toOffset())) {
      _restartGame();
      return true;
    } else if (_mainMenuButtonRect.contains(tapPoint.toOffset())) {
      _goToMainMenu();
      return true;
    }

    return false;
  }

  void show() {
    _isVisible = true;
    gameRef.pauseEngine();
  }

  void hide() {
    _isVisible = false;
    gameRef.resumeEngine();
  }

  void _resumeGame() {
    hide();
    gameRef.gameState = GameState.playing;
  }

  void _restartGame() {
    hide();
    gameRef.gameState = GameState.start;
  }

  void _goToMainMenu() {
    hide();
    gameRef.gameState = GameState.start;
  }

  bool get isVisible => _isVisible;
}
