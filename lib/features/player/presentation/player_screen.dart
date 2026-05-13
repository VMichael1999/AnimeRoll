import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/episode_model.dart';
import '../../../shared/widgets/error_view.dart';
import '../../settings/data/settings_provider.dart';
import '../data/player_provider.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String episodeUrl;
  final String title;

  const PlayerScreen({
    super.key,
    required this.episodeUrl,
    required this.title,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _activeVideoUrl;
  String? _playerError;
  List<VideoServerModel> _lastServers = const [];

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initPlayer(VideoServerModel server) async {
    final videoUrl = server.url;
    _chewieController?.dispose();
    _videoController?.dispose();
    _playerError = null;
    _activeVideoUrl = videoUrl;

    try {
      final isHls = videoUrl.contains('.m3u8');
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        formatHint: isHls ? VideoFormat.hls : null,
      );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: false,
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        placeholder: const ColoredBox(color: Colors.black),
      );
      await ref.read(preferredPlaybackServerProvider.notifier).set(server.name);
    } catch (error) {
      _playerError = 'No se pudo reproducir este servidor';
      if (ref.read(fallbackPrefProvider)) {
        _tryNextServer(videoUrl);
      }
    }

    if (mounted) setState(() {});
  }

  void _tryNextServer(String failedUrl) {
    final current = _lastServers.indexWhere(
      (server) => server.url == failedUrl,
    );
    if (current == -1) return;

    for (var i = current + 1; i < _lastServers.length; i++) {
      if (_isDirectVideoUrl(_lastServers[i].url)) {
        ref.read(selectedServerProvider.notifier).state = i;
        return;
      }
    }

    for (var i = 0; i < _lastServers.length; i++) {
      if (_lastServers[i].url != failedUrl) {
        ref.read(selectedServerProvider.notifier).state = i;
        return;
      }
    }
  }

  bool _isDirectVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('.webm') ||
        lower.contains('.mkv');
  }

  Widget _embedPlayer(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));

    return WebViewWidget(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    final serversAsync = ref.watch(serversProvider(widget.episodeUrl));
    final selectedIndex = ref.watch(selectedServerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Video area
          SafeArea(
            bottom: false,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: serversAsync.when(
                data: (servers) {
                  _lastServers = servers;
                  if (servers.isEmpty) {
                    return const Center(
                      child: Text(
                        'Sin servidores disponibles',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  final server =
                      servers[selectedIndex.clamp(0, servers.length - 1)];
                  if (!_isDirectVideoUrl(server.url)) {
                    return _embedPlayer(server.url);
                  }
                  if (_chewieController == null ||
                      _activeVideoUrl != server.url) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _initPlayer(server);
                    });
                    if (_playerError != null) {
                      return Center(
                        child: Text(
                          _playerError!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  return Chewie(controller: _chewieController!);
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (err, _) => const Center(
                  child: Text(
                    'Error al cargar el video',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          // Bottom sheet
          Expanded(
            child: Container(
              color: AppColors.bg,
              child: serversAsync.when(
                data: (servers) => _PlayerInfo(
                  title: widget.title,
                  servers: servers,
                  selectedIndex: selectedIndex,
                  onServerSelect: (i) {
                    ref
                        .read(preferredPlaybackServerProvider.notifier)
                        .set(servers[i].name);
                    ref.read(selectedServerProvider.notifier).state = i;
                    _chewieController?.dispose();
                    _videoController?.dispose();
                    _chewieController = null;
                    _videoController = null;
                    _activeVideoUrl = null;
                    _playerError = null;
                    if (_isDirectVideoUrl(servers[i].url)) {
                      _initPlayer(servers[i]);
                    } else {
                      setState(() {});
                    }
                  },
                ),
                loading: () => const SizedBox.shrink(),
                error: (e, _) => ErrorView(
                  message: 'Error al cargar servidores',
                  onRetry: () =>
                      ref.invalidate(serversProvider(widget.episodeUrl)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerInfo extends StatelessWidget {
  final String title;
  final List<VideoServerModel> servers;
  final int selectedIndex;
  final ValueChanged<int> onServerSelect;

  const _PlayerInfo({
    required this.title,
    required this.servers,
    required this.selectedIndex,
    required this.onServerSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Servidores',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: servers.length,
              separatorBuilder: (context, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final active = i == selectedIndex;
                final server = servers[i];
                return GestureDetector(
                  onTap: () => onServerSelect(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? AppColors.accent : AppColors.border,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          server.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: active
                                ? AppColors.accent2
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          [
                            _isDirectVideoUrl(server.url) ? 'Directo' : 'Web',
                            if (server.quality != null) server.quality!,
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

bool _isDirectVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.m3u8') ||
      lower.contains('.mp4') ||
      lower.contains('.webm') ||
      lower.contains('.mkv');
}
