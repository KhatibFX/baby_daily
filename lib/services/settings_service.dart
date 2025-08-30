import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class SettingsService {
  static const String _settingsFileName = 'backup_settings.json';
  static const int _defaultChunkingThreshold = 50;
  
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();
  
  SettingsService._();
  
  late Map<String, dynamic> _settings;
  bool _initialized = false;
  
  /// Initialize settings service
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _loadSettings();
    _initialized = true;
  }
  
  /// Get the chunking threshold (number of photos before chunking)
  int get chunkingThreshold => _settings['chunkingThreshold'] ?? _defaultChunkingThreshold;
  
  /// Set the chunking threshold
  Future<void> setChunkingThreshold(int threshold) async {
    _settings['chunkingThreshold'] = threshold;
    await _saveSettings();
  }
  
  /// Load settings from file
  Future<void> _loadSettings() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final settingsFile = File(path.join(appDir.path, _settingsFileName));
      
      if (await settingsFile.exists()) {
        final jsonString = await settingsFile.readAsString();
        _settings = jsonDecode(jsonString);
      } else {
        // Create default settings
        _settings = {
          'chunkingThreshold': _defaultChunkingThreshold,
        };
        await _saveSettings();
      }
    } catch (e) {
      // If loading fails, use default settings
      _settings = {
        'chunkingThreshold': _defaultChunkingThreshold,
      };
    }
  }
  
  /// Save settings to file
  Future<void> _saveSettings() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final settingsFile = File(path.join(appDir.path, _settingsFileName));
      await settingsFile.writeAsString(jsonEncode(_settings));
    } catch (e) {
      print('Failed to save settings: $e');
    }
  }
  
  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    _settings = {
      'chunkingThreshold': _defaultChunkingThreshold,
    };
    await _saveSettings();
  }
} 