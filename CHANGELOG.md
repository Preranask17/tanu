# Tanu App - Changelog & Architecture Updates

This document outlines the end-to-end changes made during the latest development sprint. The app was transformed from a basic audio dictation tool into an intelligent, polished iOS-style AI memory assistant.

---

## 6. Session 2 — Polish, Responsive Layout & Bug Fixes

### App Identity
* **Renamed to "Tanu"** across all platform manifests: `Info.plist`, `main.cpp`, `Runner.rc`, `index.html`, and `manifest.json`.

### Responsive Desktop Layout
* **Sidebar Navigation:** Implemented `ResponsiveScaffold` that swaps between a `CupertinoTabBar` (mobile/narrow) and a sidebar (desktop/wide ≥600px).
* **Content Constraints:** Wrapped core content in `Center` → `ConstrainedBox(maxWidth: 800)` across `HomeScreen`, `ConversationsScreen`, and `SettingsScreen` to prevent content from stretching on wide screens.
* **Minimum Window Size:** Added `WM_GETMINMAXINFO` handler in `win32_window.cpp` enforcing 480×600px minimum, preventing layout breakage on extreme resize.

### Onboarding Flow
* **New User Welcome:** Built `OnboardingScreen` with fade+slide animation, compact feature rows with tinted icon containers, and a full-width CTA button.
* **Responsive Layout for Desktop:** Adjusted the Onboarding Screen constraints (maxWidth 600) and vertical spacing to adapt perfectly to desktop windows, avoiding a stretched mobile appearance.
* **Native iOS Typography:** Refined the title font weight to `w700`, removed chunky icon backgrounds in favor of large tinted blue icons (`CupertinoColors.systemBlue`), and adjusted button heights to precisely match Apple's iOS setup screens.
* **Persistence Fix:** Removed a testing override in `SettingsNotifier.build()` that was force-resetting `hasCompletedOnboarding = false` on every launch — onboarding now only appears for genuinely new users.

### Bluetooth & Device Discovery
* **Scanning Performance:** Added `continuousUpdates: true` and a `continuousDivisor` to the `FlutterBluePlus.startScan` call in `BluetoothPendantSource` to dramatically speed up device discovery and RSSI polling, making the device picker populate instantly.

### Advanced Search
* **Summary Search:** Global search in `ConversationsScreen` now includes conversation `summary` text in results, not just titles and transcripts.

### Device Picker Sheet
* **Compact Redesign:** Reduced title (17px), subtitle (13px), device row icons (22px), and list height (200px) for a refined bottom sheet that doesn't dominate the screen.
* **Width Constraint:** Capped at 600px and centered via `Align(bottomCenter)` + `ConstrainedBox`.
* **Rounded Corners:** Added 14px top border radius for a native iOS sheet feel.
* **Drag to Dismiss:** Wrapped in `GestureDetector` with vertical drag detection for swipe-down dismissal.
* **Code Cleanup:** Complete rewrite of the `build` method with consistent indentation and section comments.

### Settings Screen Revamp
* **Professional Section Headers:** Replaced default `Text` headers with uppercase, letter-spaced (`0.4`), 12px grey labels for a clean, minimal aesthetic.
* **Appearance Toggle Fix:** Fixed overlapping text in the `CupertinoSlidingSegmentedControl` by reducing label font to 13px while maintaining full-width stretch.
* **Consistent Formatting:** Full rewrite with proper widget tree indentation, section separators, and clean alignment throughout.

### Bug Fixes
* **Model Download Persistence:** Fixed a `Uint8List` type-cast error in `model_download_coordinator.dart` (`_extractSync`) that silently crashed during archive extraction, causing the Whisper Base model to appear as "not downloaded" even after a successful 200MB download.
* **Syntax Errors:** Resolved multiple bracket-mismatch issues in `home_screen.dart` and `settings_provider.dart` introduced during incremental constraint edits.

---

