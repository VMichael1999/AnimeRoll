import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AchievementBanner {
  static OverlayEntry? _current;
  static final _queue = <({String title, String subtitle})>[];
  static bool _showing = false;

  static void show(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _queue.add((title: title, subtitle: subtitle));
    if (!_showing) _showNext(overlay);
  }

  static void _showNext(OverlayState overlay) {
    if (_queue.isEmpty) {
      _showing = false;
      return;
    }
    _showing = true;
    final item = _queue.removeAt(0);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _BannerWidget(
        title: item.title,
        subtitle: item.subtitle,
        onDismissed: () {
          entry.remove();
          _current = null;
          _showNext(overlay);
        },
      ),
    );
    _current?.remove();
    _current = entry;
    overlay.insert(entry);
  }
}

class _BannerWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onDismissed;

  const _BannerWidget({
    required this.title,
    required this.subtitle,
    required this.onDismissed,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 4000), _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    _controller.reverse().then((_) => widget.onDismissed());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: _dismiss,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.fromLTRB(13, topInset + 10, 13, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.warning.withValues(alpha: 0.15),
                    AppColors.error.withValues(alpha: 0.08),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
