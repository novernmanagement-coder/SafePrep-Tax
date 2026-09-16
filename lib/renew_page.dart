// NOTE: file kept as renew_page.dart (no rename/delete — this device
// can't rename or delete files). This used to be the $2.99 "renew
// your 7-day access" screen for the old sevenDay/fourteenDay purchase
// tiers. Sept 2026 — those tiers were removed wholesale when SafePrep
// Tax went lifetime-only ($19.99, no expiry, nothing to renew), and
// nothing in the app routes here anymore (safe_prep_nav_bar.dart's
// _goRenew() and its Renew nav button were deleted in the same pass).
// Gutted to a harmless stub rather than left as dead code that still
// calls the now-removed AppState.expiryDate / IAPService.buyRenewal().
// Do not re-wire this without re-adding a time-limited purchase tier.
import 'package:flutter/material.dart';

class RenewPage extends StatelessWidget {
  const RenewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('This page is no longer used.')),
    );
  }
}
