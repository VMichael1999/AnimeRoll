// coverage:ignore-file
//
// Curated content blocker list for embedded video players (VOE, YourUpload,
// StreamWish, VidHide, etc.). Blocks the ad/tracker domains they load WITHOUT
// touching the underlying video manifest or player JS itself.
//
// Keep this list short and focused — EasyList has 80k rules and would tank
// WebView startup. We only need the ~40 worst offenders that these specific
// embeds use.
//
// To add a domain: append a ContentBlocker with a urlFilter regex. The
// urlFilter MUST be a valid regex (no globs). Always anchor with `.*` on
// both sides unless you want exact matches.
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Returns a fresh list of [ContentBlocker]s. Building it inside a function
/// (instead of a const) avoids accidental mutation and keeps platform-specific
/// regex compilation lazy.
List<ContentBlocker> buildEmbedAdBlockers() {
  ContentBlocker block(String urlFilter) => ContentBlocker(
    trigger: ContentBlockerTrigger(urlFilter: urlFilter),
    action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
  );

  return <ContentBlocker>[
    // ─── Generic ad networks ─────────────────────────────────────────────
    block(r".*doubleclick\.net.*"),
    block(r".*googlesyndication\.com.*"),
    block(r".*googleadservices\.com.*"),
    block(r".*google-analytics\.com.*"),
    block(r".*googletagmanager\.com.*"),
    block(r".*googletagservices\.com.*"),
    block(r".*adservice\.google\..*"),
    block(r".*adsystem\.amazon\..*"),
    block(r".*adnxs\.com.*"),
    block(r".*adsrvr\.org.*"),
    block(r".*scorecardresearch\.com.*"),
    block(r".*quantserve\.com.*"),

    // ─── Embed-specific ad/popup networks (VOE, StreamWish, VidHide…) ────
    block(r".*popads\.net.*"),
    block(r".*popcash\.net.*"),
    block(r".*popmyads\.com.*"),
    block(r".*propellerads\.com.*"),
    block(r".*propellerclick\.com.*"),
    block(r".*onclickads\.net.*"),
    block(r".*onclickperformance\.com.*"),
    block(r".*onclkds\.com.*"),
    block(r".*adsterra\.com.*"),
    block(r".*adskeeper\.com.*"),
    block(r".*hilltopads\.net.*"),
    block(r".*exoclick\.com.*"),
    block(r".*exosrv\.com.*"),
    block(r".*juicyads\.com.*"),
    block(r".*trafficjunky\.net.*"),
    block(r".*ero-advertising\.com.*"),
    block(r".*plugrush\.com.*"),
    block(r".*tsyndicate\.com.*"),
    block(r".*clickadu\.com.*"),
    block(r".*clickaine\.com.*"),
    block(r".*revcontent\.com.*"),
    block(r".*mgid\.com.*"),
    block(r".*outbrain\.com.*"),
    block(r".*taboola\.com.*"),

    // ─── Trackers ────────────────────────────────────────────────────────
    block(r".*facebook\.net.*"),
    block(r".*connect\.facebook\.net.*"),
    block(r".*hotjar\.com.*"),
    block(r".*mixpanel\.com.*"),
    block(r".*segment\.com.*"),
    block(r".*amplitude\.com.*"),

    // ─── Crypto miners (some old VOE mirrors load these) ─────────────────
    block(r".*coinhive\.com.*"),
    block(r".*cryptoloot\.pro.*"),
    block(r".*coin-hive\.com.*"),

    // ─── Generic ad path patterns ────────────────────────────────────────
    block(r".*/ads/.*"),
    block(r".*/adserver/.*"),
    block(r".*/popunder.*"),
    block(r".*/sw\.js.*pop.*"),
  ];
}
