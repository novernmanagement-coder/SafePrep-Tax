import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'dashboard_page.dart';
import 'fsme_post_purchase_landing.dart';
import 'home_page.dart';
import 'onboard/onboard_intro.dart';

// DEBUG ONLY — do not ship. Reached only via SplashPage's access-code
// prompt (see the class-level note on SplashPage's _accessCode) — by
// the time the user lands here, access has already been verified once,
// so this page does NOT re-prompt. It just shows the destination menu
// directly.
//
// To revert: change SplashPage's access-code success branch back to
// OnboardIntro and delete this file (and its import there).
class SplashNavigatingPage extends StatelessWidget {
  const SplashNavigatingPage({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  // Windows/desktop dev builds have no working IAP store, so
  // AppState().hasUnlockedApp is never set to true by a real purchase
  // — SafePrepNavBar's gate then bounces straight to OnboardPaywall
  // on any attempt to reach Dashboard or Rapid Fire. This forces the
  // unlocked state directly so local testing doesn't require a real
  // purchase or a TestFlight round-trip.
  //
  // kDebugMode-gated: compiles to nothing in release builds, so it
  // can never be used as a free-unlock path in a shipped app even if
  // this file is accidentally left wired in.
  void _forceUnlockForDebug() {
    if (!kDebugMode) return;
    AppState().hasUnlockedApp = true;
    AppState().purchaseType = PurchaseType.lifetime;
  }

  // TEMP DEBUG (Aug 2026) — the Renew/Lifetime nav button only shows
  // once daysRemaining <= 2 on a real 7-day purchase (see
  // safe_prep_nav_bar.dart's showRenew), which normally means waiting
  // 5 real days after a real purchase before that flow is reachable
  // at all. Backdating purchaseDate here lets the REAL purchase code
  // path (Play Billing, kProductLifetimeOfferAndroid, etc. — not the
  // force-unlock stub below, which is fake and kDebugMode-only) be
  // tested on a release build without the wait. Requires an existing
  // real purchase already in progress (hasUnlockedApp + a time-limited
  // purchaseType) — does nothing to a never-purchased or lifetime
  // account. NOT kDebugMode-gated, same reasoning as the rest of this
  // page: it's only reachable via the access-code prompt already.
  // Remove this button once the $2.99 lifetime offer has been
  // confirmed working.
  Future<void> _fastForwardPurchaseForDebug(BuildContext context) async {
    final state = AppState();
    if (!state.hasUnlockedApp ||
        !state.isTimeLimited ||
        state.purchaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No active 7-day/14-day purchase to fast-forward — buy the '
            '\$4.99 seven-day first.',
          ),
        ),
      );
      return;
    }
    state.purchaseDate = state.purchaseDate!.subtract(
      const Duration(days: 5),
    );
    await AppStatePersistence.save();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Purchase backdated 5 days — daysRemaining is now '
          '${state.daysRemaining}. Renew/Lifetime button should show on '
          'Home.',
        ),
      ),
    );
    _go(context, const HomePage());
  }

  // TEMP DEBUG (Aug 2026) — AppState.reset() deliberately preserves
  // limitedRapidFireRoundsUsed (see app_state.dart) so a normal
  // "reset progress" action can't be used to farm free show-me-more
  // rounds. That's correct for real users, but it means local testing
  // permanently uses up both rounds unless something resets the
  // counter directly. This button does that. Same reasoning as the
  // rest of this page: only reachable via the access-code prompt
  // already, so it's not a real-user-facing free-unlock path. Remove
  // once the Rapid Fire "show me more" upgrade is done being tested.
  Future<void> _resetShowMeMoreRoundsForDebug(BuildContext context) async {
    AppState().limitedRapidFireRoundsUsed = 0;
    await AppStatePersistence.save();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Show-me-more rounds reset to 0/2 — the paywall’s '
          '"Try this first" link should be back.',
        ),
      ),
    );
  }

  Widget _destButton(BuildContext context, String label, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: AppSizes.primaryButtonHeight,
        child: ElevatedButton(
          onPressed: () => _go(context, page),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF13130F),
            foregroundColor: const Color(0xFFF0EDE8),
            side: const BorderSide(color: Color(0xFFD4AF37)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Debug navigation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _destButton(
                  context,
                  'FSME (post-purchase landing)',
                  const FsmePostPurchaseLanding(),
                ),
                _destButton(
                  context,
                  'Onboard Intro (funnel)',
                  const OnboardIntro(),
                ),
                _destButton(context, 'Home Page', const HomePage()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: AppSizes.primaryButtonHeight,
                    child: ElevatedButton(
                      onPressed: () {
                        _forceUnlockForDebug();
                        _go(context, const DashboardPage());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13130F),
                        foregroundColor: const Color(0xFFF0EDE8),
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.buttonCornerRadius,
                          ),
                        ),
                      ),
                      child: const Text('Dashboard (force-unlocked)'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: AppSizes.primaryButtonHeight,
                    child: ElevatedButton(
                      onPressed: () => _fastForwardPurchaseForDebug(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13130F),
                        foregroundColor: const Color(0xFFF0EDE8),
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.buttonCornerRadius,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Fast-forward purchase 5 days (test Renew/Lifetime)',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: AppSizes.primaryButtonHeight,
                    child: ElevatedButton(
                      onPressed: () => _resetShowMeMoreRoundsForDebug(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13130F),
                        foregroundColor: const Color(0xFFF0EDE8),
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.buttonCornerRadius,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Reset show-me-more rounds (0/2)',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
