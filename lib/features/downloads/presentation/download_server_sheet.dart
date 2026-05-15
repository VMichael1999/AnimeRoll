import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/episode_model.dart';
import '../../home/data/home_provider.dart';
import '../../settings/data/settings_provider.dart';

/// Server picker shown when the user taps "Download". Returns the chosen
/// server name (passed as `preferredServer` to the API) or `null` if the user
/// dismissed the sheet.
Future<String?> showDownloadServerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String episodeUrl,
  String? subtitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _DownloadServerSheet(
      episodeUrl: episodeUrl,
      subtitle: subtitle,
      variantPref: ref.read(variantPrefProvider),
    ),
  );
}

class _DownloadServerSheet extends ConsumerStatefulWidget {
  final String episodeUrl;
  final String? subtitle;
  final String variantPref;

  const _DownloadServerSheet({
    required this.episodeUrl,
    required this.subtitle,
    required this.variantPref,
  });

  @override
  ConsumerState<_DownloadServerSheet> createState() =>
      _DownloadServerSheetState();
}

class _DownloadServerSheetState extends ConsumerState<_DownloadServerSheet> {
  // Server names in priority order (mirrors backend SERVER_PRIORITY). The
  // first server present in the response with a matching variant is marked as
  // recommended.
  static const _priority = <String>[
    'vip',
    'yourupload',
    'pdrain',
    '1fichier',
    'mp4upload',
    'upnshare',
    'hls',
    'mega',
  ];

  late final Future<List<VideoServerModel>> _serversFuture;

  @override
  void initState() {
    super.initState();
    _serversFuture =
        ref.read(animeRepositoryProvider).getVideoServers(widget.episodeUrl);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Descargar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: FutureBuilder<List<VideoServerModel>>(
                future: _serversFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No se pudieron cargar los servidores',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final servers = _filterAndRank(snapshot.data ?? const []);
                  if (servers.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'Sin servidores disponibles para descargar',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: servers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final entry = servers[i];
                      return _ServerCard(
                        server: entry.server,
                        recommended: i == 0,
                        onTap: () =>
                            Navigator.of(context).pop(entry.server.name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_RankedServer> _filterAndRank(List<VideoServerModel> servers) {
    final variant = widget.variantPref.toUpperCase();
    final matchingVariant = servers
        .where((server) =>
            server.url.isNotEmpty &&
            (server.variant.toUpperCase() == variant ||
                server.variant.isEmpty))
        .toList();
    final pool =
        matchingVariant.isEmpty ? servers.where((s) => s.url.isNotEmpty).toList() : matchingVariant;

    final scored = pool.map((server) {
      final name = server.name.toLowerCase();
      final priorityIndex =
          _priority.indexWhere((p) => name.contains(p));
      return _RankedServer(
        server: server,
        score: priorityIndex == -1 ? 999 : priorityIndex,
      );
    }).toList()
      ..sort((a, b) => a.score.compareTo(b.score));

    return scored;
  }
}

class _RankedServer {
  final VideoServerModel server;
  final int score;
  _RankedServer({required this.server, required this.score});
}

class _ServerCard extends StatelessWidget {
  final VideoServerModel server;
  final bool recommended;
  final VoidCallback onTap;

  const _ServerCard({
    required this.server,
    required this.recommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: recommended
              ? AppColors.accent.withValues(alpha: 0.08)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: recommended
                ? AppColors.accent2.withValues(alpha: 0.5)
                : AppColors.border,
            width: recommended ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: recommended
                    ? AppColors.accent.withValues(alpha: 0.2)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.cloud_download_outlined,
                size: 18,
                color:
                    recommended ? AppColors.accent2 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          server.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent2,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'Recomendado',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _serverMeta(server),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    recommended ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: recommended ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_rounded,
                    size: 14,
                    color:
                        recommended ? Colors.white : AppColors.textPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Descargar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color:
                          recommended ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _serverMeta(VideoServerModel server) {
    final parts = <String>[
      if (server.variant.isNotEmpty) server.variant.toUpperCase(),
      if (server.quality != null && server.quality!.isNotEmpty) server.quality!,
      if (server.isHls) 'HLS',
    ];
    return parts.isEmpty ? 'Servidor disponible' : parts.join(' · ');
  }
}
