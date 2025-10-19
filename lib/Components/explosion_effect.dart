import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ExplosionEffect extends PositionComponent {
  final Vector2 _startPosition;
  final Random _random = Random();
  final List<_ExplosionParticle> _particles = [];

  ExplosionEffect({required Vector2 position}) : _startPosition = position {
    for (int i = 0; i < 15; i++) {
      _particles.add(_ExplosionParticle(
        position: _startPosition,
        velocity: Vector2(
          (_random.nextDouble() - 0.5) * 200,
          (_random.nextDouble() - 0.5) * 200,
        ),
        lifeTime: 0.3 + _random.nextDouble() * 0.3,
        color: _random.nextBool() ? Colors.orange : Colors.yellow,
      ));
    }

    // Efektin ömrü bittiğinde kendini kaldırması için
    add(TimerComponent(
      period: 0.6,
      onTick: () => removeFromParent(),
      removeOnFinish: true,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _particles.removeWhere((p) => p.update(dt));
  }

  @override
  void render(Canvas canvas) {
    for (final particle in _particles) {
      particle.render(canvas);
    }
  }
}

class _ExplosionParticle {
  Vector2 position;
  Vector2 velocity;
  double lifeTime;
  double _currentLife = 0;
  final Paint _paint;
  final Color _originalColor;

  _ExplosionParticle({
    required this.position,
    required this.velocity,
    required this.lifeTime,
    required Color color,
  })  : _paint = Paint()..color = color,
        _originalColor = color;

  bool update(double dt) {
    _currentLife += dt;
    position += velocity * dt;
    velocity *= 0.95; // Yavaşlama efekti

    // Alpha değerini 0-1 aralığında sınırla
    final alpha = (1.0 - (_currentLife / lifeTime)).clamp(0.0, 1.0);

    // Güvenli şekilde opacity ayarla
    try {
      _paint.color = _originalColor.withOpacity(alpha);
    } catch (e) {
      // Hata durumunda tamamen şeffaf yap
      _paint.color = _originalColor.withOpacity(0.0);
    }

    return _currentLife >= lifeTime;
  }

  void render(Canvas canvas) {
    // Sadece görünür parçacıkları çiz
    if (_paint.color.opacity > 0) {
      canvas.drawCircle(position.toOffset(), 3.0, _paint);
    }
  }
}
