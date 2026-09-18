import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'mixpanel_service.dart';

// ─────────────────────────────────────────────────────────────────
// Product IDs
//
// iOS values must match App Store Connect exactly (mixed-case,
// already live there — do not change these). Google Play product
// IDs cannot contain any uppercase letters at all (Play Console
// rejects them outright at creation time), so Android gets its own
// lowercase-only ID below — same underlying product, a different ID
// string per store. Everything else in this file just uses this
// constant and never needs to branch on platform itself.
//
// Sept 2026 — this is now the ONLY product SafePrep Tax sells. The
// old sevenDay/fourteenDay/upgrade/renewal/Android-lifetime-offer
// tiers were removed wholesale (dead the moment the app went
// lifetime-only) — see the app's memory file if you need the old
// pricing/product-ID history.
//
// Uses defaultTargetPlatform (flutter/foundation.dart) rather than
// dart:io's Platform.isAndroid — this file is still imported on the
// web build (even though IAPService.initialize() itself is never
// called there, see main.dart), and dart:io does not exist on web at
// all: importing it is a hard compile-time failure for `flutter build
// web`, not just a runtime one. defaultTargetPlatform is safe on
// every platform, web included.
// ─────────────────────────────────────────────────────────────────
final String kProductUnlockApp = defaultTargetPlatform == TargetPlatform.android
    ? 'android_st_unlock'
    : 'SafePrepTaxUnlock'; // $19.99 — lifetime, the only paywall offer.
// Price must also be set in App Store Connect / Play Console, since
// the store — not this file — is the source of truth for the
// actual charged amount; the fallback price string below is only
// what shows before the store's real price has loaded.

// How long a buy* call will wait for StoreKit to resolve (purchased,
// canceled, or errored) before giving up and returning IAPResult.timeout.
// Prevents a nav bar / button loading spinner from getting stuck forever
// if the purchase stream never emits for some edge case (e.g. app
// backgrounded mid-purchase and StoreKit's callback gets lost).
const Duration _purchaseTimeout = Duration(seconds: 90);

// ─────────────────────────────────────────────────────────────────
// IAPService
// ─────────────────────────────────────────────────────────────────
class IAPService {
  IAPService._();
  static final IAPService instance = IAPService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  ProductDetails? _unlockProduct;

  bool _available = false;
  bool get isAvailable => _available;

  // Tracks in-flight purchases so _onPurchaseUpdate can resolve the
  // Future that the calling buy* method is awaiting. Keyed by product ID
  // — this app only ever has one purchase in flight per product at a
  // time, since buy buttons disable themselves while loading.
  final Map<String, Completer<IAPResult>> _pendingPurchases = {};

  // ── Sandbox / TestFlight detection ─────────────────────────
  // Distinguishes real App Store purchases from TestFlight/sandbox
  // ones so analytics (Mixpanel) can be filtered clean of test data.
  // TestFlight purchases use a real Apple ID but resolve through
  // Apple's sandbox backend, and StoreKit/in_app_purchase gives no
  // Dart-level signal for this — the only reliable check is whether
  // the on-device App Store receipt file is named "sandboxReceipt"
  // instead of the production receipt name, which requires a native
  // platform channel call (see ios/Runner/AppDelegate.swift).
  static const _receiptChannel = MethodChannel(
    'com.geraldmiller.safepreptax/receipt',
  );
  bool? _isSandboxCached;

  Future<bool> _isSandboxEnvironment() async {
    if (_isSandboxCached != null) return _isSandboxCached!;
    try {
      _isSandboxCached =
          await _receiptChannel.invokeMethod<bool>('isSandboxReceipt') ?? false;
    } catch (e) {
      debugPrint('Sandbox receipt check failed: $e');
      // Fail safe — if the check errors for any reason, assume
      // production rather than silently mislabeling real sales as
      // test data.
      _isSandboxCached = false;
    }
    return _isSandboxCached!;
  }

