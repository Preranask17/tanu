# Tanu App - Changelog & Architecture Updates

This document outlines the end-to-end changes made during the latest development sprint. The app was transformed from a basic audio dictation tool into an intelligent, polished iOS-style AI memory assistant.

---

## 1. Core Audio Pipeline & On-Device Models
* **Silero VAD (1.8 MB):** Integrated the ultra-lightweight Silero VAD v4 model (1.8 MB) to detect human speech locally on-device. Fixed an initialization crash in `moonshine_stt_engine.dart` by explicitly setting the window size to `512`.
* **Moonshine STT (44 MB):** Integrated the `moonshine-tiny-en.tar.bz2` (44 MB) on-device speech-to-text model for robust offline audio processing.
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
