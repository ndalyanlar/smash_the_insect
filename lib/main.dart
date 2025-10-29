import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lottie/lottie.dart';
import 'package:smash_the_insect/Components/admob_service.dart';
import 'package:smash_the_insect/firebase_options.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flame/game.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:io';

import 'game_controller.dart';

import 'Components/banner_ad_widget.dart';
import 'Components/analytics_service.dart';
import 'Components/settings_screen.dart';
import 'Components/settings_service.dart';
import 'Components/sound_manager.dart';
import 'Components/firestore_service.dart';
import 'Components/nickname_screen.dart';
import 'generated/locale_keys.g.dart';

// iOS için ATT izin kontrolü
Future<void> _requestTrackingPermission() async {
  final analytics = AnalyticsService();

  try {
    // iOS 14+ için tracking iznini kontrol et
    final trackingStatus =
        await AppTrackingTransparency.trackingAuthorizationStatus;

    // Eğer izin belirsizse (notDetermined), izin iste
    if (trackingStatus == TrackingStatus.notDetermined) {
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();

      // İzin durumunu analytics'e gönder
      await analytics.logATTPermissionStatus(
        status: status.toString(),
      );
    } else {
      // Mevcut izin durumunu analytics'e gönder
      await analytics.logATTPermissionStatus(
        status: trackingStatus.toString(),
      );
    }
  } catch (e) {
    // ATT hatasını analytics'e gönder
    await analytics.logATTError(error: e.toString());
  }

  // Reklam kimliğini al (loglama için)
  try {
    final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();

    // IDFA başarıyla alındı, analytics'e gönder
    await analytics.logCustomEvent(
      eventName: 'idfa_received',
      parameters: {
        'idfa': idfa,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  } catch (e) {
    // IDFA alma hatasını analytics'e gönder
    await analytics.logATTError(error: 'IDFA Error: ${e.toString()}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS için ATT (App Tracking Transparency) izni iste
  if (Platform.isIOS) {
    await _requestTrackingPermission();
  }

  // Easy Localization'ı başlat
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // AdMob'u başlat
  await MobileAds.instance.initialize();

  // Ayarları yükle
  await SettingsService().loadSettings();

  // SoundManager ayarlarını yükle
  await SoundManager.loadSettings();

  // Başlangıç dilini al
  final settingsService = SettingsService();
  final initialLocale = Locale(settingsService.language);

  runApp(EasyLocalization(
    supportedLocales: const [Locale('tr'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    startLocale: initialLocale,
    child: const MainApp(),
  ));
}

class MainApp extends StatelessWidget {
  const MainApp({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ants And Bugs',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorObservers: const [], // Analytics observer geçici olarak devre dışı
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
      ),
      home: const SplashWrapper(),
      routes: {
        '/game': (context) => const GameScreen(),
        '/scoreboard': (context) => const ScoreBoardScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

// Splash wrapper - ilk açılışta nickname kontrolü yapar
class SplashWrapper extends StatefulWidget {
  const SplashWrapper({Key? key}) : super(key: key);

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  bool _needsNickname = false;

  @override
  void initState() {
    super.initState();
    _checkNicknameRequirement();
  }

  Future<void> _checkNicknameRequirement() async {
    final isFirstLaunch = await _firestoreService.isFirstLaunch();
    final nickname = await _firestoreService.getNickname();

    setState(() {
      _needsNickname = isFirstLaunch || nickname == null;
      _isLoading = false;
    });
  }

  void _onNicknameSet() {
    setState(() {
      _needsNickname = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF87CEEB),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (_needsNickname) {
      return NicknameScreen(onNicknameSet: _onNicknameSet);
    }

    return const HomeScreen();
  }
}

// Ana ekran
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AnalyticsService _analytics = AnalyticsService();
  final FirestoreService _firestoreService = FirestoreService();
  String? _nickname;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ana sayfa için sadece portrait (dikey) modu kullan
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _analytics.logHomeScreenView();
    _analytics.logAppOpen();

    // Kullanıcı adını yükle
    _loadNickname();

    // Uygulama açıldığında arka plan müziğini başlat
    Future.delayed(const Duration(milliseconds: 300), () {
      SoundManager.startBackgroundMusic();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _loadNickname() async {
    final nickname = await _firestoreService.getNickname();
    if (mounted) {
      setState(() {
        _nickname = nickname;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama tekrar açıldığında müziği devam ettir
      SoundManager.resumeBackgroundMusic();
    } else if (state == AppLifecycleState.paused) {
      // Uygulama arka plana gittiğinde müziği duraklat
      SoundManager.pauseBackgroundMusic();
    }
  }

  final List<String> _lottieAnimations = [
    'assets/animations/ant.json',
    'assets/animations/spider.json',
    'assets/animations/cockroach.json',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 50.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Üst Bölüm - Flexible
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kullanıcı adı - Üst kısım
                    if (_nickname != null && _nickname!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _nickname!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Oyun başlığı - kompakt
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Lottie.asset(
                            _lottieAnimations.elementAt(
                              Random().nextInt(_lottieAnimations.length),
                            ),
                            width: 50,
                            height: 50,
                          ),
                          // const Icon(
                          //   Icons.bug_report,
                          //   size: 32,
                          //   color: Colors.white,
                          // ),
                          // const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              // mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  LocaleKeys.game_title.tr(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  LocaleKeys.game_subtitle.tr(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // const SizedBox(height: 6),

              // Alt Bölüm - Talimatlar ve Banner - Flexible
              Flexible(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Oyun talimatları - Kompakt
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            LocaleKeys.how_to_play.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _InstructionItem(
                                icon: Icons.touch_app,
                                text: LocaleKeys.instruction_tap.tr(),
                              ),
                              _InstructionItem(
                                icon: Icons.favorite,
                                text: LocaleKeys.instruction_health.tr(),
                              ),
                              _InstructionItem(
                                icon: Icons.star,
                                text: LocaleKeys.instruction_score.tr(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Yatay oynanabilir bilgisi - Daha belirgin
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.screen_rotation,
                                  size: 16,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    LocaleKeys.rotate_screen_info.tr(),
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                          color: Colors.black.withOpacity(0.3),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Power-up açıklamaları
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            LocaleKeys.powerups_title.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontSize: 14,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            // alignment: WrapAlignment.spaceBetween,
                            children: [
                              _PowerUpItem(
                                emoji: "❤️",
                                description: LocaleKeys.powerup_health.tr(),
                              ),
                              _PowerUpItem(
                                emoji: "⚡️",
                                description: LocaleKeys.powerup_speed.tr(),
                              ),
                              _PowerUpItem(
                                emoji: "🛡️",
                                description: LocaleKeys.powerup_shield.tr(),
                              ),
                              _PowerUpItem(
                                emoji: "✴️",
                                description: LocaleKeys.powerup_multihit.tr(),
                              ),
                              _PowerUpItem(
                                emoji: "❄️",
                                description: LocaleKeys.powerup_freeze.tr(),
                              ),
                              _PowerUpItem(
                                emoji: "💣",
                                description: LocaleKeys.powerup_bomb.tr(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Banner reklam
                  ],
                ),
              ),

              // const SizedBox(height: 8),

              Column(
                children: [
                  // Oyuna Başla butonu - Full width
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      onPressed: () {
                        _analytics.logStartGameButtonClick();
                        Navigator.pushReplacementNamed(context, '/game');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8B57),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            LocaleKeys.start_game.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Skor Tablosu ve Ayarlar - Altta yan yana
                  Row(
                    children: [
                      Expanded(
                        child: _buildMenuButton(
                          context: context,
                          icon: Icons.leaderboard,
                          label: LocaleKeys.scoreboard.tr(),
                          color: const Color(0xFF4682B4),
                          onPressed: () {
                            _analytics.logScoreboardButtonClick();
                            Navigator.pushNamed(context, '/scoreboard');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMenuButton(
                          context: context,
                          icon: Icons.settings,
                          label: LocaleKeys.settings.tr(),
                          color: const Color(0xFF8B4513),
                          onPressed: () {
                            _analytics.logCustomEvent(
                              eventName: 'settings_button_click',
                              parameters: {
                                'timestamp':
                                    DateTime.now().millisecondsSinceEpoch
                              },
                            );
                            Navigator.pushNamed(context, '/settings');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              BannerAdWidget(adUnitId: AdMobService.bannerAdHomeScreenUnitId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Oyun ekranı
class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController game;

  @override
  void initState() {
    super.initState();
    game = GameController();
    game.setContext(context);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return GameWidget(game: game);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }
}

// Score board ekranı
class ScoreBoardScreen extends StatefulWidget {
  const ScoreBoardScreen({Key? key}) : super(key: key);

  @override
  State<ScoreBoardScreen> createState() => _ScoreBoardScreenState();
}

class _ScoreBoardScreenState extends State<ScoreBoardScreen> {
  final AnalyticsService _analytics = AnalyticsService();
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _topScores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _analytics.logScoreboardView();
    _loadTopScores();
  }

  Future<void> _loadTopScores() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final scores = await _firestoreService.getTopScores();
      setState(() {
        _topScores = scores;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading top scores: $e');
      setState(() {
        _isLoading = false;
      });
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
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.leaderboard,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        LocaleKeys.scoreboard_title.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          LocaleKeys.highest_scores.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _isLoading
                            ? const Expanded(
                                child: Center(
                                    child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white))))
                            : _topScores.isEmpty
                                ? Expanded(
                                    child: Center(
                                        child: Text('Henüz skor yok',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 16))))
                                : Expanded(
                                    child: ListView.builder(
                                      itemCount: _topScores.length,
                                      itemBuilder: (context, index) {
                                        final score = _topScores[index];
                                        final scoreValue =
                                            score['high_score'] as int;
                                        final nickname =
                                            score['nickname'] as String;
                                        final level =
                                            score['level'] as int? ?? 1;
                                        final gameTime =
                                            score['game_time'] as double? ??
                                                0.0;
                                        final isTopThree = index < 3;

                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.05),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                // Sıralama numarası
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: isTopThree
                                                        ? const Color(
                                                            0xFF6366F1)
                                                        : const Color(
                                                            0xFFF3F4F6),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: TextStyle(
                                                        color: isTopThree
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF6B7280),
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Kullanıcı adı
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              nickname,
                                                              style:
                                                                  const TextStyle(
                                                                color: Color(
                                                                    0xFF111827),
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          if (isTopThree)
                                                            Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 6),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                        0xFFFFB020)
                                                                    .withOpacity(
                                                                        0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                              child: const Icon(
                                                                Icons.star,
                                                                color: Color(
                                                                    0xFFFFB020),
                                                                size: 12,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          _buildMiniStat(
                                                            icon: Icons.star,
                                                            value: scoreValue
                                                                .toString(),
                                                            color: const Color(
                                                                0xFFFFB020),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          _buildMiniStat(
                                                            icon: Icons
                                                                .trending_up,
                                                            value: 'Lv.$level',
                                                            color: const Color(
                                                                0xFF8B5CF6),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          _buildMiniStat(
                                                            icon: Icons.timer,
                                                            value:
                                                                '${gameTime.toStringAsFixed(1)}s',
                                                            color: const Color(
                                                                0xFF10B981),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Banner reklam
                BannerAdWidget(
                    adUnitId: AdMobService.bannerAdScoreScreenUnitId),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B57),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back, size: 24),
                        const SizedBox(width: 8),
                        Text(LocaleKeys.back_to_home_settings.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
          ),
          child: Icon(icon, size: 24, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: 10, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _PowerUpItem extends StatelessWidget {
  final String emoji;
  final String description;

  const _PowerUpItem({
    required this.emoji,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
