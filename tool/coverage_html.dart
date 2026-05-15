import 'dart:convert';
import 'dart:io';

class FileCoverage {
  final String sourcePath;
  final Map<int, int> hitsByLine;

  const FileCoverage({required this.sourcePath, required this.hitsByLine});

  int get coveredLines => hitsByLine.values.where((hits) => hits > 0).length;
  int get executableLines => hitsByLine.length;
  int get missedLines => executableLines - coveredLines;
  double get percent =>
      executableLines == 0 ? 100 : coveredLines * 100 / executableLines;
}

void main(List<String> args) {
  final input = args.isNotEmpty ? args[0] : 'coverage/lcov.info';
  final output = args.length > 1 ? args[1] : 'coverage/html';
  final lcovFile = File(input);

  if (!lcovFile.existsSync()) {
    stderr.writeln('Coverage file not found: $input');
    stderr.writeln('Run: flutter test --coverage');
    exitCode = 1;
    return;
  }

  final outputDir = Directory(output);
  if (outputDir.existsSync()) {
    outputDir.deleteSync(recursive: true);
  }
  outputDir.createSync(recursive: true);
  Directory('${outputDir.path}/files').createSync(recursive: true);

  final files = _parseLcov(lcovFile.readAsLinesSync());
  if (files.isEmpty) {
    stderr.writeln('No coverage records found in $input');
    exitCode = 1;
    return;
  }

  _writeAssets(outputDir);
  for (final file in files) {
    _writeFilePage(outputDir, file);
  }
  _writeIndex(outputDir, files);

  final report = File('${outputDir.path}/index.html').absolute.path;
  stdout.writeln('Coverage HTML generated: $report');
}

List<FileCoverage> _parseLcov(List<String> lines) {
  final files = <FileCoverage>[];
  String? sourcePath;
  var hitsByLine = <int, int>{};

  void flush() {
    if (sourcePath == null) return;
    files.add(
      FileCoverage(
        sourcePath: sourcePath!.replaceAll('\\', '/'),
        hitsByLine: Map<int, int>.from(hitsByLine),
      ),
    );
    sourcePath = null;
    hitsByLine = <int, int>{};
  }

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      flush();
      sourcePath = line.substring(3).trim();
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final lineNumber = int.tryParse(parts[0]);
        final hits = int.tryParse(parts[1]);
        if (lineNumber != null && hits != null) {
          hitsByLine[lineNumber] = hits;
        }
      }
    } else if (line == 'end_of_record') {
      flush();
    }
  }
  flush();

  files.sort((a, b) => a.sourcePath.compareTo(b.sourcePath));
  return files;
}

void _writeIndex(Directory outputDir, List<FileCoverage> files) {
  final covered = files.fold<int>(0, (sum, file) => sum + file.coveredLines);
  final executable = files.fold<int>(
    0,
    (sum, file) => sum + file.executableLines,
  );
  final percent = executable == 0 ? 100.0 : covered * 100 / executable;
  final rows = files
      .map((file) {
        final page = _filePageName(file.sourcePath);
        final statusClass = _statusClass(file.percent);
        return '''
      <tr>
        <td><a href="files/$page">${_escape(file.sourcePath)}</a></td>
        <td class="number">${file.coveredLines}/${file.executableLines}</td>
        <td class="number">${file.missedLines}</td>
        <td>
          <div class="bar"><span class="$statusClass" style="width:${file.percent.toStringAsFixed(2)}%"></span></div>
          <strong>${file.percent.toStringAsFixed(1)}%</strong>
        </td>
      </tr>
    ''';
      })
      .join('\n');

  File('${outputDir.path}/index.html').writeAsStringSync('''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AnimeRoll Coverage</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main class="page">
    <header class="hero">
      <div>
        <p class="eyebrow">Flutter test coverage</p>
        <h1>AnimeRoll Coverage</h1>
      </div>
      <div class="score ${_statusClass(percent)}">${percent.toStringAsFixed(1)}%</div>
    </header>
    <section class="stats">
      <div><span>${files.length}</span><p>Files</p></div>
      <div><span>$covered</span><p>Covered lines</p></div>
      <div><span>${executable - covered}</span><p>Missed lines</p></div>
      <div><span>$executable</span><p>Executable lines</p></div>
    </section>
    <section>
      <table>
        <thead>
          <tr>
            <th>File</th>
            <th>Covered</th>
            <th>Missed</th>
            <th>Coverage</th>
          </tr>
        </thead>
        <tbody>
          $rows
        </tbody>
      </table>
    </section>
  </main>
</body>
</html>
''');
}

