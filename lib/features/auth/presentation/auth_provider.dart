import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

/// Guarantees the app always has an identity: a guest (anonymous) account is
/// created automatically, Google can be linked later.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;
  StreamSubscription<AuthUser?>? _sub;

  AuthUser? _user;
  bool _busy = false;
  String? _error;

  AuthUser? get user => _user;
  bool get isBusy => _busy;
  String? get error => _error;
  bool get isSignedIn => _user != null;
  bool get isGuest => _user?.isAnonymous ?? true;

  Future<void> init() async {
    _user = _repository.currentUser;
    _sub = _repository.userChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
    if (_user == null) await _run(_repository.signInAnonymously);
    notifyListeners();
  }

  Future<void> signInWithGoogle() => _run(_repository.signInWithGoogle);

  /// Starts a fresh guest identity (used right after an account was deleted).
  Future<void> signInAsGuest() => _run(_repository.signInAnonymously);

  /// Signs out and immediately falls back to a fresh guest account.
  Future<void> signOut() async {
    await _run(() async {
      await _repository.signOut();
      return _repository.signInAnonymously();
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _run(Future<AuthUser> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await action();
    } on AuthCancelledException {
      // User closed the account picker - nothing to report.
    } on AuthUnavailableException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Sign-in failed. Please try again.';
      debugPrint('Auth error: $e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
