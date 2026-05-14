import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/schedule_anime_model.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/schedule_provider.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  static const _days = [
    (label: 'Domingo', value: 0),
    (label: 'Lunes', value: 1),
    (label: 'Martes', value: 2),
    (label: 'Miércoles', value: 3),
    (label: 'Jueves', value: 4),
    (label: 'Viernes', value: 5),
    (label: 'Sábado', value: 6),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(scheduleDayProvider);
    final schedule = ref.watch(scheduleResultsProvider);

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
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Aviso: ',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text:
                                'Los horarios que se muestran aquí son referenciales y pueden variar.',
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _days.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final day = _days[index];
                        final active = day.value == selectedDay;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              ref.read(scheduleDayProvider.notifier).state =
                                  day.value,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF3BE2D0)
                                  : AppColors.surface2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: active
                                    ? const Color(0xFF3BE2D0)
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              day.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? Colors.black
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: schedule.when(
                data: (items) {
                  if (items.isEmpty) return const _EmptySchedule();
                  return _ScheduleGrid(items: items);
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
}

class _ScheduleGrid extends StatelessWidget {
  final List<ScheduleAnimeModel> items;

  const _ScheduleGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () =>
              context.push('/detail?url=${Uri.encodeComponent(item.url)}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.cover != null
                            ? Image.network(
                                item.cover!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const _SchedulePlaceholder(),
                              )
                            : const _SchedulePlaceholder(),
                      ),
                    ),
                    if (item.emittedAt != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface2.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Emitido - ${_formatTime(item.emittedAt!)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    if (item.type != null)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(6),
                            ),
                          ),
                          child: Text(
                            item.type!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.episode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Episodio ${item.episode}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _SchedulePlaceholder extends StatelessWidget {
  const _SchedulePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface2,
      child: Center(
        child: Icon(Icons.calendar_month_rounded, color: AppColors.border),
      ),
    );
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
