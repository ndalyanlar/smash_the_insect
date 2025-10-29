import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key, required this.adUnitId}) : super(key: key);

  final String adUnitId;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  bool _isAdLoaded = false;
  BannerAd? _bannerAd;
  final AnalyticsService _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
          _analytics.logAdShown(
            adType: 'banner',
            adUnitId: widget.adUnitId,
          );
        },
        onAdFailedToLoad: (ad, error) {
          setState(() {
            _isAdLoaded = false;
          });
          _analytics.logAdLoadError(
            adType: 'banner',
            adUnitId: widget.adUnitId,
            errorMessage: error.message,
          );
          ad.dispose();
        },
        onAdOpened: (ad) {
          _analytics.logAdClicked(
            adType: 'banner',
            adUnitId: widget.adUnitId,
          );
        },
        onAdClosed: (ad) {},
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50, // AdMob standart banner yüksekliği
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: _isAdLoaded && _bannerAd != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: AdWidget(ad: _bannerAd!),
            )
          : Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.ads_click,
                      color: Colors.grey,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reklam Yükleniyor...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
