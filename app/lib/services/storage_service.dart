import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local storage service for history, settings, and file management.
class StorageService {
  static const String _historyKey = 'faceshield_history';
  static const String _blurStyleKey = 'faceshield_blur_style';
  static const String _blurIntensityKey = 'faceshield_blur_intensity';
  static const String _autoDeleteKey = 'faceshield_auto_delete';
  static const String _consentGivenKey = 'faceshield_consent_given';
  static const String _serverUrlKey = 'faceshield_server_url';

  // --- Settings ---

  /// Get the current blur style setting.
  static Future<String> getBlurStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_blurStyleKey) ?? 'gaussian';
  }

  /// Set the blur style.
  static Future<void> setBlurStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_blurStyleKey, style);
  }

  /// Get the current blur intensity setting.
  static Future<String> getBlurIntensity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_blurIntensityKey) ?? 'high';
  }

  /// Set the blur intensity.
  static Future<void> setBlurIntensity(String intensity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_blurIntensityKey, intensity);
  }

  /// Get auto-delete from server setting.
  static Future<bool> getAutoDelete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoDeleteKey) ?? true;
  }

  /// Set auto-delete from server setting.
  static Future<void> setAutoDelete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoDeleteKey, value);
  }

  /// Check if user has given GDPR consent.
  static Future<bool> hasConsentBeenGiven() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentGivenKey) ?? false;
  }

  /// Record that user has given GDPR consent.
  static Future<void> setConsentGiven(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentGivenKey, value);
  }

  /// Get custom server URL.
  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey) ?? '';
  }

  /// Set custom server URL.
  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  // --- History ---

  /// Get all history entries.
  static Future<List<HistoryEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_historyKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> list = json.decode(jsonStr);
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  /// Add a new history entry.
  static Future<void> addHistoryEntry(HistoryEntry entry) async {
    final history = await getHistory();
    history.insert(0, entry);

    // Keep max 100 entries
    final trimmed = history.take(100).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      json.encode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  /// Delete a history entry by ID.
  static Future<void> deleteHistoryEntry(String id) async {
    final history = await getHistory();
    history.removeWhere((e) => e.id == id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      json.encode(history.map((e) => e.toJson()).toList()),
    );
  }

  /// Clear all history.
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // --- File Management ---

  /// Save processed result to local storage.
  static Future<String> saveResultFile(
    Uint8List bytes,
    String filename,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final faceshieldDir = Directory('${dir.path}/faceshield');
    if (!await faceshieldDir.exists()) {
      await faceshieldDir.create(recursive: true);
    }

    final filePath = '${faceshieldDir.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// Get a stored result file.
  static Future<File?> getResultFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) return file;
    return null;
  }

  /// Delete a stored result file.
  static Future<void> deleteResultFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Represents a processed photo or video in the user's history.
class HistoryEntry {
  final String id;
  final String type; // 'photo' or 'video'
  final String filePath;
  final String thumbnailPath;
  final DateTime timestamp;
  final int facesDetected;

  HistoryEntry({
    required this.id,
    required this.type,
    required this.filePath,
    required this.thumbnailPath,
    required this.timestamp,
    required this.facesDetected,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      type: json['type'] as String,
      filePath: json['file_path'] as String,
      thumbnailPath: json['thumbnail_path'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      facesDetected: json['faces_detected'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'file_path': filePath,
      'thumbnail_path': thumbnailPath,
      'timestamp': timestamp.toIso8601String(),
      'faces_detected': facesDetected,
    };
  }
}
