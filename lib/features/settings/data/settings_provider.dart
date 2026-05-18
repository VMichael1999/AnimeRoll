import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app_icon_changer/flutter_app_icon_changer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../home/data/anime_repository.dart';

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

class _AnimeRollIcon extends AppIcon {
  _AnimeRollIcon({
    required super.iOSIcon,
    required super.androidIcon,
    required super.isDefaultIcon,
  });
}

class AppIconStyleNotifier extends PersistedSettingNotifier<String> {
  static const _androidChannel = MethodChannel('anime_roll/app_icon');
  static final _iosChanger = FlutterAppIconChangerPlugin(
    iconsSet: [
      _AnimeRollIcon(
        iOSIcon: 'AppIcon',
        androidIcon: 'MainActivity',
        isDefaultIcon: true,
      ),
      _AnimeRollIcon(
        iOSIcon: 'AppIcon1',
        androidIcon: 'MainActivityOceano',
        isDefaultIcon: false,
      ),
      _AnimeRollIcon(
        iOSIcon: 'AppIcon2',
        androidIcon: 'MainActivityCarmesi',
        isDefaultIcon: false,
      ),
      _AnimeRollIcon(
        iOSIcon: 'AppIcon3',
        androidIcon: 'MainActivityEsmeralda',
        isDefaultIcon: false,
      ),
    ],
  );

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
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android) {
      try {
        await _androidChannel.invokeMethod<bool>('setIconStyle', {'style': value});
      } on PlatformException {
        // Visual preference still applies if the launcher rejects the swap.
      } on MissingPluginException {
        // Keeps settings usable on platforms without the native bridge.
      }
    } else if (platform == TargetPlatform.iOS) {
      final iconName = switch (value) {
        'oceano' => 'AppIcon1',
        'carmesi' => 'AppIcon2',
        'esmeralda' => 'AppIcon3',
        _ => 'AppIcon',
      };
      try {
        await _iosChanger.changeIcon(iconName);
      } on PlatformException {
        // Ignore: keeps the persisted preference even if iOS rejects.
      }
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

/// Flag persistente que indica si el proveedor VIP (CineHax) ya fue
/// desbloqueado con el código. Si es false, al intentar activar CineHax se
/// muestra el diálogo de unlock pidiendo el código.
final cinehaxUnlockedProvider =
    StateNotifierProvider<PersistedSettingNotifier<bool>, bool>(
      (ref) => PersistedSettingNotifier(
        key: 'cinehaxUnlocked',
        defaultValue: false,
      ),
    );

final availableProvidersProvider = FutureProvider<List<String>>((ref) async {
  final repo = AnimeRepository();
  final available = await repo.availableProviders(AppConstants.providers);
  final providers = available.isEmpty ? AppConstants.providers : available;
  final activeProvider = ref.read(providerPrefProvider);

  if (!providers.contains(activeProvider)) {
    Future.microtask(
      () => ref.read(providerPrefProvider.notifier).set(providers.first),
    );
  }

  return providers;
});

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
