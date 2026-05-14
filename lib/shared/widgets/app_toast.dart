import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum AppToastType { success, error, info }

class AppToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _timer?.cancel();
    _current?.remove();

    final entry = OverlayEntry(
      builder: (context) => _ToastOverlay(message: message, type: type),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 2400), () {
      entry.remove();
      if (_current == entry) _current = null;
    });
  }
}

class _ToastOverlay extends StatelessWidget {
  final String message;
  final AppToastType type;

  const _ToastOverlay({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final color = switch (type) {
      AppToastType.success => AppColors.accent,
      AppToastType.error => Colors.redAccent,
      AppToastType.info => AppColors.accent2,
    };
    final icon = switch (type) {
      AppToastType.success => Icons.check_circle_rounded,
      AppToastType.error => Icons.error_rounded,
      AppToastType.info => Icons.info_rounded,
    };

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset + 22,
      child: SafeArea(
        top: false,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.92, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.45)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.34),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 18, color: color),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