## 1. Core Audio Pipeline & On-Device Models
* **Whisper Base STT (145 MB):** Upgraded the on-device offline model from Moonshine Tiny (43 MB) to the highly accurate multilingual Whisper Base model. It natively supports code-switching (Hinglish), Hindi, Tamil, Telugu, and English effortlessly.
* **Mandatory Upgrade Popup:** Implemented a launch-time iOS-styled popup in `HomeScreen` that detects old deprecated models (like Moonshine), forces deletion to save space, and automatically triggers the new Whisper download.
* **Silero VAD (1.8 MB):** Integrated the ultra-lightweight Silero VAD v4 model (1.8 MB) to detect human speech locally on-device. Fixed an initialization crash in `whisper_stt_engine.dart` by explicitly setting the window size to `512`.
* **Deepgram Cloud STT:** Maintained support for streaming to Deepgram (nova-3) for high-fidelity cloud transcription.
* **PCM Alignment Fix:** Addressed audio phase-shifting (chipmunk/slowed down audio) in `SimulatorPendantSource`. Implemented a byte-alignment buffer to gracefully handle odd-byte-length audio chunks, ensuring perfectly aligned 16-bit PCM frames.
* **Bluetooth Scan Retry:** Fixed an issue where the "Scan again" button in the `BluetoothPendantSource` would remain disabled or silently fail. It now forcefully stops any existing scans before instantly restarting.

## 2. Safe Hardware Simulation
* **Simulator Toggle:** Implemented a clean `kUseSimulator` toggle in `ble_provider.dart`. This allows the team to seamlessly switch between the physical hardware (`BluetoothPendantSource`) and the local desktop microphone (`SimulatorPendantSource`) without breaking production code.

## 3. Complete iOS 18 Design Language Update (UI/UX)
* **Architectural Shift (UI Framework)**: Fully migrated from Material Design to native Cupertino (iOS 18) styling across the entire app.
* **Theme & Typography**: Removed all Material colors and themes (`kTanuBg`, `kTanuInk`, etc.). Implemented `CupertinoThemeData` utilizing system colors and `GoogleFonts.inter` (to cleanly mimic Apple's SF Pro) to provide an authentic, modern iOS 18 aesthetic.
* **Dynamic Dark/Light Mode Engine:**
  - Integrated `CupertinoDynamicColor.resolveFrom(context)` throughout the codebase to ensure responsive color mapping for elements like containers, text, and custom pills.
  - Implemented `AppSettings` (via Riverpod + Hive) for real-time appearance toggling (System, Light, Dark).
  - Fixed hardcoded Material colors that caused text and icons to render improperly in Dark Mode across `chat_screen.dart`, `state_indicator.dart`, and `connection_status_bar.dart`.
* **Native iOS Components:**
  - Adopted `CupertinoPageScaffold`, `CupertinoSliverNavigationBar`, and `CupertinoListSection.insetGrouped` across all screens.
  - Redesigned `CommitmentsScreen`, `ChatScreen`, `SettingsScreen`, and `HomeScreen` with native iOS styling, removing all Material artifacts (e.g. `Divider`, `Card`, `ListTile`).
  - Swapped all `Icons.*` for native `CupertinoIcons.*`.
  - Replaced standard ListViews with CustomScrollViews to support bouncy physics.
* **Device Picker Sheet**: Converted from a Material `BottomSheet` to an iOS-styled modal popup invoked via `showCupertinoModalPopup`.

## 4. Tanu Intelligence (AI Architecture)
* **Memory Processor:** Rewrote the isolated `CommitmentExtractor` into a unified `MemoryProcessor` within `mistral_agent_engine.dart`. It now parses the raw transcript and requests a single JSON payload containing: a Title, a Summary, and To-Dos.
* **Mock Fallbacks:** Added safety fallbacks to `MistralAgentEngine`. If no `MISTRAL_API_KEY` is provided, the engine will simulate a processing delay and return mock AI data.
* **State Management:** Created `agent_provider.dart` to cleanly expose the Mistral Engine to Riverpod. 
* **Background Processing:** Updated `conversation_provider.dart`. When a session closes, it triggers a background task to process the memory via the `MemoryProcessor`, updates the Hive storage with the new AI summary, and pipes any extracted action items into the `CommitmentsProvider`.

## 5. Interactive Memory Chat
* **Session Detail Upgrade:** Transformed `SessionDetailPage` (`chat_screen.dart`) from a static, read-only list of words into an interactive memory assistant.
* **Chat Interface:** Added an AI Summary card at the top, and a sticky chat input field at the bottom.
* **Contextual Q&A:** Users can type questions about their specific memory. The app passes the question and the memory's transcript to Mistral, streaming the contextual answer directly into a chat bubble history.
