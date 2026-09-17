# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - MVP build
### Changed
- **Architectural Shift (UI Framework)**: Fully migrated from Material Design to native Cupertino (iOS) styling across the entire app.
- **Theme**: Removed all Material colors and themes (`kTanuBg`, `kTanuInk`, etc.). Implemented `CupertinoThemeData` utilizing system colors (`CupertinoColors.systemBackground`, `CupertinoColors.systemGroupedBackground`, `CupertinoColors.activeBlue`, etc.) to provide an authentic, modern iOS 27 minimalistic and rich aesthetic.
- **Routing & App Shell**:
  - Replaced `MaterialApp` with `CupertinoApp`.
  - Replaced `Scaffold` and `BottomNavigationBar` with `CupertinoTabScaffold` and `CupertinoTabBar` for native iOS tab switching.
- **Home Screen**:
  - Rebuilt with `CupertinoPageScaffold`.
  - Added `CupertinoSliverNavigationBar` for large, bouncy "iOS style" titles.
  - Replaced standard ListViews with CustomScrollViews to support bouncy physics.
  - Revamped action buttons and status cards using `CupertinoButton` and subtle iOS-styled container borders and shadows.
- **Conversations Screen (Memory List)**:
  - Migrated to `CupertinoPageScaffold` with `CupertinoSliverNavigationBar`.
  - Converted the Search bar to `CupertinoSearchTextField`.
  - Adjusted the layout to seamlessly integrate with native iOS safe areas and scrolling physics.
- **Settings Screen**:
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

### Added
- Comprehensive changelog documentation (`CHANGELOG.md`) to track architectural updates and features for the team.