void _writeFilePage(Directory outputDir, FileCoverage coverage) {
  final file = File(coverage.sourcePath);
  final sourceLines = file.existsSync()
      ? file.readAsLinesSync()
      : const <String>['Source file not found on disk.'];

  final rows = <String>[];
  for (var index = 0; index < sourceLines.length; index++) {
    final lineNumber = index + 1;
    final hits = coverage.hitsByLine[lineNumber];
    final className = hits == null
        ? 'neutral'
        : hits > 0
        ? 'covered'
        : 'missed';
    rows.add('''
      <tr class="$className">
        <td class="line-number">$lineNumber</td>
        <td class="hits">${hits ?? ''}</td>
        <td class="code"><code>${_escape(sourceLines[index])}</code></td>
      </tr>
    ''');
  }

  final pageName = _filePageName(coverage.sourcePath);
  File('${outputDir.path}/files/$pageName').writeAsStringSync('''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_escape(coverage.sourcePath)} coverage</title>
  <link rel="stylesheet" href="../style.css">
</head>
<body>
  <main class="page">
    <a class="back" href="../index.html">Back to summary</a>
    <header class="hero compact">
      <div>
        <p class="eyebrow">Source file</p>
        <h1>${_escape(coverage.sourcePath)}</h1>
      </div>
      <div class="score ${_statusClass(coverage.percent)}">${coverage.percent.toStringAsFixed(1)}%</div>
    </header>
    <section class="stats">
      <div><span>${coverage.coveredLines}</span><p>Covered lines</p></div>
      <div><span>${coverage.missedLines}</span><p>Missed lines</p></div>
      <div><span>${coverage.executableLines}</span><p>Executable lines</p></div>
    </section>
    <table class="source">
      <tbody>
        ${rows.join('\n')}
      </tbody>
    </table>
  </main>
</body>
</html>
''');
}

void _writeAssets(Directory outputDir) {
  File('${outputDir.path}/style.css').writeAsStringSync('''
:root {
  color-scheme: dark;
  --bg: #111318;
  --surface: #1a1e26;
  --surface-2: #232936;
  --text: #edf0f7;
  --muted: #9aa3b5;
  --border: #343b4c;
  --good: #38c172;
  --mid: #e7b84b;
  --bad: #ef5b5b;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: var(--bg);
  color: var(--text);
}
.page {
  width: min(1180px, calc(100% - 32px));
  margin: 0 auto;
  padding: 32px 0 48px;
}
.hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  margin-bottom: 20px;
}
.hero.compact h1 {
  font-size: 24px;
  overflow-wrap: anywhere;
}
.eyebrow {
  margin: 0 0 8px;
  color: var(--muted);
  font-size: 12px;
  font-weight: 800;
  text-transform: uppercase;
}
h1 {
  margin: 0;
  font-size: 40px;
  line-height: 1.05;
}
.score {
  min-width: 126px;
  padding: 18px 20px;
  border-radius: 8px;
  color: #07110b;
  text-align: center;
  font-size: 30px;
  font-weight: 900;
}
.high, .bar .high { background: var(--good); }
.medium, .bar .medium { background: var(--mid); }
.low, .bar .low { background: var(--bad); }
.stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
  margin-bottom: 20px;
}
.stats div {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 14px;
}
.stats span {
  display: block;
  font-size: 24px;
  font-weight: 900;
}
.stats p {
  margin: 4px 0 0;
  color: var(--muted);
  font-size: 12px;
}
table {
  width: 100%;
  border-collapse: collapse;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
}
th, td {
  padding: 10px 12px;
  border-bottom: 1px solid var(--border);
  text-align: left;
  font-size: 13px;
}
th {
  color: var(--muted);
  background: var(--surface-2);
  font-size: 11px;
  text-transform: uppercase;
}
a {
  color: var(--text);
  font-weight: 700;
  text-decoration: none;
}
a:hover { text-decoration: underline; }
.number { text-align: right; white-space: nowrap; }
.bar {
  display: inline-block;
  width: min(220px, 55vw);
  height: 8px;
  margin-right: 10px;
  overflow: hidden;
  border-radius: 999px;
  background: #0b0d12;
  vertical-align: middle;
}
.bar span {
  display: block;
  height: 100%;
}
.back {
  display: inline-block;
  margin-bottom: 18px;
  color: var(--muted);
}
.source {
  table-layout: fixed;
}
.source td {
  padding: 0;
  vertical-align: top;
}
.source .line-number,
.source .hits {
  width: 72px;
  padding: 4px 10px;
  color: var(--muted);
  background: #0d0f14;
  text-align: right;
  user-select: none;
}
.source .hits { width: 58px; }
.source .code {
  padding: 4px 12px;
  overflow-x: auto;
}
.source code {
  font-family: "Cascadia Code", Consolas, monospace;
  font-size: 12px;
  white-space: pre;
}
.source tr.covered .code { background: rgba(56, 193, 114, 0.12); }
.source tr.missed .code { background: rgba(239, 91, 91, 0.16); }
.source tr.neutral .code { background: transparent; }
@media (max-width: 720px) {
  .hero { align-items: flex-start; flex-direction: column; }
  .stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  h1 { font-size: 32px; }
}
''');
}

String _filePageName(String path) {
  final encoded = base64Url.encode(utf8.encode(path)).replaceAll('=', '');
  return '$encoded.html';
}

String _statusClass(double percent) {
  if (percent >= 80) return 'high';
  if (percent >= 50) return 'medium';
  return 'low';
}

String _escape(String value) {
  return const HtmlEscape().convert(value);
}
