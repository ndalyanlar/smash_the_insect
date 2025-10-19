import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class ParticleEffect extends Component {
  final Vector2 position;
  final Color color;
  final int particleCount;
  final double spread;

  ParticleEffect({
    required this.position,
    required this.color,
    this.particleCount = 8,
    this.spread = 100.0,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final random = Random();

    for (int i = 0; i < particleCount; i++) {
      final particle = Particle(
        color: color,
        position: position.clone(),
        velocity: Vector2(
          (random.nextDouble() - 0.5) * spread,
          (random.nextDouble() - 0.5) * spread,
        ),
        life: 0.5 + random.nextDouble() * 0.5,
      );

      add(particle);
    }

    // Efekt tamamlandıktan sonra kendini kaldır
    add(TimerComponent(
      period: 1.0,
      onTick: () {
        if (parent != null) {
          removeFromParent();
        }
      },
    ));
  }
}

class Particle extends CircleComponent {
  Vector2 velocity;
  double life;
  final double maxLife;

  Particle({
    required Color color,
    required Vector2 position,
    required this.velocity,
    required this.life,
  })  : maxLife = life,
        super(
          radius: 3.0,
          paint: Paint()..color = color,
          position: position,
        );

  @override
  void update(double dt) {
    super.update(dt);

    // Pozisyonu güncelle
    position += velocity * dt;

    // Yaşam süresini azalt
    life -= dt;
    if (life <= 0) {
      if (parent != null) {
        removeFromParent();
      }
      return;
    }

    // Opacity'yi yaşam süresine göre ayarla
    final lifeRatio = life / maxLife;
    paint.color = paint.color.withOpacity(lifeRatio);

    // Yavaşlama efekti
    velocity *= 0.98;

    // Yerçekimi efekti
    velocity.y += 50 * dt;
  }
}

class ExplosionEffect extends ParticleEffect {
  ExplosionEffect({required Vector2 position})
      : super(
          position: position,
          color: const Color(0xFFFF6B35),
          particleCount: 12,
          spread: 150.0,
        );
}

class HitEffect extends ParticleEffect {
  HitEffect({required Vector2 position})
      : super(
          position: position,
          color: const Color(0xFFFFD700),
          particleCount: 6,
          spread: 80.0,
        );
}

class HealEffect extends ParticleEffect {
  HealEffect({required Vector2 position})
      : super(
          position: position,
          color: const Color(0xFF00FF7F),
          particleCount: 8,
          spread: 60.0,
        );
}
