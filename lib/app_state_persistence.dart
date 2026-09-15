import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';

class AppStatePersistence {
  static const String _key = 'safeprep_state';
  static final AppState _state = AppState();

  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_state.toJson());
      await prefs.setString(_key, json);
    } catch (e) {
      debugPrint('AppState save failed: $e');
    }
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null) {
        debugPrint('No save file found — fresh install');
        return;
      }
      _state.fromJson(jsonDecode(json));
      debugPrint('AppState loaded — user: ${_state.userName}');
    } catch (e) {
      debugPrint('AppState load failed: $e');
    }
  }

  static Future<void> delete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      debugPrint('Save file deleted');
    } catch (e) {
      debugPrint('AppState delete failed: $e');
    }
  }
}