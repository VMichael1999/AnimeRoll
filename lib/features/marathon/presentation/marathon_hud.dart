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

    final watched = _formatDuration(session.watched);
    final nextBreak = _formatDuration(session.nextBreakIn);
    return Container(
      padding: const EdgeInsets.all(12),
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.warning,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.breakRecommended
                          ? 'Pausa recomendada'
                          : 'Modo Maratón activo',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.breakRecommended
                          ? 'Llevas $watched seguidas'
                          : '$watched · ${session.episodeCount} eps',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onReset != null)
                IconButton(
                  tooltip: 'Reiniciar maratón',
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Tiempo',
                  value: watched,
                  color: AppColors.accent2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: session.breakRecommended ? 'Estado' : 'Pausa en',
                  value: session.breakRecommended ? 'Ahora' : nextBreak,
                  color: session.breakRecommended
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}m';
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
