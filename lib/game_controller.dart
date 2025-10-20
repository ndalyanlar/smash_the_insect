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

  // Skor artışı animasyonu için
  double _scoreAnimationValue = 0.0;
  double _lastScore = 0.0;
  bool _isScoreAnimating = false;

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
    // İlk 10 level için hızlı artış, sonraki level artışlarında yavaş ilerleme
    double speedIncrease;
    double spawnIncrease;

    if (currentLevel <= 10) {
      // İlk 10 level için hızlı artış
      speedIncrease = (currentLevel - 1) * 0.3; // Her level için %30 artış
      spawnIncrease = (currentLevel - 1) * 0.25; // Her level için %25 artış
    } else {
      // 10. level'dan sonra yavaş artış
      // İlk 10 level'daki artışı koru + sonraki level'lar için küçük artışlar
      final baseSpeedIncrease = 9 * 0.3; // İlk 10 level'daki toplam artış
      final baseSpawnIncrease = 9 * 0.25; // İlk 10 level'daki toplam artış

      final additionalLevels = currentLevel - 10;
      speedIncrease = baseSpeedIncrease +
          (additionalLevels * 0.05); // Sonraki level'lar için %5 artış
      spawnIncrease = baseSpawnIncrease +
          (additionalLevels * 0.04); // Sonraki level'lar için %4 artış
    }

    // Düşman hızı artışı (maksimum 4x)
    enemySpeedMultiplier = (1.0 + speedIncrease).clamp(1.0, 4.0);

    // Spawn hızı artışı (maksimum 3x)
    spawnRateMultiplier = (1.0 + spawnIncrease).clamp(1.0, 3.0);

    // EnemyManager spawn hızını güncelle
    enemyManager.updateSpawnRate();

    print(
        "Level $currentLevel - Düşman hızı: ${enemySpeedMultiplier.toStringAsFixed(2)}x, Spawn hızı: ${spawnRateMultiplier.toStringAsFixed(2)}x");
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
    const safeAreaPadding = 20.0;

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
    // Skor artışı animasyonu için pulse efekti
    final scorePulseScale = 1.0 + (sin(_pulseAnimationValue * 2) * 0.05);
    final glowIntensity = (sin(_pulseAnimationValue * 3) + 1) / 2;

    // Skor artışı animasyonu için özel efektler
    double animationScale = 1.0;
    double animationGlow = glowIntensity;

    if (_isScoreAnimating) {
      // Skor artışında büyüme efekti
      animationScale = 1.0 + (sin(_scoreAnimationValue * pi) * 0.15);
      animationGlow = glowIntensity + (_scoreAnimationValue * 0.5);
    }

    // Skor container boyutları - daha büyük ve etkileyici
    final containerWidth = 160.0;
    final containerHeight = 60.0;
    final containerX = safeAreaPadding;
    final containerY = safeAreaPadding;

    // Container arka planı
    final containerRect = Rect.fromLTWH(
      containerX,
      containerY,
      containerWidth,
      containerHeight,
    );

    // Böcek ezme temasına uygun gradient - altın/sarı tonları
    final gradient = ui.Gradient.linear(
      Offset(containerX, containerY),
      Offset(containerX + containerWidth, containerY + containerHeight),
      [
        const Color(0xFFFFD700).withOpacity(0.9), // Altın
        const Color(0xFFFF8C00).withOpacity(0.9), // Koyu turuncu
      ],
    );

    final containerPaint = Paint()..shader = gradient;

    // Glow efekti için dış gölge - animasyonlu
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.3 * animationGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(containerX - 2, containerY - 2, containerWidth + 4,
            containerHeight + 4),
        const Radius.circular(16),
      ),
      glowPaint,
    );

    // Container çizimi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(15),
      ),
      containerPaint,
    );

    // Parlak kenarlık
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(15),
      ),
      borderPaint,
    );

    // İç gölge efekti
    final innerShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(containerX + 2, containerY + 2, containerWidth - 4,
            containerHeight - 4),
        const Radius.circular(13),
      ),
      innerShadowPaint,
    );

    // Böcek ezme ikonu - çekiç/böcek teması (animasyonlu)
    _drawBugSmashIcon(canvas, containerX + 25, containerY + 30,
        scorePulseScale * animationScale);

    // Skor metni - daha büyük ve etkileyici
    TextPaint scoreText = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(offset: Offset(2, 2), blurRadius: 3, color: Colors.black87),
          Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black54),
        ],
      ),
    );

    scoreText.render(
      canvas,
      "${score.toInt()}",
      Vector2(containerX + 55, containerY + 35),
      anchor: Anchor.centerLeft,
    );

    // "SKOR" etiketi
    TextPaint labelText = TextPaint(
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54),
        ],
      ),
    );

    labelText.render(
      canvas,
      "SKOR",
      Vector2(containerX + 55, containerY + 20),
      anchor: Anchor.centerLeft,
    );

    // Skor artışı popup efekti
    if (_isScoreAnimating) {
      _drawScorePopup(
          canvas, containerX + containerWidth + 10, containerY + 20);
    }
  }

  // Skor artışı popup efekti çizimi
  void _drawScorePopup(Canvas canvas, double x, double y) {
    final popupScale = 1.0 + (sin(_scoreAnimationValue * pi) * 0.3);
    final popupOpacity = 1.0 - _scoreAnimationValue;

    // Popup arka planı
    final popupPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.9 * popupOpacity)
      ..style = PaintingStyle.fill;

    final popupRect = Rect.fromCenter(
      center: Offset(x, y),
      width: 60 * popupScale,
      height: 25 * popupScale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(popupRect, const Radius.circular(12)),
      popupPaint,
    );

    // Popup kenarlığı
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8 * popupOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(popupRect, const Radius.circular(12)),
      borderPaint,
    );

    // "+10" metni
    TextPaint popupText = TextPaint(
      style: TextStyle(
        color: Colors.white,
        fontSize: 16 * popupScale,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
              offset: const Offset(1, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(popupOpacity)),
        ],
      ),
    );

    popupText.render(
      canvas,
      "+10",
      Vector2(x, y),
      anchor: Anchor.center,
    );
  }

  // Böcek ezme ikonu çizimi
  void _drawBugSmashIcon(Canvas canvas, double x, double y, double scale) {
    // Çekiç başı
    final hammerPaint = Paint()
      ..color = const Color(0xFF8B4513) // Kahverengi
      ..style = PaintingStyle.fill;

    final hammerRect = Rect.fromCenter(
      center: Offset(x, y - 5),
      width: 12 * scale,
      height: 8 * scale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hammerRect, const Radius.circular(4)),
      hammerPaint,
    );

    // Çekiç sapı
    final handlePaint = Paint()
      ..color = const Color(0xFF654321) // Koyu kahverengi
      ..style = PaintingStyle.fill
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(x, y - 5),
      Offset(x, y + 8),
      handlePaint,
    );

    // Böcek gövdesi (ezilmiş)
    final bugPaint = Paint()
      ..color = const Color(0xFF8B4513) // Kahverengi
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x, y + 3), width: 8 * scale, height: 4 * scale),
      bugPaint,
    );

    // Böcek gözleri
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x - 2, y + 2), 1 * scale, eyePaint);
    canvas.drawCircle(Offset(x + 2, y + 2), 1 * scale, eyePaint);

    // Parlak efekt
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x - 1, y - 6), 2 * scale, shinePaint);
  }

  void _renderHealthContainer(Canvas canvas, double safeAreaPadding) {
    // Can durumuna göre animasyon değerleri
    final healthRatio = player.currentHealth / 100.0;
    final heartPulseScale = 1.0 + (sin(_pulseAnimationValue * 4) * 0.08);
    final glowIntensity = healthRatio * (sin(_pulseAnimationValue * 2) + 1) / 2;

    // Can durumuna göre renk değişimi
    final isLowHealth = healthRatio < 0.3;
    final isCriticalHealth = healthRatio < 0.15;

    // Can container boyutları
    final containerWidth = 160.0;
    final containerHeight = 60.0;
    final containerX = safeAreaPadding;
    final containerY = safeAreaPadding + 70;

    // Container arka planı
    final containerRect = Rect.fromLTWH(
      containerX,
      containerY,
      containerWidth,
      containerHeight,
    );

    // Can durumuna göre gradient renkleri
    List<Color> gradientColors;
    if (isCriticalHealth) {
      // Kritik can - kırmızı ve yanıp sönen efekt
      gradientColors = [
        const Color(0xFFFF0000).withOpacity(0.9), // Kırmızı
        const Color(0xFFB22222).withOpacity(0.9), // Koyu kırmızı
      ];
    } else if (isLowHealth) {
      // Düşük can - turuncu/kırmızı
      gradientColors = [
        const Color(0xFFFF4500).withOpacity(0.9), // Turuncu kırmızı
        const Color(0xFFCD5C5C).withOpacity(0.9), // Hint kırmızısı
      ];
    } else {
      // Sağlıklı can - yeşil tonları
      gradientColors = [
        const Color(0xFF32CD32).withOpacity(0.9), // Lime yeşil
        const Color(0xFF006400).withOpacity(0.9), // Koyu yeşil
      ];
    }

    final gradient = ui.Gradient.linear(
      Offset(containerX, containerY),
      Offset(containerX + containerWidth, containerY + containerHeight),
      gradientColors,
    );

    final containerPaint = Paint()..shader = gradient;

    // Kritik can durumunda yanıp sönen glow efekti
    if (isCriticalHealth) {
      final criticalGlowPaint = Paint()
        ..color = const Color(0xFFFF0000).withOpacity(0.5 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(containerX - 4, containerY - 4, containerWidth + 8,
              containerHeight + 8),
          const Radius.circular(18),
        ),
        criticalGlowPaint,
      );
    }

    // Normal glow efekti
    final glowPaint = Paint()
      ..color = gradientColors.first.withOpacity(0.3 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(containerX - 2, containerY - 2, containerWidth + 4,
            containerHeight + 4),
        const Radius.circular(16),
      ),
      glowPaint,
    );

    // Container çizimi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(15),
      ),
      containerPaint,
    );

    // Parlak kenarlık
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(15),
      ),
      borderPaint,
    );

    // İç gölge efekti
    final innerShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(containerX + 2, containerY + 2, containerWidth - 4,
            containerHeight - 4),
        const Radius.circular(13),
      ),
      innerShadowPaint,
    );

    // Animasyonlu kalp ikonu
    _drawAnimatedHeart(
        canvas, containerX + 25, containerY + 30, heartPulseScale, healthRatio);

    // Can metni - daha büyük ve etkileyici
    TextPaint healthText = TextPaint(
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        shadows: [
          const Shadow(
              offset: Offset(2, 2), blurRadius: 3, color: Colors.black87),
          const Shadow(
              offset: Offset(1, 1), blurRadius: 1, color: Colors.black54),
        ],
      ),
    );

    healthText.render(
      canvas,
      "${player.currentHealth.toInt()}",
      Vector2(containerX + 55, containerY + 35),
      anchor: Anchor.centerLeft,
    );

    // "CAN" etiketi
    TextPaint labelText = TextPaint(
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54),
        ],
      ),
    );

    labelText.render(
      canvas,
      "CAN",
      Vector2(containerX + 55, containerY + 20),
      anchor: Anchor.centerLeft,
    );

    // Can barı - görsel gösterge
    _drawHealthBar(canvas, containerX + 10, containerY + 50,
        containerWidth - 20, healthRatio);
  }

  // Animasyonlu kalp ikonu çizimi
  void _drawAnimatedHeart(
      Canvas canvas, double x, double y, double scale, double healthRatio) {
    // Kalp rengi can durumuna göre değişir
    Color heartColor;
    if (healthRatio < 0.15) {
      heartColor = const Color(0xFFFF0000); // Kırmızı
    } else if (healthRatio < 0.3) {
      heartColor = const Color(0xFFFF4500); // Turuncu kırmızı
    } else {
      heartColor = const Color(0xFF32CD32); // Yeşil
    }

    final heartPaint = Paint()
      ..color = heartColor
      ..style = PaintingStyle.fill;

    // Kalp şekli çizimi
    final heartPath = Path();
    final heartSize = 12 * scale;

    // Kalp şekli için bezier eğrileri
    heartPath.moveTo(x, y + heartSize * 0.3);
    heartPath.cubicTo(
      x - heartSize * 0.5,
      y - heartSize * 0.3,
      x - heartSize * 0.5,
      y + heartSize * 0.1,
      x,
      y + heartSize * 0.5,
    );
    heartPath.cubicTo(
      x + heartSize * 0.5,
      y + heartSize * 0.1,
      x + heartSize * 0.5,
      y - heartSize * 0.3,
      x,
      y + heartSize * 0.3,
    );

    canvas.drawPath(heartPath, heartPaint);

    // Kalp parlaklığı
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x - 2, y - 2), 3 * scale, shinePaint);
  }

  // Can barı çizimi
  void _drawHealthBar(
      Canvas canvas, double x, double y, double width, double healthRatio) {
    final barHeight = 6.0;

    // Arka plan barı
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, barHeight),
        const Radius.circular(3),
      ),
      backgroundPaint,
    );

    // Can barı
    final healthBarWidth = width * healthRatio;
    Color barColor;

    if (healthRatio < 0.15) {
      barColor = const Color(0xFFFF0000); // Kırmızı
    } else if (healthRatio < 0.3) {
      barColor = const Color(0xFFFF4500); // Turuncu kırmızı
    } else {
      barColor = const Color(0xFF32CD32); // Yeşil
    }

    final healthPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    if (healthBarWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, healthBarWidth, barHeight),
          const Radius.circular(3),
        ),
        healthPaint,
      );
    }

    // Bar kenarlığı
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, barHeight),
        const Radius.circular(3),
      ),
      borderPaint,
    );
  }

  void _renderLevelContainer(Canvas canvas, double safeAreaPadding) {
    // Level artışı animasyonu için özel efektler
    final levelPulseScale = 1.0 + (sin(_pulseAnimationValue * 1.5) * 0.06);
    final glowIntensity = (sin(_pulseAnimationValue * 2.5) + 1) / 2;

    // Level container boyutları - daha büyük
    final containerWidth = 120.0;
    final containerHeight = 60.0;
    final containerX = safeAreaPadding;
    final containerY = safeAreaPadding + 140;

    // Container arka planı
    final containerRect = Rect.fromLTWH(
      containerX,
      containerY,
      containerWidth,
      containerHeight,
    );

    // Level temasına uygun gradient - mor/mavi tonları
    final gradient = ui.Gradient.linear(
      Offset(containerX, containerY),
      Offset(containerX + containerWidth, containerY + containerHeight),
      [
        const Color(0xFF9C27B0).withOpacity(0.9), // Mor
        const Color(0xFF3F51B5).withOpacity(0.9), // İndigo
      ],
    );

    final containerPaint = Paint()..shader = gradient;

    // Glow efekti
    final glowPaint = Paint()
      ..color = const Color(0xFF9C27B0).withOpacity(0.4 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(containerX - 2, containerY - 2, containerWidth + 4,
            containerHeight + 4),
        const Radius.circular(16),
      ),
      glowPaint,
    );

    // Container çizimi
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(15),
      ),
      containerPaint,
    );

    // Parlak kenarlık
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        containerRect,
        const Radius.circular(15),
      ),
      borderPaint,
    );

    // İç gölge efekti
    final innerShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(containerX + 2, containerY + 2, containerWidth - 4,
            containerHeight - 4),
        const Radius.circular(13),
      ),
      innerShadowPaint,
    );

    // Level ikonu - yıldız şekli
    _drawLevelStar(canvas, containerX + 25, containerY + 30, levelPulseScale);

    // Level metni - daha büyük ve etkileyici
    TextPaint levelText = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(offset: Offset(2, 2), blurRadius: 3, color: Colors.black87),
          Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black54),
        ],
      ),
    );

    levelText.render(
      canvas,
      "$currentLevel",
      Vector2(containerX + 55, containerY + 35),
      anchor: Anchor.centerLeft,
    );

    // "LEVEL" etiketi
    TextPaint labelText = TextPaint(
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54),
        ],
      ),
    );

    labelText.render(
      canvas,
      "LEVEL",
      Vector2(containerX + 55, containerY + 20),
      anchor: Anchor.centerLeft,
    );

    // Level progress barı
    _drawLevelProgressBar(
        canvas, containerX + 10, containerY + 50, containerWidth - 20);
  }

  // Level yıldız ikonu çizimi
  void _drawLevelStar(Canvas canvas, double x, double y, double scale) {
    final starPaint = Paint()
      ..color = const Color(0xFFFFD700) // Altın
      ..style = PaintingStyle.fill;

    final starSize = 12 * scale;
    final starPath = Path();

    // 5 köşeli yıldız çizimi
    for (int i = 0; i < 5; i++) {
      final angle = (i * 144 - 90) * pi / 180; // 144 derece aralıklarla
      final radius = starSize;
      final starX = x + cos(angle) * radius;
      final starY = y + sin(angle) * radius;

      if (i == 0) {
        starPath.moveTo(starX, starY);
      } else {
        starPath.lineTo(starX, starY);
      }

      // İç köşe
      final innerAngle = ((i * 144 + 72) - 90) * pi / 180;
      final innerRadius = starSize * 0.4;
      final innerX = x + cos(innerAngle) * innerRadius;
      final innerY = y + sin(innerAngle) * innerRadius;
      starPath.lineTo(innerX, innerY);
    }
    starPath.close();

    canvas.drawPath(starPath, starPaint);

    // Yıldız parlaklığı
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x - 2, y - 2), 3 * scale, shinePaint);
  }

  // Level progress barı çizimi
  void _drawLevelProgressBar(Canvas canvas, double x, double y, double width) {
    final barHeight = 6.0;

    // Arka plan barı
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, barHeight),
        const Radius.circular(3),
      ),
      backgroundPaint,
    );

    // Level progress hesaplama (her 100 skorda level artışı)
    final levelProgress = (score % 100) / 100.0;
    final progressBarWidth = width * levelProgress;

    // Progress barı
    final progressPaint = Paint()
      ..color = const Color(0xFFFFD700) // Altın
      ..style = PaintingStyle.fill;

    if (progressBarWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, progressBarWidth, barHeight),
          const Radius.circular(3),
        ),
        progressPaint,
      );
    }

    // Bar kenarlığı
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, barHeight),
        const Radius.circular(3),
      ),
      borderPaint,
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

    // Skor artışı animasyonu
    if (_isScoreAnimating) {
      _scoreAnimationValue += dt * 8.0; // Hızlı animasyon
      if (_scoreAnimationValue >= 1.0) {
        _scoreAnimationValue = 0.0;
        _isScoreAnimating = false;
        _lastScore = score;
      }
    }

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

        // Skor artışı animasyonunu tetikle
        if (score > _lastScore) {
          _isScoreAnimating = true;
          _scoreAnimationValue = 0.0;
        }

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
