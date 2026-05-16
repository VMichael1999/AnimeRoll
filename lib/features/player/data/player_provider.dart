import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/episode_model.dart';
import '../../home/data/home_provider.dart';
import '../../settings/data/settings_provider.dart';

final serversProvider = FutureProvider.autoDispose
    .family<List<VideoServerModel>, String>((ref, url) {
      final preferredServer = ref.read(preferredPlaybackServerProvider);
      return ref
          .read(animeRepositoryProvider)
          .getVideoServers(url)
          .then((servers) => _sortPlayableServers(servers, preferredServer));
    });

final selectedServerProvider = StateProvider.autoDispose<int>((ref) => 0);

final selectedServerUrlProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

List<VideoServerModel> _sortPlayableServers(
  List<VideoServerModel> servers,
  String preferredServer,
) {
  final list = servers.where((server) => server.url.isNotEmpty).toList();
  final hasNativePlayable = list.any(
    (server) => _isNativePlayableUrl(server.url),
  );
  final indexed = <({int index, VideoServerModel server})>[
    for (var i = 0; i < list.length; i++) (index: i, server: list[i]),
  ];
  indexed.sort((a, b) {
    final scoreDiff = _serverScore(
      b.server,
      preferredServer,
      hasNativePlayable,
    ).compareTo(_serverScore(a.server, preferredServer, hasNativePlayable));
    if (scoreDiff != 0) return scoreDiff;
    return a.index.compareTo(b.index);
  });
  return indexed.map((entry) => entry.server).toList();
}

int _serverScore(
  VideoServerModel server,
  String preferredServer,
  bool hasNativePlayable,
) {
  final name = server.name.toLowerCase();
  final url = _playbackUrl(server.url).toLowerCase();
  final preferred = preferredServer.toLowerCase();
  var score = 0;

  if (preferred.isNotEmpty && name.contains(preferred)) score += 1000;
  final nativePlayable = _isNativePlayableUrl(url);
  if (nativePlayable) score += _isApplePlatform ? 250 : 40;
  if (_isApplePlatform &&
      preferred.isEmpty &&
      hasNativePlayable &&
      !nativePlayable) {
    score -= 200;
  }
  if (_isApplePlatform && (url.contains('.webm') || url.contains('.mkv'))) {
    score -= 700;
  }
  if (name.contains('yourupload')) score += 20;
  if (name.contains('streamwish')) score += 15;
  if (name.contains('filemoon')) score += 10;
  if (name.contains('mp4upload')) score += 8;
  if (name.contains('voe')) score -= 10;
  if (name.contains('mega')) score -= 20;

  return score;
}

bool get _isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

String _playbackUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final host = uri.host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
  if (host.contains('zilla-networks.com') && uri.pathSegments.isNotEmpty) {
    final playIndex = uri.pathSegments.indexWhere(
      (segment) => segment.toLowerCase() == 'play',
    );
    if (playIndex != -1 && playIndex + 1 < uri.pathSegments.length) {
      final videoId = uri.pathSegments[playIndex + 1];
      return 'https://player.zilla-networks.com/m3u8/$videoId';
    }
  }
  return url;
}

bool _isNativePlayableUrl(String url) {
  final lower = _playbackUrl(url).toLowerCase();
  // Player pages from zilla-networks (or similar embed players) look like HLS
  // by their path (.../m3u8/<id>) but really serve HTML that requires JS to
  // resolve the actual stream. iOS AVPlayer can't handle that — we must route
  // them through the WebView fallback.
  if (_isApplePlatform &&
      (lower.contains('player.zilla-networks.com') ||
          lower.contains('zilla-networks.com/m3u8') ||
          lower.contains('player.zilla'))) {
    return false;
  }
  // Match ONLY real file extensions: extension must be followed by `?`, `#`,
  // `/`, or end-of-string. `contains('.mp4')` was matching `www.mp4upload.com`
  // (substring `.mp4u`) and routing embed pages to ExoPlayer.
  final applePattern = RegExp(r'\.(m3u8|mp4|mov)([?#/]|$)');
  final androidPattern = RegExp(r'\.(m3u8|mp4|mov|webm|mkv)([?#/]|$)');
  return (_isApplePlatform ? applePattern : androidPattern).hasMatch(lower);
}
