import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/shop_state.dart';

/// Profile sync for purchases/coins (so a reinstall or a second device sees
/// them). Stored privately at users/{uid}/private/shop.
abstract class ShopCloudSync {
  Future<ShopState?> fetch(String uid);
  Future<void> push(String uid, ShopState state);
}

/// Used when Firebase is disabled.
class NoopShopCloudSync implements ShopCloudSync {
  const NoopShopCloudSync();

  @override
  Future<ShopState?> fetch(String uid) async => null;

  @override
  Future<void> push(String uid, ShopState state) async {}
}

class FirestoreShopCloudSync implements ShopCloudSync {
  FirestoreShopCloudSync([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('shop');

  @override
  Future<ShopState?> fetch(String uid) async {
    final data = (await _doc(uid).get()).data();
    return data == null ? null : ShopState.fromJson(data);
  }

  @override
  Future<void> push(String uid, ShopState state) {
    return _doc(uid).set(
      <String, Object?>{
        ...state.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
