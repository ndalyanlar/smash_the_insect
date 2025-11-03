import 'package:flutter/material.dart';
import 'package:smash_the_insect/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'shop_service.dart';
import 'analytics_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({Key? key}) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ShopService _shopService = ShopService();
  final AnalyticsService _analytics = AnalyticsService();
  
  int _coins = 0;
  String _selectedCake = '';
  String _selectedEnemy = '';
  List<String> _purchasedCakes = [];
  List<String> _purchasedEnemies = [];

  @override
  void initState() {
    super.initState();
    _analytics.logCustomEvent(
      eventName: 'shop_screen_view',
      parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    final coins = await _shopService.getCoins();
    final selectedCake = await _shopService.getSelectedCake();
    final selectedEnemy = await _shopService.getSelectedEnemy();
    final purchasedCakes = await _shopService.getPurchasedCakes();
    final purchasedEnemies = await _shopService.getPurchasedEnemies();

    setState(() {
      _coins = coins;
      _selectedCake = selectedCake;
      _selectedEnemy = selectedEnemy;
      _purchasedCakes = purchasedCakes;
      _purchasedEnemies = purchasedEnemies;
    });
  }

  Future<void> _purchaseCake(String cakeId, int price) async {
    if (_coins >= price) {
      final success = await _shopService.spendCoins(price);
      if (success) {
        await _shopService.addPurchasedCake(cakeId);
        await _shopService.setSelectedCake(cakeId);
        
        _analytics.logCustomEvent(
          eventName: 'cake_purchased',
          parameters: {
            'cake_id': cakeId,
            'price': price,
            'coins_remaining': _coins - price,
          },
        );
        
        await _loadShopData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocaleKeys.shop_purchase_success.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocaleKeys.shop_not_enough_coins.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectCake(String cakeId) async {
    if (await _shopService.isCakePurchased(cakeId)) {
      await _shopService.setSelectedCake(cakeId);
      
      _analytics.logCustomEvent(
        eventName: 'cake_selected',
        parameters: {'cake_id': cakeId},
      );
      
      await _loadShopData();
    }
  }

  Future<void> _purchaseEnemy(String enemyId, int price) async {
    if (_coins >= price) {
      final success = await _shopService.spendCoins(price);
      if (success) {
        await _shopService.addPurchasedEnemy(enemyId);
        await _shopService.setSelectedEnemy(enemyId);
        
        _analytics.logCustomEvent(
          eventName: 'enemy_purchased',
          parameters: {
            'enemy_id': enemyId,
            'price': price,
            'coins_remaining': _coins - price,
          },
        );
        
        await _loadShopData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocaleKeys.shop_purchase_success.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocaleKeys.shop_not_enough_coins.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectEnemy(String enemyId) async {
    if (await _shopService.isEnemyPurchased(enemyId)) {
      await _shopService.setSelectedEnemy(enemyId);
      
      _analytics.logCustomEvent(
        eventName: 'enemy_selected',
        parameters: {'enemy_id': enemyId},
      );
      
      await _loadShopData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2D3436),
              Color(0xFF636E72),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Başlık ve coin gösterimi
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          LocaleKeys.shop_title.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            '$_coins',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Coin bilgi açıklaması
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        LocaleKeys.shop_coin_info.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // İçerik
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pasta modelleri
                      Text(
                        LocaleKeys.shop_cakes.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCakeGrid(),
                      
                      const SizedBox(height: 32),
                      
                      // Düşman modelleri
                      Text(
                        LocaleKeys.shop_enemies.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildEnemyGrid(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCakeGrid() {
    final cakes = [
      _CakeItem(
        id: 'cake_1',
        name: LocaleKeys.shop_cake_classic.tr(),
        price: 0,
        color: const Color(0xFF8B4513),
        isDefault: true,
      ),
      _CakeItem(
        id: 'cake_2',
        name: LocaleKeys.shop_cake_chocolate.tr(),
        price: 100,
        color: const Color(0xFF3E2723),
      ),
      _CakeItem(
        id: 'cake_3',
        name: LocaleKeys.shop_cake_strawberry.tr(),
        price: 150,
        color: const Color(0xFFFF6B6B),
      ),
      _CakeItem(
        id: 'cake_4',
        name: LocaleKeys.shop_cake_vanilla.tr(),
        price: 200,
        color: const Color(0xFFFFF8DC),
      ),
      _CakeItem(
        id: 'cake_5',
        name: LocaleKeys.shop_cake_rainbow.tr(),
        price: 300,
        color: Colors.purple,
      ),
      _CakeItem(
        id: 'cake_6',
        name: LocaleKeys.shop_cake_golden.tr(),
        price: 500,
        color: const Color(0xFFFFD700),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: cakes.length,
      itemBuilder: (context, index) {
        final cake = cakes[index];
        final isPurchased = _purchasedCakes.contains(cake.id);
        final isSelected = _selectedCake == cake.id;
        
        return _buildCakeCard(cake, isPurchased, isSelected);
      },
    );
  }

  Widget _buildCakeCard(_CakeItem cake, bool isPurchased, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (isPurchased) {
          _selectCake(cake.id);
        } else {
          _purchaseCake(cake.id, cake.price);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Colors.amber 
                : Colors.white.withOpacity(0.3),
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pasta görseli (renkli daire)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cake.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: cake.color.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '🍰',
                  style: TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              cake.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!isPurchased)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${cake.price}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      LocaleKeys.shop_selected.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  LocaleKeys.shop_tap_to_select.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnemyGrid() {
    final enemies = [
      _EnemyItem(
        id: 'enemy_1',
        name: LocaleKeys.shop_enemy_ant.tr(),
        price: 0,
        color: const Color(0xFF8B4513),
        isDefault: true,
      ),
      _EnemyItem(
        id: 'enemy_2',
        name: LocaleKeys.shop_enemy_spider.tr(),
        price: 100,
        color: const Color(0xFF000000),
      ),
      _EnemyItem(
        id: 'enemy_3',
        name: LocaleKeys.shop_enemy_cockroach.tr(),
        price: 150,
        color: const Color(0xFF654321),
      ),
      _EnemyItem(
        id: 'enemy_4',
        name: LocaleKeys.shop_enemy_beetle.tr(),
        price: 200,
        color: const Color(0xFF2E7D32),
      ),
      _EnemyItem(
        id: 'enemy_5',
        name: LocaleKeys.shop_enemy_wasp.tr(),
        price: 250,
        color: const Color(0xFFFFEB3B),
      ),
      _EnemyItem(
        id: 'enemy_6',
        name: LocaleKeys.shop_enemy_scorpion.tr(),
        price: 400,
        color: const Color(0xFFE91E63),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: enemies.length,
      itemBuilder: (context, index) {
        final enemy = enemies[index];
        final isPurchased = _purchasedEnemies.contains(enemy.id);
        final isSelected = _selectedEnemy == enemy.id;
        
        return _buildEnemyCard(enemy, isPurchased, isSelected);
      },
    );
  }

  Widget _buildEnemyCard(_EnemyItem enemy, bool isPurchased, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (isPurchased) {
          _selectEnemy(enemy.id);
        } else {
          _purchaseEnemy(enemy.id, enemy.price);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Colors.amber 
                : Colors.white.withOpacity(0.3),
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Düşman görseli (renkli daire)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: enemy.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: enemy.color.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '🦗',
                  style: TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              enemy.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!isPurchased)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${enemy.price}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      LocaleKeys.shop_selected.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  LocaleKeys.shop_tap_to_select.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CakeItem {
  final String id;
  final String name;
  final int price;
  final Color color;
  final bool isDefault;

  _CakeItem({
    required this.id,
    required this.name,
    required this.price,
    required this.color,
    this.isDefault = false,
  });
}

class _EnemyItem {
  final String id;
  final String name;
  final int price;
  final Color color;
  final bool isDefault;

  _EnemyItem({
    required this.id,
    required this.name,
    required this.price,
    required this.color,
    this.isDefault = false,
  });
}

