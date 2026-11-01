import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_user.dart';

abstract class AuthRepository {
  AuthUser? get currentUser;

  /// Emits on every user change (sign-in, sign-out, anonymous -> Google link).
  Stream<AuthUser?> userChanges();

  Future<AuthUser> signInAnonymously();

  /// If the current user is an anonymous guest the Google account is *linked*
  /// to it, so level progress and leaderboard score keep the same uid.
  Future<AuthUser> signInWithGoogle();

  Future<void> signOut();

  /// Proves the user is still in control of a Google account (needed by
  /// Firebase before deleting it). No-op for guests. Throws
  /// [AuthCancelledException] if the user dismisses the account picker.
  Future<void> reauthenticate();

  /// Permanently deletes the signed-in Firebase user (not the app data).
  Future<void> deleteCurrentUser();
}

/// Offline guest identity used when Firebase is disabled. Google sign-in is
/// unavailable here.
class LocalAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> userChanges() => _controller.stream;

  @override
  Future<AuthUser> signInAnonymously() async {
    _user = const AuthUser(uid: 'local-guest', isAnonymous: true);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> signInWithGoogle() => throw const AuthUnavailableException(
        'Google sign-in needs Firebase. Start the app with --dart-define=USE_FIREBASE=true.',
      );

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> reauthenticate() async {}

  @override
  Future<void> deleteCurrentUser() => signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  /// iOS OAuth client of the `gearspin-game` Firebase project (public identifier,
  /// the same value as CLIENT_ID in GoogleService-Info.plist).
  static const String _iosClientId =
      '246340584752-e9e3acgncptb8qc3trin2ltseoi1epok.apps.googleusercontent.com';
  static const String _webClientId =
      '246340584752-k91tp0hnfq56nqgbpjlc0mgeeidli66k.apps.googleusercontent.com';

  FirebaseAuthRepository({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _google = googleSignIn ??
            GoogleSignIn(
              clientId: kIsWeb
                  ? _webClientId
                  : (defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null),
            );

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(uid: u.uid, isAnonymous: u.isAnonymous, displayName: u.displayName);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  // userChanges() (not authStateChanges()) so linking a credential is reported.
  @override
  Stream<AuthUser?> userChanges() => _auth.userChanges().map(_map);

  @override
  Future<AuthUser> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return _map(cred.user)!;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final current = _auth.currentUser;
      try {
        final result = (current != null && current.isAnonymous)
            ? await current.linkWithPopup(provider)
            : await _auth.signInWithPopup(provider);
        return _map(result.user)!;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user') {
          throw const AuthCancelledException();
        }
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          final result = await _auth.signInWithPopup(provider);
          return _map(result.user)!;
        }
        rethrow;
      }
    }

    final account = await _google.signIn();
    if (account == null) throw const AuthCancelledException();

    final tokens = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );

    final current = _auth.currentUser;
    try {
      final result = (current != null && current.isAnonymous)
          ? await current.linkWithCredential(credential)
          : await _auth.signInWithCredential(credential);
      return _map(result.user)!;
    } on FirebaseAuthException catch (e) {
      // This Google account already has its own player: switch to it.
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        final result = await _auth.signInWithCredential(e.credential ?? credential);
        return _map(result.user)!;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> reauthenticate() async {
    final current = _auth.currentUser;
    if (current == null || current.isAnonymous) return;

    if (kIsWeb) {
      await current.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }

    final account = await _google.signInSilently() ?? await _google.signIn();
    if (account == null) throw const AuthCancelledException();
    final tokens = await account.authentication;
    await current.reauthenticateWithCredential(
      GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      ),
    );
  }

  @override
  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
    try {
      await _google.disconnect();
    } catch (_) {
      // Not signed in with Google (guest) - nothing to revoke.
    }
  }
}
