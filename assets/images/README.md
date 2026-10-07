# TANU wordmark logo

`tanu_wordmark.png` must be the official white TANU wordmark on transparency.

The file currently in this folder is a 1px transparent stand-in so builds
pass and nothing renders broken. Replace it with the real asset:

- Same filename: `tanu_wordmark.png` (referenced by `TanuWordmark` widget).
- White typography, transparent background.
- High resolution for crisp high-DPI rendering (e.g. ~1200px wide source;
  displayed at 32dp logical height with aspect preserved).
- PNG with alpha (no JPG — transparency is required on the dark UI).

After replacing, no code changes are needed — hot restart and it appears on
onboarding pages 1 and 6. Declared in `pubspec.yaml` under `flutter/assets`.
