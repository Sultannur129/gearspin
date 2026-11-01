import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/level_progress.dart';

/// Storage boundary. The UI/provider only knows this interface, so a
/// Firestore-backed implementation (or a local+cloud merge) can be added
/// later without touching presentation code.
abstract class ProgressRepository {
  Future<Map<int, LevelProgress>> load();
  Future<void> save(Map<int, LevelProgress> progress);
}

/// Offline-first local cache (SharedPreferences, one JSON blob).
class LocalProgressRepository implements ProgressRepository {
  static const _key = 'level_progress_v1';

  @override
  Future<Map<int, LevelProgress>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          int.parse(e.key): LevelProgress.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      // Corrupt data must never brick the game; start fresh.
      return {};
    }
  }

  @override
  Future<void> save(Map<int, LevelProgress> progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({for (final e in progress.entries) '${e.key}': e.value.toJson()}),
    );
  }
}
