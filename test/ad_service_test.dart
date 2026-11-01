import 'package:flutter_test/flutter_test.dart';
import 'package:gear_spin/core/services/ad_service.dart';

void main() {
  group('AdUnitIds', () {
    test('provides valid banner, interstitial and rewarded ids', () {
      expect(AdUnitIds.banner, isNotEmpty);
      expect(AdUnitIds.interstitial, isNotEmpty);
      expect(AdUnitIds.rewarded, isNotEmpty);
      expect(AdUnitIds.banner, startsWith('ca-app-pub-'));
      expect(AdUnitIds.interstitial, startsWith('ca-app-pub-'));
      expect(AdUnitIds.rewarded, startsWith('ca-app-pub-'));
    });
  });

  group('MockAdService', () {
    test('reflects adsRemoved state from closure', () {
      var removed = false;
      final adService = MockAdService(isAdsRemoved: () => removed);

      expect(adService.adsRemoved, isFalse);

      removed = true;
      expect(adService.adsRemoved, isTrue);
    });

    test('showRewarded resolves with true in mock mode', () async {
      final adService = MockAdService();
      final earned = await adService.showRewarded();
      expect(earned, isTrue);
    });

    test('showInterstitial completes without throwing', () async {
      final adService = MockAdService();
      await expectLater(adService.showInterstitial(), completes);
    });

    test('createDefaultAdService instantiates appropriate service on desktop/test', () {
      final adService = createDefaultAdService();
      expect(adService, isA<MockAdService>());
    });
  });
}