  // ── Initialization ──────────────────────────────────────────
  Future<void> initialize() async {
    // TIMEOUT GUARD (Aug 2026) — isAvailable() and queryProductDetails()
    // below are platform-channel calls into Play Billing/StoreKit with
    // no built-in timeout. A hung billing connection (seen right after
    // a fresh Play Store install) would previously await forever.
    // main() no longer blocks runApp() on this call, but without a cap
    // here IAP would just silently never become available for the rest
    // of the session if the platform call never resolves — so fail
    // safe after a reasonable wait instead.
    try {
      _available = await _iap.isAvailable().timeout(
        const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('IAP isAvailable() timed out or failed: $e');
      _available = false;
    }
    if (!_available) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (e) => debugPrint('IAP stream error: $e'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final ProductDetailsResponse response;
    try {
      response = await _iap
          .queryProductDetails({kProductUnlockApp})
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('IAP product load timeout/error: $e');
      return;
    }

    if (response.error != null) {
      debugPrint('IAP product load error: ${response.error}');
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'Play could not find these product IDs: '
        '${response.notFoundIDs.join(', ')} '
        '(requested ${response.productDetails.length + response.notFoundIDs.length} total, '
        'found ${response.productDetails.length})',
      );
    }

    for (final p in response.productDetails) {
      if (p.id == kProductUnlockApp) {
        _unlockProduct = p;
      }
    }

    debugPrint(
      'IAP products loaded: ${response.productDetails.map((p) => p.id).toList()}',
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  // ── Purchase stream handler ─────────────────────────────────
  // This is where the ACTUAL outcome of a purchase becomes known —
  // buyNonConsumable()/buyConsumable() only confirm the request was
  // submitted, not whether the person completed, canceled, or hit an
  // error in the App Store sheet. Every outcome here both resolves
  // the Completer the calling buy* method is waiting on AND logs a
  // Mixpanel event, so purchase outcomes are visible in analytics,
  // not just taps. Every logged event also carries `is_test_purchase`
  // so TestFlight/sandbox activity can be filtered out of real
  // conversion data.
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    final isSandbox = await _isSandboxEnvironment();

    for (final purchase in purchases) {
      final completer = _pendingPurchases[purchase.productID];

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccess(purchase);
          MixpanelService.instance.track(
            'purchase_completed',
            properties: {
              'product_id': purchase.productID,
              'restored': purchase.status == PurchaseStatus.restored,
              'is_test_purchase': isSandbox,
            },
          );
          completer?.complete(IAPResult.success);
          _pendingPurchases.remove(purchase.productID);
          break;

        case PurchaseStatus.error:
          debugPrint('IAP error: ${purchase.error?.message}');
          MixpanelService.instance.track(
            'purchase_failed',
            properties: {
              'product_id': purchase.productID,
              'error': purchase.error?.message ?? 'unknown',
              'is_test_purchase': isSandbox,
            },
          );
          completer?.complete(IAPResult.error);
          _pendingPurchases.remove(purchase.productID);
          break;

        case PurchaseStatus.canceled:
          debugPrint('IAP canceled: ${purchase.productID}');
          MixpanelService.instance.track(
            'purchase_canceled',
            properties: {
              'product_id': purchase.productID,
              'is_test_purchase': isSandbox,
            },
          );
          completer?.complete(IAPResult.canceled);
          _pendingPurchases.remove(purchase.productID);
          break;

        case PurchaseStatus.pending:
          debugPrint('IAP pending: ${purchase.productID}');
          // Don't resolve yet — StoreKit is still working (e.g. Ask to
          // Buy family approval). The caller keeps waiting up to
          // _purchaseTimeout.
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _handleSuccess(PurchaseDetails purchase) async {
    final state = AppState();

    // Clear trial history on first purchase only
    if (!state.hasUnlockedApp) {
      state.testHistory.clear();
      state.clearCurriculumProgress();
      state.hasSeenIntro = false;
    }

    state.hasUnlockedApp = true;
    state.purchaseDate = DateTime.now();
    state.purchaseType = PurchaseType.lifetime;

    await AppStatePersistence.save();
    debugPrint(
      'IAP success: ${purchase.productID} → ${state.purchaseType.name}',
    );
  }

  // ── Buy ─────────────────────────────────────────────────────
  // Shared purchase flow used by every buy* method below. Submits the
  // request, then WAITS for _onPurchaseUpdate to actually resolve it
  // (success / canceled / error) instead of returning as soon as the
  // App Store sheet is requested. That's the fix for buttons appearing
  // to "do nothing" when a user backs out of the purchase sheet — the
  // caller now genuinely knows what happened.
  //
  // The only product left (kProductUnlockApp) is a one-time-forever
  // non-consumable, so this always goes through buyNonConsumable() —
  // the old isConsumable branch (used only by the removed repeatable
  // $2.99 renewal) is gone.
  Future<IAPResult> _purchase(ProductDetails? Function() getProduct) async {
    if (!_available) return IAPResult.storeUnavailable;

    var product = getProduct();
    if (product == null) {
      await _loadProducts();
      product = getProduct();
      if (product == null) return IAPResult.productNotFound;
    }

    final completer = Completer<IAPResult>();
    _pendingPurchases[product.id] = completer;

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('IAP buy error: $e');
      _pendingPurchases.remove(product.id);
      return IAPResult.error;
    }

    return completer.future.timeout(
      _purchaseTimeout,
      onTimeout: () {
        _pendingPurchases.remove(product!.id);
        return IAPResult.timeout;
      },
    );
  }

  Future<IAPResult> buyUnlockApp() => _purchase(() => _unlockProduct);

  // ── Restore ─────────────────────────────────────────────────
  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  // UI-facing convenience for a "Restore Purchases" button. Fires the
  // restore, then waits for the purchase stream to redeliver any
  // already-owned purchase and for _handleSuccess (above) to process
  // it — restorePurchases() itself only submits the request, it
  // doesn't report an outcome. This is also the recovery path for the
  // Play Billing "item already owned" scenario: a purchase that
  // charged the user and is already owned on the store's side, but
  // whose _onPurchaseUpdate delivery was missed locally (e.g. an app
  // kill between the purchase completing and AppStatePersistence.save()
  // writing to disk) — buying again just returns
  // PurchaseStatus.error(ITEM_ALREADY_OWNED) from the store, but this
  // re-syncs local state with what the store already has on record.
  // Returns true if the account is unlocked afterward — either this
  // restore found something, or it already was unlocked.
  Future<bool> restoreAndWait({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (AppState().hasUnlockedApp) return true;
    if (!_available) return false;
    await restorePurchases();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (AppState().hasUnlockedApp) return true;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return AppState().hasUnlockedApp;
  }

  // ── Late-confirmation recovery ──────────────────────────────
  // A buy* call above can come back as IAPResult.timeout if StoreKit/
  // Play Billing's confirmation doesn't arrive within _purchaseTimeout.
  // That does NOT mean the purchase failed or was lost — _onPurchaseUpdate
  // keeps listening in the background and will still run _handleSuccess()
  // whenever the confirmation eventually shows up, unlocking and
  // persisting normally. The gap was that nothing told the CALLER this
  // happened after it already gave up and showed an error, so someone
  // who genuinely paid could be stuck on an error message with no way
  // in — this is what Apple's Sept 2026 rejection of 1.16.2 described
  // ("did not receive a receipt after purchase"), most likely because
  // App Review's own sandbox is slower than production and outlasted
  // the 90-second window.
  //
  // Call this after a timeout (or any non-success, non-canceled
  // result) and treat `true` as success before finally giving up —
  // see onboard_paywall.dart, safe_prep_nav_bar.dart, and
  // rapid_fire_limited_page.dart for the call sites.
  //
  // Sets AppState().hasUnlockedApp on success.
  Future<bool> waitForLateUnlock({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (AppState().hasUnlockedApp) return true;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (AppState().hasUnlockedApp) return true;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return AppState().hasUnlockedApp;
  }

  // ── Price strings ────────────────────────────────────────────
  String get unlockPrice => _unlockProduct?.price ?? '\$19.99';
}

// ── Result enum ──────────────────────────────────────────────
// NOTE: this replaces the old enum, which had `initiated` — meaning
// "request submitted," not "purchase resolved." Every buy* call site
// must be updated: `success` now means the purchase actually completed;
// there is no longer a value that means "we don't know yet."
enum IAPResult {
  success,
  canceled,
  storeUnavailable,
  productNotFound,
  timeout,
  error,
}

extension IAPErrorMessage on IAPResult {
  String? get userMessage {
    switch (this) {
      case IAPResult.success:
        return null;
      case IAPResult.canceled:
        return null; // user intentionally backed out — no error to show
      case IAPResult.storeUnavailable:
        return 'The App Store is not available right now. Please try again later.';
      case IAPResult.productNotFound:
        return 'Purchase could not be loaded. Please check your connection and try again.';
      case IAPResult.timeout:
        return 'The purchase is taking longer than expected. Check your connection and try again — if you were charged, use Restore Purchases.';
      case IAPResult.error:
        return 'Something went wrong. Please try again.';
    }
  }
}
