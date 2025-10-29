import 'dart:math';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:smash_the_insect/generated/locale_keys.g.dart';

import 'Components/Util/state.dart';
import 'Components/enemy_manager.dart';
import 'Components/enemy.dart';
import 'Components/health_bar.dart';
import 'Components/player.dart';
import 'Components/blood_effect.dart';
import 'Components/explosion_effect.dart';
import 'Components/pause_menu.dart';
import 'Components/admob_service.dart';
import 'Components/analytics_service.dart';
import 'Components/sound_manager.dart';
import 'Components/firestore_service.dart';
import 'Components/banner_ad_widget.dart';
import 'Components/power_up.dart';

class GameController extends FlameGame
    with TapDetector, HasKeyboardHandlerComponents {
  // Oyun durumu
  late GameState gameState;
  late Player player;
  late EnemyManager enemyManager;
  late PowerUpManager powerUpManager;
  late HealthBar healthBar;
  late PauseMenu pauseMenu;

  // Dialog sistemi için
  BuildContext? _context;
  bool _isPaused = false;

  // AdMob servisi
  final AdMobService _adMobService = AdMobService();

  // Analytics servisi
  final AnalyticsService _analytics = AnalyticsService();

  // Firestore servisi
  final FirestoreService _firestoreService = FirestoreService();

  // Oyun değişkenleri
  double score = 0;
  double gameTime = 0.0;
  late Random rnd;

  // UI/Sprite ölçekleme (tablet/telefon ekranına göre)
  double _uiScale = 1.0;

  // UI ölçek getter'ı
  double get uiScale => _uiScale;

  // Animasyonlu UI için
  double _pulseAnimationValue = 0.0;

  // HealthBar için getter
  double get pulseAnimationValue => _pulseAnimationValue;

  // Skor artışı animasyonu için
  double _scoreAnimationValue = 0.0;
  double _lastScore = 0.0;
  int _displayedScore = 0; // Görünen animasyonlu skor

  // Level animasyonu için
  double _levelAnimationValue = 0.0;
  bool _isLevelAnimating = false;
  bool _levelAnimationCompleted = false;
  int _previousLevel = 1;
  Color _currentBackgroundColor = const Color(0xFF87CEEB);
  Color _targetBackgroundColor = const Color(0xFF87CEEB);
  double _colorTransitionProgress = 0.0;

  // Level sistemi
  int currentLevel = 1;
  double enemySpeedMultiplier = 1.0;
  double spawnRateMultiplier = 1.0;

  // Power-up etkileri
  double tapRadiusMultiplier = 1.0; // speed buff etkisi için dokunma yarıçapı
  bool shieldActive = false;
  bool freezeActive = false;
  double scoreMultiplier = 1.0;

  late Timer? _speedTimer = null;
  late Timer? _shieldTimer = null;
  late Timer? _freezeTimer = null;
  late Timer? _multiHitTimer = null;

  // Level hesaplama ve güncelleme
  void _updateLevel() {
    final newLevel = (score / 10).floor() + 1; // Her 100 skorda level artışı

    if (newLevel > currentLevel) {
      _previousLevel = currentLevel;
      currentLevel = newLevel;

      // Arka plan renk geçişini başlat
      _startColorTransition();

      // Level animasyonunu başlat
      _isLevelAnimating = true;
      _levelAnimationValue = 0.0;

      _updateGameSpeed();

      // Pasta sprite'ını yeni boyutta yeniden oluştur
      // if (player.parent != null) {
      //   // Level'e göre pasta boyutunu hesapla (40px + (level-1)*3px, max 100px)
      //   final baseSize = 40.0;
      //   final sizePerLevel = 3.0;
      //   final maxSize = 100.0;
      //   final levelGrowth = (currentLevel - 1) * sizePerLevel;
      //   final targetSizePx = (baseSize + levelGrowth).clamp(40.0, maxSize);

      //   // Player boyutunu güncelle
      //   player.size = Vector2(targetSizePx * _uiScale, targetSizePx * _uiScale);

      //   // Sprite'ı güncelle
      //   player.sprite = _createEnhancedCakeSprite(scale: _uiScale);
      //   print(
      //       "Pasta boyutu level $currentLevel için güncellendi: ${targetSizePx}px");
      // }

      // Analytics: Level up event'i
      _analytics.logLevelUp(
        newLevel: currentLevel,
        score: score.toInt(),
        gameTime: gameTime,
      );
    }
  }

  // Arka plan renk geçişini başlat
  void _startColorTransition() {
    _currentBackgroundColor = _getColorForLevel(_previousLevel);
    _targetBackgroundColor = _getColorForLevel(currentLevel);
    _colorTransitionProgress = 0.0;
  }

  // İki renk arasında interpolation
  Color _interpolateColor(Color start, Color end, double progress) {
    progress = progress.clamp(0.0, 1.0);
    return Color.fromRGBO(
      (start.red + (end.red - start.red) * progress).round(),
      (start.green + (end.green - start.green) * progress).round(),
      (start.blue + (end.blue - start.blue) * progress).round(),
      start.opacity,
    );
  }

  // Level'e göre renk döndür
  Color _getColorForLevel(int level) {
    if (level <= 3) {
      return const Color(0xFF87CEEB); // Açık mavi
    } else if (level <= 6) {
      return const Color(0xFF70C3FF); // Canlı mavi
    } else if (level <= 9) {
      return const Color(0xFF5A9FD4); // Derin mavi
    } else if (level <= 12) {
      return const Color(0xFFFFB347); // Sarı-Turuncu
    } else if (level <= 15) {
      return const Color(0xFFFF8C94); // Açık kırmızı
    } else if (level <= 18) {
      return const Color(0xFFFF6B9D); // Pembe-Kırmızı
    } else if (level <= 21) {
      return const Color(0xFFDDA0DD); // Mor
    } else {
      return const Color(0xFF9370DB); // Koyu mor
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
      const baseSpeedIncrease = 9 * 0.3; // İlk 10 level'daki toplam artış
      const baseSpawnIncrease = 9 * 0.25; // İlk 10 level'daki toplam artış

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
    // Power-up spawn hızını da güncelle
    powerUpManager.updateSpawnRate();
  }

  // Pasta yer değiştirme
  late Timer pastaMoveTimer;

  // Sprite'lar
  // late Sprite spriteCake;
  // late Sprite spriteExplosion;
  // late Sprite spriteAnt;
  // late Sprite spriteSpider;
  // late Sprite spriteCockroach;

  @override
  Future<void>? onLoad() async {
    super.onLoad();
    rnd = Random();

    // Oyun durumunu başlat
    gameState = GameState.start;

    // Ekran boyutuna göre ölçek belirle (kısa kenara göre)
    // Tablette çok büyük gözükmemesi için ölçeği daha düşük tutuyoruz
    final minDim = min(size.x, size.y);
    // Telefon ve tablet için daha dengeli ölçek: minDim/800 ile daha küçük
    _uiScale = (minDim / 800).clamp(0.8, 1.5).toDouble();

    // Sprite'ları yükle
    // await _loadSprites();

    // Player'ı oluştur
    _createPlayer();

    // EnemyManager'ı oluştur
    _createEnemyManager();

    // PowerUpManager'ı oluştur
    _createPowerUpManager();

    // HealthBar'ı oluştur
    _createHealthBar();

    // Interstitial reklamı yükle
    _adMobService.loadInterstitialAd();

    // Rewarded reklamı yükle
    _adMobService.loadRewardedAd();

    // PauseMenu'yu oluştur
    _createPauseMenu();

    // Pasta yer değiştirme timer'ını başlat
    pastaMoveTimer = Timer(3.0, onTick: _movePasta, repeat: true);
    pastaMoveTimer.start();

    gameState = GameState.playing;

    // Müzik zaten ana ekranda başlatıldı, oyunda devam ediyor olacak
    // Eğer müzik kapalıysa açılmış olabilir, resume yap
    SoundManager.resumeBackgroundMusic();

    // Analytics: Oyun başlatma event'i
    _analytics.logGameStart();
  }

  // Future<void> _loadSprites() async {
  //   try {
  //     print("Sprite'lar yükleniyor...");
  //     // Temel sprite'ları yükle
  //     await images.loadAll(["cake.png", "explosion.png", "hearth.png"]);

  //     // Pasta sprite'ını oluştur (ölçekli)
  //     spriteCake = _createEnhancedCakeSprite(scale: _uiScale);
  //     print("Pasta sprite oluşturuldu");
  //     spriteExplosion = Sprite(images.fromCache("explosion.png"));

  //     // Böcek sprite'larını oluştur (ölçekli)
  //     spriteAnt =
  //         _createBugSprite(const Color(0xFF8B4513), "ANT", scale: _uiScale);
  //     spriteSpider =
  //         _createBugSprite(const Color(0xFF000000), "SPIDER", scale: _uiScale);
  //     spriteCockroach = _createBugSprite(const Color(0xFF654321), "COCKROACH",
  //         scale: _uiScale);
  //     print("Tüm sprite'lar başarıyla yüklendi");
  //   } catch (e) {
  //     print("Sprite yükleme hatası: $e");
  //     // Fallback sprite'lar oluştur
  //     // spriteCake = _createSimpleCakeSprite(scale: _uiScale);
  //     // print("Fallback pasta sprite oluşturuldu");
  //     // spriteExplosion = _createSimpleExplosionSprite();
  //     // spriteAnt =
  //     //     _createSimpleBugSprite(const Color(0xFF8B4513), scale: _uiScale);
  //     // spriteSpider =
  //     //     _createSimpleBugSprite(const Color(0xFF000000), scale: _uiScale);
  //     // spriteCockroach =
  //     //     _createSimpleBugSprite(const Color(0xFF654321), scale: _uiScale);
  //   }
  // }

  void _createPlayer() {
    player = Player(
      sprite: createEnhancedCakeSprite(scale: _uiScale),
      size: Vector2(85 * _uiScale, 85 * _uiScale),
      position: size / 2,
      gameController: this,
    );
    player.anchor = Anchor.center;

    add(player);
  }

  void _createEnemyManager() {
    enemyManager = EnemyManager(
      gameController: this,
      sprites: [
        _createBugSprite(
          const Color(0xFF8B4513),
          "ANT",
          scale: _uiScale,
        ),
        _createBugSprite(
          const Color(0xFF000000),
          "SPIDER",
          scale: _uiScale,
        ),
        _createBugSprite(
          const ui.Color.fromARGB(255, 150, 116, 83),
          "COCKROACH",
          scale: _uiScale,
        )
      ],
    );
    add(enemyManager);
  }

  void _createPowerUpManager() {
    powerUpManager = PowerUpManager(gameController: this);
    add(powerUpManager);
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

    // Arka plan müziğini duraklat
    SoundManager.pauseBackgroundMusic();

    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D3436),
                  Color(0xFF636E72),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pause ikonu ve başlık
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.pause_circle_filled,
                          size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LocaleKeys.game_paused.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Banner reklam
                    BannerAdWidget(
                      adUnitId: AdMobService.bannerAdPauseDialogUnitId,
                    ),
                    const SizedBox(height: 16),

                    // Devam et butonu - ana aksiyon
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          resumeGame();
                        },
                        icon: const Icon(Icons.play_arrow_rounded,
                            size: 28, color: Colors.white),
                        label: Text(
                          LocaleKeys.continue_game.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ED573),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF2ED573).withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Diğer butonlar - 2 sütun kompakt
                    Row(
                      children: [
                        // Yeniden başla
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              restartGame();
                            },
                            icon: const Icon(Icons.refresh, size: 22),
                            label: Text(
                              LocaleKeys.restart_game.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFA502),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Ana menü
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              goToMainMenu();
                            },
                            icon: const Icon(Icons.home, size: 22),
                            label: Text(
                              LocaleKeys.main_menu.tr().toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF74B9FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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

    // Arka plan müziğini devam ettir
    SoundManager.resumeBackgroundMusic();
  }

  // Oyunu yeniden başlatma
  void restartGame() {
    _isPaused = false;
    resumeEngine();

    // Oyunu yeniden başlatmak için gerekli işlemler
    score = 0;
    _displayedScore = 0; // Animasyonlu skor sıfırla
    gameTime = 0.0;
    player.resetHealth();

    // Level'i sıfırla
    currentLevel = 1;
    _previousLevel = 1;
    enemySpeedMultiplier = 1.0;
    spawnRateMultiplier = 1.0;
    enemyManager.updateSpawnRate();
    powerUpManager.updateSpawnRate();

    // Animasyonları sıfırla
    _isLevelAnimating = false;
    _levelAnimationValue = 0.0;
    _levelAnimationCompleted = false;

    // Arka plan rengini ilk renge sıfırla
    _currentBackgroundColor = const Color(0xFF87CEEB);
    _targetBackgroundColor = const Color(0xFF87CEEB);
    _colorTransitionProgress = 1.0;

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

    // Arka plan müziğini başlat
    SoundManager.startBackgroundMusic();
  }

  // Ses ayarları için getter'lar (artık SoundManager kullanılıyor)

  // Öldürülen düşman sayısını hesapla
  int _getEnemiesKilledCount() {
    // Skor bazlı tahmin (her düşman için ortalama puan)
    return score.toInt(); // Her düşman için 10 puan varsayımı
  }

  // Oyun bitişi
  void _gameOver() {
    gameState = GameState.end;
    pauseEngine();

    // Arka plan müziğini durdur
    SoundManager.stopBackgroundMusic();

    // Analytics: Oyun bitiş event'i
    _analytics.logGameEnd(
      score: score.toInt(),
      gameTime: gameTime,
      level: currentLevel,
      enemiesKilled: _getEnemiesKilledCount(),
    );

    // High score kaydet
    _saveHighScore();

    // Interstitial reklamı göster (eğer yüklendiyse)
    if (_adMobService.isInterstitialAdLoaded) {
      _adMobService.showInterstitialAd();
    }

    // Oyun bitiş ekranını göster
    showGameOverDialog();
  }

  // High score kaydetme
  Future<void> _saveHighScore() async {
    try {
      final nickname = await _firestoreService.getNickname();
      if (nickname != null) {
        final scoreInt = score.toInt();

        // Firestore'a kaydet (score, level ve süre ile birlikte)
        await _firestoreService.saveHighScore(
          nickname,
          scoreInt,
          level: currentLevel,
          gameTime: gameTime,
        );

        // Local high score'u güncelle
        await _firestoreService.updateLocalHighScore(scoreInt);
      } else {}
    } catch (e) {
      print('Error saving high score: $e');
    }
  }

  // Oyun bitiş dialog'u
  void showGameOverDialog() {
    if (_context == null) {
      return;
    }

    // Dialog'u bir sonraki frame'e geciktir
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _showDialogSafely();
    });
  }

  // Güvenli dialog gösterimi
  void _showDialogSafely() {
    try {
      if (_context == null) {
        return;
      }

      showDialog(
        context: _context!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 600),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2D3436),
                    Color(0xFF636E72),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pasta ve başlık
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Text('🍰', style: TextStyle(fontSize: 40)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        LocaleKeys.game_over.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // İstatistikler - yan yana kompakt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCompactStat('💰', '${score.toInt()}',
                              LocaleKeys.stat_score.tr()),
                          _buildCompactStat(
                              '⏱️',
                              '${gameTime.toStringAsFixed(0)}s',
                              LocaleKeys.stat_time.tr()),
                          _buildCompactStat('🌟', '$currentLevel',
                              LocaleKeys.stat_level.tr()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Ödüllü reklam - GÖZE ÇARPICI
                      if (_adMobService.isRewardedAdLoaded) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ElevatedButton(
                                onPressed: () => _watchRewardedAd(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.black,
                                  shadowColor: Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.play_circle_filled,
                                        size: 28, color: Colors.black),
                                    const SizedBox(width: 10),
                                    Text(
                                      LocaleKeys.watch_ad_for_life.tr(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                LocaleKeys.watch_ad_subtitle.tr(),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Diğer butonlar - 2 sütun kompakt
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                restartGame();
                              },
                              icon: const Icon(Icons.refresh, size: 22),
                              label: Text(
                                LocaleKeys.restart_game.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2ED573),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                goToMainMenu();
                              },
                              icon: const Icon(Icons.home, size: 22),
                              label: Text(
                                LocaleKeys.main_menu.tr().toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF74B9FF),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Dialog gösterilirken hata oluştu
    }
  }

  // Power-up efektleri
  void activateSpeedBoost({int durationSeconds = 8}) {
    tapRadiusMultiplier = 1.8; // Dokunma yarıçapını daha fazla büyüt
    _speedTimer?.stop();
    _speedTimer = Timer(durationSeconds.toDouble(), onTick: () {
      tapRadiusMultiplier = 1.0;
    });
    _speedTimer!.start();
  }

  void activateShield({int durationSeconds = 6}) {
    shieldActive = true;
    _shieldTimer?.stop();
    _shieldTimer = Timer(durationSeconds.toDouble(), onTick: () {
      shieldActive = false;
    });
    _shieldTimer!.start();
  }

  void activateMultiHit({int durationSeconds = 10}) {
    scoreMultiplier = 2.0;
    _multiHitTimer?.stop();
    _multiHitTimer = Timer(durationSeconds.toDouble(), onTick: () {
      scoreMultiplier = 1.0;
    });
    _multiHitTimer!.start();
  }

  void activateFreeze({int durationSeconds = 4}) {
    freezeActive = true;
    _freezeTimer?.stop();
    _freezeTimer = Timer(durationSeconds.toDouble(), onTick: () {
      freezeActive = false;
    });
    _freezeTimer!.start();
  }

  void triggerBomb() {
    final enemiesToKill =
        List<Enemy>.from(enemyManager.enemies).where((e) => !e.isDead).toList();
    for (final enemy in enemiesToKill) {
      enemy.isDead = true;
      add(ExplosionEffect(position: enemy.position));
      add(BloodEffect(position: enemy.position));
      score +=
          (enemy.isComboEnemy ? enemy.comboMultiplier : 1) * scoreMultiplier;
      enemy.removeFromParent();
      enemyManager.enemies.remove(enemy);
    }
  }

  // Kompakt istatistik widget'ı
  Widget _buildCompactStat(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Ödüllü reklam izleme
  void _watchRewardedAd() {
    _adMobService.showRewardedAd(
      onRewarded: (reward) {
        // Analytics
        _analytics.logCustomEvent(
          eventName: 'rewarded_ad_watched',
          parameters: {
            'score': score.toInt(),
            'level': currentLevel,
            'reward_amount': reward.amount,
            'reward_type': reward.type,
          },
        );

        // Oyunu devam ettir
        _continueGameAfterReward();
      },
    );
  }

  // Ödül sonrası oyunu devam ettirme
  void _continueGameAfterReward() {
    // İlk önce dialog'u kapat
    if (_context != null) {
      Navigator.of(_context!).pop();
    }

    // Dialog kapandıktan sonra küçük bir gecikme ekle
    Future.delayed(const Duration(milliseconds: 300), () {
      // Oyun durumunu playing yap
      gameState = GameState.playing;

      // Motoru devam ettir
      resumeEngine();

      // Müziği başlat
      SoundManager.startBackgroundMusic();

      // Canı fulle
      player.currentHealth = 100.0;

      // Pause durumunu sıfırla
      _isPaused = false;
    });
  }

  // Ana menüye dönme
  void goToMainMenu() {
    _isPaused = false;
    resumeEngine();

    // Oyunu sıfırla
    score = 0;
    _displayedScore = 0; // Animasyonlu skor sıfırla
    gameTime = 0.0;
    player.resetHealth();

    // Level'i sıfırla
    currentLevel = 1;
    _previousLevel = 1;
    enemySpeedMultiplier = 1.0;
    spawnRateMultiplier = 1.0;

    // Animasyonları sıfırla
    _isLevelAnimating = false;
    _levelAnimationValue = 0.0;
    _levelAnimationCompleted = false;

    // Arka plan rengini ilk renge sıfırla
    _currentBackgroundColor = const Color(0xFF87CEEB);
    _targetBackgroundColor = const Color(0xFF87CEEB);
    _colorTransitionProgress = 1.0;

    // Düşmanları temizle
    for (final enemy in enemyManager.enemies) {
      enemy.removeFromParent();
    }
    enemyManager.enemies.clear();

    // Player'ı merkeze taşı
    player.updatePosition(size / 2);

    // Timer'ları durdur
    pastaMoveTimer.stop();

    // Müziği durdurma, ana ekranda devam etsin
    // Ana ekrana döndüğünde müzik zaten çalıyor olacak

    // Oyun durumunu start olarak ayarla
    gameState = GameState.start;

    // Ana ekrana dön
    if (_context != null) {
      Navigator.of(_context!).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  void _movePasta() {
    if (gameState != GameState.playing) return;

    // Ekranın ortasında rastgele bir pozisyon seç
    const margin = 150.0;
    final centerX = size.x / 2;
    final centerY = size.y / 2;

    final newX = centerX + (rnd.nextDouble() - 0.5) * margin;
    final newY = centerY + (rnd.nextDouble() - 0.5) * margin;

    player.updatePosition(Vector2(newX, newY));
  }

  // Level'e göre arka plan rengi (animasyonlu geçiş ile)
  Color get _backgroundColor {
    if (_colorTransitionProgress < 1.0) {
      // Animasyonlu geçiş
      return _interpolateColor(
        _currentBackgroundColor,
        _targetBackgroundColor,
        _colorTransitionProgress,
      );
    }
    return _targetBackgroundColor;
  }

  @override
  void render(Canvas canvas) {
    // Arka plan rengi - level'e göre dinamik
    canvas.drawColor(_backgroundColor, BlendMode.srcOver);

    // Büyük skor gösterimi (arka planda, ortada)
    _renderBigScore(canvas);

    // UI'yi render et
    _renderUI(canvas);

    // Düşmanları kontrol et
    _checkEnemyCollisions();

    super.render(canvas);
  }

  // Arka planda büyük skor gösterimi
  void _renderBigScore(Canvas canvas) {
    final centerX = size.x / 2;
    final centerY = size.y / 2;

    // Animasyonlu scale - skor değişirken büyür
    double scale = 1.0;
    if (_scoreAnimationValue > 0.0) {
      final pulse = sin(_scoreAnimationValue * pi * 2);
      scale = 1.0 + (pulse * 0.12); // Hafif büyüme/küçülme
    }

    // Glow efekti
    TextPaint glowText = TextPaint(
      style: TextStyle(
        fontSize: 150 * scale,
        fontWeight: FontWeight.bold,
        color: Colors.white.withOpacity(0.08),
      ),
    );

    // Glow arka plan
    glowText.render(
      canvas,
      "$_displayedScore",
      Vector2(centerX, centerY),
      anchor: Anchor.center,
    );

    // Ana skor metni - büyük ve yarı saydam
    TextPaint scoreText = TextPaint(
      style: TextStyle(
        fontSize: 150 * scale,
        fontWeight: FontWeight.bold,
        color: Colors.white.withOpacity(0.2),
        letterSpacing: 5,
      ),
    );

    scoreText.render(
      canvas,
      "$_displayedScore",
      Vector2(centerX, centerY),
      anchor: Anchor.center,
    );
  }

  void _renderUI(Canvas canvas) {
    // MediaQuery'den safe area padding al
    double topPadding = 0;
    double leftPadding = 0;
    double rightPadding = 0;

    if (_context != null) {
      try {
        final mediaQuery = MediaQuery.of(_context!);
        topPadding = mediaQuery.padding.top;
        leftPadding = mediaQuery.padding.left;
        rightPadding = mediaQuery.padding.right;
      } catch (e) {
        print("MediaQuery error: $e");
      }
    }

    // Ekstra güvenlik padding'i
    const safeAreaPadding = 10.0;
    final topPaddingWithSafeArea = topPadding + safeAreaPadding;

    final yPos = topPaddingWithSafeArea;

    // Level gösteriminin x pozisyonu - ekran genişliğine göre ayarla
    final levelXPos = leftPadding + safeAreaPadding + 10.0;

    // Sadece level göster (can ekranın altında)
    _renderModernLevel(canvas, levelXPos, yPos);

    // Pause butonu (sağ üst köşede) - ekran genişliğine göre ayarla
    final pauseButtonXPos = size.x - 50.0 - rightPadding - safeAreaPadding;
    _renderModernPauseButton(canvas, pauseButtonXPos, yPos);
  }

  void _renderModernLevel(Canvas canvas, double x, double y) {
    // Modern minimal level gösterimi
    const containerWidth = 55.0;
    const containerHeight = 40.0;

    final containerRect = Rect.fromLTWH(x, y, containerWidth, containerHeight);

    // Glassmorphism efekti
    final glassPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(containerRect, const Radius.circular(18)),
      glassPaint,
    );

    // Level artışında hafif glow efekti
    double glowIntensity = 0.3;
    if (_isLevelAnimating || _levelAnimationCompleted) {
      glowIntensity = 0.6;
    }

    // Purple glow border
    final borderPaint = Paint()
      ..color = const Color(0xFF6C5CE7).withOpacity(glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(containerRect, const Radius.circular(18)),
      borderPaint,
    );

    // Etiket
    TextPaint labelText = TextPaint(
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );

    labelText.render(
        canvas,
        "LVL",
        Vector2(
          x + containerWidth / 2,
          y + 10,
        ),
        anchor: Anchor.center);

    // Level metni
    TextPaint levelText = TextPaint(
      style: const TextStyle(
        color: Color(0xFF6C5CE7),
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 3,
            color: Colors.black45,
          ),
        ],
      ),
    );

    levelText.render(
      canvas,
      "$currentLevel",
      Vector2(x + containerWidth / 2, y + 25),
      anchor: Anchor.center,
    );
  }

  // Skor artışı popup efekti çizimi

  // Böcek ezme ikonu çizimi

  // Animasyonlu kalp ikonu çizimi

  // Kompakt kalp ikonu çizimi

  // Kompakt can barı çizimi

  // Kompakt level yıldız ikonu çizimi

  // Can barı çizimi

  // Level yıldız ikonu çizimi

  // Level progress barı çizimi

  void _renderModernPauseButton(Canvas canvas, double x, double y) {
    // Modern minimal pause butonu
    const buttonWidth = 40.0;
    const buttonHeight = 35.0;

    final buttonRect = Rect.fromLTWH(x, y, buttonWidth, buttonHeight);

    // Glassmorphism buton
    final buttonPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(buttonRect, const Radius.circular(18)),
      buttonPaint,
    );

    // Subtle border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(buttonRect, const Radius.circular(18)),
      borderPaint,
    );

    // Pause ikonu - daha ince
    final iconPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    final iconCenterX = x + buttonWidth / 2;
    final iconCenterY = y + buttonHeight / 2;
    const iconSpacing = 4.5;

    canvas.drawLine(
      Offset(iconCenterX - iconSpacing, iconCenterY - 5),
      Offset(iconCenterX - iconSpacing, iconCenterY + 5),
      iconPaint,
    );
    canvas.drawLine(
      Offset(iconCenterX + iconSpacing, iconCenterY - 5),
      Offset(iconCenterX + iconSpacing, iconCenterY + 5),
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

      // Temas kontrolü - pastaya daha yakın mesafe
      final distance = player.position.distanceTo(enemy.position);
      if (distance < 45) {
        // Hasar ver
        if (!shieldActive) {
          player.takeDamage(5);
        }
        enemy.isDead = true;

        // Hasar sesi çal
        SoundManager.playDamageSound();

        // Düşmanı hemen kaldır - güvenli şekilde
        enemy.removeFromParent();
        // Liste iteration sırasında değişmemesi için remove işlemini geciktir
        Future.microtask(() => enemyManager.enemies.remove(enemy));

        // Kan efekti
        add(BloodEffect(position: enemy.position));

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

    // Skor artışı animasyonu - sayı sayarak artır
    if (_displayedScore < score.toInt()) {
      final diff = score.toInt() - _displayedScore;
      final increment = (diff * dt * 15).ceil(); // Yumuşak geçiş
      _displayedScore += increment;
      if (_displayedScore > score.toInt()) {
        _displayedScore = score.toInt();
      }

      // Skor değişirken pulse efekti
      _scoreAnimationValue = (_scoreAnimationValue + dt * 3.0) % 1.0;
    } else {
      _scoreAnimationValue = 0.0;
    }

    // Level animasyonu - sadece glow efekti için
    if (_isLevelAnimating) {
      _levelAnimationValue += dt * 3.0;
      if (_levelAnimationValue >= 1.0) {
        _levelAnimationValue = 1.0;
        _isLevelAnimating = false;
        _levelAnimationCompleted = true;
      }
    }

    // Glow efekti geri dönüşü
    if (_levelAnimationCompleted && !_isLevelAnimating) {
      _levelAnimationValue -= dt * 1.5;
      if (_levelAnimationValue <= 0.0) {
        _levelAnimationValue = 0.0;
        _levelAnimationCompleted = false;
      }
    }

    // Renk geçiş animasyonu
    if (_colorTransitionProgress < 1.0) {
      _colorTransitionProgress += dt * 0.8; // Yavaş renk geçişi
      if (_colorTransitionProgress >= 1.0) {
        _colorTransitionProgress = 1.0;
        _currentBackgroundColor = _targetBackgroundColor;
      }
    }

    // Level güncellemesi
    _updateLevel();

    // Timer'ları güncelle
    pastaMoveTimer.update(dt);

    // Power-up timer'larını güncelle
    _speedTimer?.update(dt);
    _shieldTimer?.update(dt);
    _freezeTimer?.update(dt);
    _multiHitTimer?.update(dt);

    super.update(dt);
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (gameState != GameState.playing) {
      return;
    }

    final tapPosition = info.eventPosition.global;

    // Pause butonuna dokunma kontrolü (yeni tasarım)
    if (_isPauseButtonTapped(tapPosition)) {
      showPauseDialog();
      return;
    }

    // Düşmanlara dokunma kontrolü
    for (final enemy in enemyManager.enemies) {
      if (enemy.isDead) continue;

      // Manuel collision detection - kombo düşmanlar için daha büyük radius
      final baseRadius = enemy.isComboEnemy ? 50.0 : 35.0;
      final enemyRadius = baseRadius * tapRadiusMultiplier;
      final distance = (tapPosition - enemy.position).length;

      if (distance < enemyRadius) {
        // Düşmanı öldür
        enemy.isDead = true;

        // Kombo düşmanlara basınca ekstra puan ver
        final basePoints = enemy.isComboEnemy ? enemy.comboMultiplier : 1;
        score += basePoints * scoreMultiplier;

        // Düşman öldürme sesi çal
        SoundManager.playSmashSound();

        // Analytics: Düşman öldürme event'i
        _analytics.logEnemyKilled(
          enemyType: enemy.runtimeType.toString(),
          currentScore: score.toInt(),
          level: currentLevel,
        );

        // Skor artışı animasyonunu tetikle
        if (score > _lastScore) {
          _scoreAnimationValue = 0.0;
        }

        // Kombo düşmanlar için daha fazla efekt
        if (enemy.isComboEnemy) {
          // Büyük patlama efekti
          for (int i = 0; i < 3; i++) {
            add(ExplosionEffect(position: enemy.position));
          }
          // Büyük kan efekti
          for (int i = 0; i < 5; i++) {
            add(BloodEffect(position: enemy.position));
          }
        } else {
          // Normal patlama efekti
          add(ExplosionEffect(position: enemy.position));
          add(BloodEffect(position: enemy.position));
        }

        // Düşmanı hemen kaldır
        enemy.removeFromParent();
        enemyManager.enemies.remove(enemy);

        break;
      }
    }

    // Power-up'lara dokunma kontrolü
    print(
        "🎯 PowerUp kontrolü - Liste uzunluğu: ${powerUpManager.powerUps.length}, Tap: $tapPosition");

    if (powerUpManager.powerUps.isEmpty) {
      print("⚠️ PowerUp listesi boş!");
    }

    for (final powerUp in powerUpManager.powerUps) {
      if (powerUp.isCollected) {
        print("⏭️ PowerUp zaten toplanmış: ${powerUp.type}");
        continue;
      }

      // Anchor center olduğu için position zaten center
      final powerUpCenter = powerUp.position;
      final powerUpRadius = powerUp.size.x / 2; // Power-up'ın radius'u
      final distance = (tapPosition - powerUpCenter).length;

      print(
          "🎁 PowerUp kontrol - Type: ${powerUp.type}, Center: $powerUpCenter, Size: ${powerUp.size}, Radius: $powerUpRadius, Distance: $distance");

      if (distance < powerUpRadius) {
        // Power-up'ı topla ve aktif et
        print("✅ PowerUp toplandı: ${powerUp.type}");
        powerUp.collect();
        SoundManager.playSmashSound();
        break;
      } else {
        print(
            "❌ PowerUp mesafe fazla - Distance: $distance, Radius: $powerUpRadius");
      }
    }
  }

  bool _isPauseButtonTapped(Vector2 tapPosition) {
    // MediaQuery'den safe area padding al
    double topPadding = 0;
    double rightPadding = 0;

    if (_context != null) {
      try {
        final mediaQuery = MediaQuery.of(_context!);
        topPadding = mediaQuery.padding.top;
        rightPadding = mediaQuery.padding.right;
      } catch (e) {
        // MediaQuery error
      }
    }

    // Ekstra güvenlik padding'i
    const safeAreaPadding = 10.0;
    const buttonWidth = 40.0;
    const buttonHeight = 35.0;

    final yPos = topPadding + safeAreaPadding;
    final buttonX = size.x - 50.0 - rightPadding - safeAreaPadding;

    final buttonRect = Rect.fromLTWH(buttonX, yPos, buttonWidth, buttonHeight);

    return buttonRect.contains(tapPosition.toOffset());
  }

  // Böcek sprite'ı oluşturma metodu
  Sprite _createBugSprite(Color color, String type, {double scale = 1.0}) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final s = scale;
    // Daha büyük sprite boyutu için koordinatları 2x'e çıkar
    final multiplier = 2.0;

    // Ana vücut
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(64 * s * multiplier, 64 * s * multiplier),
        50 * s * multiplier, bodyPaint);

    // Gözler
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(52 * s * multiplier, 52 * s * multiplier),
        6 * s * multiplier, eyePaint);
    canvas.drawCircle(Offset(76 * s * multiplier, 52 * s * multiplier),
        6 * s * multiplier, eyePaint);

    // Göz bebekleri
    final pupilPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(52 * s * multiplier, 52 * s * multiplier),
        3 * s * multiplier, pupilPaint);
    canvas.drawCircle(Offset(76 * s * multiplier, 52 * s * multiplier),
        3 * s * multiplier, pupilPaint);

    // Bacaklar
    final legPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 4.0 * s * multiplier
      ..style = PaintingStyle.stroke;

    // Sol bacaklar
    canvas.drawLine(Offset(40 * s * multiplier, 90 * s * multiplier),
        Offset(30 * s * multiplier, 110 * s * multiplier), legPaint);
    canvas.drawLine(Offset(50 * s * multiplier, 90 * s * multiplier),
        Offset(40 * s * multiplier, 110 * s * multiplier), legPaint);

    // Sağ bacaklar
    canvas.drawLine(Offset(78 * s * multiplier, 90 * s * multiplier),
        Offset(88 * s * multiplier, 110 * s * multiplier), legPaint);
    canvas.drawLine(Offset(88 * s * multiplier, 90 * s * multiplier),
        Offset(98 * s * multiplier, 110 * s * multiplier), legPaint);

    // Kenarlık
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * s * multiplier;
    canvas.drawCircle(Offset(64 * s * multiplier, 64 * s * multiplier),
        50 * s * multiplier, borderPaint);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(
        (128 * s * multiplier).round(), (128 * s * multiplier).round());

    return Sprite(image);
  }

  // Gelişmiş pasta sprite'ı oluşturma metodu
  Sprite createEnhancedCakeSprite({double scale = 1.0}) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Tasarım referans boyutu - SABİT OLARAK 150x150 PİKSEL YÜKSEK ÇÖZÜNÜRLÜKTE ÜRETİLECEK
    const designSize = 150.0;

    // Canvas'ı her zaman yüksek çözünürlükte çiz (hangi level olursa olsun)
    const fixedCanvasSize = 150.0;
    final s = fixedCanvasSize / designSize; // Çizim ölçeği 1x (normal boyutta)

    // Pasta tabanı (kahverengi) - gölge efekti ile
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(75 * s, 97.5 * s),
        width: 127.5 * s,
        height: 18 * s,
      ),
      shadowPaint,
    );

    // Pasta tabanı (kahverengi) - ana pasta
    final basePaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(75 * s, 75 * s), 57 * s, basePaint);

    // Pasta tabanı gradient alt
    final baseGradientPaint = Paint()
      ..color = const Color(0xFFA0522D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(75 * s, 82.5 * s), 57 * s, baseGradientPaint);

    // Pasta üstü - çift katman
    final topPaint = Paint()
      ..color = const Color(0xFFFFF8DC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(75 * s, 63 * s), 48 * s, topPaint);

    // Pasta üstü - krema detayı
    final creamPaint = Paint()
      ..color = const Color(0xFFFFFACD)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(75 * s, 57 * s), 42 * s, creamPaint);

    // Krema tepe noktası
    final creamPeakPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(75 * s, 48 * s), 36 * s, creamPeakPaint);

    // Çilek detayları (birkaç çilek)
    final strawberryPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;

    // Ana çilek
    canvas.drawCircle(Offset(75 * s, 33 * s), 18 * s, strawberryPaint);

    // Çilek gölgesi
    final strawberryShadow = Paint()
      ..color = const Color(0xFFE63946)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(75 * s, 37.5 * s), 18 * s, strawberryShadow);

    // Çilek yaprakları (detaylı)
    final leafPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;

    // Yaprak 1
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(75 * s, 15 * s),
        width: 27 * s,
        height: 15 * s,
      ),
      leafPaint,
    );

    // Yaprak 2
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(67.5 * s, 18 * s),
        width: 22.5 * s,
        height: 12 * s,
      ),
      leafPaint,
    );

    // Yaprak 3
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(82.5 * s, 18 * s),
        width: 22.5 * s,
        height: 12 * s,
      ),
      leafPaint,
    );

    // Pasta kenarı detayı - dekoreatif kenar
    final decorationPaint = Paint()
      ..color = const Color(0xFFF0E68C)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0 * 3.14159) / 180.0;
      final x = 75 * s + 45 * s * cos(angle);
      final y = 63 * s + 45 * s * sin(angle);
      canvas.drawCircle(Offset(x, y), 6 * s, decorationPaint);
    }

    // Pasta kenarı detayı - iki katmanlı
    final decorationPaint2 = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0 * 3.14159) / 180.0;
      final x = 75 * s + 45 * s * cos(angle);
      final y = 63 * s + 45 * s * sin(angle);
      canvas.drawCircle(Offset(x, y), 4.5 * s, decorationPaint2);
    }

    // Pasta kenarı - koyu kahverengi gölge
    final baseShadowPaint = Paint()
      ..color = const Color(0xFF654321)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * s;
    canvas.drawCircle(Offset(75 * s, 75 * s), 57 * s, baseShadowPaint);

    // Ana kenarlık
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.75 * s;
    canvas.drawCircle(Offset(75 * s, 75 * s), 57 * s, borderPaint);

    final picture = recorder.endRecording();
    // Her zaman yüksek çözünürlüklü (150x150) sprite oluştur
    final highResImage = picture.toImageSync(
      fixedCanvasSize.round(),
      fixedCanvasSize.round(),
    );

    return Sprite(highResImage);
  }
}
