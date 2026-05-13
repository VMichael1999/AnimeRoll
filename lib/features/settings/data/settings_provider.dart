import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class PersistedSettingNotifier<T> extends StateNotifier<T> {
  final String key;
  final T defaultValue;

  PersistedSettingNotifier({required this.key, required this.defaultValue})
    : super(defaultValue) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(key);
    if (value is T) state = value;
  }

  Future<void> set(T value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    switch (value) {
      case String():
        await prefs.setString(key, value);
      case bool():
        await prefs.setBool(key, value);
      case int():
        await prefs.setInt(key, value);
      default:
        throw UnsupportedError('Unsupported setting type: $T');
    }
  }
}

final providerPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<String>, String>(
      (ref) => PersistedSettingNotifier(
        key: 'providerPref',
        defaultValue: AppConstants.providers.first,
      ),
    );

final qualityPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<String>, String>(
      (ref) =>
          PersistedSettingNotifier(key: 'qualityPref', defaultValue: '1080p'),
    );

final variantPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<String>, String>(
      (ref) =>
          PersistedSettingNotifier(key: 'variantPref', defaultValue: 'SUB'),
    );

final autoplayPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<bool>, bool>(
      (ref) =>
          PersistedSettingNotifier(key: 'autoplayPref', defaultValue: true),
    );

final fallbackPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<bool>, bool>(
      (ref) =>
          PersistedSettingNotifier(key: 'fallbackPref', defaultValue: true),
    );

final preferredPlaybackServerProvider =
    StateNotifierProvider<PersistedSettingNotifier<String>, String>(
      (ref) => PersistedSettingNotifier(
        key: 'preferredPlaybackServer',
        defaultValue: '',
      ),
    );

final wifiOnlyPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<bool>, bool>(
      (ref) =>
          PersistedSettingNotifier(key: 'wifiOnlyPref', defaultValue: false),
    );

final darkThemePrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<bool>, bool>(
      (ref) =>
          PersistedSettingNotifier(key: 'darkThemePref', defaultValue: true),
    );

final debugDownloadPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<bool>, bool>(
      (ref) => PersistedSettingNotifier(
        key: 'debugDownloadPref',
        defaultValue: false,
      ),
    );

final simultaneousDownloadsProvider =
    StateNotifierProvider<PersistedSettingNotifier<int>, int>(
      (ref) => PersistedSettingNotifier(
        key: 'simultaneousDownloads',
        defaultValue: 3,
      ),
    );
