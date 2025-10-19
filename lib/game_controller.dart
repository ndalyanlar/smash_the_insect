import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'Components/Util/state.dart';
import 'Components/enemy_manager.dart';
import 'Components/enemy.dart';
import 'Components/health_bar.dart';
import 'Components/player.dart';
import 'Components/blood_effect.dart';
import 'Components/explosion_effect.dart';
import 'Components/pause_menu.dart';

class GameController extends FlameGame
    with TapDetector, HasKeyboardHandlerComponents {
  // Oyun durumu
  late GameState gameState;
  late Player player;
  late EnemyManager enemyManager;
  late HealthBar healthBar;
  late PauseMenu pauseMenu;

  // Dialog sistemi için
  BuildContext? _context;
  bool _isPaused = false;

  // Oyun değişkenleri
  double score = 0;
  double gameTime = 0.0;
  late Random rnd;

  // Animasyonlu UI için
  double _pulseAnimationValue = 0.0;

  // Level sistemi
  int currentLevel = 1;
  double enemySpeedMultiplier = 1.0;
  double spawnRateMultiplier = 1.0;

  // Level hesaplama ve güncelleme
  void _updateLevel() {
    final newLevel = (score / 100).floor() + 1; // Her 100 skorda level artışı

    if (newLevel > currentLevel) {
      currentLevel = newLevel;
      _updateGameSpeed();
      print("Level $currentLevel'e yükseldin! Oyun hızlandı!");
    }
  }

  // Oyun hızını level'e göre güncelle
  void _updateGameSpeed() {
    // Düşman hızı artışı (maksimum 3x)
    enemySpeedMultiplier = (1.0 + (currentLevel - 1) * 0.2).clamp(1.0, 3.0);

    // Spawn hızı artışı (maksimum 2x)
    spawnRateMultiplier = (1.0 + (currentLevel - 1) * 0.15).clamp(1.0, 2.0);

    // EnemyManager spawn hızını güncelle
    enemyManager.updateSpawnRate();

    print(
        "Level $currentLevel - Düşman hızı: ${enemySpeedMultiplier}x, Spawn hızı: ${spawnRateMultiplier}x");
  }

  // Pasta yer değiştirme
  late Timer pastaMoveTimer;

  // Sprite'lar
  late Sprite spriteCake;
  late Sprite spriteExplosion;
  late Sprite spriteAnt;
  late Sprite spriteSpider;
  late Sprite spriteCockroach;

  @override
  Future<void>? onLoad() async {
    super.onLoad();
    rnd = Random();

    // Oyun durumunu başlat
    gameState = GameState.start;

    // Sprite'ları yükle
    await _loadSprites();

    // Player'ı oluştur
    _createPlayer();

    // EnemyManager'ı oluştur
    _createEnemyManager();

    // HealthBar'ı oluştur
    _createHealthBar();

    // PauseMenu'yu oluştur
    _createPauseMenu();

    // Pasta yer değiştirme timer'ını başlat
    pastaMoveTimer = Timer(3.0, onTick: _movePasta, repeat: true);
    pastaMoveTimer.start();

    gameState = GameState.playing;
  }

  Future<void> _loadSprites() async {
    try {
      print("Sprite'lar yükleniyor...");
      // Temel sprite'ları yükle
      await images.loadAll(["cake.png", "explosion.png", "hearth.png"]);

      // Pasta sprite'ını oluştur
      spriteCake = _createEnhancedCakeSprite();
      print("Pasta sprite oluşturuldu");
      spriteExplosion = Sprite(images.fromCache("explosion.png"));

      // Böcek sprite'larını oluştur
      spriteAnt = _createBugSprite(Color(0xFF8B4513), "ANT");
      spriteSpider = _createBugSprite(Color(0xFF000000), "SPIDER");
      spriteCockroach = _createBugSprite(Color(0xFF654321), "COCKROACH");
      print("Tüm sprite'lar başarıyla yüklendi");
    } catch (e) {
      print("Sprite yükleme hatası: $e");
      // Fallback sprite'lar oluştur
      spriteCake = _createSimpleCakeSprite();
      print("Fallback pasta sprite oluşturuldu");
      spriteExplosion = _createSimpleExplosionSprite();
      spriteAnt = _createSimpleBugSprite(Color(0xFF8B4513));
      spriteSpider = _createSimpleBugSprite(Color(0xFF000000));
      spriteCockroach = _createSimpleBugSprite(Color(0xFF654321));
    }
  }

  void _createPlayer() {
    print("=== PLAYER OLUŞTURULUYOR ===");
    print("SpriteCake oluşturuldu");
    print("Game Size: $size");

    player = Player(
      sprite: spriteCake,
      size: Vector2(80, 80),
      position: size / 2,
      gameController: this,
    );
    player.anchor = Anchor.center;

    print(
        "Player oluşturuldu - Position: ${player.position}, Size: ${player.size}");
    print("Player sprite: ${player.sprite != null}");

    add(player);
    print("Player GameController'a eklendi");
  }

  void _createEnemyManager() {
    enemyManager = EnemyManager(
      gameController: this,
      sprites: [spriteAnt, spriteSpider, spriteCockroach],
    );
    add(enemyManager);
  }

  void _createHealthBar() {
    healthBar = HealthBar(gameController: this);
    add(healthBar);
  }

  void _createPauseMenu() {
    pauseMenu = PauseMenu();
    add(pauseMenu);
  }

  // BuildContext'i set etmek için
  void setContext(BuildContext context) {
    _context = context;
  }

  // Pause dialog gösterme
  void showPauseDialog() {
    if (_context == null || _isPaused) return;

    _isPaused = true;
    pauseEngine();

    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'OYUN DURAKLADI',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    resumeGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'DEVAM ET',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    restartGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'YENİDEN BAŞLAT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    goToMainMenu();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'ANA MENÜ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Oyunu devam ettirme
  void resumeGame() {
    _isPaused = false;
    resumeEngine();
    gameState = GameState.playing;
  }

  // Oyunu yeniden başlatma
  void restartGame() {
    print("=== OYUN YENİDEN BAŞLATILIYOR ===");
    _isPaused = false;
    resumeEngine();

    // Oyunu yeniden başlatmak için gerekli işlemler
    score = 0;
    gameTime = 0.0;
    player.resetHealth();

    // Level'i sıfırla
    currentLevel = 1;
    enemySpeedMultiplier = 1.0;
    spawnRateMultiplier = 1.0;
    enemyManager.updateSpawnRate();

    // Düşmanları tam olarak temizle
    for (final enemy in enemyManager.enemies) {
      enemy.removeFromParent();
    }
    enemyManager.enemies.clear();

    // Player'ı merkeze taşı
    player.updatePosition(size / 2);

    // Pasta yer değiştirme timer'ını yeniden başlat
    pastaMoveTimer.stop();
    pastaMoveTimer.start();

    // Oyun durumunu playing olarak ayarla
    gameState = GameState.playing;

    print("Oyun yeniden başlatıldı!");
  }

  // Oyun bitişi
  void _gameOver() {
    print("=== _GAMEOVER METODU ÇAĞRILDI ===");
    gameState = GameState.end;
    pauseEngine();

    print("=== OYUN BİTTİ ===");
    print("Final Skor: $score");
    print("Oyun Süresi: ${gameTime.toStringAsFixed(1)} saniye");
    print("Context durumu: ${_context != null}");

    // Oyun bitiş ekranını göster
    showGameOverDialog();
  }

  // Oyun bitiş dialog'u
  void showGameOverDialog() {
    print("=== SHOWGAMEOVERDIALOG METODU ÇAĞRILDI ===");
    print("Context null mu: ${_context == null}");

    if (_context == null) {
      print("CONTEXT NULL! Dialog gösterilemiyor!");
      return;
    }

    print("=== GAME OVER DIALOG GÖSTERİLİYOR ===");
    print("Final Skor: $score");
    print("Oyun Süresi: ${gameTime.toStringAsFixed(1)} saniye");
    print("Context: $_context");

    // Dialog'u bir sonraki frame'e geciktir
    SchedulerBinding.instance.addPostFrameCallback((_) {
      print("PostFrameCallback çağrıldı - Dialog gösteriliyor");
      _showDialogSafely();
    });
  }

  // Güvenli dialog gösterimi
  void _showDialogSafely() {
    try {
      if (_context == null) {
        print("Context hala null!");
        return;
      }

      showDialog(
        context: _context!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          print("Dialog builder çağrıldı!");
          return AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(color: Colors.red, width: 3),
            ),
            title: Column(
              children: [
                Icon(Icons.sports_esports, color: Colors.red, size: 40),
                SizedBox(height: 10),
                Text(
                  'GAME OVER!',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Text(
                  'OYUN BİTTİ!',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.5), width: 1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Final Skor: $score',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Oyun Süresi: ${gameTime.toStringAsFixed(1)} saniye',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '🍰 Pasta yenildi! Daha iyi korumaya çalışın! 🍰',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        restartGame();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'YENİDEN BAŞLA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        goToMainMenu();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'ANA MENÜ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Dialog gösterilirken hata: $e");
    }

    print("Dialog gösterimi tamamlandı");
  }

  // Ana menüye dönme
  void goToMainMenu() {
    print("=== ANA MENÜYE DÖNÜLÜYOR ===");
    _isPaused = false;
    resumeEngine();

    // Oyunu sıfırla
    score = 0;
    gameTime = 0.0;
    player.resetHealth();

    // Düşmanları temizle
    for (final enemy in enemyManager.enemies) {
      enemy.removeFromParent();
    }
    enemyManager.enemies.clear();

    // Player'ı merkeze taşı
    player.updatePosition(size / 2);

    // Timer'ları durdur
    pastaMoveTimer.stop();

    // Oyun durumunu start olarak ayarla
    gameState = GameState.start;

    // Ana ekrana dön
    if (_context != null) {
      Navigator.of(_context!).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }

    print("Ana menüye dönüldü!");
  }

  void _movePasta() {
    if (gameState != GameState.playing) return;

    // Ekranın ortasında rastgele bir pozisyon seç
    final margin = 150.0;
    final centerX = size.x / 2;
    final centerY = size.y / 2;

    final newX = centerX + (rnd.nextDouble() - 0.5) * margin;
    final newY = centerY + (rnd.nextDouble() - 0.5) * margin;

    player.updatePosition(Vector2(newX, newY));

    print("Pasta yeni pozisyona taşındı: $newX, $newY");
  }

  @override
  void render(Canvas canvas) {
    // Arka plan rengi
    canvas.drawColor(Color(0xFF87CEEB), BlendMode.srcOver);

    // UI'yi render et
    _renderUI(canvas);

    // Düşmanları kontrol et
    _checkEnemyCollisions();

    super.render(canvas);
  }

  void _renderUI(Canvas canvas) {
    // SafeArea için padding
    final safeAreaPadding = 20.0;

    // Modern skor container'ı
    _renderScoreContainer(canvas, safeAreaPadding);

    // Modern can container'ı
    _renderHealthContainer(canvas, safeAreaPadding);

    // Level container'ı
    _renderLevelContainer(canvas, safeAreaPadding);

    // Pause butonu - daha düzgün tasarım
    _renderPauseButton(canvas, safeAreaPadding);
  }

  void _renderScoreContainer(Canvas canvas, double safeAreaPadding) {
    // Minimal animasyon değerleri
    final pulseScale = 1.0 + (sin(_pulseAnimationValue) * 0.02);

    // Skor container boyutları - metin için genişletildi
    final containerWidth = 140.0;
    final containerHeight = 50.0;
    final containerX = safeAreaPadding;
    final containerY = safeAreaPadding;

    // Container arka planı
    final containerRect = Rect.fromLTWH(
      containerX,
      containerY,
      containerWidth,
      containerHeight,
    );

    // Minimal gradient arka plan
    final gradient = ui.Gradient.linear(
      Offset(containerX, containerY),
      Offset(containerX + containerWidth, containerY + containerHeight),
      [
        const Color(0xFF2E8B57).withOpacity(0.8),
        const Color(0xFF228B22).withOpacity(0.8),
      ],
    );

    final containerPaint = Paint()..shader = gradient;

    // Container çizimi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(12),
      ),
      containerPaint,
    );

    // Minimal kenarlık
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // Minimal gölge
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            containerX + 1, containerY + 1, containerWidth, containerHeight),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    // Minimal skor ikonu (küçük daire)
    final iconPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(containerX + 18, containerY + 22),
      6 * pulseScale,
      iconPaint,
    );

    // Minimal skor metni
    TextPaint scoreText = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black),
        ],
      ),
    );

    scoreText.render(
      canvas,
      "Skor: ${score.toInt()}",
      Vector2(containerX + 35, containerY + 28),
      anchor: Anchor.centerLeft,
    );
  }

  void _renderHealthContainer(Canvas canvas, double safeAreaPadding) {
    // Minimal animasyon değerleri
    final pulseScale = 1.0 + (sin(_pulseAnimationValue + pi) * 0.02);
    final healthRatio = player.currentHealth / 100.0;

    // Can container boyutları - metin için genişletildi
    final containerWidth = 140.0;
    final containerHeight = 50.0;
    final containerX = safeAreaPadding;
    final containerY = safeAreaPadding + 60;

    // Container arka planı
    final containerRect = Rect.fromLTWH(
      containerX,
      containerY,
      containerWidth,
      containerHeight,
    );

    // Minimal gradient arka plan (can durumuna göre)
    final gradient = ui.Gradient.linear(
      Offset(containerX, containerY),
      Offset(containerX + containerWidth, containerY + containerHeight),
      [
        Color.lerp(
          const Color(0xFFD32F2F),
          const Color(0xFF4CAF50),
          healthRatio,
        )!
            .withOpacity(0.8),
        Color.lerp(
          const Color(0xFFB71C1C),
          const Color(0xFF2E8B57),
          healthRatio,
        )!
            .withOpacity(0.8),
      ],
    );

    final containerPaint = Paint()..shader = gradient;

    // Container çizimi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(12),
      ),
      containerPaint,
    );

    // Minimal kenarlık
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // Minimal gölge
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            containerX + 1, containerY + 1, containerWidth, containerHeight),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    // Minimal kalp ikonu (küçük daire)
    final heartPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(containerX + 18, containerY + 22),
      6 * pulseScale,
      heartPaint,
    );

    // Minimal can metni
    TextPaint healthText = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black),
        ],
      ),
    );

    healthText.render(
      canvas,
      "Can: ${player.currentHealth.toInt()}",
      Vector2(containerX + 35, containerY + 28),
      anchor: Anchor.centerLeft,
    );
  }

  void _renderLevelContainer(Canvas canvas, double safeAreaPadding) {
    // Minimal animasyon değerleri
    final pulseScale = 1.0 + (sin(_pulseAnimationValue + pi * 2) * 0.02);

    // Level container boyutları
    final containerWidth = 100.0;
    final containerHeight = 50.0;
    final containerX = safeAreaPadding;
    final containerY = safeAreaPadding + 120;

    // Container arka planı
    final containerRect = Rect.fromLTWH(
      containerX,
      containerY,
      containerWidth,
      containerHeight,
    );

    // Level gradient arka plan
    final gradient = ui.Gradient.linear(
      Offset(containerX, containerY),
      Offset(containerX + containerWidth, containerY + containerHeight),
      [
        const Color(0xFF9C27B0).withOpacity(0.8), // Mor
        const Color(0xFF673AB7).withOpacity(0.8), // Koyu mor
      ],
    );

    final containerPaint = Paint()..shader = gradient;

    // Container çizimi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(12),
      ),
      containerPaint,
    );

    // Minimal kenarlık
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // Minimal gölge
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            containerX + 1, containerY + 1, containerWidth, containerHeight),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    // Level ikonu (küçük daire)
    final iconPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(containerX + 18, containerY + 25),
      6 * pulseScale,
      iconPaint,
    );

    // Level metni
    TextPaint levelText = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black),
        ],
      ),
    );

    levelText.render(
      canvas,
      "Lv.$currentLevel",
      Vector2(containerX + 35, containerY + 28),
      anchor: Anchor.centerLeft,
    );
  }

  void _renderPauseButton(Canvas canvas, double safeAreaPadding) {
    // Pause butonu boyutları
    final buttonWidth = 80.0;
    final buttonHeight = 40.0;
    final buttonMargin = safeAreaPadding;

    // Buton pozisyonu (sağ üst köşe, SafeArea içinde)
    final buttonX = size.x - buttonWidth - buttonMargin;
    final buttonY = safeAreaPadding;

    // Buton arka planı
    final buttonRect =
        Rect.fromLTWH(buttonX, buttonY, buttonWidth, buttonHeight);
    final buttonPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Buton kenarlığı
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Buton arka planını çiz
    canvas.drawRRect(
      RRect.fromRectAndRadius(buttonRect, const Radius.circular(8)),
      buttonPaint,
    );

    // Buton kenarlığını çiz
    canvas.drawRRect(
      RRect.fromRectAndRadius(buttonRect, const Radius.circular(8)),
      borderPaint,
    );

    // Pause ikonu (iki dikey çizgi)
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeWidth = 3.0;

    final iconCenterX = buttonX + buttonWidth / 2;
    final iconCenterY = buttonY + buttonHeight / 2;
    final iconSpacing = 6.0;

    // İki dikey çizgi çiz
    canvas.drawLine(
      Offset(iconCenterX - iconSpacing, iconCenterY - 8),
      Offset(iconCenterX - iconSpacing, iconCenterY + 8),
      iconPaint,
    );
    canvas.drawLine(
      Offset(iconCenterX + iconSpacing, iconCenterY - 8),
      Offset(iconCenterX + iconSpacing, iconCenterY + 8),
      iconPaint,
    );
  }

  void _checkEnemyCollisions() {
    if (gameState != GameState.playing) return;

    // Düşmanların pasta ile temasını kontrol et
    // Concurrent modification hatası önlemek için kopya liste kullan
    final enemiesToCheck = List<Enemy>.from(enemyManager.enemies);

    for (final enemy in enemiesToCheck) {
      if (enemy.isDead) continue;

      // Temas kontrolü
      final distance = player.position.distanceTo(enemy.position);
      if (distance < 50) {
        print("=== TEMAS TESPİT EDİLDİ ===");
        print("Mesafe: $distance");
        print("Pasta durumu - Can: ${player.currentHealth}");
        print("Pasta parent: ${player.parent != null}");
        print("Pasta sprite: ${player.sprite != null}");

        // Hasar ver
        player.takeDamage(5);
        enemy.isDead = true;

        // Düşmanı hemen kaldır - güvenli şekilde
        enemy.removeFromParent();
        // Liste iteration sırasında değişmemesi için remove işlemini geciktir
        Future.microtask(() => enemyManager.enemies.remove(enemy));

        // Kan efekti
        add(BloodEffect(position: enemy.position));

        print("Pasta hasar aldı! Kalan can: ${player.currentHealth}");
        print("Hasar sonrası pasta parent: ${player.parent != null}");
        print("Hasar sonrası pasta sprite: ${player.sprite != null}");

        //Oyun bitti mi kontrol et - pasta hiç ölmesin
        if (player.currentHealth <= 0) {
          _gameOver();
        }

        // Bir düşmanla temas ettikten sonra döngüden çık
        break;
      }
    }
  }

  @override
  void update(double dt) {
    if (gameState != GameState.playing) return;

    // Oyun zamanını güncelle
    gameTime += dt;

    // Animasyon değerlerini güncelle
    _pulseAnimationValue += dt * 3.0; // Pulse animasyonu

    // Level güncellemesi
    _updateLevel();

    // Timer'ları güncelle
    pastaMoveTimer.update(dt);

    super.update(dt);
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (gameState != GameState.playing) return;

    final tapPosition = info.eventPosition.global;

    // Pause butonuna dokunma kontrolü (yeni tasarım)
    if (_isPauseButtonTapped(tapPosition)) {
      showPauseDialog();
      return;
    }

    // Düşmanlara dokunma kontrolü
    for (final enemy in enemyManager.enemies) {
      if (enemy.isDead) continue;

      if (enemy.containsPoint(tapPosition)) {
        // Düşmanı öldür
        enemy.isDead = true;
        score += 10;

        // Patlama efekti
        add(ExplosionEffect(position: enemy.position));

        // Kan efekti
        add(BloodEffect(position: enemy.position));

        // Düşmanı hemen kaldır
        enemy.removeFromParent();
        enemyManager.enemies.remove(enemy);

        print("Düşman öldürüldü! Skor: $score");
        break;
      }
    }
  }

  bool _isPauseButtonTapped(Vector2 tapPosition) {
    final safeAreaPadding = 20.0;
    final buttonWidth = 80.0;
    final buttonHeight = 40.0;
    final buttonMargin = safeAreaPadding;

    final buttonX = size.x - buttonWidth - buttonMargin;
    final buttonY = safeAreaPadding;

    final buttonRect =
        Rect.fromLTWH(buttonX, buttonY, buttonWidth, buttonHeight);
    return buttonRect.contains(tapPosition.toOffset());
  }

  // Böcek sprite'ı oluşturma metodu
  Sprite _createBugSprite(Color color, String type) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Ana vücut
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(32, 32), 25, bodyPaint);

    // Gözler
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(26, 26), 3, eyePaint);
    canvas.drawCircle(const Offset(38, 26), 3, eyePaint);

    // Göz bebekleri
    final pupilPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(26, 26), 1.5, pupilPaint);
    canvas.drawCircle(const Offset(38, 26), 1.5, pupilPaint);

    // Bacaklar
    final legPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Sol bacaklar
    canvas.drawLine(const Offset(20, 45), const Offset(15, 55), legPaint);
    canvas.drawLine(const Offset(25, 45), const Offset(20, 55), legPaint);

    // Sağ bacaklar
    canvas.drawLine(const Offset(39, 45), const Offset(44, 55), legPaint);
    canvas.drawLine(const Offset(44, 45), const Offset(49, 55), legPaint);

    // Kenarlık
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(const Offset(32, 32), 25, borderPaint);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(64, 64);

    return Sprite(image);
  }

  // Gelişmiş pasta sprite'ı oluşturma metodu
  Sprite _createEnhancedCakeSprite() {
    print("Gelişmiş pasta sprite oluşturuluyor...");
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Pasta tabanı (kahverengi)
    final basePaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(40, 40), 35, basePaint);

    // Pasta üstü (krem rengi)
    final topPaint = Paint()
      ..color = const Color(0xFFFFF8DC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(40, 35), 30, topPaint);

    // Çilek (kırmızı)
    final strawberryPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(40, 25), 10, strawberryPaint);

    // Çilek yaprağı (yeşil)
    final leafPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(40, 15), width: 15, height: 8),
        leafPaint);

    // Kenarlık
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(const Offset(40, 40), 35, borderPaint);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(80, 80);

    print("Gelişmiş pasta sprite oluşturuldu");
    return Sprite(image);
  }

  // Basit fallback sprite metodları
  Sprite _createSimpleCakeSprite() {
    print("Basit pasta sprite oluşturuluyor...");
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(40, 40), 35, paint);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(80, 80);

    print("Basit pasta sprite oluşturuldu");
    return Sprite(image);
  }

  Sprite _createSimpleExplosionSprite() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(32, 32), 30, paint);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(64, 64);

    return Sprite(image);
  }

  Sprite _createSimpleBugSprite(Color color) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(32, 32), 25, paint);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(64, 64);

    return Sprite(image);
  }
}
