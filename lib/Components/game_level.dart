import 'package:flutter/material.dart';

enum EnemyType {
  ant, // Temel düşman - yavaş, kolay
  spider, // Orta seviye - hızlı, küçük
  cockroach, // Zor düşman - çok hızlı, küçük
  beetle, // Boss düşman - büyük, çok güçlü
  wasp, // Özel düşman - uçan, hızlı
}

enum PowerUpType {
  health, // Sağlık artırır
  speed, // Hız artırır
  shield, // Kalkan verir
  multiHit, // Çoklu vuruş
  freeze, // Düşmanları dondurur
  bomb, // Patlayıcı bomba
  magnet, // Düşmanları çeker
}

class GameLevel {
  final int levelNumber;
  final String name;
  final String description;
  final int targetScore;
  final double spawnRate;
  final List<EnemyType> availableEnemies;
  final List<PowerUpType> availablePowerUps;
  final double enemySpeedMultiplier;
  final double enemySizeMultiplier;
  final int maxEnemies;
  final Duration levelDuration;
  final Color backgroundColor;
  final String backgroundMusic;

  const GameLevel({
    required this.levelNumber,
    required this.name,
    required this.description,
    required this.targetScore,
    required this.spawnRate,
    required this.availableEnemies,
    required this.availablePowerUps,
    required this.enemySpeedMultiplier,
    required this.enemySizeMultiplier,
    required this.maxEnemies,
    required this.levelDuration,
    required this.backgroundColor,
    required this.backgroundMusic,
  });
}

class LevelManager {
  static final List<GameLevel> _levels = [
    // Seviye 1: Başlangıç
    const GameLevel(
      levelNumber: 1,
      name: "Böcek Bahçesi",
      description: "Küçük karıncalarla başla!",
      targetScore: 50,
      spawnRate: 1.5,
      availableEnemies: [EnemyType.ant],
      availablePowerUps: [PowerUpType.health],
      enemySpeedMultiplier: 1.0,
      enemySizeMultiplier: 1.0,
      maxEnemies: 5,
      levelDuration: Duration(seconds: 60),
      backgroundColor: Color(0xFFE8F5E8),
      backgroundMusic: "level1.mp3",
    ),

    // Seviye 2: Örümcekler
    const GameLevel(
      levelNumber: 2,
      name: "Örümcek Ağı",
      description: "Hızlı örümcekler geliyor!",
      targetScore: 100,
      spawnRate: 1.2,
      availableEnemies: [EnemyType.ant, EnemyType.spider],
      availablePowerUps: [PowerUpType.health, PowerUpType.speed],
      enemySpeedMultiplier: 1.2,
      enemySizeMultiplier: 0.9,
      maxEnemies: 7,
      levelDuration: Duration(seconds: 90),
      backgroundColor: Color(0xFFF3E5F5),
      backgroundMusic: "level2.mp3",
    ),

    // Seviye 3: Hamamböcekleri
    const GameLevel(
      levelNumber: 3,
      name: "Hamamböceği İstilası",
      description: "Çok hızlı hamamböcekleri!",
      targetScore: 200,
      spawnRate: 1.0,
      availableEnemies: [EnemyType.ant, EnemyType.spider, EnemyType.cockroach],
      availablePowerUps: [
        PowerUpType.health,
        PowerUpType.speed,
        PowerUpType.shield
      ],
      enemySpeedMultiplier: 1.5,
      enemySizeMultiplier: 0.8,
      maxEnemies: 10,
      levelDuration: Duration(seconds: 120),
      backgroundColor: Color(0xFFFFF3E0),
      backgroundMusic: "level3.mp3",
    ),

    // Seviye 4: Arılar
    const GameLevel(
      levelNumber: 4,
      name: "Arı Sürüsü",
      description: "Uçan arılar çok tehlikeli!",
      targetScore: 350,
      spawnRate: 0.8,
      availableEnemies: [EnemyType.spider, EnemyType.cockroach, EnemyType.wasp],
      availablePowerUps: [
        PowerUpType.health,
        PowerUpType.speed,
        PowerUpType.shield,
        PowerUpType.freeze
      ],
      enemySpeedMultiplier: 1.8,
      enemySizeMultiplier: 0.7,
      maxEnemies: 12,
      levelDuration: Duration(seconds: 150),
      backgroundColor: Color(0xFFFFF8E1),
      backgroundMusic: "level4.mp3",
    ),

    // Seviye 5: Boss Seviyesi
    const GameLevel(
      levelNumber: 5,
      name: "Böcek Kralı",
      description: "Dev böcek boss ile savaş!",
      targetScore: 500,
      spawnRate: 0.6,
      availableEnemies: [EnemyType.cockroach, EnemyType.wasp, EnemyType.beetle],
      availablePowerUps: [
        PowerUpType.health,
        PowerUpType.speed,
        PowerUpType.shield,
        PowerUpType.multiHit,
        PowerUpType.bomb
      ],
      enemySpeedMultiplier: 2.0,
      enemySizeMultiplier: 1.2,
      maxEnemies: 8,
      levelDuration: Duration(seconds: 180),
      backgroundColor: Color(0xFFFFEBEE),
      backgroundMusic: "boss.mp3",
    ),
  ];

