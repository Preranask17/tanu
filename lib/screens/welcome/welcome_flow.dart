import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import 'onboarding_pages.dart';
import 'orb_enter_transition.dart';
import 'wave_dot_background.dart';

/// First-run experience: 6-page mini manual -> orb "entering TANU"
/// transition -> existing main app.
///
/// There is deliberately NO formation/loading movie here: first launch goes
/// straight into onboarding. The formation movie lives in
/// [ReturningStartupGate] and only plays on cold starts after onboarding.
///
/// Sits strictly BEFORE the app: it only calls the existing
/// `completeOnboarding()` once the enter-transition ends (screen is black,
/// so the swap is invisible). No backend code is touched.
class WelcomeFlow extends ConsumerStatefulWidget {
  const WelcomeFlow({super.key});

  @override
  ConsumerState<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends ConsumerState<WelcomeFlow> {
  bool _entering = false;
  bool _finished = false;

  /// Get Started: swap to the orb zoom; when it ends (black screen), flip
  /// the existing onboarding flag — [app.dart] swaps to the main app itself.
  void _beginEnter() {
    if (_entering) return;
    setState(() => _entering = true);
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    ref.read(settingsProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: _entering
          ? OrbEnterTransition(
              key: const ValueKey('entering'),
              onDone: _complete,
            )
          : _OnboardingPager(
              key: const ValueKey('pages'),
              onDone: _beginEnter,
            ),
    );
  }
}

class _OnboardingPager extends StatefulWidget {
  const _OnboardingPager({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<_OnboardingPager> createState() => _OnboardingPagerState();
}

class _OnboardingPagerState extends State<_OnboardingPager> {
  late final PageController _pages;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) {
    HapticFeedback.selectionClick();
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = buildWelcomePages();
    final last = _index == pages.length - 1;

    return Scaffold(
      // First-run cinematic is intentionally dark on all theme modes.
      backgroundColor: Colors.black,
      // Persistent dot-wave backdrop behind every page; foreground column
      // stays interactive on top (background is pointer-transparent).
      body: Stack(
        children: [
          // Page-driven morphing backdrop (reads the same PageController,
          // so finger drags AND arrow taps morph it in sync).
          Positioned.fill(child: WaveDotBackground(pages: _pages)),
          SafeArea(
            child: Column(
              children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final page in pages)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      // Centers short content, scrolls tall content: no
                      // overflow on small/short screens.
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            // IntrinsicHeight centers short content AND gives
                            // the pages' Expanded children finite height.
                            // Pages must avoid LayoutBuilder (it cannot
                            // resolve inside intrinsic measurement) — use
                            // MediaQuery sizing instead.
                            child: IntrinsicHeight(child: page),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Circular dot indicators: active slightly larger.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 9 : 6,
                    height: i == _index ? 9 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index
                          ? Theme.of(context).primaryColor
                          : const Color(0xFF333333),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Arrow controls · Get Started on the final page.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: last
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onDone();
                        },
                        child: const Text('Get Started with TANU'),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Visibility(
                          visible: _index > 0,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: _ArrowButton(
                            icon: Icons.arrow_back,
                            onTap: () => _go(_index - 1),
                          ),
                        ),
                        _ArrowButton(
                          icon: Icons.arrow_forward,
                          onTap: () => _go(_index + 1),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal circular arrow control in the app's surface language.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
          border: Border.all(
            color:
                isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFFBBBBBB),
        ),
      ),
    );
  }
}
