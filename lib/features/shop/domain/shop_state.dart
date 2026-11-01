import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'skin.dart';

/// Everything the player owns. Persisted locally and synced to the profile.
@immutable
class ShopState {
  const ShopState({
    this.coins = 0,
    this.ownedSkins = const {kDefaultSkinId},
    this.equippedSkin = kDefaultSkinId,
    this.noAds = false,
  });

  final int coins;
  final Set<String> ownedSkins;
  final String equippedSkin;
  final bool noAds;

  ShopState copyWith({
    int? coins,
    Set<String>? ownedSkins,
    String? equippedSkin,
    bool? noAds,
  }) =>
      ShopState(
        coins: coins ?? this.coins,
        ownedSkins: ownedSkins ?? this.ownedSkins,
        equippedSkin: equippedSkin ?? this.equippedSkin,
        noAds: noAds ?? this.noAds,
      );

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'owned': ownedSkins.toList()..sort(),
        'equipped': equippedSkin,
        'noAds': noAds,
      };

  /// Defensive: tolerates missing / malformed fields.
  factory ShopState.fromJson(Map<String, dynamic> json) {
    final owned = <String>{
      kDefaultSkinId,
      ...((json['owned'] as List?)?.whereType<String>() ?? const <String>[]),
    };
    final equipped = json['equipped'] as String?;
    return ShopState(
      coins: math.max(0, (json['coins'] as num?)?.toInt() ?? 0),
      ownedSkins: owned,
      equippedSkin: equipped != null && owned.contains(equipped) ? equipped : kDefaultSkinId,
      noAds: json['noAds'] == true,
    );
  }

  /// Combines the device state ([local]) with the cloud profile ([remote]).
  /// Entitlements are never lost: No Ads and skins are unions, coins take the
  /// larger balance, and the device's equipped skin wins.
  static ShopState merge(ShopState local, ShopState remote) {
    final owned = {...local.ownedSkins, ...remote.ownedSkins};
    return ShopState(
      coins: math.max(local.coins, remote.coins),
      ownedSkins: owned,
      equippedSkin:
          owned.contains(local.equippedSkin) ? local.equippedSkin : kDefaultSkinId,
      noAds: local.noAds || remote.noAds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShopState &&
      other.coins == coins &&
      other.noAds == noAds &&
      other.equippedSkin == equippedSkin &&
      setEquals(other.ownedSkins, ownedSkins);

  @override
  int get hashCode => Object.hash(coins, noAds, equippedSkin, Object.hashAllUnordered(ownedSkins));
}
