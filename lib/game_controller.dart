import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

import 'Components/Util/knows_game_size.dart';
import 'Components/Util/state.dart';
import 'Components/enemy_manager.dart';
import 'Components/health_bar.dart';
import 'Components/player.dart';

class GameController extends FlameGame
    with PanDetector, HasGameRef, TapDetector {
  late Vector2 infoPoint = Vector2(0, 0);

  double score = 0;
  late EnemyManager enemyManager;
  late GameState gameState;
  late HealthBar healthBar;
  late Player player;

  late Sprite spriteExplosion;
  late Sprite spriteSpider;
  late Sprite spriteCockrock;

  List<double> playerDirection = [0, 0];
  late Random rnd;
  @override
  Future<void>? onLoad() async {
    super.onLoad();
    rnd = Random();

    await images.loadAll([
      "ant.png",
      "cake.png",
      "explosion.png",
      "hearth.png",
      "cockrock.png",
      "spider.png"
    ]);
    final _spriteCake = Sprite(images.fromCache("cake.png"));
    final _spriteAnt = Sprite(images.fromCache("ant.png"));
    spriteExplosion = Sprite(images.fromCache("explosion.png"));
    spriteSpider = Sprite(images.fromCache("spider.png"));
    spriteCockrock = Sprite(images.fromCache("cockrock.png"));

    healthBar = HealthBar(gameController: this);

    gameState = GameState.start;

    player = Player(
      sprite: _spriteCake,
      size: Vector2(64, 64),
      position: size / 2,
    );
    player.anchor = Anchor.center;

    add(player);

    enemyManager = EnemyManager(
        gameController: this, sprites: [_spriteAnt, spriteExplosion]);
    add(enemyManager);
  }

  @override
  void render(Canvas canvas) {
    if (gameState == GameState.start) {
      gameState = GameState.playing;
    }

    canvas.drawColor(Colors.grey.shade100, BlendMode.screen);

    TextPaint txtScore = TextPaint(
        config: const TextPaintConfig(color: Colors.black, fontSize: 40));
    TextPaint txtHealth = TextPaint(
        config: const TextPaintConfig(color: Colors.white, fontSize: 35));

    paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(size.x / 2 - 40, size.y - 80, 80, 80),
        image: images.fromCache("hearth.png"),
        alignment: Alignment.center);
    txtScore.render(canvas, score.toInt().toString(),
        Vector2(size.x / 2 + size.x / 3, size.y - 10),
        anchor: Anchor.bottomCenter);

    txtHealth.render(canvas, player.currentHealth.toInt().toString(),
        Vector2(size.x / 2, size.y - 25),
        anchor: Anchor.bottomCenter);

    enemyManager.enemyList.forEach((key, value) {
      if (player.currentHealth > 0) {
        if (key.containsPoint(infoPoint)) {
          if (key.isPressed) {
            enemyManager.removeAll([value, key]);
          }
        }
        player.containsPoint(key.position) && !key.isPressed
            ? {
                player.currentHealth -= 0.1,
              }
            : null;
      } else {
        gameState = GameState.end;
        remove(enemyManager);
      }
    });

    healthBar.render(canvas);

    super.render(canvas);
  }

  @override
  void prepare(Component parent) {
    if (parent is KnowsGameSize) {
      parent.onGameResize(size);
    }

    super.prepare(parent);
  }

  @override
  void update(double dt) {
    score >= 30 ? enemyManager.sprites = [spriteSpider, spriteExplosion] : null;
    score >= 60 ? enemyManager.sprites = [spriteSpider, spriteExplosion] : null;
    score % 5 == 0 && score != 0
        ? player.position = Vector2(playerDirection[0], playerDirection[1])
        : null;
    super.update(dt);
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);

    if (parent != null) {
      if (parent!.isPrepared) {
        parent!.children.whereType<KnowsGameSize>().forEach((component) {
          component.onGameResize(size);
        });
      }
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (gameState == GameState.playing) {
      score % 5 == 0 && score != 0
          ? playerDirection = [
              rnd.nextInt(size.toRect().width.toInt()).toDouble(),
              rnd.nextInt(size.toRect().height.toInt()).toDouble()
            ]
          : null;
      infoPoint = info.eventPosition.global;

      player.position.distanceTo(info.eventPosition.global) <= 30
          ? --player.currentHealth
          : null;

      enemyManager.enemyList.forEach((key, value) {
        if (key.containsPoint(infoPoint)) {
          key.isPressed = true;
          value.isPressed = true;
        }

        if (key.isPressed) {
          value.setOpacity(1);
          key.setOpacity(0);
        }
      });
    }
  }
}
