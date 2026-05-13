import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/anime_model.dart';
import '../../home/data/home_provider.dart';

final queryProvider = StateProvider<String>((ref) => '');
final domainProvider = StateProvider<String?>((ref) => null);

final searchResultsProvider = FutureProvider.autoDispose<List<AnimeModel>>((
  ref,
) async {
  final query = ref.watch(queryProvider);
  final domain = ref.watch(domainProvider);
  if (query.trim().isEmpty) return [];
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (disposed) return [];
  final repo = ref.read(animeRepositoryProvider);
  if (domain == null) {
    return repo.searchImageFirst(query.trim());
  }
  return repo.search(query.trim(), domain: domain);
});
