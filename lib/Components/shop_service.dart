import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ShopService {
  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  // Pasta modelleri
  static const String _selectedCakeKey = 'selected_cake';
  static const String _purchasedCakesKey = 'purchased_cakes';

  // Düşman modelleri
  static const String _selectedEnemyKey = 'selected_enemy';
  static const String _purchasedEnemiesKey = 'purchased_enemies';

  // Skor (coin) anahtarı
  static const String _coinsKey = 'user_coins';

  // Varsayılan pasta modeli ID'si
  static const String defaultCakeId = 'cake_1';

  // Varsayılan düşman modeli ID'si
  static const String defaultEnemyId = 'enemy_1';

  /// Mevcut skor (coin) miktarını al
  Future<int> getCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_coinsKey) ?? 0;
  }

  /// Skor (coin) ekle
  Future<void> addCoins(int amount) async {
    final currentCoins = await getCoins();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coinsKey, currentCoins + amount);
  }

  /// Skor (coin) kullan
  Future<bool> spendCoins(int amount) async {
    final currentCoins = await getCoins();
    if (currentCoins >= amount) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_coinsKey, currentCoins - amount);
      return true;
    }
    return false;
  }

  /// Seçili pasta modelini al
  Future<String> getSelectedCake() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedCakeKey) ?? defaultCakeId;
  }

  /// Seçili pasta modelini kaydet
  Future<void> setSelectedCake(String cakeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCakeKey, cakeId);
  }

  /// Satın alınan pasta modellerini al
  Future<List<String>> getPurchasedCakes() async {
    final prefs = await SharedPreferences.getInstance();
    final purchased = prefs.getStringList(_purchasedCakesKey) ?? [];
    // Varsayılan pasta her zaman satın alınmış sayılır
    if (!purchased.contains(defaultCakeId)) {
      purchased.add(defaultCakeId);
    }
    return purchased;
  }

  /// Pasta modelini satın alınmış olarak işaretle
  Future<void> addPurchasedCake(String cakeId) async {
    final purchased = await getPurchasedCakes();
    if (!purchased.contains(cakeId)) {
      purchased.add(cakeId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_purchasedCakesKey, purchased);
    }
  }

  /// Pasta modeli satın alınmış mı kontrol et
  Future<bool> isCakePurchased(String cakeId) async {
    final purchased = await getPurchasedCakes();
    return purchased.contains(cakeId);
  }

  /// Seçili düşman modelini al
  Future<String> getSelectedEnemy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedEnemyKey) ?? defaultEnemyId;
  }

  /// Seçili düşman modelini kaydet
  Future<void> setSelectedEnemy(String enemyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedEnemyKey, enemyId);
  }

  /// Satın alınan düşman modellerini al
  Future<List<String>> getPurchasedEnemies() async {
    final prefs = await SharedPreferences.getInstance();
    final purchased = prefs.getStringList(_purchasedEnemiesKey) ?? [];
    // Varsayılan düşman her zaman satın alınmış sayılır
    if (!purchased.contains(defaultEnemyId)) {
      purchased.add(defaultEnemyId);
    }
    return purchased;
  }

  /// Düşman modelini satın alınmış olarak işaretle
  Future<void> addPurchasedEnemy(String enemyId) async {
    final purchased = await getPurchasedEnemies();
    if (!purchased.contains(enemyId)) {
      purchased.add(enemyId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_purchasedEnemiesKey, purchased);
    }
  }

  /// Düşman modeli satın alınmış mı kontrol et
  Future<bool> isEnemyPurchased(String enemyId) async {
    final purchased = await getPurchasedEnemies();
    return purchased.contains(enemyId);
  }

  /// Oyun bitişinde skoru coin'e çevir
  Future<void> convertScoreToCoins(int score) async {
    // Her 10 skor = 1 coin
    final coins = score ~/ 10;
    if (coins > 0) {
      await addCoins(coins);
      if (kDebugMode) {
        print('Skor coin\'e çevrildi: $score skor = $coins coin');
      }
    }
  }
}
