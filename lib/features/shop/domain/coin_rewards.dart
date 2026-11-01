/// Coins granted when a level is cleared.
abstract final class CoinRewards {
  static const int base = 10;
  static const int perStar = 10;

  /// First-ever clear of a level pays double (replays still pay, but less).
  static int forWin({required int stars, required bool firstClear}) {
    final clamped = stars.clamp(1, 3);
    final amount = base + perStar * clamped;
    return firstClear ? amount * 2 : amount;
  }
}
