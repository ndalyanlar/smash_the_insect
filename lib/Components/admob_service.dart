import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics_service.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Debug/Test Ad Unit IDs
  // Banner Ad Unit ID'leri - Farklı ekranlar için farklı ID'ler
  static String get bannerAdHomeScreenUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    } else {
      return Platform.isAndroid
          ? 'ca-app-pub-5838214729645023/9258583543' // Android Home Screen Banner
          : 'ca-app-pub-5838214729645023/3900361376'; // iOS Home Screen Banner
    }
  }

  static String get bannerAdScoreScreenUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    } else {
      return Platform.isAndroid
          ? 'ca-app-pub-5838214729645023/5614852009' // Android Score Screen Banner
          : 'ca-app-pub-5838214729645023/4632942823'; // iOS Score Screen Banner
    }
  }

  static String get bannerAdPauseDialogUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    } else {
      return Platform.isAndroid
          ? 'ca-app-pub-5838214729645023/2988688667' // Android Pause Dialog Banner
          : 'ca-app-pub-5838214729645023/1571665211'; // iOS Pause Dialog Banner
    }
  }

  static String get _interstitialAdUnitId {
    if (kDebugMode) {
      // Test ID'leri (Debug modunda)
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712' // Android Test Interstitial
          : 'ca-app-pub-3940256099942544/4411468910'; // iOS Test Interstitial
    } else {
      // Production ID'leri - Buraya kendi gerçek Ad Unit ID'lerinizi girin
      return Platform.isAndroid
          ? 'ca-app-pub-5838214729645023/8961116367' // Android Production Interstitial
          : 'ca-app-pub-5838214729645023/3558576443'; // iOS Production Interstitial
    }
  }

  static String get _rewardedAdUnitId {
    if (kDebugMode) {
      // Test ID'leri (Debug modunda)
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917' // Android Test Rewarded
          : 'ca-app-pub-3940256099942544/1712485313'; // iOS Test Rewarded
    } else {
      // Production ID'leri - Buraya kendi gerçek Ad Unit ID'lerinizi girin
      return Platform.isAndroid
          ? 'ca-app-pub-5838214729645023/5923889480' // Android Production Rewarded
          : 'ca-app-pub-5838214729645023/6823991894'; // iOS Production Rewarded
    }
  }

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isInterstitialAdLoaded = false;
  bool _isRewardedAdLoaded = false;

  // Analytics servisi
  final AnalyticsService _analytics = AnalyticsService();

  // Interstitial Ad
  bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  // Rewarded Ad
  bool get isRewardedAdLoaded => _isRewardedAdLoaded;

  // Interstitial Ad yükleme
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          _analytics.logAdShown(
            adType: 'interstitial',
            adUnitId: _interstitialAdUnitId,
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoaded = false;
          _analytics.logAdLoadError(
            adType: 'interstitial',
            adUnitId: _interstitialAdUnitId,
            errorMessage: error.message,
          );
        },
      ),
    );
  }

  // Interstitial Ad gösterimi
  void showInterstitialAd() {
    if (_interstitialAd != null && _isInterstitialAdLoaded) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          _analytics.logAdShown(
            adType: 'interstitial',
            adUnitId: _interstitialAdUnitId,
          );
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          // Yeni interstitial ad yükle
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
          _analytics.logAdLoadError(
            adType: 'interstitial',
            adUnitId: _interstitialAdUnitId,
            errorMessage: error.message,
          );
        },
      );
      _interstitialAd!.show();
    }
  }

  // Rewarded Ad yükleme
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          if (kDebugMode) {
            print('Rewarded ad loaded');
          }
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoaded = false;
          if (kDebugMode) {
            print('Rewarded ad failed to load: $error');
          }
        },
      ),
    );
  }

  // Rewarded Ad gösterimi
  void showRewardedAd({required Function(RewardItem) onRewarded}) {
    if (_rewardedAd != null && _isRewardedAdLoaded) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          if (kDebugMode) {
            print('Rewarded ad showed full screen content');
          }
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
          // Yeni rewarded ad yükle
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
          if (kDebugMode) {
            print('Rewarded ad failed to show: $error');
          }
        },
      );

      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        if (kDebugMode) {
          print('User earned reward: ${reward.amount} ${reward.type}');
        }
        onRewarded(reward);
      });
    }
  }

  // Tüm reklamları dispose et
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
    _isInterstitialAdLoaded = false;
    _isRewardedAdLoaded = false;
  }
}
