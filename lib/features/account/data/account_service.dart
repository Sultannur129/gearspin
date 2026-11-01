import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_user.dart';
import 'account_data_eraser.dart';

/// Thrown with a message that is safe to show to the player.
class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Permanently deletes a player: cloud data, Firebase user, local data.
///
/// Order matters: the user must still be signed in while their Firestore data
/// is removed (security rules), and the local wipe happens last so a failure
/// half-way never leaves the player without their local progress.
class AccountService {
  AccountService({required AuthRepository auth, required AccountDataEraser eraser})
      : _auth = auth,
        _eraser = eraser;

  final AuthRepository _auth;
  final AccountDataEraser _eraser;

  /// Throws [AuthCancelledException] if the user dismisses the Google prompt
  /// and [AccountDeletionException] for anything else that goes wrong.
  Future<void> deleteAccount() async {
    final AuthUser? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _auth.reauthenticate();
      await _eraser.eraseCloud(user.uid);
      try {
        await _auth.deleteCurrentUser();
      } on FirebaseAuthException catch (e) {
        // Guests cannot re-authenticate; their data is already gone, so just
        // sign out - the orphaned anonymous record holds no personal data.
        if (e.code == 'requires-recent-login' && user.isAnonymous) {
          await _auth.signOut();
        } else {
          rethrow;
        }
      }
      await _eraser.eraseLocal();
    } on AuthCancelledException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(
        e.code == 'requires-recent-login'
            ? 'Please sign in again and retry.'
            : 'Could not delete the account (${e.code}). Please try again.',
      );
    } catch (_) {
      throw const AccountDeletionException(
        'Could not delete the account. Check your connection and try again.',
      );
    }
  }
}
