// Geçici olarak Firebase Analytics devre dışı
// Firebase Analytics paketinde sorun var, daha sonra düzeltilecek

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Geçici observer - Firebase Analytics olmadan
  static dynamic get observer => null;

  // Oyun başlatma
  Future<void> logGameStart() async {
    print('Analytics: Game started');
  }

  // Oyun bitişi
  Future<void> logGameEnd({
    required int score,
    required double gameTime,
    required int level,
    required int enemiesKilled,
  }) async {
    print(
        'Analytics: Game ended - Score: $score, Time: $gameTime, Level: $level, Enemies: $enemiesKilled');
  }

  // Düşman öldürme
  Future<void> logEnemyKilled({
    required String enemyType,
    required int currentScore,
    required int level,
  }) async {
    print(
        'Analytics: Enemy killed - Type: $enemyType, Score: $currentScore, Level: $level');
  }

  // Level geçişi
  Future<void> logLevelUp({
    required int newLevel,
    required int score,
    required double gameTime,
  }) async {
    print(
        'Analytics: Level up - New Level: $newLevel, Score: $score, Time: $gameTime');
  }

  // Ana sayfa görüntüleme
  Future<void> logHomeScreenView() async {
    print('Analytics: Home screen viewed');
  }

  // Skor tablosu görüntüleme
  Future<void> logScoreboardView() async {
    print('Analytics: Scoreboard viewed');
  }

  // Oyun başlatma butonu tıklama
  Future<void> logStartGameButtonClick() async {
    print('Analytics: Start game button clicked');
  }

  // Skor tablosu butonu tıklama
  Future<void> logScoreboardButtonClick() async {
    print('Analytics: Scoreboard button clicked');
  }

  // Reklam gösterimi
  Future<void> logAdShown({
    required String adType,
    required String adUnitId,
  }) async {
    print('Analytics: Ad shown - Type: $adType, Unit ID: $adUnitId');
  }

  // Reklam tıklama
  Future<void> logAdClicked({
    required String adType,
    required String adUnitId,
  }) async {
    print('Analytics: Ad clicked - Type: $adType, Unit ID: $adUnitId');
  }

  // Reklam yükleme hatası
  Future<void> logAdLoadError({
    required String adType,
    required String adUnitId,
    required String errorMessage,
  }) async {
    print(
        'Analytics: Ad load error - Type: $adType, Unit ID: $adUnitId, Error: $errorMessage');
  }

  // Uygulama açılışı
  Future<void> logAppOpen() async {
    print('Analytics: App opened');
  }

  // Custom event
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    print('Analytics: Custom event - $eventName, Parameters: $parameters');
  }

  // Kullanıcı özellikleri
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    print('Analytics: User property set - $name: $value');
  }

  // Kullanıcı ID'si ayarlama
  Future<void> setUserId(String userId) async {
    print('Analytics: User ID set - $userId');
  }

  // ATT izin durumu
  Future<void> logATTPermissionStatus({
    required String status,
    String? advertisingId,
  }) async {
    await logCustomEvent(
      eventName: 'att_permission_status',
      parameters: {
        'status': status,
        'advertising_id': advertisingId ?? 'N/A',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // ATT hata durumu
  Future<void> logATTError({
    required String error,
  }) async {
    await logCustomEvent(
      eventName: 'att_error',
      parameters: {
        'error': error,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}
