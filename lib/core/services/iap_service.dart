import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

IapService createDefaultIapService() {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    return StoreIapService();
  }
  return MockIapService();
}

/// A product as shown in the shop (price is already localised by the store).
class IapProduct {
  const IapProduct({required this.id, required this.title, required this.price});

  final String id;
  final String title;
  final String price;
}

sealed class IapEvent {
  const IapEvent();
}

class IapPending extends IapEvent {
  const IapPending(this.productId);
  final String productId;
}

/// The store confirmed the entitlement (new purchase or restore).
class IapGranted extends IapEvent {
  const IapGranted(this.productId, {this.restored = false});
  final String productId;
  final bool restored;
}

class IapCancelled extends IapEvent {
  const IapCancelled(this.productId);
  final String productId;
}

class IapFailed extends IapEvent {
  const IapFailed(this.message, {this.productId});
  final String message;
  final String? productId;
}

/// Thin boundary over the in_app_purchase plugin so the shop logic can be
/// tested without a real store.
abstract class IapService {
  Stream<IapEvent> get events;

  Future<bool> isAvailable();
  Future<Map<String, IapProduct>> loadProducts(Set<String> ids);

  /// Starts the store purchase sheet; the outcome arrives on [events].
  Future<void> buy(String productId);

  /// Re-delivers past non-consumable purchases on [events] as restored.
  Future<void> restore();

  void dispose();
}

/// Google Play Billing (Android) and StoreKit (iOS).
class StoreIapService implements IapService {
  StoreIapService({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance {
    // Must be listened to from app start so pending/interrupted purchases
    // are delivered even if the shop screen is never opened.
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => _events.add(IapFailed('Store error: $e')),
    );
  }

  final InAppPurchase _iap;
  final _events = StreamController<IapEvent>.broadcast();
  final Map<String, ProductDetails> _details = {};
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSub;

  @override
  Stream<IapEvent> get events => _events.stream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<Map<String, IapProduct>> loadProducts(Set<String> ids) async {
    final response = await _iap.queryProductDetails(ids);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('IAP products not found in store: ${response.notFoundIDs}');
    }
    for (final d in response.productDetails) {
      _details[d.id] = d;
    }
    return {
      for (final d in response.productDetails)
        d.id: IapProduct(id: d.id, title: d.title, price: d.price),
    };
  }

  @override
  Future<void> buy(String productId) async {
    final details = _details[productId];
    if (details == null) {
      _events.add(IapFailed('This item is not available right now.', productId: productId));
      return;
    }
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) {
        _events.add(IapFailed('Could not start the purchase.', productId: productId));
      }
    } catch (e) {
      _events.add(IapFailed('Could not start the purchase.', productId: productId));
      debugPrint('IAP buy error: $e');
    }
  }

  @override
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _events.add(const IapFailed('Could not restore purchases.'));
      debugPrint('IAP restore error: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(IapPending(p.productID));
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // TODO(security): verify p.verificationData on your backend
          // (e.g. a Cloud Function calling Play Developer API / App Store
          // Server API) before trusting the entitlement.
          _events.add(
            IapGranted(p.productID, restored: p.status == PurchaseStatus.restored),
          );
        case PurchaseStatus.canceled:
          _events.add(IapCancelled(p.productID));
        case PurchaseStatus.error:
          _events.add(IapFailed(
            p.error?.message ?? 'Purchase failed.',
            productId: p.productID,
          ));
      }
      // The store refunds / re-delivers the purchase until it is completed.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  @override
  void dispose() {
    _purchaseSub.cancel();
    _events.close();
  }
}

/// Test / desktop stand-in. NEVER used on Android/iOS builds.
class MockIapService implements IapService {
  MockIapService({
    this.available = true,
    Set<String> entitlements = const {},
    this.failNextBuy = false,
  }) : _entitlements = {...entitlements};

  bool available;
  bool failNextBuy;
  final Set<String> _entitlements;
  final _events = StreamController<IapEvent>.broadcast();

  @override
  Stream<IapEvent> get events => _events.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, IapProduct>> loadProducts(Set<String> ids) async => {
        if (available)
          for (final id in ids)
            id: IapProduct(
              id: id,
              title: id,
              price: id == 'no_ads' ? r'$1.99' : r'$2.99',
            ),
      };

  @override
  Future<void> buy(String productId) async {
    if (!available) {
      _events.add(IapFailed('Store unavailable', productId: productId));
    } else if (failNextBuy) {
      failNextBuy = false;
      _events.add(IapFailed('Payment declined', productId: productId));
    } else {
      _entitlements.add(productId);
      _events.add(IapGranted(productId));
    }
  }

  @override
  Future<void> restore() async {
    for (final id in _entitlements) {
      _events.add(IapGranted(id, restored: true));
    }
  }

  @override
  void dispose() => _events.close();
}
