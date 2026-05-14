import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/marathon_provider.dart';

class MarathonHud extends StatelessWidget {
  final MarathonSession session;
  final VoidCallback? onReset;

  const MarathonHud({super.key, required this.session, this.onReset});

  @override
  Widget build(BuildContext context) {
    if (!session.isActive) return const SizedBox.shrink();

    final watched = _fmt(session.watched);
    final nextBreak = _fmt(session.nextBreakIn);
    final isRecord = session.isNewRecord;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: session.breakRecommended
              ? AppColors.warning
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Row 1: header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sesión actual',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  isRecord
                      ? '🔥 ${session.episodeCount} eps · Récord personal'
                      : '🔥 ${session.episodeCount} eps',
                  style: TextStyle(
                    color: session.breakRecommended
                        ? AppColors.warning
                        : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onReset != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      tooltip: 'Reiniciar maratón',
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      color: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Ring + stats grid
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RingProgress(
                  progress: session.breakProgress,
                  label: '${(session.breakProgress * 100).round()}%',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsGrid(
                    items: [
                      _StatItem(label: 'Tiempo', value: watched, color: AppColors.textPrimary),
                      _StatItem(label: 'Eps vistos', value: '${session.episodeCount}', color: AppColors.textPrimary),
                      _StatItem(
                        label: 'Sig. pausa',
                        value: session.breakRecommended ? 'Ahora' : nextBreak,
                        color: session.breakRecommended ? AppColors.warning : AppColors.success,
                      ),
                      _StatItem(
                        label: 'Récord',
                        value: session.recordEpisodeCount > 0
                            ? '${session.recordEpisodeCount} eps'
                            : '--',
                        color: AppColors.accent2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tip card
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Consejo de maratón  ',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: 'Llevas '),
                          TextSpan(
                            text: watched,
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                            text:
                                ' seguidas. En el siguiente capítulo te sugerimos una pausa de 5 minutos.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h <= 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 2.4,
      children: items.map((item) => _StatCell(item: item)).toList(),
    );
  }
}

class _StatCell extends StatelessWidget {
  final _StatItem item;
  const _StatCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          item.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: item.color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          item.label.toUpperCase(),
          maxLines: 1,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color color;
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _RingProgress extends StatelessWidget {
  final double progress;
  final String label;

  const _RingProgress({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: _ArcPainter(progress: progress),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.accent2,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final inset = stroke / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - stroke,
      size.height - stroke,
    );

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
