import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/episode_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/error_view.dart';
import '../../detail/data/detail_provider.dart';
import '../../downloads/data/downloads_provider.dart';
import '../../favorites/data/favorites_provider.dart';
import '../../history/data/watch_history_provider.dart';
import '../../settings/data/settings_provider.dart';
import '../data/player_provider.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String episodeUrl;
  final String title;
  final String animeUrl;

  const PlayerScreen({
    super.key,
    required this.episodeUrl,
    required this.title,
    this.animeUrl = '',
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _floating = Floating();
  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _activeVideoUrl;
  String? _initializingVideoUrl;
  String? _playerError;
  List<VideoServerModel> _lastServers = const [];
  AnimeDetailData? _latestDetail;
  DateTime? _lastHistorySaveAt;

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _saveCurrentProgress(force: true);
    _chewieController?.dispose();
    _videoController?.removeListener(_onVideoProgress);
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initPlayer(VideoServerModel server) async {
    final videoUrl = server.url;
    if (_initializingVideoUrl == videoUrl) return;

    _saveCurrentProgress(force: true);
    _chewieController?.dispose();
    final previousController = _videoController;
    previousController?.removeListener(_onVideoProgress);
    _videoController = null;
    await previousController?.dispose();

    _playerError = null;
    _activeVideoUrl = videoUrl;
    _initializingVideoUrl = videoUrl;

    try {
      final isHls = videoUrl.contains('.m3u8');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        formatHint: isHls ? VideoFormat.hls : null,
      );

      _videoController = controller;
      await controller.initialize();
      if (!mounted || _activeVideoUrl != videoUrl) {
        await controller.dispose();
        if (_videoController == controller) _videoController = null;
        return;
      }
      await _seekToSavedPosition(controller);
      controller.addListener(_onVideoProgress);

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: false,
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        placeholder: ColoredBox(color: Colors.black),
      );
      await ref.read(preferredPlaybackServerProvider.notifier).set(server.name);
      _startPlaybackAfterFirstFrame(videoUrl);
    } catch (error) {
      _playerError = 'No se pudo reproducir este servidor';
      if (ref.read(fallbackPrefProvider)) {
        _tryNextServer(videoUrl);
      }
    } finally {
      if (_initializingVideoUrl == videoUrl) {
        _initializingVideoUrl = null;
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _seekToSavedPosition(VideoPlayerController controller) async {
    final entry = ref
        .read(watchHistoryProvider.notifier)
        .find(widget.episodeUrl);
    if (entry == null || entry.completed) return;
    final position = Duration(milliseconds: entry.positionMs);
    final duration = controller.value.duration;
    if (position < const Duration(seconds: 10) ||
        duration <= Duration.zero ||
        position >= duration - const Duration(seconds: 30)) {
      return;
    }
    await controller.seekTo(position);
  }

  void _onVideoProgress() {
    final now = DateTime.now();
    final last = _lastHistorySaveAt;
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _lastHistorySaveAt = now;
    _saveCurrentProgress();
  }

  void _saveCurrentProgress({bool force = false}) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!force &&
        controller.value.position < const Duration(seconds: 5) &&
        controller.value.duration > const Duration(minutes: 1)) {
      return;
    }

    final detail = _latestDetail;
    final episode = detail?.episodes
        .where((item) => item.url == widget.episodeUrl)
        .firstOrNull;
    final animeUrl = widget.animeUrl.isNotEmpty
        ? widget.animeUrl
        : detail?.anime.url ?? _inferAnimeUrl(widget.episodeUrl);
    unawaited(
      ref
          .read(watchHistoryProvider.notifier)
          .upsertProgress(
            episodeUrl: widget.episodeUrl,
            episodeTitle: episode?.title ?? widget.title,
            animeTitle: detail?.anime.title ?? widget.title.split('·').first,
            animeUrl: animeUrl,
            thumbnail: episode?.thumbnail ?? detail?.anime.cover,
            episodeNumber: episode?.number,
            position: controller.value.position,
            duration: controller.value.duration,
            source: 'stream',
          ),
    );
  }

  void _startPlaybackAfterFirstFrame(String videoUrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted || _activeVideoUrl != videoUrl) return;
      final controller = _videoController;
      if (controller == null || !controller.value.isInitialized) return;
      await controller.play();
    });
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

  Future<void> _enterPiP() async {
    final available = await _floating.isPipAvailable;
    if (!available || !mounted) return;
    await _floating.enable(const ImmediatePiP(aspectRatio: Rational(16, 9)));
  }

  void _setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    setState(() => _sleepTimerRemaining = duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepTimerRemaining;
      if (remaining == null || remaining.inSeconds <= 1) {
        timer.cancel();
        _videoController?.pause();
        if (mounted) setState(() => _sleepTimerRemaining = null);
        return;
      }
      if (mounted) {
        setState(
          () => _sleepTimerRemaining = remaining - const Duration(seconds: 1),
        );
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() => _sleepTimerRemaining = null);
  }

  String _formatSleepTimer(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
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
    final animeUrl = widget.animeUrl.isNotEmpty
        ? widget.animeUrl
        : _inferAnimeUrl(widget.episodeUrl);
    final detailAsync = animeUrl.isEmpty
        ? null
        : ref.watch(animeDetailProvider(animeUrl));
    _latestDetail = detailAsync?.valueOrNull;

    final videoArea = SafeArea(
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
            final server = servers[selectedIndex.clamp(0, servers.length - 1)];
            if (!_isDirectVideoUrl(server.url)) {
              return _embedPlayer(server.url);
            }
            if (_chewieController == null || _activeVideoUrl != server.url) {
              if (_initializingVideoUrl != server.url) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _initPlayer(server);
                });
              }
              if (_playerError != null) {
                return Center(
                  child: Text(
                    _playerError!,
                    style: TextStyle(color: Colors.white),
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
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        final available = await _floating.isPipAvailable;
        if (available && mounted) {
          await _floating.enable(
            const ImmediatePiP(aspectRatio: Rational(16, 9)),
          );
        } else {
          router.pop();
        }
      },
      child: PiPSwitcher(
        childWhenEnabled: ColoredBox(
          color: Colors.black,
          child: Center(child: videoArea),
        ),
        childWhenDisabled: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              videoArea,
              Expanded(
                child: Container(
                  color: AppColors.bg,
                  child: serversAsync.when(
                    data: (servers) => _PlayerInfo(
                      title: widget.title,
                      episodeUrl: widget.episodeUrl,
                      animeUrl: animeUrl,
                      servers: servers,
                      selectedIndex: selectedIndex,
                      detailAsync: detailAsync,
                      onPiP: _enterPiP,
                      sleepTimerRemaining: _sleepTimerRemaining,
                      onSetSleepTimer: _setSleepTimer,
                      onCancelSleepTimer: _cancelSleepTimer,
                      formatSleepTimer: _formatSleepTimer,
                      onServerSelect: (i) {
                        ref
                            .read(preferredPlaybackServerProvider.notifier)
                            .set(servers[i].name);
                        ref.read(selectedServerProvider.notifier).state = i;
                        _chewieController?.dispose();
                        final controller = _videoController;
                        _saveCurrentProgress(force: true);
                        _chewieController = null;
                        _videoController = null;
                        _activeVideoUrl = null;
                        _initializingVideoUrl = null;
                        _playerError = null;
                        controller?.removeListener(_onVideoProgress);
                        controller?.dispose();
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
        ),
      ),
    );
  }

  String _inferAnimeUrl(String episodeUrl) {
    final uri = Uri.tryParse(episodeUrl);
    if (uri == null || uri.pathSegments.isEmpty) return '';
    if (uri.host.contains('hentaila.com') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'ver') {
      final episodeSlug = uri.pathSegments[1];
      final animeSlug = episodeSlug.replaceFirst(RegExp(r'-\d+$'), '');
      return uri.replace(pathSegments: ['media', animeSlug]).toString();
    }
    if (uri.pathSegments.length < 3) return '';
    final parentSegments = uri.pathSegments.take(uri.pathSegments.length - 1);
    return uri.replace(pathSegments: parentSegments).toString();
  }
}

class _PlayerInfo extends ConsumerWidget {
  final String title;
  final String episodeUrl;
  final String animeUrl;
  final List<VideoServerModel> servers;
  final int selectedIndex;
  final AsyncValue<AnimeDetailData>? detailAsync;
  final VoidCallback? onPiP;
  final Duration? sleepTimerRemaining;
  final ValueChanged<Duration> onSetSleepTimer;
  final VoidCallback onCancelSleepTimer;
  final String Function(Duration) formatSleepTimer;
  final ValueChanged<int> onServerSelect;

  const _PlayerInfo({
    required this.title,
    required this.episodeUrl,
    required this.animeUrl,
    required this.servers,
    required this.selectedIndex,
    required this.detailAsync,
    required this.onServerSelect,
    required this.onSetSleepTimer,
    required this.onCancelSleepTimer,
    required this.formatSleepTimer,
    this.onPiP,
    this.sleepTimerRemaining,
  });

  void _showSleepTimerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sleep Timer',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          for (final minutes in [15, 30, 45, 60, 90])
            ListTile(
              leading: Icon(
                Icons.bedtime_rounded,
                color: AppColors.accent2,
                size: 20,
              ),
              title: Text('$minutes minutos'),
              onTap: () {
                Navigator.pop(ctx);
                onSetSleepTimer(Duration(minutes: minutes));
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _downloadCurrentEpisode(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final detail = detailAsync?.valueOrNull;
    final anime = detail?.anime;
    final episode = detail?.episodes
        .where((item) => item.url == episodeUrl)
        .firstOrNull;

    try {
      await ref
          .read(downloadsProvider.notifier)
          .startEpisode(
            episodeUrl: episodeUrl,
            title: anime == null
                ? title
                : '${anime.title} · ${episode?.title ?? title}',
            thumbnail: episode?.thumbnail ?? anime?.cover,
            animeTitle: anime?.title,
            animeUrl: anime?.url ?? animeUrl,
            episodeTitle: episode?.title ?? title,
            episodeNumber: episode?.number,
            quality: ref.read(qualityPrefProvider),
            variant: ref.read(variantPrefProvider),
            preferredServer: animeUrl.contains('hentaila.com')
                ? 'VIP'
                : 'yourupload',
          );
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'Descarga agregada',
          type: AppToastType.success,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'No se pudo iniciar la descarga',
          type: AppToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 2,
                ),
              ),
              GestureDetector(
                onTap: () => sleepTimerRemaining != null
                    ? onCancelSleepTimer()
                    : _showSleepTimerSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: sleepTimerRemaining != null
                        ? AppColors.accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: sleepTimerRemaining != null
                        ? Border.all(color: AppColors.accent)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bedtime_rounded,
                        size: 16,
                        color: sleepTimerRemaining != null
                            ? AppColors.accent2
                            : AppColors.textSecondary,
                      ),
                      if (sleepTimerRemaining != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          formatSleepTimer(sleepTimerRemaining!),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.accent2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.download_rounded, size: 20),
                onPressed: () => _downloadCurrentEpisode(context, ref),
                padding: EdgeInsets.zero,
                color: AppColors.textSecondary,
                tooltip: 'Descargar episodio',
              ),
              const SizedBox(width: 2),
              if (onPiP != null)
                IconButton(
                  icon: Icon(Icons.picture_in_picture_alt_rounded, size: 20),
                  onPressed: onPiP,
                  padding: EdgeInsets.zero,
                  color: AppColors.textSecondary,
                  tooltip: 'Picture in Picture',
                ),
            ],
          ),
          const SizedBox(height: 16),
          _EpisodeNavigation(episodeUrl: episodeUrl, detailAsync: detailAsync),
          const SizedBox(height: 16),
          const Text(
            'Servidores',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _ServerVariantRows(
            servers: servers,
            selectedIndex: selectedIndex,
            onServerSelect: onServerSelect,
          ),
          const SizedBox(height: 22),
          _EpisodeGridPanel(episodeUrl: episodeUrl, detailAsync: detailAsync),
          const SizedBox(height: 22),
          _AnimeEpisodeInfo(title: title, detailAsync: detailAsync),
        ],
      ),
    );
  }
}

