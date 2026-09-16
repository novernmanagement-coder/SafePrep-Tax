// NOTE: file kept as lifetime_offer_page.dart (no rename/delete — this
// device can't rename or delete files). This used to be the
// Android-only $2.99 "one-time lifetime unlock" upsell shown to
// existing 7-day/14-day purchasers on day 5. Sept 2026 — the
// sevenDay/fourteenDay tiers were removed wholesale when SafePrep Tax
// went lifetime-only ($19.99 up front, nothing to upsell to), and
// nothing in the app routes here anymore (safe_prep_nav_bar.dart's
// _goRenew() and its Renew nav button were deleted in the same pass).
// Gutted to a harmless stub rather than left as dead code that still
// calls the now-removed IAPService.buyLifetimeOffer() /
// kProductLifetimeOfferAndroid. Do not re-wire this without
// re-adding a time-limited purchase tier.
import 'package:flutter/material.dart';

class LifetimeOfferPage extends StatelessWidget {
  const LifetimeOfferPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('This page is no longer used.')),
    );
  }
}
