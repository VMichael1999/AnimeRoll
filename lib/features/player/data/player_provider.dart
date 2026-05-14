import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/episode_model.dart';
import '../../home/data/home_provider.dart';
import '../../settings/data/settings_provider.dart';

final serversProvider = FutureProvider.autoDispose
    .family<List<VideoServerModel>, String>((ref, url) {
      final preferredServer = url.toLowerCase().contains('hentaila.com')
          ? 'vip'
          : ref.read(preferredPlaybackServerProvider);
      return ref
          .read(animeRepositoryProvider)
          .getVideoServers(url)
          .then((servers) => _sortPlayableServers(servers, preferredServer));
    });

final selectedServerProvider = StateProvider.autoDispose<int>((ref) => 0);

List<VideoServerModel> _sortPlayableServers(
  List<VideoServerModel> servers,
  String preferredServer,
) {
  final list = servers.where((server) => server.url.isNotEmpty).toList();
  list.sort(
    (a, b) => _serverScore(
      b,
      preferredServer,
    ).compareTo(_serverScore(a, preferredServer)),
  );
  return list;
}

int _serverScore(VideoServerModel server, String preferredServer) {
  final name = server.name.toLowerCase();
  final url = server.url.toLowerCase();
  final preferred = preferredServer.toLowerCase();
  var score = 0;

  if (name == 'hls' || name.contains('hls')) score += 500;
  if (name == 'vip') score += 450;
  if (preferred.isNotEmpty && name.contains(preferred)) score += 200;
  if (_isDirectVideoUrl(url)) score += 100;
  if (server.isHls || url.contains('.m3u8')) score += 30;
  if (name.contains('yourupload')) score += 20;
  if (name.contains('streamwish')) score += 15;
  if (name.contains('filemoon')) score += 10;
  if (name.contains('mp4upload')) score += 8;
  if (name.contains('voe')) score -= 10;
  if (name.contains('mega')) score -= 20;

  return score;
}

bool _isDirectVideoUrl(String url) {
  return url.contains('.m3u8') ||
      url.contains('.mp4') ||
      url.contains('.webm') ||
      url.contains('.mkv');
}
