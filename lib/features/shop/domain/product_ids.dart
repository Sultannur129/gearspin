/// Store product identifiers. Create these as **non-consumable** in Google Play
/// Console and App Store Connect with exactly the same ids.
abstract final class ProductIds {
  static const String noAds = 'no_ads';
  static const String skinGoldenNova = 'skin_golden_nova';

  static const Set<String> all = {noAds, skinGoldenNova};
}
