import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/iap_service.dart';
import '../../auth/domain/auth_user.dart';
import '../data/shop_cloud_sync.dart';
import '../data/shop_repository.dart';
import '../domain/product_ids.dart';
import '../domain/shop_state.dart';
import '../domain/skin.dart';

enum SkinPurchase { success, notEnoughCoins, alreadyOwned, notForCoins }

/// Coins, owned/equipped skins and the "No Ads" entitlement.
class ShopProvider extends ChangeNotifier {
  ShopProvider({
    required ShopRepository repository,
    required IapService iap,
    ShopCloudSync cloud = const NoopShopCloudSync(),
  })  : _repository = repository,
        _iap = iap,
        _cloud = cloud;

  final ShopRepository _repository;
  final IapService _iap;
  final ShopCloudSync _cloud;

  ShopState _state = const ShopState();
  Map<String, IapProduct> _products = const {};
  bool _isLoaded = false;
  bool _storeAvailable = false;
  String? _purchasingId;
  String? _uid;
  Future<void>? _initFuture;
  StreamSubscription<IapEvent>? _iapSub;
  Timer? _restoreTimer;
  bool _restoreFoundSomething = false;

  final _messages = StreamController<String>.broadcast();

  /// One-shot user-facing messages (snackbars).
  Stream<String> get messages => _messages.stream;

  bool get isLoaded => _isLoaded;
  bool get storeAvailable => _storeAvailable;
  bool get isPurchasing => _purchasingId != null;
  String? get purchasingId => _purchasingId;

  int get coins => _state.coins;
  bool get noAds => _state.noAds;
  Skin get equippedSkin => skinById(_state.equippedSkin);
  bool owns(Skin skin) => _state.ownedSkins.contains(skin.id);
  bool isEquipped(Skin skin) => _state.equippedSkin == skin.id;

  /// Localised store price, or null until the store answered.
  String? priceOf(String productId) => _products[productId]?.price;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    _state = await _repository.load();
    _isLoaded = true;
    notifyListeners();

    // Listen before querying so no purchase event can be missed.
    _iapSub = _iap.events.listen(_onIapEvent);
    try {
      _storeAvailable = await _iap.isAvailable();
      if (_storeAvailable) _products = await _iap.loadProducts(ProductIds.all);
    } catch (e) {
      debugPrint('Store init failed: $e');
      _storeAvailable = false;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- profile

  /// Called by ChangeNotifierProxyProvider when auth changes (build phase:
  /// must not notify synchronously).
  void updateUser(AuthUser? user) {
    final uid = user?.uid;
    if (uid == _uid) return;
    _uid = uid;
    if (uid != null) scheduleMicrotask(() => _syncWithCloud(uid));
  }

  Future<void> _syncWithCloud(String uid) async {
    await init(); // never merge into a not-yet-loaded state
    try {
      final remote = await _cloud.fetch(uid);
      if (_uid != uid) return;
      final merged = remote == null ? _state : ShopState.merge(_state, remote);
      if (merged != _state) {
        _state = merged;
        await _repository.save(_state);
        notifyListeners();
      }
      if (remote == null || merged != remote) await _cloud.push(uid, merged);
    } catch (e) {
      debugPrint('Shop cloud sync failed: $e');
    }
  }

  /// Forgets coins / skins / No Ads in memory (after account deletion; the
  /// persisted copy was already wiped). A Play purchase can be restored.
  void resetLocal() {
    _state = const ShopState();
    notifyListeners();
  }

  // ----------------------------------------------------------------- coins

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    await _update(_state.copyWith(coins: _state.coins + amount));
  }

  Future<SkinPurchase> buySkinWithCoins(Skin skin) async {
    if (owns(skin)) return SkinPurchase.alreadyOwned;
    final price = skin.coinPrice;
    if (price == null) return SkinPurchase.notForCoins;
    if (_state.coins < price) {
      _say('Not enough coins - you need ${price - _state.coins} more.');
      return SkinPurchase.notEnoughCoins;
    }
    await _update(_state.copyWith(
      coins: _state.coins - price,
      ownedSkins: {..._state.ownedSkins, skin.id},
      equippedSkin: skin.id,
    ));
    _say('${skin.name} unlocked and equipped!');
    return SkinPurchase.success;
  }

  /// Equips an owned skin. Returns false if the skin is not owned.
  Future<bool> equip(Skin skin) async {
    if (!owns(skin)) return false;
    if (isEquipped(skin)) return true;
    await _update(_state.copyWith(equippedSkin: skin.id));
    return true;
  }

  // ------------------------------------------------------------------- IAP

  Future<void> buyNoAds() => buyProduct(ProductIds.noAds);

  Future<void> buyProduct(String productId) async {
    if (isPurchasing) return;
    if (!_storeAvailable) {
      _say('The store is not available right now.');
      return;
    }
    _purchasingId = productId;
    notifyListeners();
    await _iap.buy(productId);
  }

  Future<void> restorePurchases() async {
    if (!_storeAvailable) {
      _say('The store is not available right now.');
      return;
    }
    _say('Checking your purchases...');
    _restoreFoundSomething = false;
    _restoreTimer?.cancel();
    // The stores stay silent when there is nothing to restore, so answer the
    // user ourselves if no entitlement arrived in time.
    _restoreTimer = Timer(const Duration(seconds: 6), () {
      if (!_restoreFoundSomething) _say('No previous purchases found.');
    });
    await _iap.restore();
  }

  Future<void> _onIapEvent(IapEvent event) async {
    switch (event) {
      case IapPending():
        _say('Payment pending...');
      case IapGranted(:final productId, :final restored):
        _purchasingId = null;
        if (restored) _restoreFoundSomething = true;
        await _grant(productId, restored: restored);
      case IapCancelled():
        _purchasingId = null;
        notifyListeners();
      case IapFailed(:final message):
        _purchasingId = null;
        _restoreFoundSomething = true; // an error message replaces the timeout one
        notifyListeners();
        _say(message);
    }
  }

  Future<void> _grant(String productId, {required bool restored}) async {
    if (productId == ProductIds.noAds) {
      final already = _state.noAds;
      await _update(_state.copyWith(noAds: true));
      if (!already) _say(restored ? 'No Ads restored!' : 'Thank you! Ads removed.');
      return;
    }
    final skin = kSkins.where((s) => s.iapProductId == productId).firstOrNull;
    if (skin != null) {
      final already = owns(skin);
      await _update(_state.copyWith(
        ownedSkins: {..._state.ownedSkins, skin.id},
        equippedSkin: restored ? null : skin.id,
      ));
      if (!already) _say(restored ? '${skin.name} restored!' : '${skin.name} unlocked!');
      return;
    }
    debugPrint('Granted unknown product: $productId');
    notifyListeners();
  }

  // --------------------------------------------------------------- helpers

  void _say(String message) {
    if (!_messages.isClosed) _messages.add(message);
  }

  Future<void> _update(ShopState next) async {
    _state = next;
    notifyListeners();
    await _repository.save(next);
    final uid = _uid;
    if (uid == null) return;
    try {
      await _cloud.push(uid, next);
    } catch (e) {
      debugPrint('Shop cloud push failed: $e');
    }
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    _restoreTimer?.cancel();
    _messages.close();
    super.dispose();
  }
}
