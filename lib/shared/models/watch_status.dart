import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum WatchStatus {
  watching,
  completed,
  planToWatch,
  onHold,
  dropped,
}

extension WatchStatusX on WatchStatus {
  String get label => switch (this) {
        WatchStatus.watching => 'Viendo',
        WatchStatus.completed => 'Completado',
        WatchStatus.planToWatch => 'Planeado',
        WatchStatus.onHold => 'En pausa',
        WatchStatus.dropped => 'Abandonado',
      };

  IconData get icon => switch (this) {
        WatchStatus.watching => Icons.play_circle_rounded,
        WatchStatus.completed => Icons.check_circle_rounded,
        WatchStatus.planToWatch => Icons.bookmark_rounded,
        WatchStatus.onHold => Icons.pause_circle_rounded,
        WatchStatus.dropped => Icons.remove_circle_rounded,
      };

  Color get color => switch (this) {
        WatchStatus.watching => AppColors.accent2,
        WatchStatus.completed => AppColors.success,
        WatchStatus.planToWatch => AppColors.warning,
        WatchStatus.onHold => AppColors.textSecondary,
        WatchStatus.dropped => AppColors.error,
      };
}
