import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/episode_model.dart';
import '../../../shared/widgets/error_view.dart';
import '../../detail/data/detail_provider.dart';
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
      if (!mounted || _activeVideoUrl != videoUrl) {
        await _videoController?.dispose();
        _videoController = null;
        return;
      }

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
    final animeUrl = widget.animeUrl.isNotEmpty
        ? widget.animeUrl
        : _inferAnimeUrl(widget.episodeUrl);
    final detailAsync = animeUrl.isEmpty
        ? null
        : ref.watch(animeDetailProvider(animeUrl));

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
                  episodeUrl: widget.episodeUrl,
                  servers: servers,
                  selectedIndex: selectedIndex,
                  detailAsync: detailAsync,
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

  String _inferAnimeUrl(String episodeUrl) {
    final uri = Uri.tryParse(episodeUrl);
    if (uri == null || uri.pathSegments.length < 3) return '';
    final parentSegments = uri.pathSegments.take(uri.pathSegments.length - 1);
    return uri.replace(pathSegments: parentSegments).toString();
  }
}

class _PlayerInfo extends StatelessWidget {
  final String title;
  final String episodeUrl;
  final List<VideoServerModel> servers;
  final int selectedIndex;
  final AsyncValue<AnimeDetailData>? detailAsync;
  final ValueChanged<int> onServerSelect;

  const _PlayerInfo({
    required this.title,
    required this.episodeUrl,
    required this.servers,
    required this.selectedIndex,
    required this.detailAsync,
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
              const Text(
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
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
                  style: const TextStyle(
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showChevron)
            const Icon(
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

class _EpisodeInfoBody extends StatelessWidget {
  final String title;
  final AnimeModel? anime;
  final bool loading;

  const _EpisodeInfoBody({
    required this.title,
    this.anime,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            anime!.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accent2,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        if (metadata.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            metadata.join('  •  '),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
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
            style: const TextStyle(
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
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                sublabel,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
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
                const Divider(height: 1, color: AppColors.border),
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
              style: const TextStyle(
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