  static GameLevel getLevel(int levelNumber) {
    if (levelNumber <= 0 || levelNumber > _levels.length) {
      return _levels[0];
    }
    return _levels[levelNumber - 1];
  }

  static int get totalLevels => _levels.length;

  static bool isLevelCompleted(int levelNumber, int currentScore) {
    final level = getLevel(levelNumber);
    return currentScore >= level.targetScore;
  }

  static GameLevel? getNextLevel(int currentLevel) {
    if (currentLevel < _levels.length) {
      return _levels[currentLevel];
    }
    return null;
  }

  static List<GameLevel> getAllLevels() => List.unmodifiable(_levels);
}

class LevelProgress {
  int currentLevel;
  int currentScore;
  int totalScore;
  int enemiesKilled;
  int powerUpsCollected;
  int combosAchieved;
  Duration timePlayed;
  bool isLevelCompleted;

  LevelProgress({
    this.currentLevel = 1,
    this.currentScore = 0,
    this.totalScore = 0,
    this.enemiesKilled = 0,
    this.powerUpsCollected = 0,
    this.combosAchieved = 0,
    this.timePlayed = Duration.zero,
    this.isLevelCompleted = false,
  });

  void resetForNewLevel() {
    currentScore = 0;
    enemiesKilled = 0;
    powerUpsCollected = 0;
    combosAchieved = 0;
    timePlayed = Duration.zero;
    isLevelCompleted = false;
  }

  void nextLevel() {
    currentLevel++;
    resetForNewLevel();
  }

  Map<String, dynamic> toJson() {
    return {
      'currentLevel': currentLevel,
      'currentScore': currentScore,
      'totalScore': totalScore,
      'enemiesKilled': enemiesKilled,
      'powerUpsCollected': powerUpsCollected,
      'combosAchieved': combosAchieved,
      'timePlayed': timePlayed.inSeconds,
      'isLevelCompleted': isLevelCompleted,
    };
  }

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    return LevelProgress(
      currentLevel: json['currentLevel'] ?? 1,
      currentScore: json['currentScore'] ?? 0,
      totalScore: json['totalScore'] ?? 0,
      enemiesKilled: json['enemiesKilled'] ?? 0,
      powerUpsCollected: json['powerUpsCollected'] ?? 0,
      combosAchieved: json['combosAchieved'] ?? 0,
      timePlayed: Duration(seconds: json['timePlayed'] ?? 0),
      isLevelCompleted: json['isLevelCompleted'] ?? false,
    );
  }
}
