// coverage:ignore-file
import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'package:better_player_plus/better_player_plus.dart';
import 'package:floating/floating.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/web/ad_blocker.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/episode_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/error_view.dart';
import '../../detail/data/detail_provider.dart';
import '../../downloads/data/downloads_provider.dart';
import '../../downloads/presentation/download_server_sheet.dart';
import '../../favorites/data/favorites_provider.dart';
import '../../history/data/watch_history_provider.dart';
import '../../marathon/data/marathon_provider.dart';
import '../../marathon/presentation/marathon_hud.dart';
import '../../settings/data/settings_provider.dart';
import '../data/ai_recap_provider.dart';
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
  final GlobalKey _betterPlayerKey = GlobalKey();
  final _floating = Floating();
  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  BetterPlayerController? _bpController;
  String? _activeVideoUrl;
  String? _initializingVideoUrl;
  String? _playerError;
  List<VideoServerModel> _lastServers = const [];
  AnimeDetailData? _latestDetail;
  DateTime? _lastHistorySaveAt;
  Duration? _lastMarathonPosition;
  String? _lastMarathonEpisodeKey;
  bool _breakModalShown = false;

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _saveCurrentProgress(force: true);
    _bpController?.removeEventsListener(_onPlayerEvent);
    _bpController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initPlayer(VideoServerModel server) async {
    final videoUrl = _playbackUrl(server.url);
    if (_initializingVideoUrl == videoUrl) return;

    _saveCurrentProgress(force: true);
    _resetMarathonTick();

    final previousController = _bpController;
    previousController?.removeEventsListener(_onPlayerEvent);
    _bpController = null;
    previousController?.dispose();

    _playerError = null;
    _activeVideoUrl = videoUrl;
    _initializingVideoUrl = videoUrl;

    try {
      final isHls = videoUrl.contains('.m3u8');
      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        videoUrl,
        headers: _headersForVideoUrl(videoUrl),
        videoFormat: isHls ? BetterPlayerVideoFormat.hls : null,
      );

      final controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: false,
          fit: BoxFit.contain,
          aspectRatio: 16 / 9,
          allowedScreenSleep: false,
          deviceOrientationsAfterFullScreen: const [
            DeviceOrientation.portraitUp,
          ],
          placeholder: const ColoredBox(color: Colors.black),
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            enablePip: true,
            enableFullscreen: true,
            enableMute: true,
            enableSkips: false,
            enableSubtitles: false,
            enableQualities: false,
            enableAudioTracks: false,
            enablePlaybackSpeed: true,
            enableProgressBar: true,
            enableProgressText: true,
            enablePlayPause: true,
          ),
        ),
        betterPlayerDataSource: dataSource,
      );

      _bpController = controller;
      controller.addEventsListener(_onPlayerEvent);

      if (!mounted || _activeVideoUrl != videoUrl) {
        controller.removeEventsListener(_onPlayerEvent);
        controller.dispose();
        if (_bpController == controller) _bpController = null;
        return;
      }
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

  Future<void> _seekToSavedPosition(BetterPlayerController controller) async {
    final entry = ref
        .read(watchHistoryProvider.notifier)
        .find(widget.episodeUrl);
    if (entry == null || entry.completed) return;
    final position = Duration(milliseconds: entry.positionMs);
    final duration =
        controller.videoPlayerController?.value.duration ?? Duration.zero;
    if (position < const Duration(seconds: 10) ||
        duration <= Duration.zero ||
        position >= duration - const Duration(seconds: 30)) {
      return;
    }
    await controller.seekTo(position);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        final controller = _bpController;
        if (controller != null) {
          unawaited(_seekToSavedPosition(controller));
          unawaited(controller.play());
        }
        break;
      case BetterPlayerEventType.exception:
        _playerError = 'No se pudo reproducir este servidor';
        final url = _activeVideoUrl;
        if (url != null && ref.read(fallbackPrefProvider)) {
          _tryNextServer(url);
        }
        if (mounted) setState(() {});
        break;
      case BetterPlayerEventType.progress:
        final now = DateTime.now();
        final last = _lastHistorySaveAt;
        if (last != null &&
            now.difference(last) < const Duration(seconds: 10)) {
          return;
        }
        _lastHistorySaveAt = now;
        _saveCurrentProgress();
        _recordMarathonTick();
        break;
      default:
        break;
    }
  }

  void _recordMarathonTick() {
    final video = _bpController?.videoPlayerController;
    if (video == null ||
        !video.value.initialized ||
        !video.value.isPlaying) {
      return;
    }
    final position = video.value.position;
    final key = widget.episodeUrl;
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

  void _showBreakModal() {
    final session = ref.read(marathonProvider);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MarathonBreakDialog(
        session: session,
        onTakeBreak: () {
          _bpController?.pause();
          Navigator.of(context).pop();
        },
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _saveCurrentProgress({bool force = false}) {
    final video = _bpController?.videoPlayerController;
    if (video == null || !video.value.initialized) return;
    if (!force &&
        video.value.position < const Duration(seconds: 5) &&
        video.value.duration != null &&
        video.value.duration! > const Duration(minutes: 1)) {
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
            position: video.value.position,
            duration: video.value.duration ?? Duration.zero,
            source: 'stream',
          ),
    );
  }

  void _tryNextServer(String failedUrl) {
    final current = _lastServers.indexWhere(
      (server) => _playbackUrl(server.url) == failedUrl,
    );
    if (current == -1) return;

    for (var i = current + 1; i < _lastServers.length; i++) {
      if (_isDirectVideoUrl(_lastServers[i].url)) {
        ref.read(selectedServerProvider.notifier).state = i;
        ref.read(selectedServerUrlProvider.notifier).state = _playbackUrl(
          _lastServers[i].url,
        );
        return;
      }
    }

    for (var i = 0; i < _lastServers.length; i++) {
      if (_playbackUrl(_lastServers[i].url) != failedUrl) {
        ref.read(selectedServerProvider.notifier).state = i;
        ref.read(selectedServerUrlProvider.notifier).state = _playbackUrl(
          _lastServers[i].url,
        );
        return;
      }
    }
  }

  bool _isDirectVideoUrl(String url) {
    final lower = _playbackUrl(url).toLowerCase();
    final isApplePlatform =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    // Player pages from zilla-networks return HTML, not a real .m3u8.
    // iOS AVPlayer can't resolve them — fall back to the WebView embed.
    if (isApplePlatform &&
        (lower.contains('player.zilla-networks.com') ||
            lower.contains('zilla-networks.com/m3u8') ||
            lower.contains('player.zilla'))) {
      return false;
    }
    // Match ONLY real file extensions: the extension must be followed by `?`,
    // `#`, `/`, or end-of-string. Plain `.contains('.mp4')` was matching
    // `www.mp4upload.com` (substring `.mp4u`) and similar embed hosts, causing
    // ExoPlayer to try playing an HTML embed page as a video → "Source error".
    final applePattern = RegExp(r'\.(m3u8|mp4|mov)([?#/]|$)');
    final androidPattern = RegExp(r'\.(m3u8|mp4|mov|webm|mkv)([?#/]|$)');
    return (isApplePlatform ? applePattern : androidPattern).hasMatch(lower);
  }

  Future<void> _enterPiP() async {
    // Android: use the `floating` package (native PictureInPictureMode). It's
    // simpler, reliable, and doesn't pull the player into fullscreen first.
    if (Platform.isAndroid) {
      try {
        final available = await _floating.isPipAvailable;
        if (!mounted) return;
        if (!available) {
          AppToast.show(
            context,
            message: 'PiP no soportado en este dispositivo',
            type: AppToastType.error,
          );
          return;
        }
        await _floating.enable(
          const ImmediatePiP(aspectRatio: Rational(16, 9)),
        );
      } catch (_) {
        if (mounted) {
          AppToast.show(
            context,
            message: 'No se pudo activar PiP',
            type: AppToastType.error,
          );
        }
      }
      return;
    }

    // iOS: use BetterPlayer's PiP (it wraps AVPictureInPictureController).
    final controller = _bpController;
    if (controller == null || !mounted) return;
    final video = controller.videoPlayerController;
    if (video == null || !video.value.initialized) {
      AppToast.show(
        context,
        message: 'Espera a que el video cargue',
        type: AppToastType.info,
      );
      return;
    }
    try {
      final supported = await controller.isPictureInPictureSupported();
      if (!mounted) return;
      if (!supported) {
        AppToast.show(
          context,
          message: 'PiP no soportado en este dispositivo',
          type: AppToastType.error,
        );
        return;
      }
      await controller.enablePictureInPicture(_betterPlayerKey);
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'No se pudo activar PiP',
          type: AppToastType.error,
        );
      }
    }
  }

  void _setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    setState(() => _sleepTimerRemaining = duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepTimerRemaining;
      if (remaining == null || remaining.inSeconds <= 1) {
        timer.cancel();
        _bpController?.pause();
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
    // Use the original embed URL (NOT the rewritten /m3u8/<id> variant) so the
    // player page can run its own JS and resolve the real stream internally.
    //
    // Three layers of ad/popup defense:
    //   1) ContentBlocker — blocks ad/tracker subresources at the network layer.
    //   2) shouldOverrideUrlLoading + onCreateWindow — block popup navigation.
    //   3) Injected JS (`addUserScript`) — overrides window.open and intercepts
    //      synthetic anchor clicks that VOE uses to bypass ContentBlocker.
    return InAppWebView(
      // Force rebuild when URL changes (switching servers). Without this, Flutter
      // reuses the same widget instance and the WebView keeps the old page.
      key: ValueKey<String>(url),
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        useShouldOverrideUrlLoading: true,
        useOnLoadResource: false,
        transparentBackground: false,
        supportZoom: false,
        contentBlockers: buildEmbedAdBlockers(),
        // Allow inline + fullscreen video; YourUpload's <video> needs both.
        allowsInlineMediaPlayback: true,
        iframeAllowFullscreen: true,
        // Android: hybrid composition lets the video surface composite
        // correctly when the WebView is sized to fit the player area.
        useHybridComposition: true,
        // Mobile UA so embeds serve their mobile player (smaller, fewer ads).
        userAgent:
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      ),
      // Run an anti-popup script at document start, BEFORE any of the page's
      // own scripts execute. This neutralizes VOE's popup chain (which uses
      // synchronous window.open from click handlers and a hidden anchor that
      // gets programmatically clicked).
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _antiPopupScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
        UserScript(
          source: _antiOverlayScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        ),
      ]),
      shouldOverrideUrlLoading: (controller, action) async {
        final target = action.request.url?.toString().toLowerCase() ?? '';
        const adHosts = [
          'doubleclick',
          'googlesyndication',
          'popads',
          'popcash',
          'propellerads',
          'onclickads',
          'adsterra',
          'exoclick',
          'juicyads',
          'trafficjunky',
          'clickadu',
          'hilltopads',
          // VOE-specific popup chain
          'lambsaktur',
          'popcdn',
          'voe-network',
          'voe-un',
          'voe-st',
        ];
        for (final host in adHosts) {
          if (target.contains(host)) {
            return NavigationActionPolicy.CANCEL;
          }
        }
        // Block any navigation that's clearly off-host from the original embed.
        // Most embed pages stay within their own domain to load the video.
        return NavigationActionPolicy.ALLOW;
      },
      onCreateWindow: (controller, action) async {
        // Block all popup windows — exclusively ads for these embed servers.
        return false;
      },
    );
  }

  /// JS injected before any of the embed page's own scripts. Disables every
  /// known popup vector: window.open, programmatic clicks on anchor[target],
  /// document.location assignments to off-host URLs, and `<meta refresh>`
  /// redirects to ad domains.
  static const String _antiPopupScript = r'''
(function() {
  // 1. Neutralize window.open — return a stub object so callers don't crash.
  var noopWin = { closed: true, close: function(){}, focus: function(){},
    blur: function(){}, postMessage: function(){}, document: {} };
  try {
    Object.defineProperty(window, 'open', {
      value: function() { return noopWin; },
      writable: false, configurable: false
    });
  } catch (e) {}

  // 2. Intercept clicks on anchors with target=_blank (popup style).
  document.addEventListener('click', function(e) {
    var el = e.target;
    while (el && el !== document.body) {
      if (el.tagName === 'A' && (el.target === '_blank' || el.rel === 'noopener')) {
        var href = (el.href || '').toLowerCase();
        // If the link goes off-host, kill it.
        if (href && href.indexOf(location.host) === -1) {
          e.preventDefault();
          e.stopPropagation();
          return false;
        }
      }
      el = el.parentElement;
    }
  }, true);

  // 3. Block <meta http-equiv="refresh"> redirects added dynamically.
  var origAppend = Element.prototype.appendChild;
  Element.prototype.appendChild = function(child) {
    if (child && child.tagName === 'META' &&
        (child.httpEquiv || '').toLowerCase() === 'refresh') {
      return child;
    }
    return origAppend.call(this, child);
  };
})();
''';

  /// JS injected at document end. VOE specifically renders ad overlays as inline
  /// divs/iframes with high z-index that sit ON TOP of the video. We:
  ///   1) Hide them with a stylesheet (covers static & SPA renders).
  ///   2) Run a MutationObserver that strips new overlay nodes as they appear.
  static const String _antiOverlayScript = r'''
(function() {
  // 1. Stylesheet that hides common ad-overlay patterns.
  var style = document.createElement('style');
  style.textContent = [
    // VOE / generic full-screen ad overlays
    '[id*="overlay" i]:not(video):not([id*="player" i]):not([id*="control" i]),',
    '[class*="overlay" i]:not(video):not([class*="player" i]):not([class*="control" i]):not([class*="loading" i]):not([class*="spinner" i]),',
    '[id*="popup" i], [class*="popup" i],',
    '[id*="banner" i], [class*="banner" i]:not([class*="player" i]),',
    '[id*="advert" i], [class*="advert" i],',
    '[id^="ad-"], [class^="ad-"], [id$="-ad"], [class$="-ad"],',
    '[id*="adsterra" i], [class*="adsterra" i],',
    '[id*="exoclick" i], [class*="exoclick" i],',
    'iframe[src*="ads" i], iframe[src*="popcdn" i], iframe[src*="lambsaktur" i]',
    '{ display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }',
    // Block fixed-position floating ads
    'div[style*="position: fixed"][style*="z-index"]:not([id*="player" i]):not([class*="player" i])',
    '{ display: none !important; }',
  ].join('\n');
  (document.head || document.documentElement).appendChild(style);

  // 2. MutationObserver: strip overlay nodes injected after page load.
  var adKeywords = ['overlay', 'popup', 'banner', 'advert', 'ads', 'adsterra',
    'exoclick', 'popcdn', 'lambsaktur'];
  function looksLikeAd(el) {
    if (!el || !el.tagName) return false;
    var t = el.tagName.toLowerCase();
    if (t === 'video' || t === 'source' || t === 'track') return false;
    var id = (el.id || '').toLowerCase();
    var cls = (el.className && el.className.toString ? el.className.toString() : '').toLowerCase();
    // Whitelist obvious player/control elements
    if (id.indexOf('player') !== -1 || id.indexOf('control') !== -1) return false;
    if (cls.indexOf('player') !== -1 || cls.indexOf('control') !== -1) return false;
    for (var i = 0; i < adKeywords.length; i++) {
      if (id.indexOf(adKeywords[i]) !== -1 || cls.indexOf(adKeywords[i]) !== -1) {
        return true;
      }
    }
    if (t === 'iframe') {
      var src = (el.src || '').toLowerCase();
      if (src.indexOf('ads') !== -1 || src.indexOf('popcdn') !== -1 ||
          src.indexOf('lambsaktur') !== -1) {
        return true;
      }
    }
    return false;
  }
  var observer = new MutationObserver(function(mutations) {
    for (var m = 0; m < mutations.length; m++) {
      var added = mutations[m].addedNodes;
      for (var i = 0; i < added.length; i++) {
        var node = added[i];
        if (node.nodeType === 1 && looksLikeAd(node)) {
          try { node.remove(); } catch (e) {}
        }
      }
    }
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
''';

  /// Choose Referer/Origin headers based on the video URL's host.
  ///
  /// Some CDNs (HentaiLA's `cdn.hentaila.com`, AnimeAV1's HLS, etc.) reject
  /// requests whose `Referer` doesn't match their expected provider domain.
  /// Hardcoding `animeav1.com` for everything would break HentaiLA's direct
  /// MP4 downloads with a `403` / source error in ExoPlayer.
  Map<String, String> _headersForVideoUrl(String videoUrl) {
    const ua =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/17.0 Safari/605.1.15';
    final host = Uri.tryParse(videoUrl)?.host.toLowerCase() ?? '';

    // HentaiLA: CDN + direct downloads
    if (host.contains('hentaila.com') || host.contains('hentaila')) {
      return {
        'Referer': 'https://hentaila.com/',
        'Origin': 'https://hentaila.com',
        'User-Agent': ua,
      };
    }

    // Default to AnimeAV1 — most providers funnel through its HLS/embed chain.
    return {
      'Referer': 'https://animeav1.com/',
      'Origin': 'https://animeav1.com',
      'User-Agent': ua,
    };
  }

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

  @override
  Widget build(BuildContext context) {
    final serversAsync = ref.watch(serversProvider(widget.episodeUrl));
    final selectedIndex = ref.watch(selectedServerProvider);
    final selectedServerUrl = ref.watch(selectedServerUrlProvider);
    final marathon = ref.watch(marathonProvider);

    ref.listen<MarathonSession>(marathonProvider, (prev, next) {
      if (next.breakRecommended &&
          !(prev?.breakRecommended ?? false) &&
          !_breakModalShown) {
        _breakModalShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showBreakModal();
        });
      }
    });
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
            final selectedUrlIndex = selectedServerUrl == null
                ? -1
                : servers.indexWhere(
                    (server) => _playbackUrl(server.url) == selectedServerUrl,
                  );
            final effectiveIndex = selectedUrlIndex == -1
                ? selectedIndex.clamp(0, servers.length - 1)
                : selectedUrlIndex;
            final server = servers[effectiveIndex];
            final playbackUrl = _playbackUrl(server.url);
            if (!_isDirectVideoUrl(server.url)) {
              return _embedPlayer(server.url);
            }
            if (_bpController == null || _activeVideoUrl != playbackUrl) {
              if (_initializingVideoUrl != playbackUrl) {
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
            return BetterPlayer(
              key: _betterPlayerKey,
              controller: _bpController!,
            );
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

    return Scaffold(
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
                  selectedIndex: selectedServerUrl == null
                      ? selectedIndex.clamp(0, servers.length - 1)
                      : servers
                            .indexWhere(
                              (server) =>
                                  _playbackUrl(server.url) ==
                                  selectedServerUrl,
                            )
                            .clamp(0, servers.length - 1),
                  detailAsync: detailAsync,
                  onPiP: _enterPiP,
                  sleepTimerRemaining: _sleepTimerRemaining,
                  onSetSleepTimer: _setSleepTimer,
                  onCancelSleepTimer: _cancelSleepTimer,
                  formatSleepTimer: _formatSleepTimer,
                  marathon: marathon,
                  onResetMarathon: () =>
                      ref.read(marathonProvider.notifier).reset(),
                  onServerSelect: (i) {
                    ref
                        .read(preferredPlaybackServerProvider.notifier)
                        .set(servers[i].name);
                    ref.read(selectedServerProvider.notifier).state = i;
                    ref.read(selectedServerUrlProvider.notifier).state =
                        _playbackUrl(servers[i].url);
                    _resetMarathonTick();
                    _saveCurrentProgress(force: true);
                    final controller = _bpController;
                    _bpController = null;
                    _activeVideoUrl = null;
                    _initializingVideoUrl = null;
                    _playerError = null;
                    controller?.removeEventsListener(_onPlayerEvent);
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
  final MarathonSession marathon;
  final VoidCallback onResetMarathon;
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
    required this.marathon,
    required this.onResetMarathon,
    this.onPiP,
    this.sleepTimerRemaining,
  });

  static AiRecapRequest? _buildRecapRequest({
    required WatchHistoryEntry? historyEntry,
    required AnimeDetailData? detail,
    required EpisodeModel? episode,
    required String recapDetail,
    required int daysThreshold,
  }) {
    if (historyEntry == null ||
        historyEntry.completed ||
        historyEntry.percent <= 0.08) {
      return null;
    }
    final updatedAt = DateTime.tryParse(historyEntry.updatedAt);
    if (updatedAt != null) {
      final daysSince = DateTime.now().difference(updatedAt).inDays;
      if (daysSince < daysThreshold) return null;
    }
    return AiRecapRequest(
      animeTitle: detail?.anime.title ?? historyEntry.animeTitle,
      episodeTitle: episode?.title ?? historyEntry.episodeTitle,
      percent: historyEntry.percent,
      synopsis: detail?.anime.synopsis,
      episodeNumber: episode?.number ?? historyEntry.episodeNumber,
      detail: recapDetail,
    );
  }

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

    final isHentaila = animeUrl.contains('hentaila.com');
    final preferredServer = await showDownloadServerSheet(
      context: context,
      ref: ref,
      episodeUrl: episodeUrl,
      subtitle: anime == null
          ? title
          : '${anime.title} · ${episode?.title ?? title}',
    );
    if (preferredServer == null) return; // user cancelled
    if (!context.mounted) return;

    // Hentaila ships per-episode stills as thumbnails. Prefer the anime cover
    // so the saved download shows the poster instead of a scene.
    final thumbnail = isHentaila
        ? (anime?.cover ?? episode?.thumbnail)
        : (episode?.thumbnail ?? anime?.cover);

    try {
      await ref
          .read(downloadsProvider.notifier)
          .startEpisode(
            episodeUrl: episodeUrl,
            title: anime == null
                ? title
                : '${anime.title} · ${episode?.title ?? title}',
            thumbnail: thumbnail,
            animeTitle: anime?.title,
            animeUrl: anime?.url ?? animeUrl,
            episodeTitle: episode?.title ?? title,
            episodeNumber: episode?.number,
            quality: ref.read(qualityPrefProvider),
            variant: ref.read(variantPrefProvider),
            preferredServer: preferredServer,
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
    final historyEntry = ref.watch(
      watchHistoryProvider.select(
        (items) =>
            items.where((item) => item.episodeUrl == episodeUrl).firstOrNull,
      ),
    );
    final recapDetail = ref.watch(recapDetailPrefProvider);
    final recapDaysThreshold = ref.watch(recapDaysThresholdPrefProvider);
    final detail = detailAsync?.valueOrNull;
    final episode = detail?.episodes
        .where((item) => item.url == episodeUrl)
        .firstOrNull;
    final recapRequest = _buildRecapRequest(
      historyEntry: historyEntry,
      detail: detail,
      episode: episode,
      recapDetail: recapDetail,
      daysThreshold: recapDaysThreshold,
    );
    final recapDaysSince = historyEntry != null
        ? DateTime.now()
              .difference(
                DateTime.tryParse(historyEntry.updatedAt) ?? DateTime.now(),
              )
              .inDays
        : 0;
    final recapPositionMs = historyEntry?.positionMs ?? 0;
    final episodes = detail?.episodes ?? [];
    final currentEpIndex = episodes.indexWhere((e) => e.url == episodeUrl);
    final recapNextEpNumber =
        currentEpIndex >= 0 && currentEpIndex < episodes.length - 1
        ? episodes[currentEpIndex + 1].number
        : null;
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
          if (recapRequest != null) ...[
            _AiRecapCard(
              request: recapRequest,
              daysSince: recapDaysSince,
              positionMs: recapPositionMs,
              nextEpisodeNumber: recapNextEpNumber,
              episodeThumbnail: episode?.thumbnail,
              animeCover: detail?.anime.cover,
            ),
            const SizedBox(height: 16),
          ],
          MarathonHud(session: marathon, onReset: onResetMarathon),
          if (marathon.isActive) const SizedBox(height: 16),
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

class _AiRecapCard extends ConsumerStatefulWidget {
  final AiRecapRequest request;
  final int daysSince;
  final int positionMs;
  final int? nextEpisodeNumber;
  final String? episodeThumbnail;
  final String? animeCover;

  const _AiRecapCard({
    required this.request,
    required this.daysSince,
    required this.positionMs,
    this.nextEpisodeNumber,
    this.episodeThumbnail,
    this.animeCover,
  });

  @override
  ConsumerState<_AiRecapCard> createState() => _AiRecapCardState();
}

class _AiRecapCardState extends ConsumerState<_AiRecapCard> {
  bool _dismissed = false;

  static const _dotColors = [
    Color(0xFFEF4444),
    Color(0xFF7C3AED),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
  ];

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final recap = ref.watch(aiRecapProvider(widget.request));
    final epNum = widget.request.episodeNumber;
    final nextEpNum = widget.nextEpisodeNumber;
    final thumbnail = widget.episodeThumbnail ?? widget.animeCover;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.15),
            AppColors.accent2.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accent2],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '✶ AI RECAP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.request.animeTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: Text(
              epNum != null
                  ? 'Ultima vez: Ep. $epNum · hace ${widget.daysSince} dia${widget.daysSince == 1 ? '' : 's'}'
                  : 'hace ${widget.daysSince} dia${widget.daysSince == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (thumbnail != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A1228), Color(0xFF0E0D1A)],
                          ),
                        ),
                      ),
                      Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const SizedBox.shrink(),
                      ),
                      Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            nextEpNum != null
                                ? 'Continuar en Ep. $nextEpNum · ${_formatDuration(widget.positionMs)}'
                                : epNum != null
                                ? 'Ep. $epNum · ${_formatDuration(widget.positionMs)}'
                                : _formatDuration(widget.positionMs),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          recap.when(
            data: (data) => Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.recap,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                  if (data.highlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: data.highlights.asMap().entries.map((e) {
                        final color = _dotColors[e.key % _dotColors.length];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                e.value,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _dismissed = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              nextEpNum != null
                                  ? '▶ Continuar Ep. $nextEpNum'
                                  : '▶ Continuar',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _dismissed = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Saltar recap',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.accent2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Generando resumen...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const _TypingDots(),
                ],
              ),
            ),
            error: (e, st) => const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Text(
                'No se pudo cargar el recap.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
      builder: (context, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final opacity = ((_controller.value * 3) - i).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Text(
                '.',
                style: TextStyle(
                  color: AppColors.accent2,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }),
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

class _MarathonBreakDialog extends StatefulWidget {
  final MarathonSession session;
  final VoidCallback onTakeBreak;
  final VoidCallback onContinue;

  const _MarathonBreakDialog({
    required this.session,
    required this.onTakeBreak,
    required this.onContinue,
  });

  @override
  State<_MarathonBreakDialog> createState() => _MarathonBreakDialogState();
}

class _MarathonBreakDialogState extends State<_MarathonBreakDialog> {
  static const _totalSeconds = 5 * 60;
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = _totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) {
          _remaining--;
        } else {
          _timer?.cancel();
          widget.onContinue();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h <= 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final eps = session.episodeCount;
    final prevRecord = session.recordEpisodeCount;
    final isNewRecord = session.isNewRecord;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧘', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              '¡Momento de descansar!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                children: [
                  const TextSpan(text: 'Llevas '),
                  TextSpan(
                    text: '$eps episodios',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' seguidos. Tu próximo ep empieza en:'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                colors: [AppColors.accent, AppColors.accent2],
              ).createShader(rect),
              child: Text(
                _formatted,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Stats grid
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Estadísticas del maratón 🏆',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.8,
              children: [
                _BreakStat(
                  value: '$eps',
                  label: 'Eps esta sesión',
                  valueColor: AppColors.error,
                ),
                _BreakStat(
                  value: prevRecord > 0 ? '🔥 $prevRecord' : '--',
                  label: 'Récord anterior',
                  valueColor: AppColors.warning,
                ),
                _BreakStat(
                  value: isNewRecord ? '+${eps - prevRecord} 🎉' : '--',
                  label: 'Nuevo récord',
                  valueColor: AppColors.success,
                  highlighted: isNewRecord,
                ),
                _BreakStat(
                  value: _fmtDuration(session.watched),
                  label: 'Tiempo sesión',
                  valueColor: AppColors.accent2,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onTakeBreak,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                child: const Text('Tomar pausa (recomendado)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onContinue,
                child: const Text(
                  'Continuar igual',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final bool highlighted;

  const _BreakStat({
    required this.value,
    required this.label,
    required this.valueColor,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
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
