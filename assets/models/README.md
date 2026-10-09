# Bundled offline speech model

These files ship inside the APK and are copied into app storage on first
launch (see `ModelDownloadCoordinator` + `kBundledModelVersion`).

- `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2` (~155 MB)
  is git-ignored (GitHub rejects files > 100 MB). Re-fetch it with:

```sh
curl -L -o assets/models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2 \
  https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2
```

- `silero_vad.onnx` (~0.6 MB) is committed normally.
