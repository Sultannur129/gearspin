import 'package:flutter_test/flutter_test.dart';
import 'package:gear_spin/features/account/data/account_data_eraser.dart';
import 'package:gear_spin/features/account/data/account_service.dart';
import 'package:gear_spin/features/auth/data/auth_repository.dart';

class _FakeEraser implements AccountDataEraser {
  final calls = <String>[];
  bool failCloud = false;

  @override
  Future<void> eraseCloud(String uid) async {
    if (failCloud) throw Exception('offline');
    calls.add('cloud:$uid');
  }

  @override
  Future<void> eraseLocal() async => calls.add('local');
}

void main() {
  test('deleteAccount erases cloud, signs the user out, then wipes local data', () async {
    final auth = LocalAuthRepository();
    await auth.signInAnonymously();
    final eraser = _FakeEraser();

    await AccountService(auth: auth, eraser: eraser).deleteAccount();

    expect(eraser.calls, ['cloud:local-guest', 'local']);
    expect(auth.currentUser, isNull);
  });

  test('a failing cloud delete keeps the local data and the user', () async {
    final auth = LocalAuthRepository();
    await auth.signInAnonymously();
    final eraser = _FakeEraser()..failCloud = true;

    await expectLater(
      AccountService(auth: auth, eraser: eraser).deleteAccount(),
      throwsA(isA<AccountDeletionException>()),
    );

    expect(eraser.calls, isEmpty);
    expect(auth.currentUser, isNotNull);
  });

  test('deleteAccount without a signed-in user does nothing', () async {
    final eraser = _FakeEraser();
    await AccountService(auth: LocalAuthRepository(), eraser: eraser).deleteAccount();
    expect(eraser.calls, isEmpty);
  });
}
