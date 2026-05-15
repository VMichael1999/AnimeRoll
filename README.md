# AnimeRoll

AnimeRoll is a Flutter anime streaming app that consumes an `anime1v-api` compatible backend. It includes home discovery, search, anime detail pages, episode playback, per-episode downloads, batch downloads, and user playback/download preferences.

## Features

- Home screen with hero content, popular anime, latest episodes, and genre filters.
- Anime search with cover-first provider prioritization.
- Anime detail screen with synopsis, cover art, metadata, and episode list.
- Episode thumbnails with fallback to the anime cover.
- Native playback for direct video URLs (`m3u8`, `mp4`, `webm`, `mkv`).
- WebView playback for embedded providers.
- Server ordering and automatic fallback when a direct playback server fails.
- Remembers the playback server that worked and prioritizes it later.
- Per-episode download buttons and download progress screen.
- Persistent settings for provider, quality, variant, fallback, theme, and downloads.

## Tech Stack

- Flutter / Dart
- Riverpod
- GoRouter
- Dio
- Chewie + video_player
- webview_flutter
- SharedPreferences

## Requirements

- Flutter SDK installed
- Android Studio or Xcode for native builds
- A running backend compatible with `anime1v-api`

Backend repository used during development:

```text
/Users/toolrides/Documents/anime1v-api
```

## API Configuration

The app reads the API URL and API key from Dart defines:

```bash
--dart-define=ANIME_API_BASE_URL=https://animea1v-api-production.up.railway.app/api/v1
--dart-define=ANIME_API_KEY=dev-anime1v-key
```

When testing against a local backend on a physical Android device, use the PC/local network IP instead of `localhost`, for example:

```bash
flutter run -d ZY32L4KVLJ \
  --dart-define=ANIME_API_BASE_URL=http://172.22.1.165:3000/api/v1 \
  --dart-define=ANIME_API_KEY=dev-anime1v-key
```

## Getting Started

Install dependencies:

```bash
flutter pub get
```

Analyze the project:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Generate coverage with an HTML report:

```powershell
.\tool\coverage.ps1
```

The report is written to:

```text
coverage/html/index.html
```

Run the app:

```bash
flutter run \
  --dart-define=ANIME_API_BASE_URL=https://animea1v-api-production.up.railway.app/api/v1 \
  --dart-define=ANIME_API_KEY=dev-anime1v-key
```

## Backend Notes

The app expects these backend endpoints:

- `GET /anime/search`
- `GET /anime/info`
- `GET /anime/episode`
- `POST /anime/download`
- `GET /anime/download/:id`
- `POST /anime/batch-download`
- `GET /anime/batch/:id`

Authentication is sent with the `x-api-key` header when `ANIME_API_KEY` is not empty.

## Project Structure

```text
lib/
  core/
    constants/
    network/
    router/
    theme/
  features/
    detail/
    downloads/
    home/
    player/
    search/
    settings/
  shared/
    models/
    widgets/
```

## Current Limitations

- Some providers return embedded players instead of direct video URLs.
- Playback and downloads depend on what the backend resolver can extract.
- Direct playback is best when the backend returns `m3u8` or direct media URLs.
- Download status is managed by the backend; if the backend restarts, in-memory download IDs may disappear.

## License

No license has been selected yet.
