# Tanu App - Changelog & Architecture Updates

This document outlines the end-to-end changes made during the latest development sprint. The app was transformed from a basic audio dictation tool into an intelligent, polished AI memory assistant.

---

## 1. Core Audio Pipeline & BLE Fixes
* **Silero VAD Window Size Fix:** Fixed an initialization crash in `moonshine_stt_engine.dart` by explicitly setting the window size for the Silero VAD v4 model to `512` (previously it was defaulting to an incompatible size).
* **PCM Alignment Fix:** Addressed audio phase-shifting (chipmunk/slowed down audio) in `SimulatorPendantSource`. Implemented a byte-alignment buffer to gracefully handle odd-byte-length audio chunks, ensuring perfectly aligned 16-bit PCM frames.
* **Scan Again Fix:** Fixed a bug in `BluetoothPendantSource` where the "Scan again" button in the device picker would silently fail if the system thought it was already scanning. It now forcefully stops any existing scans before restarting.

## 2. Safe Hardware Simulation
* **Simulator Toggle:** Implemented a clean `kUseSimulator` toggle in `ble_provider.dart`. This allows the team to seamlessly switch between the physical hardware (`BluetoothPendantSource`) and the local desktop microphone (`SimulatorPendantSource`) without polluting or breaking the production hardware code.

## 3. UI/UX Overhaul: Minimalist Monolith
We completely pivoted the visual design language from a warm, notebook-style aesthetic to a premium, high-contrast "Minimalist Monolith" design (similar to Apple HIG and modern SaaS).
* **Typography:** Added the `google_fonts` package and migrated the entire app to the `Inter` typeface for crisp, geometric readability.
* **Palette:** Stripped out beiges and greens. Replaced with stark off-white backgrounds (`#FAFAFA`), pure white surfaces, and deep black (`#111111`) ink.
* **Floating Components:** Replaced harsh borders in `home_screen.dart` and `conversation_tile.dart` with meticulously tuned, ultra-soft drop shadows. 
* **Navigation:** Redesigned `bottom_nav_bar.dart` from a full-width gradient block into a sleek, floating white pill.
* **Equalizer:** Replaced the neon green active-listening equalizer with a sophisticated monochrome (black/grey) wave.

## 4. Tanu Intelligence (AI Architecture)
We wired up the "Brain" of the app to process raw transcripts into structured, actionable memories.
* **Memory Processor:** Rewrote the isolated `CommitmentExtractor` into a unified `MemoryProcessor` within `mistral_agent_engine.dart`. It now parses the raw transcript and requests a single JSON payload containing:
  1. A smart Title
  2. A 2-sentence Summary
  3. Extracted Commitments/To-Dos
* **Mock Fallbacks:** Added safety fallbacks to `MistralAgentEngine`. If no `MISTRAL_API_KEY` is provided, the engine will simulate a processing delay and return mock AI data, preventing the app from crashing and allowing the team to test the UI safely.
* **State Management:** Created `agent_provider.dart` to cleanly expose the Mistral Engine to Riverpod. 
* **Background Processing:** Updated `conversation_provider.dart`. When a session closes (`forceEndSession`), it triggers a background task to process the memory via the `MemoryProcessor`, updates the Hive storage with the new AI summary, and pipes any extracted action items into the `CommitmentsProvider`.
* **Data Model:** Upgraded `ConversationSession` in `transcript.dart` to support storing the AI `summary`.

## 5. Interactive Memory Chat
* **Session Detail Upgrade:** Transformed `SessionDetailPage` (`chat_screen.dart`) from a static, read-only list of words into an interactive memory assistant.
* **Chat Interface:** Added an AI Summary card at the top, and a sticky chat input field at the bottom.
* **Contextual Q&A:** Users can now type questions about their specific memory. The app passes the question and the memory's transcript to Mistral, streaming the contextual answer directly into a chat bubble history.
