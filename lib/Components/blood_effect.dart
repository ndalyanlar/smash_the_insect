import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BloodEffect extends PositionComponent {
  final Vector2 _startPosition;
  final Random _random = Random();
  final List<_BloodParticle> _particles = [];

  BloodEffect({required Vector2 position}) : _startPosition = position {
    // Daha fazla kan parçacığı oluştur
    for (int i = 0; i < 20; i++) {
      _particles.add(_BloodParticle(
        position: _startPosition,
        velocity: Vector2(
          (_random.nextDouble() - 0.5) * 150, // Daha hızlı
          (_random.nextDouble() - 0.5) * 150,
        ),
        lifeTime: 0.8 + _random.nextDouble() * 0.7, // Daha uzun süre
        size: 2.0 + _random.nextDouble() * 4.0, // Farklı boyutlar
        color: _getRandomBloodColor(),
      ));
    }

    // Efektin ömrü bittiğinde kendini kaldırması için
    add(TimerComponent(
      period: 1.5,
      onTick: () => removeFromParent(),
      removeOnFinish: true,
    ));
  }

  Color _getRandomBloodColor() {
    final colors = [
      const Color(0xFF8B0000), // Koyu kırmızı
      const Color(0xFFDC143C), // Crimson
      const Color(0xFFB22222), // Fire brick
      const Color(0xFFA52A2A), // Brown
      const Color(0xFF800000), // Maroon
    ];
    return colors[_random.nextInt(colors.length)];
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

class _BloodParticle {
  Vector2 position;
  Vector2 velocity;
  double lifeTime;
  double size;
  Color color;
  double _currentLife = 0;
  final Paint _paint = Paint();

  _BloodParticle({
    required this.position,
    required this.velocity,
    required this.lifeTime,
    required this.size,
    required this.color,
  }) {
    _paint.color = color;
  }

  bool update(double dt) {
    _currentLife += dt;

    // Yerçekimi efekti
    velocity.y += 200 * dt;

    // Hava direnci
    velocity *= 0.98;

    position += velocity * dt;

    // Alpha değerini güncelle
    final alpha = (1.0 - (_currentLife / lifeTime)).clamp(0.0, 1.0);
    _paint.color = color.withOpacity(alpha);

    return _currentLife >= lifeTime;
  }

  void render(Canvas canvas) {
    if (_paint.color.opacity > 0) {
      // Kan damlası şekli (oval)
      final rect = Rect.fromCenter(
        center: position.toOffset(),
        width: size,
        height: size * 1.5,
      );

      // Kan damlası gölgesi
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(_paint.color.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(position.x + 1, position.y + 1),
          width: size,
          height: size * 1.5,
        ),
        shadowPaint,
      );

      // Ana kan damlası
      canvas.drawOval(rect, _paint);

      // Kan damlası parlaklığı
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(_paint.color.opacity * 0.4);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(position.x - size * 0.2, position.y - size * 0.3),
          width: size * 0.3,
          height: size * 0.4,
        ),
        highlightPaint,
      );
    }
  }
}
