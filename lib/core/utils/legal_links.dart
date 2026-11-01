import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Public pages published from the repository's `docs/` folder.
abstract final class LegalLinks {
  static String get _lang =>
      PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'tr' ? 'tr' : 'en';

  static Uri get privacyPolicy => Uri.parse('$legalBaseUrl/privacy-$_lang.html');
  static Uri get termsOfUse => Uri.parse('$legalBaseUrl/terms-$_lang.html');
  static Uri get accountDeletion => Uri.parse('$legalBaseUrl/delete-account.html');

  /// Returns false when no browser could be opened.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open $uri: $e');
      return false;
    }
  }
}
