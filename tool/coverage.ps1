$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$flutter = Join-Path $root ".fvm\flutter_sdk\bin\flutter.bat"
$dart = Join-Path $root ".fvm\flutter_sdk\bin\dart.bat"

if (-not (Test-Path $flutter)) {
  $flutter = "flutter"
}

if (-not (Test-Path $dart)) {
  $dart = "dart"
}

Push-Location $root
try {
  & $flutter test --coverage
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  & $dart run .\tool\coverage_filter.dart .\coverage\lcov.info .\coverage\lcov.filtered.info
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  & $dart run .\tool\coverage_html.dart .\coverage\lcov.filtered.info .\coverage\html
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  Write-Host ""
  Write-Host "Coverage report:"
  Write-Host "  $root\coverage\html\index.html"
} finally {
  Pop-Location
}
