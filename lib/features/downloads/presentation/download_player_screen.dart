// coverage:ignore-file
import 'dart:async';
import 'dart:io';

import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/download_model.dart';
import '../data/downloads_provider.dart';
import '../../history/data/watch_history_provider.dart';
import '../../marathon/data/marathon_provider.dart';
import '../../marathon/presentation/marathon_hud.dart';

class DownloadPlayerScreen extends ConsumerStatefulWidget {
  final String? downloadId;
  final String title;
  final String localPath;
  final String? animeTitle;

  const DownloadPlayerScreen({
    super.key,
    this.downloadId,
    required this.title,
    required this.localPath,
    this.animeTitle,
  });

  @override
  ConsumerState<DownloadPlayerScreen> createState() =>
      _DownloadPlayerScreenState();
}

class _DownloadPlayerScreenState extends ConsumerState<DownloadPlayerScreen> {
  final _floating = Floating();
  VideoPlayerController? _controller;
  Object? _error;
  bool _showControls = true;
  bool _isFullscreen = false;
  double _speed = 1;
  late String? _activeDownloadId;
  late String _activePath;
  bool _hasStartedCurrentVideo = false;
  Timer? _hideControlsTimer;
  DateTime? _lastHistorySaveAt;
  Duration? _lastMarathonPosition;
  String? _lastMarathonEpisodeKey;

  @override
  void initState() {
    super.initState();
    _activeDownloadId = widget.downloadId;
    _activePath = widget.localPath;
    _initialize(_activePath);
  }

