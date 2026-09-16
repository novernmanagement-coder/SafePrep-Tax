import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'mixpanel_service.dart';
import 'iap_service.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'rapid_fire_page.dart';
import 'onboard/onboard_paywall.dart';

class SafePrepNavBar extends StatefulWidget {
  final bool isDashboardPage;

  const SafePrepNavBar({super.key, this.isDashboardPage = false});

  @override
  State<SafePrepNavBar> createState() => _SafePrepNavBarState();
}

class _SafePrepNavBarState extends State<SafePrepNavBar> {
  bool _purchaseInFlight = false;

  void _goHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  // Gated on real purchase state — lifetime is the only tier now, so
  // this is just "never purchased." Locked users route to
  // OnboardPaywall — confirmed the sole active in-app paywall; the old
  // preview/PreviewRevealPage screen is no longer used anywhere and
  // should not be re-added.
  void _goDashboard(BuildContext context) {
    final state = AppState();
    final bool locked = !state.hasUnlockedApp;
    if (locked) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardPaywall()),
        (route) => false,
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

  // Same gate as _goDashboard() — previously Rapid Fire had NO lock
  // check at all here, relying only on the old paywall page hiding
  // its own nav footer to indirectly block access. That's a real gap
  // if a locked user reaches this nav bar from anywhere else it
  // appears, so this button now checks directly like Dashboard does.
  void _goRapidFire(BuildContext context) {
    final state = AppState();
    final bool locked = !state.hasUnlockedApp;
    if (locked) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardPaywall()),
        (route) => false,
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RapidFirePage()),
    );
  }

  // The only purchase this app sells — the $19.99 lifetime unlock.
  Future<void> _buyNow(BuildContext context) async {
    if (_purchaseInFlight) return;
    setState(() => _purchaseInFlight = true);

    MixpanelService.instance.track(
      'paywall_viewed',
      properties: {'source': 'nav_bar', 'app_name': 'ST'},
    );

    var result = await IAPService.instance.buyUnlockApp();

    if (!mounted) return;

    // See IAPService.waitForLateUnlock — a timeout doesn't necessarily
    // mean the purchase failed, just that confirmation arrived late.
    if (result == IAPResult.timeout) {
      final unlockedLate = await IAPService.instance.waitForLateUnlock();
      if (!mounted) return;
      if (unlockedLate) result = IAPResult.success;
    }

    setState(() => _purchaseInFlight = false);

    if (result == IAPResult.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You're unlocked! 🎉")));
      return;
    }

    if (result == IAPResult.canceled) {
      return;
    }

    final message = result.userMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState();
    final bool isUnlocked = state.hasUnlockedApp;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        spacing: 6,
        children: [
          Expanded(
            child: _NavButton(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () => _goHome(context),
            ),
          ),
          Expanded(
            child: _NavButton(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () => _goDashboard(context),
            ),
          ),
          Expanded(
            child: _NavButton(
              icon: Icons.bolt_outlined,
              label: 'Rapid Fire',
              onTap: () => _goRapidFire(context),
            ),
          ),
          if (!isUnlocked)
            Expanded(
              child: _UnlockNavButton(
                loading: _purchaseInFlight,
                onTap: () => _buyNow(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnlockNavButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _UnlockNavButton({required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: SizedBox(
        height: AppSizes.footerButtonHeight,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0F),
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: AppSizes.buttonBorderThickness,
            ),
            borderRadius: BorderRadius.circular(
              AppSizes.footerButtonCornerRadius,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD4AF37),
                      ),
                    )
                  : const Icon(Icons.star, size: 18, color: Color(0xFFD4AF37)),
              Text(
                'Unlock',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppFonts.label,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: AppSizes.footerButtonHeight,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryButton,
            border: Border.all(
              color: AppColors.footerButtonBorder,
              width: AppSizes.buttonBorderThickness,
            ),
            borderRadius: BorderRadius.circular(
              AppSizes.footerButtonCornerRadius,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              Icon(icon, size: 18, color: AppColors.secondaryButtonForeground),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFonts.label,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryButtonForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
