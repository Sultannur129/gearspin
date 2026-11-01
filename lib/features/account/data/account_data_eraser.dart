import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Removes everything we store about a player. Split in two so the cloud part
/// can be Firestore in production and a no-op offline / in tests.
abstract class AccountDataEraser {
  /// Deletes the player's public profile row and private data in the cloud.
  Future<void> eraseCloud(String uid);

  /// Wipes level progress, coins, skins and settings stored on this device.
  Future<void> eraseLocal();
}

class FirestoreAccountDataEraser implements AccountDataEraser {
  FirestoreAccountDataEraser([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<void> eraseCloud(String uid) async {
    final user = _db.collection('users').doc(uid);
    // Subcollections are not removed by deleting the parent document.
    await user.collection('private').doc('shop').delete();
    await user.delete();
  }

  @override
  Future<void> eraseLocal() => _clearPrefs();
}

/// Offline mode (Firebase disabled): there is nothing in the cloud.
class LocalAccountDataEraser implements AccountDataEraser {
  const LocalAccountDataEraser();

  @override
  Future<void> eraseCloud(String uid) async {}

  @override
  Future<void> eraseLocal() => _clearPrefs();
}

Future<void> _clearPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}
