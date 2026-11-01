import 'package:flutter_test/flutter_test.dart';
import 'package:gear_spin/core/services/iap_service.dart';
import 'package:gear_spin/features/auth/domain/auth_user.dart';
import 'package:gear_spin/features/shop/data/shop_cloud_sync.dart';
import 'package:gear_spin/features/shop/data/shop_repository.dart';
import 'package:gear_spin/features/shop/domain/coin_rewards.dart';
import 'package:gear_spin/features/shop/domain/product_ids.dart';
import 'package:gear_spin/features/shop/domain/shop_state.dart';
import 'package:gear_spin/features/shop/domain/skin.dart';
import 'package:gear_spin/features/shop/presentation/shop_provider.dart';

class _MemoryShopRepository implements ShopRepository {
  ShopState state = const ShopState();

  @override
  Future<ShopState> load() async => state;

  @override
  Future<void> save(ShopState newState) async => state = newState;
}

class _MemoryShopCloudSync implements ShopCloudSync {
  final Map<String, ShopState> cloud = {};

  @override
  Future<ShopState?> fetch(String uid) async => cloud[uid];

  @override
  Future<void> push(String uid, ShopState state) async => cloud[uid] = state;
}

void main() {
  group('ShopState & CoinRewards', () {
    test('CoinRewards computes base and first clear bonus', () {
      expect(CoinRewards.forWin(stars: 1, firstClear: false), 20);
      expect(CoinRewards.forWin(stars: 3, firstClear: false), 40);
      expect(CoinRewards.forWin(stars: 3, firstClear: true), 80);
    });

    test('ShopState json serialization roundtrip and error resilience', () {
      const original = ShopState(
        coins: 450,
        ownedSkins: {'default', 'comet'},
        equippedSkin: 'comet',
        noAds: true,
      );
      final json = original.toJson();
      final restored = ShopState.fromJson(json);
      expect(restored, original);

      // Faulty json fallback
      final fallback = ShopState.fromJson({'coins': -50, 'owned': null, 'equipped': 'invalid'});
      expect(fallback.coins, 0);
      expect(fallback.ownedSkins, {'default'});
      expect(fallback.equippedSkin, 'default');
      expect(fallback.noAds, isFalse);
    });

    test('ShopState merge preserves entitlements and max coins', () {
      const local = ShopState(
        coins: 100,
        ownedSkins: {'default', 'comet'},
        equippedSkin: 'comet',
        noAds: false,
      );
      const remote = ShopState(
        coins: 250,
        ownedSkins: {'default', 'ion'},
        equippedSkin: 'ion',
        noAds: true,
      );
      final merged = ShopState.merge(local, remote);
      expect(merged.coins, 250);
      expect(merged.ownedSkins, {'default', 'comet', 'ion'});
      expect(merged.equippedSkin, 'comet'); // keeps local equipped skin
      expect(merged.noAds, isTrue);
    });

    test('Skin catalog fallback', () {
      expect(skinById('unknown_xyz').id, kDefaultSkinId);
      expect(skinById('comet').name, 'Comet');
    });
  });

  group('ShopProvider', () {
    late _MemoryShopRepository repo;
    late _MemoryShopCloudSync cloud;
    late MockIapService iap;
    late ShopProvider provider;

    setUp(() async {
      repo = _MemoryShopRepository();
      cloud = _MemoryShopCloudSync();
      iap = MockIapService();
      provider = ShopProvider(repository: repo, iap: iap, cloud: cloud);
      await provider.init();
    });

    tearDown(() => provider.dispose());

    test('starts with initial state and default classic skin', () {
      expect(provider.coins, 0);
      expect(provider.noAds, isFalse);
      expect(provider.equippedSkin.id, kDefaultSkinId);
      expect(provider.owns(kDefaultSkin), isTrue);
    });

    test('addCoins increases coins and persists to repository', () async {
      await provider.addCoins(250);
      expect(provider.coins, 250);
      expect(repo.state.coins, 250);
    });

    test('coin purchase flow: insufficient coins, success, and equip', () async {
      final comet = skinById('comet');
      // 0 coins: should fail
      final res1 = await provider.buySkinWithCoins(comet);
      expect(res1, SkinPurchase.notEnoughCoins);
      expect(provider.owns(comet), isFalse);

      // Add enough coins
      await provider.addCoins(300);
      final res2 = await provider.buySkinWithCoins(comet);
      expect(res2, SkinPurchase.success);
      expect(provider.coins, 100);
      expect(provider.owns(comet), isTrue);
      expect(provider.isEquipped(comet), isTrue);
      expect(repo.state.equippedSkin, 'comet');

      // Attempting to buy again returns alreadyOwned
      final res3 = await provider.buySkinWithCoins(comet);
      expect(res3, SkinPurchase.alreadyOwned);

      // Equipping classic skin
      final equipped = await provider.equip(kDefaultSkin);
      expect(equipped, isTrue);
      expect(provider.isEquipped(kDefaultSkin), isTrue);

      // Cannot equip unowned skin
      final ion = skinById('ion');
      expect(await provider.equip(ion), isFalse);
    });

    test('buyNoAds IAP marks noAds as true and persists', () async {
      expect(provider.noAds, isFalse);
      await provider.buyNoAds();
      await pumpEventQueue();

      expect(provider.noAds, isTrue);
      expect(repo.state.noAds, isTrue);
    });

    test('buy premium skin via IAP grants and equips skin', () async {
      final goldenNova = skinById('golden_nova');
      expect(provider.owns(goldenNova), isFalse);

      await provider.buyProduct(ProductIds.skinGoldenNova);
      await pumpEventQueue();

      expect(provider.owns(goldenNova), isTrue);
      expect(provider.isEquipped(goldenNova), isTrue);
    });

    test('restore purchases re-grants entitlements', () async {
      iap = MockIapService(entitlements: {ProductIds.noAds, ProductIds.skinGoldenNova});
      provider.dispose();
      provider = ShopProvider(repository: repo, iap: iap, cloud: cloud);
      await provider.init();

      expect(provider.noAds, isFalse);
      await provider.restorePurchases();
      await pumpEventQueue();

      expect(provider.noAds, isTrue);
      expect(provider.owns(skinById('golden_nova')), isTrue);
    });

    test('cloud sync merges remote purchases when user logs in', () async {
      cloud.cloud['user_1'] = const ShopState(
        coins: 500,
        ownedSkins: {'default', 'nebula'},
        equippedSkin: 'nebula',
        noAds: true,
      );

      provider.updateUser(const AuthUser(uid: 'user_1', isAnonymous: false));
      await pumpEventQueue();

      expect(provider.coins, 500);
      expect(provider.noAds, isTrue);
      expect(provider.owns(skinById('nebula')), isTrue);
    });
  });
}
