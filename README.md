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