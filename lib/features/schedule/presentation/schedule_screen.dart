import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/schedule_anime_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/schedule_notifications_provider.dart';
import '../data/schedule_provider.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  static const _weekDays = [
    (label: 'Lunes', short: 'LUN', value: 1),
    (label: 'Martes', short: 'MAR', value: 2),
    (label: 'Miércoles', short: 'MIÉ', value: 3),
    (label: 'Jueves', short: 'JUE', value: 4),
    (label: 'Viernes', short: 'VIE', value: 5),
    (label: 'Sábado', short: 'SÁB', value: 6),
    (label: 'Domingo', short: 'DOM', value: 0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(scheduleDayProvider);
    final schedule = ref.watch(scheduleResultsProvider);
    final selectedDate = _dateForDayValue(selectedDay);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Horario',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '← ${_monthLabel(selectedDate)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Semana actual',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_nextMonthLabel(selectedDate)} →',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _weekDays.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final day = _weekDays[index];
                        final active = day.value == selectedDay;
                        final date = _dateForDayValue(day.value);
                        return _WeekDayButton(
                          short: day.short,
                          dayNumber: date.day,
                          active: active,
                          onTap: () =>
                              ref.read(scheduleDayProvider.notifier).state =
                                  day.value,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  schedule.maybeWhen(
                    data: (items) =>
                        _NextEpisodeBanner(item: _nextEmission(items)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: schedule.when(
                data: (items) {
                  if (items.isEmpty) return const _EmptySchedule();
                  return _ScheduleList(
                    items: _sortByTime(items),
                    selectedDate: selectedDate,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message: 'No se pudo cargar el horario.',
                  onRetry: () => ref.invalidate(scheduleResultsProvider),
                ),
              ),
            ),
          ],
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

  static ScheduleAnimeModel? _nextEmission(List<ScheduleAnimeModel> items) {
    final now = DateTime.now();
    final upcoming = _sortByTime(items).where((item) {
      final emittedAt = item.emittedAt;
      return emittedAt != null && emittedAt.isAfter(now);
    });
    return upcoming.isEmpty ? null : upcoming.first;
  }

  static DateTime _dateForDayValue(int value) {
    final now = DateTime.now();
    final todayValue = now.weekday % 7;
    final diff = value - todayValue;
    return DateTime(now.year, now.month, now.day).add(Duration(days: diff));
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String _nextMonthLabel(DateTime date) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final next = DateTime(date.year, date.month + 1);
    return months[next.month - 1];
  }
}

class _WeekDayButton extends StatelessWidget {
  final String short;
  final int dayNumber;
  final bool active;
  final VoidCallback onTap;

  const _WeekDayButton({
    required this.short,
    required this.dayNumber,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 32,
        child: Column(
          children: [
            Text(
              short,
              style: TextStyle(
                color: AppColors.accent2,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent2),
              ),
              child: Text(
                '$dayNumber',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextEpisodeBanner extends StatelessWidget {
  final ScheduleAnimeModel? item;

  const _NextEpisodeBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    final target = item?.emittedAt;
    final label = target == null
        ? 'Sin próximos episodios programados'
        : '⏰ ${item!.title} en ${_relative(target)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent2.withValues(alpha: 0.65)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.accent2,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _relative(DateTime value) {
    final diff = value.difference(DateTime.now());
    if (diff.inMinutes <= 0) return 'unos minutos';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }
}

class _ScheduleList extends StatelessWidget {
  final List<ScheduleAnimeModel> items;
  final DateTime selectedDate;

  const _ScheduleList({required this.items, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      children: [
        _ScheduleGroupHeader(date: selectedDate),
        const SizedBox(height: 8),
        for (final item in items) ...[
          _ScheduleTile(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ScheduleGroupHeader extends StatelessWidget {
  final DateTime date;

  const _ScheduleGroupHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(date.year, date.month, date.day);
    final prefix = current == today
        ? 'Hoy'
        : current == today.add(const Duration(days: 1))
        ? 'Mañana'
        : _dayName(date);
    return Text(
      '$prefix — ${_dayName(date)} ${date.day}',
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
    );
  }

  String _dayName(DateTime date) {
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return names[date.weekday - 1];
  }
}

class _ScheduleTile extends ConsumerWidget {
  final ScheduleAnimeModel item;

  const _ScheduleTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emittedAt = item.emittedAt;
    final enabled = ref.watch(
      scheduleNotificationsProvider.select((state) {
        final time = item.emittedAt?.millisecondsSinceEpoch ?? 0;
        return state.contains('${item.episodeUrl}|$time');
      }),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => context.push('/detail?url=${Uri.encodeComponent(item.url)}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                emittedAt == null ? '--:--' : _formatTime(emittedAt),
                style: TextStyle(
                  color: AppColors.accent2,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.episode == null
                        ? item.title
                        : '${item.title} — Ep. ${item.episode}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    emittedAt != null && emittedAt.isBefore(DateTime.now())
                        ? 'Nuevo episodio hoy'
                        : 'Estreno esta tarde',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: enabled ? 'Quitar recordatorio' : 'Recordarme',
              onPressed: () async {
                final active = await ref
                    .read(scheduleNotificationsProvider.notifier)
                    .toggle(item);
                if (!context.mounted) return;
                AppToast.show(
                  context,
                  message: active
                      ? 'Recordatorio activado'
                      : 'Recordatorio desactivado',
                  type: active ? AppToastType.success : AppToastType.info,
                );
              },
              icon: Icon(
                enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_rounded,
                size: 18,
                color: enabled ? AppColors.accent2 : AppColors.textSecondary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: enabled
                    ? AppColors.accent.withValues(alpha: 0.35)
                    : AppColors.surface2,
                fixedSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No hay emisiones para este día',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
