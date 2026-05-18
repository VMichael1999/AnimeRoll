import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/schedule_anime_model.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/schedule_notifications_provider.dart';
import '../data/schedule_provider.dart';

/// Horario rediseñado al estilo del mockup acordado:
/// - Header compacto con título + chip del mes.
/// - Strip horizontal scrollable de chips de día (56×70).
/// - Hero del próximo episodio con backdrop, cuenta atrás y acciones.
/// - Secciones agrupadas: "Ya disponibles" (verde) y "Próximos" (ámbar).
/// - Cards 16:9 con thumbnail del episodio (campo `cover`, viene del backend
///   como screenshot por episodio).
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _weekDaysShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  // Build the canonical 7-day strip starting Monday of the current week.
  static List<({int value, String short, DateTime date})> _weekStrip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // weekday: Mon=1..Sun=7. We want Mon as index 0.
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) {
      final date = monday.add(Duration(days: i));
      // scheduleDayProvider uses dart's getDay (Sun=0..Sat=6).
      final value = date.weekday == DateTime.sunday ? 0 : date.weekday;
      return (value: value, short: _weekDaysShort[i], date: date);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(scheduleDayProvider);
    final schedule = ref.watch(scheduleResultsProvider);
    final week = _weekStrip();
    final selectedDate = week.firstWhere(
      (d) => d.value == selectedDay,
      orElse: () => week.first,
    ).date;
    final isToday = _isSameDay(selectedDate, DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: schedule.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorView(
            message: 'No se pudo cargar el horario.',
            onRetry: () => ref.invalidate(scheduleResultsProvider),
          ),
          data: (items) {
            final sorted = _sortByTime(items);
            final aired = isToday
                ? sorted.where((e) => _isPast(e.emittedAt)).toList()
                : <ScheduleAnimeModel>[];
            final upcoming = isToday
                ? sorted.where((e) => !_isPast(e.emittedAt)).toList()
                : sorted;
            final nextEmission = upcoming.firstOrNull;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ScheduleHeader(
                    selectedDate: selectedDate,
                    week: week,
                    selectedDay: selectedDay,
                    onSelect: (v) =>
                        ref.read(scheduleDayProvider.notifier).state = v,
                  ),
                ),
                if (nextEmission != null && isToday)
                  SliverToBoxAdapter(
                    child: _HeroNextEpisode(item: nextEmission),
                  ),
                if (sorted.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptySchedule(),
                  )
                else ...[
                  if (aired.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        kind: _SectionKind.live,
                        prefix: 'Hoy · ',
                        title: 'Ya disponibles',
                        count: aired.length,
                      ),
                    ),
                    _EpisodeSliverList(items: aired),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        kind: isToday ? _SectionKind.upcoming : _SectionKind.scheduled,
                        title: isToday ? 'Próximos hoy' : 'Programados',
                        count: upcoming.length,
                      ),
                    ),
                    _EpisodeSliverList(items: upcoming),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static List<ScheduleAnimeModel> _sortByTime(List<ScheduleAnimeModel> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final aTime = a.emittedAt;
      final bTime = b.emittedAt;
      if (aTime == null && bTime == null) return a.title.compareTo(b.title);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });
    return sorted;
  }

  static bool _isPast(DateTime? value) =>
      value != null && value.isBefore(DateTime.now());

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: title + month pill + day chips strip
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleHeader extends StatelessWidget {
  final DateTime selectedDate;
  final List<({int value, String short, DateTime date})> week;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  const _ScheduleHeader({
    required this.selectedDate,
    required this.week,
    required this.selectedDay,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Horario',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              _MonthPill(date: selectedDate),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: week.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final day = week[index];
                final isToday = ScheduleScreen._isSameDay(
                  day.date,
                  DateTime.now(),
                );
                return _DayChip(
                  short: day.short,
                  dayNumber: day.date.day,
                  active: day.value == selectedDay,
                  isToday: isToday,
                  onTap: () => onSelect(day.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPill extends StatelessWidget {
  final DateTime date;

  const _MonthPill({required this.date});

  @override
  Widget build(BuildContext context) {
    final label = '${ScheduleScreen._months[date.month - 1]} ${date.year}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String short;
  final int dayNumber;
  final bool active;
  final bool isToday;
  final VoidCallback onTap;

  const _DayChip({
    required this.short,
    required this.dayNumber,
    required this.active,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        height: 70,
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? Colors.transparent
                : (isToday ? accent : AppColors.border),
            width: isToday && !active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              short,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: active
                    ? Colors.white.withValues(alpha: 0.85)
                    : (isToday ? accent : AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero: next episode card (16:9 backdrop + countdown + actions)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroNextEpisode extends ConsumerWidget {
  final ScheduleAnimeModel item;

  const _HeroNextEpisode({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emittedAt = item.emittedAt;
    final countdown = emittedAt == null
        ? null
        : _formatRelative(emittedAt.difference(DateTime.now()));
    final imageUrl = _bestHeroImage(item);
    final enabled = ref.watch(
      scheduleNotificationsProvider.select(
        (state) => state.contains(
          '${item.episodeUrl}|${emittedAt?.millisecondsSinceEpoch ?? 0}',
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.surface),
              if (imageUrl != null)
                AppNetworkImage(
                  url: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: ColoredBox(color: AppColors.surface),
                ),
              // Bottom gradient overlay for legibility.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (countdown != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Próximo en $countdown',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      item.episode == null
                          ? item.title
                          : '${item.title} · Ep. ${item.episode}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (emittedAt != null) _formatTime(emittedAt),
                        if (item.type != null) item.type!,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Row(
                  children: [
                    _HeroActionButton(
                      icon: enabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      active: enabled,
                      onTap: () => _toggleReminder(context, ref),
                    ),
                    const SizedBox(width: 6),
                    _HeroActionButton(
                      icon: Icons.play_arrow_rounded,
                      primary: true,
                      onTap: () => context.push(
                        '/detail?url=${Uri.encodeComponent(item.url)}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReminder(BuildContext context, WidgetRef ref) async {
    final active = await ref
        .read(scheduleNotificationsProvider.notifier)
        .toggle(item);
    if (!context.mounted) return;
    AppToast.show(
      context,
      message: active ? 'Recordatorio activado' : 'Recordatorio desactivado',
      type: active ? AppToastType.success : AppToastType.info,
    );
  }

  static String? _bestHeroImage(ScheduleAnimeModel item) =>
      item.backdrop ?? item.cover ?? item.poster;

  static String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatRelative(Duration diff) {
    if (diff.isNegative || diff.inMinutes < 1) return 'unos minutos';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}min';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }
}

class _HeroActionButton extends StatelessWidget {
  final IconData icon;
  final bool primary;
  final bool active;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: primary
              ? accent
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active && !primary ? accent : Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header (live / upcoming / scheduled)
// ─────────────────────────────────────────────────────────────────────────────

enum _SectionKind { live, upcoming, scheduled }

class _SectionHeader extends StatelessWidget {
  final _SectionKind kind;
  final String? prefix;
  final String title;
  final int count;

  const _SectionHeader({
    required this.kind,
    required this.title,
    required this.count,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (kind) {
      _SectionKind.live => const Color(0xFF10B981),
      _SectionKind.upcoming => const Color(0xFFF59E0B),
      _SectionKind.scheduled => AppColors.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: Row(
        children: [
          _PulseDot(color: dotColor, animate: kind == _SectionKind.live),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
              children: [
                if (prefix != null)
                  TextSpan(
                    text: prefix!.toUpperCase(),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                TextSpan(
                  text: title.toUpperCase(),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot that pulses outward when `animate` is true. Used to signal a "live"
/// section where episodes have already aired.
class _PulseDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _PulseDot({required this.color, required this.animate});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      height: 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.animate)
            AnimatedBuilder(
              animation: _controller,
              builder: (_, _) {
                final t = _controller.value;
                return Container(
                  width: 8 + 12 * t,
                  height: 8 + 12 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: (1 - t).clamp(0, 1)),
                  ),
                );
              },
            ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: widget.animate
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Episode list + card
// ─────────────────────────────────────────────────────────────────────────────

class _EpisodeSliverList extends StatelessWidget {
  final List<ScheduleAnimeModel> items;

  const _EpisodeSliverList({required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _EpisodeCard(item: items[i]),
      ),
    );
  }
}

class _EpisodeCard extends ConsumerWidget {
  final ScheduleAnimeModel item;

  const _EpisodeCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emittedAt = item.emittedAt;
    final aired = emittedAt != null && emittedAt.isBefore(DateTime.now());
    final accent = Theme.of(context).colorScheme.secondary;
    final enabled = ref.watch(
      scheduleNotificationsProvider.select(
        (state) => state.contains(
          '${item.episodeUrl}|${emittedAt?.millisecondsSinceEpoch ?? 0}',
        ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/detail?url=${Uri.encodeComponent(item.url)}'),
      child: Opacity(
        opacity: aired ? 0.88 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _CardThumbnail(item: item),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (item.episode != null)
                                _EpisodeChip(number: item.episode!),
                              if (item.episode != null) const SizedBox(width: 8),
                              Flexible(
                                child: _StatusText(
                                  emittedAt: emittedAt,
                                  aired: aired,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _BellButton(
                    enabled: enabled,
                    accent: accent,
                    onTap: () => _toggleReminder(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReminder(BuildContext context, WidgetRef ref) async {
    final active = await ref
        .read(scheduleNotificationsProvider.notifier)
        .toggle(item);
    if (!context.mounted) return;
    AppToast.show(
      context,
      message: active ? 'Recordatorio activado' : 'Recordatorio desactivado',
      type: active ? AppToastType.success : AppToastType.info,
    );
  }
}

class _CardThumbnail extends StatelessWidget {
  final ScheduleAnimeModel item;

  const _CardThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.cover ?? item.backdrop ?? item.poster;
    final time = item.emittedAt;
    return SizedBox(
      width: 120,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surface2),
            AppNetworkImage(
              url: imageUrl,
              width: 120,
              fit: BoxFit.cover,
              errorWidget: const _ThumbnailPlaceholder(),
              placeholder: const _ThumbnailPlaceholder(),
            ),
            if (time != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatTime(time),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface2,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}

class _EpisodeChip extends StatelessWidget {
  final int number;

  const _EpisodeChip({required this.number});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'Ep. $number',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final DateTime? emittedAt;
  final bool aired;

  const _StatusText({required this.emittedAt, required this.aired});

  @override
  Widget build(BuildContext context) {
    if (emittedAt == null) {
      return const Text(
        'Sin hora',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );
    }
    final diff = emittedAt!.difference(DateTime.now());
    final color = aired ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final label = aired
        ? '● Hace ${_formatPast(diff)}'
        : '⏱ En ${_formatFuture(diff)}';
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }

  static String _formatPast(Duration diff) {
    final abs = diff.abs();
    if (abs.inMinutes < 60) return '${abs.inMinutes}min';
    if (abs.inHours < 24) return '${abs.inHours}h';
    return '${abs.inDays}d';
  }

  static String _formatFuture(Duration diff) {
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }
}

/// Botón circular para activar/desactivar el recordatorio. Vive dentro del
/// padding derecho de la card, no como columna separada — esto mantiene la
/// card como un solo bloque visual y respeta las esquinas redondeadas sin
/// pelearse con el ClipRRect del padre.
class _BellButton extends StatelessWidget {
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  const _BellButton({
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: enabled ? accent.withValues(alpha: 0.18) : AppColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: enabled
                ? accent.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              size: 18,
              color: enabled ? accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'No hay emisiones para este día',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