class _EpisodeNavigation extends StatelessWidget {
  final String episodeUrl;
  final AsyncValue<AnimeDetailData>? detailAsync;

  const _EpisodeNavigation({
    required this.episodeUrl,
    required this.detailAsync,
  });

  @override
  Widget build(BuildContext context) {
    final detail = detailAsync;
    if (detail == null) {
      return const SizedBox.shrink();
    }

    return detail.maybeWhen(
      data: (data) {
        final episodes = data.episodes;
        final index = episodes.indexWhere(
          (episode) => episode.url == episodeUrl,
        );
        if (index == -1 || episodes.length < 2) {
          return const SizedBox.shrink();
        }

        final previous = index > 0 ? episodes[index - 1] : null;
        final next = index < episodes.length - 1 ? episodes[index + 1] : null;

        return Row(
          children: [
            Expanded(
              child: _EpisodeNavButton(
                icon: Icons.chevron_left_rounded,
                label: 'Anterior',
                enabled: previous != null,
                onTap: previous == null
                    ? null
                    : () => _openEpisode(context, data.anime.url, previous),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EpisodeNavButton(
                icon: Icons.chevron_right_rounded,
                label: 'Siguiente',
                enabled: next != null,
                trailingIcon: true,
                onTap: next == null
                    ? null
                    : () => _openEpisode(context, data.anime.url, next),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _openEpisode(
    BuildContext context,
    String animeUrl,
    EpisodeModel episode,
  ) {
    context.pushReplacement(
      '/player?url=${Uri.encodeComponent(episode.url)}&title=${Uri.encodeComponent(episode.title)}&animeUrl=${Uri.encodeComponent(animeUrl)}',
    );
  }
}

class _EpisodeNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool trailingIcon;
  final VoidCallback? onTap;

  const _EpisodeNavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.trailingIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textPrimary : AppColors.textSecondary;
    final children = [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface2 : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: trailingIcon ? children.reversed.toList() : children,
        ),
      ),
    );
  }
}

class _EpisodeGridPanel extends StatefulWidget {
  final String episodeUrl;
  final AsyncValue<AnimeDetailData>? detailAsync;

  const _EpisodeGridPanel({
    required this.episodeUrl,
    required this.detailAsync,
  });

  @override
  State<_EpisodeGridPanel> createState() => _EpisodeGridPanelState();
}

class _EpisodeGridPanelState extends State<_EpisodeGridPanel> {
  int _rangeStart = 0;
  bool _descending = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final detail = widget.detailAsync;
    if (detail == null) return const SizedBox.shrink();

    return detail.maybeWhen(
      data: (data) {
        final episodes = data.episodes;
        if (episodes.isEmpty) return const SizedBox.shrink();

        if (data.anime.url.contains('hentaila.com')) {
          return _HentailaEpisodeListPanel(
            anime: data.anime,
            episodes: episodes,
            episodeUrl: widget.episodeUrl,
          );
        }

        final currentIndex = episodes.indexWhere(
          (episode) => episode.url == widget.episodeUrl,
        );
        final currentEpisode = currentIndex == -1
            ? null
            : episodes[currentIndex];
        final ranges = _ranges(episodes.length);
        final maxRangeStart = ranges.isEmpty ? 0 : ranges.last;
        final safeRangeStart = _rangeStart.clamp(0, maxRangeStart);
        if (safeRangeStart != _rangeStart) {
          _rangeStart = safeRangeStart;
        }

        var visible = episodes
            .skip(safeRangeStart)
            .take(100)
            .toList(growable: false);
        if (_query.trim().isNotEmpty) {
          final query = _query.trim().toLowerCase();
          visible = episodes
              .where((episode) {
                final number = episode.number?.toString() ?? '';
                return number.contains(query) ||
                    episode.title.toLowerCase().contains(query);
              })
              .toList(growable: false);
        }
        if (_descending) visible = visible.reversed.toList(growable: false);

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estás viendo',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.accent2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                currentEpisode?.title ?? 'Episodio',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _EpisodeRangeSelector(
                      ranges: ranges,
                      selectedStart: safeRangeStart,
                      total: episodes.length,
                      onChanged: (value) => setState(() {
                        _rangeStart = value;
                        _query = '';
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SquareActionButton(
                    icon: Icons.search_rounded,
                    onTap: () => _showSearch(context),
                  ),
                  const SizedBox(width: 8),
                  _SquareActionButton(
                    icon: Icons.swap_vert_rounded,
                    onTap: () => setState(() => _descending = !_descending),
                    active: _descending,
                  ),
                ],
              ),
              if (_query.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Búsqueda: $_query',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  childAspectRatio: 1.25,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                ),
                itemBuilder: (context, index) {
                  final episode = visible[index];
                  final active = episode.url == widget.episodeUrl;
                  return _EpisodeNumberButton(
                    episode: episode,
                    active: active,
                    onTap: () => _openEpisode(context, data.anime.url, episode),
                  );
                },
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  List<int> _ranges(int total) {
    return [for (var start = 0; start < total; start += 100) start];
  }

  Future<void> _showSearch(BuildContext context) async {
    final controller = TextEditingController(text: _query);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Buscar episodio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            hintText: 'Número o título',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Limpiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) setState(() => _query = result);
  }

  void _openEpisode(
    BuildContext context,
    String animeUrl,
    EpisodeModel episode,
  ) {
    context.pushReplacement(
      '/player?url=${Uri.encodeComponent(episode.url)}&title=${Uri.encodeComponent(episode.title)}&animeUrl=${Uri.encodeComponent(animeUrl)}',
    );
  }
}

class _EpisodeRangeSelector extends StatelessWidget {
  final List<int> ranges;
  final int selectedStart;
  final int total;
  final ValueChanged<int> onChanged;

  const _EpisodeRangeSelector({
    required this.ranges,
    required this.selectedStart,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (ranges.length <= 1) {
      return _RangeShell(label: '1 - $total');
    }

    return PopupMenuButton<int>(
      onSelected: onChanged,
      color: AppColors.surface2,
      itemBuilder: (context) => ranges.map((start) {
        final end = (start + 100).clamp(1, total);
        return PopupMenuItem<int>(
          value: start,
          child: Text('${start + 1} - $end'),
        );
      }).toList(),
      child: _RangeShell(
        label:
            '${selectedStart + 1} - ${(selectedStart + 100).clamp(1, total)}',
        showChevron: true,
      ),
    );
  }
}

class _HentailaEpisodeListPanel extends StatelessWidget {
  final AnimeModel anime;
  final List<EpisodeModel> episodes;
  final String episodeUrl;

  const _HentailaEpisodeListPanel({
    required this.anime,
    required this.episodes,
    required this.episodeUrl,
  });

  @override
  Widget build(BuildContext context) {
    final current = episodes.firstWhere(
      (episode) => episode.url == episodeUrl,
      orElse: () => episodes.first,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estas viendo',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.accent2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            current.title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 290),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: episodes.length,
              separatorBuilder: (context, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final episode = episodes[index];
                final active = episode.url == episodeUrl;
                return _HentailaEpisodeTile(
                  anime: anime,
                  episode: episode,
                  active: active,
                  onTap: () => context.pushReplacement(
                    '/player?url=${Uri.encodeComponent(episode.url)}&title=${Uri.encodeComponent(episode.title)}&animeUrl=${Uri.encodeComponent(anime.url)}',
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

class _HentailaEpisodeTile extends StatelessWidget {
  final AnimeModel anime;
  final EpisodeModel episode;
  final bool active;
  final VoidCallback onTap;

  const _HentailaEpisodeTile({
    required this.anime,
    required this.episode,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail = episode.thumbnail ?? anime.cover;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent2 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 58,
                child: thumbnail == null
                    ? ColoredBox(color: AppColors.surface)
                    : Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            ColoredBox(color: AppColors.surface),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: active ? AppColors.accent2 : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    anime.title,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (active)
              Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.accent2,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _RangeShell extends StatelessWidget {
  final String label;
  final bool showChevron;

  const _RangeShell({required this.label, this.showChevron = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showChevron)
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }
}

class _SquareActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _SquareActionButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.2)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Icon(icon, size: 19, color: AppColors.textSecondary),
      ),
    );
  }
}

class _EpisodeNumberButton extends StatelessWidget {
  final EpisodeModel episode;
  final bool active;
  final VoidCallback onTap;

  const _EpisodeNumberButton({
    required this.episode,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = episode.number?.toString() ?? episode.title;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent2 : AppColors.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? AppColors.accent2 : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AnimeEpisodeInfo extends StatelessWidget {
  final String title;
  final AsyncValue<AnimeDetailData>? detailAsync;

  const _AnimeEpisodeInfo({required this.title, required this.detailAsync});

  @override
  Widget build(BuildContext context) {
    final detail = detailAsync;
    if (detail == null) {
      return _EpisodeInfoBody(title: title);
    }

    return detail.when(
      data: (data) => _EpisodeInfoBody(title: title, anime: data.anime),
      loading: () => _EpisodeInfoBody(title: title, loading: true),
      error: (_, _) => _EpisodeInfoBody(title: title),
    );
  }
}

class _EpisodeInfoBody extends ConsumerWidget {
  final String title;
  final AnimeModel? anime;
  final bool loading;

  const _EpisodeInfoBody({
    required this.title,
    this.anime,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = anime == null
        ? false
        : ref.watch(
            favoritesProvider.select(
              (items) => items.any((item) => item.url == anime!.url),
            ),
          );
    final metadata = [
      if (anime?.type != null) anime!.type!,
      if (anime?.year != null) anime!.year!,
      if (anime?.status != null) anime!.status!,
      if (anime?.episodeCount != null) '${anime!.episodeCount} eps',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (anime?.title.isNotEmpty == true)
          Row(
            children: [
              Expanded(
                child: Text(
                  anime!.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent2,
                  ),
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'Quitar favorito' : 'Agregar favorito',
                onPressed: anime == null
                    ? null
                    : () => ref.read(favoritesProvider.notifier).toggle(anime!),
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? AppColors.accent2
                      : AppColors.textSecondary,
                  size: 22,
                ),
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          )
        else if (anime != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: isFavorite ? 'Quitar favorito' : 'Agregar favorito',
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(anime!),
              icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? AppColors.accent2 : AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        if (metadata.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            metadata.join('  •  '),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
        if (anime?.genres.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: anime!.genres
                .map((genre) => _GenrePill(label: genre))
                .toList(),
          ),
        ],
        if (anime?.synopsis?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          Text(
            anime!.synopsis!,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.55,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ] else if (loading) ...[
          const SizedBox(height: 18),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (anime?.score != null || anime?.votes != null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              if (anime?.score != null)
                _MetricChip(
                  icon: Icons.star_rounded,
                  label: anime!.score!.toStringAsFixed(2),
                  sublabel: 'MAL rating',
                ),
              if (anime?.votes != null) ...[
                const SizedBox(width: 8),
                _MetricChip(
                  icon: Icons.how_to_vote_outlined,
                  label: _formatVotes(anime!.votes!),
                  sublabel: 'Votos',
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  String _formatVotes(int votes) {
    final text = votes.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

class _GenrePill extends StatelessWidget {
  final String label;

  const _GenrePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface2,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.amberAccent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                sublabel,
                style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServerVariantRows extends StatelessWidget {
  final List<VideoServerModel> servers;
  final int selectedIndex;
  final ValueChanged<int> onServerSelect;

  const _ServerVariantRows({
    required this.servers,
    required this.selectedIndex,
    required this.onServerSelect,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<({int index, VideoServerModel server})>>{};
    for (final entry in servers.indexed) {
      final (index, server) = entry;
      grouped.putIfAbsent(server.variant.toUpperCase(), () => []).add((
        index: index,
        server: server,
      ));
    }

    final variants = [
      for (final variant in const ['DUB', 'SUB'])
        if (grouped.containsKey(variant)) variant,
      ...grouped.keys.where((variant) => variant != 'DUB' && variant != 'SUB'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: variants.indexed.map((entry) {
          final (rowIndex, variant) = entry;
          return Column(
            children: [
              _ServerVariantRow(
                variant: variant,
                choices: grouped[variant]!,
                selectedIndex: selectedIndex,
                onServerSelect: onServerSelect,
              ),
              if (rowIndex < variants.length - 1)
                Divider(height: 1, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ServerVariantRow extends StatelessWidget {
  final String variant;
  final List<({int index, VideoServerModel server})> choices;
  final int selectedIndex;
  final ValueChanged<int> onServerSelect;

  const _ServerVariantRow({
    required this.variant,
    required this.choices,
    required this.selectedIndex,
    required this.onServerSelect,
  });

  @override
  Widget build(BuildContext context) {
    final icon = variant == 'DUB'
        ? Icons.mic_none_rounded
        : Icons.subtitles_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent2),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              variant,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: choices.length,
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final choice = choices[i];
                  return _ServerChip(
                    label: choice.server.name,
                    active: choice.index == selectedIndex,
                    onTap: () => onServerSelect(choice.index),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ServerChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.accent2 : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent2 : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? Colors.black : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
