Complete change summary
Capture UI
Updated home_screen.dart:

Redesigned the Capture page layout.
Removed Recent Memories from Capture.
Removed the orb’s surrounding card/box.
Improved desktop and mobile spacing.
Aligned the Capture page title with Memories and Settings.
Standardized the Capture heading font and size.
Added connection status presentation.
Added connected, connecting, reconnecting, scanning, and disconnected states.
Added battery percentage display.
Improved the Capture hero text.
Preserved the on-device privacy messaging.
Kept the VoicePill inline instead of floating.
Adjusted bottom spacing for desktop and mobile navigation.
Added responsive max-width content behavior.
VoicePill
Rebuilt voice_pill.dart:

Rebuilt the VoicePill from scratch.
Added idle state with “Tap to capture.”
Added listening state.
Added paused state.
Added cancelling state.
Added elapsed recording timer.
Added pause and resume controls.
Added stop/save control.
Added swipe-left cancellation.
Added haptic feedback.
Added animated active-state transitions.
Added transcript display inside the pill.
Removed the waveform after the UI review.
Preserved light and dark theme support.
Kept compatibility with the existing microphone level API.
Aura Orb
Updated aura_orb.dart:

Made the orb responsive to available screen size.
Improved glow sizing.
Added continuous animation.
Made the orb pulse based on microphone level.
Increased visual response during louder speech.
Improved the connected/disconnected visual states.
Removed the surrounding container from the Capture page.
Memories
Updated conversations_screen.dart:

Standardized the Memories page title.
Aligned the Memories title with the shared page rail.
Improved title spacing.
Added consistent icon button styling.
Added search and trash tooltips/affordances.
Improved hover/cursor behavior.
Preserved search, filtering, pinning, deletion, and trash navigation.
Preserved grouped memory presentation by date.
Settings
Updated settings_screen.dart:

Removed “Make Tanu feel like yours.”
Kept the page title as “Settings.”
Reused the existing DM Serif Display heading font.
Redesigned the Settings page structure.
Added responsive content width.
Added pendant connection dashboard.
Added battery/readiness state.
Added appearance controls.
Added speech engine/model status.
Added memory/privacy controls.
Added developer diagnostics console.
Added raw audio capture status.
Added BLE statistics and codec information.
Aligned Settings content with the same page rail as Capture and Memories.
Shared UI layout
Added page_layout.dart:

Added shared page max width.
Added shared page gutters.
Added reusable page title widget.
Added reusable page content rail.
Added reusable icon button styling.
Centralized layout values so page titles do not drift independently.
Navigation and responsive behavior
Updated responsive_scaffold.dart:

Improved desktop sidebar navigation.
Improved mobile navigation dock.
Added animated selected states.
Added hover cursors.
Added navigation tooltips.
Improved active icon styling.
Preserved repeat-tap scroll-to-top behavior.
Preserved desktop sidebar and mobile bottom navigation behavior.
Live conversation UI
Updated chat_screen.dart:

Redesigned the live conversation page as a fullscreen black UI.
Added centered Tanu title.
Added close button.
Added compact Bluetooth and battery status.
Added live header waveform.
Removed the duplicate transcript-area waveform.
Preserved transcript grouping.
Preserved partial transcript rendering.
Preserved timestamps.
Preserved session detail navigation.
Bluetooth reliability
Updated bluetooth_pendant_source.dart:

Added connection-attempt tracking.
Prevented overlapping BLE connection attempts.
Attached the connection listener before setup.
Ignored the initial Windows disconnected event during active connection setup.
Handled already-connected devices.
Preserved setup when the platform reports an already-connected error.
Improved reconnect timer cancellation.
Prevented repeated reconnect loops.
Stopped reconnect attempts when Bluetooth is disabled.
Cleared stale battery metadata on disconnect.
Cleared stale device names on disconnect.
Improved teardown of audio, button, connection, and battery subscriptions.
Preserved service discovery and characteristic subscription behavior.
Preserved codec detection and Opus setup.
Updated ble_provider.dart:

Emits the current Bluetooth status immediately.
Prevents the UI from waiting for a future status event.
Preserved reconnect and device-picker providers.
Updated audio_source.dart:

Extended PendantStatus.copyWith.
Added explicit stale battery clearing.
Added explicit stale device-name clearing.
Speech-to-text
Updated moonshine_stt_engine.dart:

Preserved Moonshine v2 base English model.
Tuned VAD confidence for better accuracy.
Restored a safer minimum speech duration.
Restored a safer minimum decoded segment length.
Restored a stronger minimum-energy filter.
Tuned trailing silence to reduce delay without clipping words.
Preserved valid short responses such as “yes,” “no,” and “you.”
Added partial transcript delivery before final delivery.
Removed the temporary ? prefix from partial text.
Preserved hallucination filtering for known filler phrases.
Kept the 16kHz mono PCM pipeline.
Preserved isolate-based recognizer execution.
Updated conversation_provider.dart:

Kept partial transcript segments open until finalization.
Prevented duplicate transcript entries from partial/final results.
Removed over-aggressive filtering of valid short phrases.
Preserved session lifecycle behavior.
Preserved pause/resume/stop behavior.
Preserved active memory persistence.
Preserved automatic session processing.
Maintenance
Updated app.dart:

Removed an unused import.
Updated transcript.dart:

Fixed an invalid startedAt fallback expression.
Confirmed the model file analyzes cleanly.
Validation
UI files analyzed successfully with no issues.
BLE reassembler tests passed: 4/4.
No GitHub pull request was created.
The code was pushed directly to Development.