  Future<void> _initialize(String path, {bool autoPlay = false}) async {
    _hideControlsTimer?.cancel();
    final previous = _controller;
    _saveCurrentProgress(force: true);
    _resetMarathonTick();
    previous?.removeListener(_onVideoTick);
    setState(() {
      _controller = null;
      _error = null;
      _showControls = true;
      _hasStartedCurrentVideo = false;
    });
    await previous?.dispose();

    try {
      final uri = Uri.parse(path);
      final controller = uri.scheme == 'content'
          ? VideoPlayerController.contentUri(uri)
          : VideoPlayerController.file(File(path));

      await controller.initialize();
      await controller.setPlaybackSpeed(_speed);
      await _seekToSavedPosition(controller, path);
      await controller.pause();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onVideoTick);
      setState(() => _controller = controller);
      if (autoPlay) await controller.play();
      _scheduleControlsHide();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _onVideoTick() {
    final now = DateTime.now();
    final last = _lastHistorySaveAt;
    if (last == null || now.difference(last) >= const Duration(seconds: 10)) {
      _lastHistorySaveAt = now;
      _saveCurrentProgress();
      _recordMarathonTick();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _saveCurrentProgress(force: true);
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    _restorePortraitChrome();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);
    final current = _currentDownload(downloads);
    final title = current?.displayEpisodeTitle ?? widget.title;
    final animeTitle = current?.albumTitle ?? widget.animeTitle ?? 'AnimeRoll';
    final episodes = _albumEpisodes(downloads, current);
    final marathon = ref.watch(marathonProvider);

    final videoStage = _VideoStage(
      controller: _controller,
      error: _error,
      title: title,
      animeTitle: animeTitle,
      speed: _speed,
      showControls: _showControls,
      fullscreen: _isFullscreen,
      onBack: _isFullscreen ? _exitFullscreen : () => context.pop(),
      onToggleControls: _toggleControls,
      onTogglePlay: _togglePlay,
      onSeekRelative: _seekRelative,
      onSeekToFraction: _seekToFraction,
      onSpeedTap: _cycleSpeed,
      onFullscreenTap: _isFullscreen ? _exitFullscreen : _enterFullscreen,
      onPiP: _enterPiP,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isFullscreen) {
          await _exitFullscreen();
          return;
        }
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
          child: Center(
            child: _VideoStage(
              controller: _controller,
              error: _error,
              title: title,
              animeTitle: animeTitle,
              speed: _speed,
              showControls: false,
              fullscreen: false,
              onBack: () {},
              onToggleControls: () {},
              onTogglePlay: _togglePlay,
              onSeekRelative: _seekRelative,
              onSeekToFraction: _seekToFraction,
              onSpeedTap: _cycleSpeed,
              onFullscreenTap: () {},
            ),
          ),
        ),
        childWhenDisabled: Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            top: !_isFullscreen,
            bottom: !_isFullscreen,
            child: _isFullscreen
                ? videoStage
                : Column(
                    children: [
                      videoStage,
                      Expanded(
                        child: _InfoPanel(
                          current: current,
                          fallbackTitle: title,
                          fallbackAnimeTitle: animeTitle,
                          duration: _controller?.value.duration,
                          episodes: episodes,
                          marathon: marathon,
                          onResetMarathon: () =>
                              ref.read(marathonProvider.notifier).reset(),
                          onEpisodeTap: _openEpisode,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  DownloadModel? _currentDownload(List<DownloadModel> downloads) {
    if (_activeDownloadId != null && _activeDownloadId!.isNotEmpty) {
      return downloads
          .where((item) => item.id == _activeDownloadId)
          .firstOrNull;
    }
    return downloads.where((item) => item.localPath == _activePath).firstOrNull;
  }

  List<DownloadModel> _albumEpisodes(
    List<DownloadModel> downloads,
    DownloadModel? current,
  ) {
    if (current == null) return const [];
    final episodes = downloads
        .where(
          (item) => item.albumKey == current.albumKey && item.isSavedOnDevice,
        )
        .toList();
    episodes.sort(
      (a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0),
    );
    return episodes;
  }

  Future<void> _openEpisode(DownloadModel episode) async {
    final path = episode.localPath;
    if (path == null || path.isEmpty || path == _currentPath) return;
    _saveCurrentProgress(force: true);
    _resetMarathonTick();
    _activeDownloadId = episode.id;
    _activePath = path;
    await _initialize(path);
  }

  Future<void> _seekToSavedPosition(
    VideoPlayerController controller,
    String path,
  ) async {
    final key = _historyKey(path);
    final entry = ref.read(watchHistoryProvider.notifier).find(key);
    if (entry == null || entry.completed) {
      await controller.seekTo(Duration.zero);
      return;
    }
    final position = Duration(milliseconds: entry.positionMs);
    final duration = controller.value.duration;
    if (position < const Duration(seconds: 10) ||
        duration <= Duration.zero ||
        position >= duration - const Duration(seconds: 30)) {
      await controller.seekTo(Duration.zero);
      return;
    }
    await controller.seekTo(position);
  }

  void _saveCurrentProgress({bool force = false}) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!force &&
        controller.value.position < const Duration(seconds: 5) &&
        controller.value.duration > const Duration(minutes: 1)) {
      return;
    }

    final current = _currentDownload(ref.read(downloadsProvider));
    final key = current?.url.isNotEmpty == true ? current!.url : _activePath;
    unawaited(
      ref
          .read(watchHistoryProvider.notifier)
          .upsertProgress(
            episodeUrl: key,
            episodeTitle: current?.displayEpisodeTitle ?? widget.title,
            animeTitle: current?.albumTitle ?? widget.animeTitle ?? 'AnimeRoll',
            animeUrl: current?.animeUrl ?? '',
            thumbnail: current?.thumbnail,
            episodeNumber: current?.episodeNumber,
            position: controller.value.position,
            duration: controller.value.duration,
            source: 'download',
          ),
    );
  }

  String _historyKey(String path) {
    final current = _currentDownload(ref.read(downloadsProvider));
    return current?.url.isNotEmpty == true ? current!.url : path;
  }

  String get _currentPath {
    final current = _currentDownload(ref.read(downloadsProvider));
    return current?.localPath ?? _activePath;
  }

  void _recordMarathonTick() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying) {
      return;
    }
    final key = _historyKey(_activePath);
    final position = controller.value.position;
    final previous = _lastMarathonEpisodeKey == key
        ? _lastMarathonPosition
        : null;
    _lastMarathonEpisodeKey = key;
    _lastMarathonPosition = position;
    if (previous == null) return;
    final delta = position - previous;
    unawaited(
      ref
          .read(marathonProvider.notifier)
          .recordPlayback(episodeKey: key, delta: delta),
    );
  }

  void _resetMarathonTick() {
    _lastMarathonPosition = null;
    _lastMarathonEpisodeKey = null;
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (!_hasStartedCurrentVideo) {
        await controller.seekTo(Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (!mounted || _controller != controller) return;
        _hasStartedCurrentVideo = true;
      }
      await controller.play();
    }
    _scheduleControlsHide();
  }

  Future<void> _seekRelative(Duration offset) async {
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    final target = controller.value.position + offset;
    final bounded = target < Duration.zero
        ? Duration.zero
        : target > duration
        ? duration
        : target;
    await controller.seekTo(bounded);
    _hasStartedCurrentVideo = true;
    _scheduleControlsHide();
  }

  Future<void> _seekToFraction(double fraction) async {
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    await controller.seekTo(duration * fraction.clamp(0, 1));
    _hasStartedCurrentVideo = true;
    _scheduleControlsHide();
  }

  Future<void> _cycleSpeed() async {
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
    final next = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    setState(() => _speed = next);
    await _controller?.setPlaybackSpeed(next);
    _scheduleControlsHide();
  }

  Future<void> _enterPiP() async {
    final available = await _floating.isPipAvailable;
    if (!available || !mounted) return;
    if (_isFullscreen) {
      setState(() {
        _isFullscreen = false;
        _showControls = true;
      });
      await _restorePortraitChrome();
    }
    await _floating.enable(const ImmediatePiP(aspectRatio: Rational(16, 9)));
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _hideControlsTimer?.cancel();
    if (_controller?.value.isPlaying != true) return;
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _enterFullscreen() async {
    setState(() {
      _isFullscreen = true;
      _showControls = true;
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _scheduleControlsHide();
  }

  Future<void> _exitFullscreen() async {
    if (!_isFullscreen) {
      context.pop();
      return;
    }
    setState(() {
      _isFullscreen = false;
      _showControls = true;
    });
    await _restorePortraitChrome();
  }

  Future<void> _restorePortraitChrome() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}

class _VideoStage extends StatelessWidget {
  final VideoPlayerController? controller;
  final Object? error;
  final String title;
  final String animeTitle;
  final double speed;
  final bool showControls;
  final bool fullscreen;
  final VoidCallback onBack;
  final VoidCallback onToggleControls;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeekRelative;
  final ValueChanged<double> onSeekToFraction;
  final VoidCallback onSpeedTap;
  final VoidCallback onFullscreenTap;
  final VoidCallback? onPiP;

  const _VideoStage({
    required this.controller,
    required this.error,
    required this.title,
    required this.animeTitle,
    required this.speed,
    required this.showControls,
    required this.fullscreen,
    required this.onBack,
    required this.onToggleControls,
    required this.onTogglePlay,
    required this.onSeekRelative,
    required this.onSeekToFraction,
    required this.onSpeedTap,
    required this.onFullscreenTap,
    this.onPiP,
  });

  @override
  Widget build(BuildContext context) {
    final video = controller;
    final value = video?.value;
    final ready = value?.isInitialized == true;
    final aspectRatio = fullscreen ? null : 16 / 9;

    return GestureDetector(
      onTap: onToggleControls,
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: fullscreen ? double.infinity : null,
        child: AspectRatio(
          aspectRatio: aspectRatio ?? (value?.aspectRatio ?? 16 / 9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: value!.size.width,
                    height: value.size.height,
                    child: VideoPlayer(video!),
                  ),
                )
              else
                _VideoPlaceholder(error: error),
              AnimatedOpacity(
                opacity: showControls ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: IgnorePointer(
                  ignoring: !showControls,
                  child: _VideoOverlay(
                    controller: controller,
                    title: title,
                    animeTitle: animeTitle,
                    speed: speed,
                    onBack: onBack,
                    onTogglePlay: onTogglePlay,
                    onSeekRelative: onSeekRelative,
                    onSeekToFraction: onSeekToFraction,
                    onSpeedTap: onSpeedTap,
                    onFullscreenTap: onFullscreenTap,
                    onPiP: onPiP,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  final Object? error;

  const _VideoPlaceholder({this.error});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0A14), Color(0xFF12101E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: error == null
            ? CircularProgressIndicator(color: AppColors.accent2)
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 42,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No se pudo reproducir el archivo local',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
      ),
    );
  }
}

class _VideoOverlay extends StatelessWidget {
  final VideoPlayerController? controller;
  final String title;
  final String animeTitle;
  final double speed;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeekRelative;
  final ValueChanged<double> onSeekToFraction;
  final VoidCallback onSpeedTap;
  final VoidCallback onFullscreenTap;
  final VoidCallback? onPiP;

  const _VideoOverlay({
    required this.controller,
    required this.title,
    required this.animeTitle,
    required this.speed,
    required this.onBack,
    required this.onTogglePlay,
    required this.onSeekRelative,
    required this.onSeekToFraction,
    required this.onSpeedTap,
    required this.onFullscreenTap,
    this.onPiP,
  });

  @override
  Widget build(BuildContext context) {
    final value = controller?.value;
    final ready = value?.isInitialized == true;
    final position = value?.position ?? Duration.zero;
    final duration = value?.duration ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;
    final buffered = _bufferedFraction(value);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Color(0x15000000),
            Color(0x15000000),
            Color(0xDD000000),
          ],
          stops: [0, 0.28, 0.62, 1],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                _OverlayIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: 'Volver',
                  onTap: onBack,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        animeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.accent2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSpeedTap,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                _OverlayIconButton(
                  icon: value?.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  tooltip: 'Volumen',
                  onTap: () {
                    final video = controller;
                    if (video == null) return;
                    video.setVolume(video.value.volume == 0 ? 1 : 0);
                  },
                ),
                if (onPiP != null)
                  _OverlayIconButton(
                    icon: Icons.picture_in_picture_alt_rounded,
                    tooltip: 'Picture in Picture',
                    onTap: ready ? onPiP : null,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkipButton(
                  icon: Icons.replay_10_rounded,
                  onTap: ready
                      ? () => onSeekRelative(const Duration(seconds: -10))
                      : null,
                ),
                const SizedBox(width: 26),
                _PlayButton(
                  isPlaying: value?.isPlaying == true,
                  onTap: ready ? onTogglePlay : null,
                ),
                const SizedBox(width: 26),
                _SkipButton(
                  icon: Icons.forward_10_rounded,
                  onTap: ready
                      ? () => onSeekRelative(const Duration(seconds: 10))
                      : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: ready
                          ? (details) => onSeekToFraction(
                              details.localPosition.dx / constraints.maxWidth,
                            )
                          : null,
                      child: SizedBox(
                        height: 20,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: buffered.clamp(0, 1),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress.clamp(0, 1),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.accent,
                                      AppColors.accent2,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            Positioned(
                              left:
                                  (constraints.maxWidth * progress.clamp(0, 1))
                                      .clamp(0, constraints.maxWidth - 10),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent2,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '/',
                        style: TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Pantalla completa',
                      visualDensity: VisualDensity.compact,
                      onPressed: ready ? onFullscreenTap : null,
                      icon: Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _bufferedFraction(VideoPlayerValue? value) {
    if (value == null ||
        value.duration.inMilliseconds == 0 ||
        value.buffered.isEmpty) {
      return 0;
    }
    final end = value.buffered.last.end.inMilliseconds;
    return end / value.duration.inMilliseconds;
  }
}

class _OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SkipButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Saltar',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
        fixedSize: const Size(48, 48),
      ),
      icon: Icon(icon, color: Colors.white, size: 28),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onTap;

  const _PlayButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isPlaying ? 'Pausar' : 'Reproducir',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.accent,
        disabledBackgroundColor: AppColors.border,
        fixedSize: const Size(64, 64),
        shadowColor: AppColors.accent2,
        elevation: 12,
      ),
      icon: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final DownloadModel? current;
  final String fallbackTitle;
  final String fallbackAnimeTitle;
  final Duration? duration;
  final List<DownloadModel> episodes;
  final MarathonSession marathon;
  final VoidCallback onResetMarathon;
  final ValueChanged<DownloadModel> onEpisodeTap;

  const _InfoPanel({
    required this.current,
    required this.fallbackTitle,
    required this.fallbackAnimeTitle,
    required this.duration,
    required this.episodes,
    required this.marathon,
    required this.onResetMarathon,
    required this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = current?.displayEpisodeTitle ?? fallbackTitle;
    final animeTitle = current?.albumTitle ?? fallbackAnimeTitle;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          animeTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: AppColors.accent2,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        MarathonHud(session: marathon, onReset: onResetMarathon),
        if (marathon.isActive) const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            const _InfoChip(
              icon: Icons.folder_rounded,
              label: 'Almacenamiento local',
            ),
            _InfoChip(
              icon: Icons.high_quality_rounded,
              label: current?.quality ?? 'Video',
            ),
            _InfoChip(
              icon: Icons.subtitles_rounded,
              label: current?.variant ?? 'Local',
            ),
            if (duration != null)
              _InfoChip(
                icon: Icons.timer_rounded,
                label: _formatDuration(duration!),
              ),
          ],
        ),
        if (episodes.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Mas episodios descargados',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final episode in episodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EpisodeTile(
                episode: episode,
                active: episode.id == current?.id,
                onTap: () => onEpisodeTap(episode),
              ),
            ),
        ],
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final DownloadModel episode;
  final bool active;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: active ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.surface,
          border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.displayEpisodeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? AppColors.accent2 : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${episode.quality} - ${episode.variant}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            active
                ? const _Equalizer()
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
          ],
        ),
      ),
    );
  }
}

class _Equalizer extends StatefulWidget {
  const _Equalizer();

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        return Row(
          children: [
            _bar(6 + value * 8),
            const SizedBox(width: 2),
            _bar(12 - value * 6),
            const SizedBox(width: 2),
            _bar(8 + value * 5),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.accent2,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
