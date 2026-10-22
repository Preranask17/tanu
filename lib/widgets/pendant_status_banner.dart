import 'package:flutter/material.dart';

import '../theme/tanu_colors.dart';

/// Flat symmetrical banner positioned below the AppBar showing pendant status.
/// Uses ValueNotifier for isolated micro-rebuilds without re-rendering parent widgets.
///
/// Tapping the banner cycles the audio status through three states:
/// "Listening...", "Syncing 2 entries...", and "Up to date".
class PendantStatusBanner extends StatelessWidget {
  const PendantStatusBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    // Use ValueNotifier for lightweight state management - only this widget
    // rebuilds when state changes, not parent widgets
    final _statusNotifier = ValueNotifier<BannerState>(BannerState.listening);

    // Cycle through states on tap
    _statusNotifier.addListener(() {
      // Listener triggered on value change - used for rebuild
    });

    return ValueListenableBuilder(
      valueListenable: _statusNotifier,
      builder: (context, state, child) => GestureDetector(
        onTap: () {
          // Cycle through the three states
          final nextIndex = (_statusNotifier.value.index + 1) % 3;
          _statusNotifier.value = BannerState.values[nextIndex];
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: c.scaffold,
            border: Border(
              bottom: BorderSide(
                color: c.border,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Bluetooth state indicator
              _StatusDot(isConnected: state == BannerState.listening),
              const SizedBox(width: 8),
              // Battery level
              Text(
                '85%',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              // Audio state
              Text(
                _getAudioText(state),
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: c.heading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAudioText(BannerState state) {
    switch (state) {
      case BannerState.listening:
        return 'Listening...';
      case BannerState.syncing:
        return 'Syncing 2 entries...';
      case BannerState.upToDate:
        return 'Up to date';
    }
  }
}

/// Internal enum for banner audio states.
enum BannerState { listening, syncing, upToDate }

/// Small dot indicator showing Bluetooth connection state.
class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.isConnected,
    super.key,
  });

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final color = isConnected ? c.success : c.textMuted;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}