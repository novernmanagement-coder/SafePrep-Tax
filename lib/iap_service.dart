import 'dart:async';
import 'dart:io';
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
// lowercase-only IDs below — same underlying product, a different
// ID string per store. Everything else in this file just uses these
// constants and never needs to branch on platform itself.
// ─────────────────────────────────────────────────────────────────
final String kProductSevenDay = Platform.isAndroid
    ? 'android_st_sevenday'
    : 'SafePrepTaxSevenDay'; // $4.99 — 7 days
final String kProductFourteenDay = Platform.isAndroid
    ? 'android_st_fourteenday'
    : 'SafePrepTaxFourteenDay'; // $8.99 — 14 days
final String kProductUnlockApp = Platform.isAndroid
    ? 'android_st_unlock'
    : 'SafePrepTaxUnlock'; // $9.99 — lifetime
const String kProductUpgrade =
    'com.geraldmiller.safepreptax.upgrade'; // $4.99 — upgrade to lifetime — already lowercase, same ID works on both stores
final String kProductRenewal = Platform.isAndroid
    ? 'android_st_renewalweek'
    : 'SafePrepTaxRenewalWeek'; // $2.99 — +7 days, existing purchasers only (iOS)

// Android-only replacement for the day-5 renewal offer above. Rather
// than a repeatable +7-day extension (which relies on the app calling
// Play Billing's consume API correctly — see the long discussion this
// replaced), this grants LIFETIME access outright for a one-time,
// non-consumable purchase, same simple pattern as kProductUnlockApp /
// kProductUpgrade. iOS keeps its real, live $2.99 renewal
// (kProductRenewal / SafePrepRenewalWeek) untouched — this constant is
// never queried or purchased on iOS. Deliberately no price baked into
// the ID (just "lifetime", not "lifetime299") so the price can change
// in Play Console later without the ID looking stale.
const String kProductLifetimeOfferAndroid = 'android_st_lifetime';
// TODO: confirm both the iOS and Android versions of this product ID
// have actually been created in their respective stores before
// shipping — buyRenewal() will resolve productNotFound until they
// exist. IMPORTANT: must be created as a CONSUMABLE product type (Google
// Play: a one-time product that "can be used and re-purchased"), not
// durable/non-consumable — it's meant to be bought repeatedly, and
// _purchase() below now routes it through buyConsumable() specifically
// because of that.

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

  ProductDetails? _sevenDayProduct;
  ProductDetails? _fourteenDayProduct;
  ProductDetails? _unlockProduct;
  ProductDetails? _upgradeProduct;
  ProductDetails? _renewalProduct;
  ProductDetails? _lifetimeOfferProduct;

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
          .queryProductDetails({
            kProductSevenDay,
            kProductFourteenDay,
            kProductUnlockApp,
            kProductUpgrade,
            kProductRenewal,
            if (Platform.isAndroid) kProductLifetimeOfferAndroid,
          })
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

    // NOTE: was a switch on p.id — switch case labels must be
    // compile-time constants in Dart, and kProduct* are no longer
    // const (they're platform-dependent at runtime now, see the
    // declarations above), so this is an if/else chain instead.
    for (final p in response.productDetails) {
      if (p.id == kProductSevenDay) {
        _sevenDayProduct = p;
      } else if (p.id == kProductFourteenDay) {
        _fourteenDayProduct = p;
      } else if (p.id == kProductUnlockApp) {
        _unlockProduct = p;
      } else if (p.id == kProductUpgrade) {
        _upgradeProduct = p;
      } else if (p.id == kProductRenewal) {
        _renewalProduct = p;
      } else if (p.id == kProductLifetimeOfferAndroid) {
        _lifetimeOfferProduct = p;
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

    // Renewal is handled separately from every other product below —
    // it does NOT reset purchaseDate to now (that would hand back a
    // full fresh 7 days regardless of how little time was left,
    // silently deleting whatever they were about to lose). Instead
    // it anchors the new purchaseDate at the CURRENT expiry (or now,
    // only if access had already fully lapsed) so the +7 days from
    // that point preserves any remaining time, per the earlier
    // "currentExpiry + 7, not now + 7" decision.
    if (purchase.productID == kProductRenewal) {
      final currentExpiry = state.expiryDate;
      final anchor =
          (currentExpiry != null && currentExpiry.isAfter(DateTime.now()))
          ? currentExpiry
          : DateTime.now();
      state.purchaseDate = anchor;
      // purchaseType stays sevenDay — a renewal doesn't change the
      // plan shape, just extends it.
      state.purchaseType = PurchaseType.sevenDay;
      // Let the HomePage renewal explainer fire again on a future
      // cycle instead of staying permanently seen after one renewal.
      state.hasSeenRenewalExplainer = false;
      await AppStatePersistence.save();
      debugPrint('IAP renewal success: new expiry ${state.expiryDate}');
      return;
    }

    // Clear trial history on first purchase only
    if (!state.hasUnlockedApp) {
      state.testHistory.clear();
      state.clearCurriculumProgress();
      state.hasSeenIntro = false;
    }

    state.hasUnlockedApp = true;
    state.purchaseDate = DateTime.now();

    // NOTE: was a switch on purchase.productID — same reason as the
    // one in _loadProducts above, kProduct* aren't compile-time
    // constants anymore.
    if (purchase.productID == kProductSevenDay) {
      state.purchaseType = PurchaseType.sevenDay;
    } else if (purchase.productID == kProductFourteenDay) {
      state.purchaseType = PurchaseType.fourteenDay;
    } else if (purchase.productID == kProductUnlockApp) {
      state.purchaseType = PurchaseType.lifetime;
    } else if (purchase.productID == kProductUpgrade) {
      // Upgrade — keep purchase date, just elevate to lifetime
      state.purchaseType = PurchaseType.lifetime;
    } else if (purchase.productID == kProductLifetimeOfferAndroid) {
      // Android's day-5 offer — a straight lifetime unlock, not an
      // extension, so no special expiry math needed (unlike
      // kProductRenewal above).
      state.purchaseType = PurchaseType.lifetime;
    }

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
  // isConsumable determines which StoreKit call gets used —
  // buyNonConsumable() for one-time-forever products (seven day,
  // fourteen day, unlock, upgrade — all still non-consumable, matches
  // how they were purchased before) vs buyConsumable() for products
  // meant to be bought repeatedly (currently just the renewal). This
  // matters beyond semantics: Apple's own StoreKit validation can
  // reject or mishandle a repeat purchase attempt on a product bought
  // through the wrong call, so it's not just a style choice.
  Future<IAPResult> _purchase(
    ProductDetails? Function() getProduct, {
    bool isConsumable = false,
  }) async {
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
      if (isConsumable) {
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
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

  Future<IAPResult> buySevenDay() => _purchase(() => _sevenDayProduct);

  Future<IAPResult> buyFourteenDay() => _purchase(() => _fourteenDayProduct);

  Future<IAPResult> buyUnlockApp() => _purchase(() => _unlockProduct);

  Future<IAPResult> buyUpgrade() => _purchase(() => _upgradeProduct);

  Future<IAPResult> buyRenewal() =>
      _purchase(() => _renewalProduct, isConsumable: true);

  // Android-only. Non-consumable — same call pattern as buyUnlockApp /
  // buyUpgrade, since this is a one-time-forever purchase, not a
  // repeatable one.
  Future<IAPResult> buyLifetimeOffer() =>
      _purchase(() => _lifetimeOfferProduct);

  // ── Restore ─────────────────────────────────────────────────
  // NOTE: restorePurchases() only restores non-consumables (Apple
  // doesn't track consumable purchase history for restore) — the
  // renewal product being consumable means a reinstall/new-device
  // user will NOT get their renewal back via Restore Purchases, only
  // their original sevenDay/fourteenDay/unlock/upgrade purchase.
  // That matches how a consumable extension is expected to behave
  // (it's spent, not owned), but worth knowing if support questions
  // come up about "I renewed and it didn't restore."
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
  // Call one of these two after a timeout (or any non-success,
  // non-canceled result) and treat `true` as success before finally
  // giving up — see onboard_paywall.dart, safe_prep_nav_bar.dart,
  // rapid_fire_limited_page.dart, lifetime_offer_page.dart, and
  // renew_page.dart for the call sites.

  // Covers every one-time-unlock product (seven day, fourteen day,
  // unlock, upgrade, and Android's lifetime offer) — anything that
  // sets AppState().hasUnlockedApp on success.
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

  // The renewal purchase can't be detected with waitForLateUnlock above —
  // hasUnlockedApp is already true for anyone eligible to renew. Instead
  // the caller passes the expiryDate it observed right before starting
  // the purchase, and this waits for that to actually move forward
  // (per _handleSuccess's "currentExpiry + 7" anchor logic above).
  Future<bool> waitForLateRenewal(
    DateTime? previousExpiry, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    bool renewed() {
      final current = AppState().expiryDate;
      if (current == null) return false;
      if (previousExpiry == null) return true;
      return current.isAfter(previousExpiry);
    }

    if (renewed()) return true;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (renewed()) return true;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return renewed();
  }

  // ── Price strings ────────────────────────────────────────────
  String get sevenDayPrice => _sevenDayProduct?.price ?? '\$4.99';
  String get fourteenDayPrice => _fourteenDayProduct?.price ?? '\$8.99';
  String get unlockPrice => _unlockProduct?.price ?? '\$9.99';
  String get upgradePrice => _upgradeProduct?.price ?? '\$4.99';
  String get renewalPrice => _renewalProduct?.price ?? '\$2.99';
  String get lifetimeOfferPrice => _lifetimeOfferProduct?.price ?? '\$2.99';
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
