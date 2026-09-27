# Tanu App

The mobile companion app for the Tanu pendant — a wearable that listens through
your day.

Tanu streams audio from a Bluetooth Low Energy (BLE) pendant, transcribes it in
real-time, and routes your words to an on-device or cloud agent. Conversations
and commitments are indexed and kept locally on the phone.

## Getting Started

A few resources to get you started:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

## Features

- **BLE pendant link** — scan, pair, and stream Opus audio from the pendant with
  live connection/battery status.
- **Real-time speech-to-text** — on-device (Sherpa-ONNX) or streaming cloud
  (Deepgram), hot-swappable mid-conversation.
- **Agent brain** — the app is agnostic behind an `AgentEngine` abstraction;
  today it calls a cloud Mistral endpoint.
- **Conversations & commitments** — transcripts and commitments are stored
  locally with Hive CE and searchable from the app.
- **Foreground service** — keeps listening while the app is backgrounded.

## Stack

- Flutter / Riverpod (state management)
- `flutter_blue_plus` (BLE)
- `opus_dart` / `opus_flutter` (audio decode)
- `sherpa_onnx` (on-device STT)
- `hive_ce_flutter` (local storage)
- `web_socket_channel` / `http` / `record` (streaming & capture)

## Running

```sh
flutter pub get
flutter run
```

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Analytics (PostHog)

Tanu is instrumented with PostHog for a usage funnel. The token is a build-time
constant and is **not** committed — pass it per build:

```sh
flutter run --dart-define=POSTHOG_TOKEN=phc_your_project_token
```

`POSTHOG_HOST` is optional and defaults to `https://us.i.posthog.com`
(use `https://eu.i.posthog.com` for an EU project).

Without a token the SDK never initialises and every `capture()` call is a no-op,
so local development and CI work with no extra setup. PostHog has no Linux or
Windows implementation, so the service is inert on those platforms and on
Android/iOS debug runs without a token.

### What is sent

Only aggregate shapes: event names, counts, durations, booleans, and a few
fixed enum labels. Both levels are allowlisted in
`lib/services/analytics/analytics_service.dart` — an event outside
`allowedEvents`, or a property outside `allowedPropertyKeys`, is dropped by the
`beforeSend` hook before it reaches the network.

**Never sent:** transcript text, memory titles and summaries, segment text,
commitment actions or people, device names, MAC addresses, or any device or
user identifier. There is no sign-in, so no person profiles are created
(`identifiedOnly`) and no individual is identifiable from the event stream.
Session replay is disabled.

`test/analytics_redaction_test.dart` guards this. If you add a `capture()` call,
add the event to `allowedEvents` and its properties to `allowedPropertyKeys` —
the tests fail otherwise, which is intentional: a silently-dropped property
looks exactly like working code.

### Native initialisation

PostHog's `AUTO_INIT` is set to `false` in `android/app/src/main/AndroidManifest.xml`
and `ios/Runner/Info.plist`. Tanu initialises from Dart instead
(`AnalyticsService.init`) so the `beforeSend` redaction hook is guaranteed to
run — native auto-init would bypass it and bake a token into the manifest.
