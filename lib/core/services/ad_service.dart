import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show GlobalKey, NavigatorState;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../widgets/mock_ad_dialog.dart';

/// Ad Unit IDs for Android and iOS.
///
/// By default, these use official Google Test Ad Unit IDs so you can test ads
/// immediately without getting banned. Replace these with your production AdMob
/// unit IDs before publishing to Google Play and App Store.
abstract final class AdUnitIds {
  // Configurable via --dart-define or fallback to official Google Test IDs
  static const String _customAndroidBanner =
      String.fromEnvironment('ADMOB_ANDROID_BANNER', defaultValue: 'ca-app-pub-1849510147113404/9343253454');
  static const String _customAndroidInterstitial =
      String.fromEnvironment('ADMOB_ANDROID_INTERSTITIAL', defaultValue: 'ca-app-pub-1849510147113404/4246839447');
  static const String _customAndroidRewarded =
      String.fromEnvironment('ADMOB_ANDROID_REWARDED', defaultValue: 'ca-app-pub-1849510147113404/3919536384');

  static const String _customIosBanner =
      String.fromEnvironment('ADMOB_IOS_BANNER', defaultValue: 'ca-app-pub-1849510147113404/7520317153');
  static const String _customIosInterstitial =
      String.fromEnvironment('ADMOB_IOS_INTERSTITIAL', defaultValue: 'ca-app-pub-1849510147113404/3400661631');
  static const String _customIosRewarded =
      String.fromEnvironment('ADMOB_IOS_REWARDED', defaultValue: 'ca-app-pub-1849510147113404/7284066329');

  // Official Google sample ad units (always fill, safe to click).
  static const String _testAndroidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testAndroidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  /// Test ads in debug runs, real ads in release.
  /// Force with `--dart-define=ADMOB_USE_TEST_ADS=true|false`.
  static const bool useTestAds =
      bool.fromEnvironment('ADMOB_USE_TEST_ADS', defaultValue: kDebugMode);

  static String get banner => useTestAds
      ? (Platform.isAndroid ? _testAndroidBanner : _testIosBanner)
      : (Platform.isAndroid ? _customAndroidBanner : _customIosBanner);
  static String get interstitial => useTestAds
      ? (Platform.isAndroid ? _testAndroidInterstitial : _testIosInterstitial)
      : (Platform.isAndroid ? _customAndroidInterstitial : _customIosInterstitial);
  static String get rewarded => useTestAds
      ? (Platform.isAndroid ? _testAndroidRewarded : _testIosRewarded)
      : (Platform.isAndroid ? _customAndroidRewarded : _customIosRewarded);
}

/// Abstraction over AdMob so the game layer never depends on the SDK directly.
abstract class AdService {
  /// True when the user bought "No Ads" (banner + interstitial are skipped;
  /// rewarded ads stay available because they are opt-in).
  bool get adsRemoved;

  Future<void> showInterstitial();

  /// Resolves to `true` only if the user earned the reward.
  Future<bool> showRewarded();

  void dispose();
}

/// Production AdMob implementation using google_mobile_ads.
class AdMobService implements AdService {
  AdMobService({bool Function()? isAdsRemoved})
      : _isAdsRemoved = isAdsRemoved ?? (() => false) {
    _loadInterstitial();
    _loadRewarded();
  }

  final bool Function() _isAdsRemoved;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  @override
  bool get adsRemoved => _isAdsRemoved();

  void _loadInterstitial() {
    if (adsRemoved || _isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  void _loadRewarded() {
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: AdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _rewardedAd = null;
          _isRewardedLoading = false;
        },
      ),
    );
  }

  @override
  Future<void> showInterstitial() async {
    if (adsRemoved) return;

    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );

    await ad.show();
    return completer.future;
  }

  @override
  Future<bool> showRewarded() async {
    var ad = _rewardedAd;
    if (ad == null) {
      _loadRewarded();
      // Allow fallback if ad is not ready immediately in test
      await Future<void>.delayed(const Duration(milliseconds: 500));
      ad = _rewardedAd;
      if (ad == null) return false;
    }

    final completer = Completer<bool>();
    var rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (_, __) {
        rewardEarned = true;
      },
    );

    return completer.future;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

/// Development / testing / desktop stand-in.
class MockAdService implements AdService {
  MockAdService({
    bool Function()? isAdsRemoved,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _isAdsRemoved = isAdsRemoved ?? (() => false),
        _navigatorKey = navigatorKey;

  final bool Function() _isAdsRemoved;
  final GlobalKey<NavigatorState>? _navigatorKey;

  @override
  bool get adsRemoved => _isAdsRemoved();

  @override
  Future<void> showInterstitial() async {
    if (adsRemoved) return;
    final context = _navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      await showMockInterstitialDialog(context);
    }
  }

  @override
  Future<bool> showRewarded() async {
    final context = _navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      return await showMockRewardedDialog(context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return true;
  }

  @override
  void dispose() {}
}

/// Factory that chooses AdMobService on supported mobile platforms, or MockAdService
/// on test / desktop platforms.
AdService createDefaultAdService({
  bool Function()? isAdsRemoved,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    return AdMobService(isAdsRemoved: isAdsRemoved);
  }
  return MockAdService(isAdsRemoved: isAdsRemoved, navigatorKey: navigatorKey);
}
