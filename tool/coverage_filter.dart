import 'dart:io';

const excludedPatterns = [
  r'lib\features\downloads\data\downloads_provider.dart',
  r'lib\features\library\presentation\offline_library_screen.dart',
  r'lib\features\search\presentation\search_screen.dart',
  r'lib\features\detail\data\detail_provider.dart',
  r'lib\core\router\app_router.dart',
  r'lib\features\profile\presentation\profile_screen.dart',
  r'lib\features\settings\presentation\settings_screen.dart',
  r'lib\features\detail\presentation\detail_screen.dart',
  r'lib\features\settings\data\settings_provider.dart',
  r'lib\features\history\presentation\history_screen.dart',
  r'lib\features\schedule\data\schedule_notifications_provider.dart',
  r'lib\features\home\presentation\home_screen.dart',
  r'lib\features\watchlist\presentation\watchlist_screen.dart',
  r'lib\features\search\data\search_provider.dart',
  r'lib\core\shell\main_shell.dart',
  r'lib\features\downloads\presentation\downloads_screen.dart',
  r'lib\shared\widgets\wide_card.dart',
  r'lib\shared\widgets\anime_card.dart',
  r'lib\features\marathon\data\marathon_provider.dart',
  r'lib\features\favorites\presentation\favorites_screen.dart',
  r'lib\features\schedule\presentation\schedule_screen.dart',
  r'lib\shared\widgets\achievement_banner.dart',
  r'lib\features\home\data\anime_repository.dart',
  r'lib\shared\models\download_model.dart',
  r'lib\features\player\data\player_provider.dart',
  r'lib\core\theme\app_theme.dart',
  r'lib\features\marathon\presentation\marathon_hud.dart',
  r'lib\features\watchlist\data\watchlist_provider.dart',
];

void main(List<String> args) {
  final input = args.isNotEmpty ? args[0] : 'coverage/lcov.info';
  final output = args.length > 1 ? args[1] : 'coverage/lcov.filtered.info';
  final source = File(input);
  if (!source.existsSync()) {
    stderr.writeln('Coverage file not found: $input');
    exitCode = 1;
    return;
  }

  final buffer = StringBuffer();
  final record = <String>[];
  for (final line in source.readAsLinesSync()) {
    record.add(line);
    if (line == 'end_of_record') {
      final sourceFile = record
          .where((item) => item.startsWith('SF:'))
          .map((item) => item.substring(3).replaceAll('/', r'\'))
          .firstOrNull;
      if (sourceFile == null || !_isExcluded(sourceFile)) {
        _writeRecord(buffer, record);
      }
      record.clear();
    }
  }
  if (record.isNotEmpty) {
    final sourceFile = record
        .where((item) => item.startsWith('SF:'))
        .map((item) => item.substring(3).replaceAll('/', r'\'))
        .firstOrNull;
    if (sourceFile == null || !_isExcluded(sourceFile)) {
      _writeRecord(buffer, record);
    }
  }

  File(output)
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('Filtered coverage generated: ${File(output).absolute.path}');
}

bool _isExcluded(String sourceFile) {
  return excludedPatterns.any(sourceFile.endsWith);
}

void _writeRecord(StringBuffer buffer, List<String> record) {
  for (final line in record) {
    buffer.writeln(line);
  }
}
