// history_service.dart — con soporte de progreso de reproducción
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/anime_episode.dart';

class HistoryService {
  static const _historyKey  = 'watch_history';
  static const _progressKey = 'watch_progress'; // episodeLink → 0.0-1.0

  // ── Historial ─────────────────────────────────────────────────────────────
  Future<List<AnimeEpisode>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_historyKey) ?? [];
    return raw
        .map((s) => AnimeEpisode.fromJson(jsonDecode(s)))
        .toList()
        .reversed
        .toList();
  }

  Future<void> addToHistory(AnimeEpisode episode) async {
    final prefs   = await SharedPreferences.getInstance();
    final raw     = prefs.getStringList(_historyKey) ?? [];
    final updated = raw.where((s) {
      final ep = AnimeEpisode.fromJson(jsonDecode(s));
      return ep.link != episode.link;
    }).toList();
    updated.add(jsonEncode(episode.toJson()));
    // Máximo 50 episodios
    if (updated.length > 50) updated.removeAt(0);
    await prefs.setStringList(_historyKey, updated);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_progressKey);
  }

  // ── Progreso de reproducción ──────────────────────────────────────────────
  // progress: 0.0 → 1.0
  Future<void> saveProgress(String episodeLink, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_progressKey);
    final map   = raw != null
        ? Map<String, double>.from(
            (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())))
        : <String, double>{};
    map[episodeLink] = progress.clamp(0.0, 1.0);
    await prefs.setString(_progressKey, jsonEncode(map));
  }

  Future<double> getProgress(String episodeLink) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_progressKey);
    if (raw == null) return 0.0;
    final map = Map<String, dynamic>.from(jsonDecode(raw));
    return (map[episodeLink] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_progressKey);
    if (raw == null) return {};
    return Map<String, double>.from(
        (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
  }
}