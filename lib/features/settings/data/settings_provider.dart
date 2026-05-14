import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    if (value is T) state = normalize(value);
  }

  T normalize(T value) => value;

  Future<void> set(T value) async {
    value = normalize(value);
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

class AppIconStyleNotifier extends PersistedSettingNotifier<String> {
  static const _channel = MethodChannel('anime_roll/app_icon');

  AppIconStyleNotifier() : super(key: 'appIconStyle', defaultValue: 'violeta');

  @override
  String normalize(String value) {
    return switch (value) {
      'clapper' || 'bolt' || 'fire' || 'wave' => 'violeta',
      'violeta' || 'oceano' || 'carmesi' || 'esmeralda' => value,
      _ => 'violeta',
    };
  }

  @override
  Future<void> set(String value) async {
    await super.set(value);
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<bool>('setIconStyle', {'style': value});
    } on PlatformException {
      // The visual preference still applies even if the launcher rejects a swap.
    } on MissingPluginException {
      // Keeps settings usable on platforms without the native icon bridge.
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

final accentColorIndexProvider =
    StateNotifierProvider<PersistedSettingNotifier<int>, int>(
      (ref) =>
          PersistedSettingNotifier(key: 'accentColorIndex', defaultValue: 0),
    );

final catalogLayoutProvider =
    StateNotifierProvider<PersistedSettingNotifier<String>, String>(
      (ref) =>
          PersistedSettingNotifier(key: 'catalogLayout', defaultValue: 'grid'),
    );

final appIconStyleProvider =
    StateNotifierProvider<PersistedSettingNotifier<String>, String>(
      (ref) => AppIconStyleNotifier(),
    );

final recapDetailPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<String>, String>(
      (ref) => PersistedSettingNotifier(
        key: 'recapDetailPref',
        defaultValue: 'medium',
      ),
    );

final recapDaysThresholdPrefProvider =
    StateNotifierProvider<PersistedSettingNotifier<int>, int>(
      (ref) =>
          PersistedSettingNotifier(key: 'recapDaysThreshold', defaultValue: 7),
    );
