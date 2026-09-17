# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - MVP build
### Changed
- **Architectural Shift (UI Framework)**: Fully migrated from Material Design to native Cupertino (iOS) styling across the entire app.
- **Theme**: Removed all Material colors and themes (`kTanuBg`, `kTanuInk`, etc.). Implemented `CupertinoThemeData` utilizing system colors (`CupertinoColors.systemBackground`, `CupertinoColors.systemGroupedBackground`, `CupertinoColors.activeBlue`, etc.) to provide an authentic, modern iOS 27 minimalistic and rich aesthetic.
- **Complete iOS 18 Design Language Update:**
  - Migrated entire app structure from `MaterialApp` to pure `CupertinoApp` (iOS 18 style).
  - Adopted `CupertinoPageScaffold`, `CupertinoSliverNavigationBar`, and `CupertinoListSection.insetGrouped` across all screens.
  - Redesigned `CommitmentsScreen`, `ChatScreen`, `SettingsScreen`, and `HomeScreen` with native iOS styling, removing all Material artifacts (e.g. `Divider`, `Card`, `ListTile`).
  - Swapped all `Icons.*` for native `CupertinoIcons.*`.
- **Dynamic Dark/Light Mode Engine:**
  - Integrated `CupertinoDynamicColor.resolveFrom(context)` throughout the codebase to ensure responsive color mapping for elements like containers, text, and custom pills.
  - Implemented `AppSettings` (via Riverpod + Hive) for real-time appearance toggling (System, Light, Dark).
  - Replaced standard ListViews with CustomScrollViews to support bouncy physics.
  - Revamped action buttons and status cards using `CupertinoButton` and subtle iOS-styled container borders and shadows.
- **Conversations Screen (Memory List)**:
  - Migrated to `CupertinoPageScaffold` with `CupertinoSliverNavigationBar`.
  - Converted the Search bar to `CupertinoSearchTextField`.
  - Adjusted the layout to seamlessly integrate with native iOS safe areas and scrolling physics.
- **Settings Screen**:
  - Added a new `APPEARANCE` section with a `CupertinoSlidingSegmentedControl` to toggle between System, Light, and Dark modes.
  - Refactored entire layout from standard `ListView` to `CupertinoListSection.insetGrouped` for the classic iOS settings appearance.
  - Replaced custom tiles with `CupertinoListTile`.
  - Replaced standard toggles with `CupertinoSwitch`.
  - Converted all dialogs (delete confirmations, etc.) to `CupertinoAlertDialog` invoked via `showCupertinoDialog`.
- **Chat Screen & Session Detail (Live Memory)**:
  - Migrated to `CupertinoPageScaffold`.
  - Replaced standard AppBar with `CupertinoNavigationBar` (inline middle titles for pushed pages).
  - Redesigned chat bubbles to use iOS styling (Blue for user, Grey/White for assistant).
  - Migrated text input to `CupertinoTextField` with an integrated rounded `CupertinoButton` for the send action.
  - Replaced `CircularProgressIndicator` with `CupertinoActivityIndicator`.
- **Device Picker Sheet**:
  - Converted from a Material `BottomSheet` to an iOS-styled modal popup invoked via `showCupertinoModalPopup`.
  - Styled with native background colors, rounded top edges, and standard Cupertino typography.

### Fixed
- **Bluetooth Scan Retry**: Fixed the `BluetoothPendantSource` to allow the user to successfully retry scanning for devices when the initial scan times out or fails. The "Scan again" button is now fully functional.
- **Dark Mode UI Inconsistencies**: Fixed hardcoded Material colors and missing `resolveFrom(context)` calls in `chat_screen.dart`, `state_indicator.dart`, and `connection_status_bar.dart` that caused text and icons to render improperly in Dark Mode.
- **Material Icon Crashes**: Replaced leftover Material `Icons.*` with `CupertinoIcons.*` in `state_indicator.dart` and `connection_status_bar.dart`.

### Added
- **Dark Mode Support**: Full support for iOS dark mode natively.
- Comprehensive changelog documentation (`CHANGELOG.md`) to track architectural updates and features for the team.
