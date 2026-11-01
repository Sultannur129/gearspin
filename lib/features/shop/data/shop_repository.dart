import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/shop_state.dart';

abstract class ShopRepository {
  Future<ShopState> load();
  Future<void> save(ShopState state);
}

/// Local persistence (SharedPreferences). This is what makes "No Ads" survive
/// app restarts even when offline.
class LocalShopRepository implements ShopRepository {
  static const _key = 'shop_state_v1';

  @override
  Future<ShopState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const ShopState();
    try {
      return ShopState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt data must not brick the shop.
      return const ShopState();
    }
  }

  @override
  Future<void> save(ShopState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }
}
