import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../levels/presentation/level_provider.dart';
import '../../shop/presentation/shop_provider.dart';
import '../data/account_service.dart';

/// "Delete account" flow required by Google Play: confirm -> delete cloud +
/// local data -> continue as a brand-new guest.
Future<void> confirmAndDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text(
        'This permanently deletes your profile, leaderboard entry, level '
        'progress, coins and skins from our servers and from this device. '
        'This cannot be undone.\n\n'
        'Purchases are managed by Google Play and are not refunded; you can '
        'restore them later with "Restore purchases".',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD94848)),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // Capture everything needed after the awaits.
  final account = context.read<AccountService>();
  final auth = context.read<AuthProvider>();
  final levels = context.read<LevelProvider>();
  final shop = context.read<ShopProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  String? message;
  try {
    await account.deleteAccount();
    await levels.load();
    shop.resetLocal();
    await auth.signInAsGuest();
    message = 'Your account and data were deleted.';
  } on AuthCancelledException {
    message = null; // user dismissed the Google prompt
  } on AccountDeletionException catch (e) {
    message = e.message;
  } finally {
    navigator.pop(); // progress dialog
  }

  if (message != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
  }
}
