import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/schedule_anime_model.dart';
import '../../home/data/home_provider.dart';

final scheduleDayProvider = StateProvider<int>(
  (ref) => DateTime.now().weekday % 7,
);

final scheduleResultsProvider =
    FutureProvider.autoDispose<List<ScheduleAnimeModel>>((ref) async {
      final day = ref.watch(scheduleDayProvider);
      final repo = ref.read(animeRepositoryProvider);
      return repo.schedule(day: day);
    });
