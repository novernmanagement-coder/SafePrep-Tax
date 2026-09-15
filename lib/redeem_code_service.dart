import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'app_state_persistence.dart';
import 'mixpanel_service.dart';

/// Lets a student who bought an in-person ServSafe class (booked through
/// Food Safety Made Easy / Indiana Safe Food — NOT through the App
/// Store) redeem a free SafePrep Manager unlock using a short code
/// their instructor hands them after the sale. Fulfills the promo on
/// the Indiana Safe Food page: "Free SafePrep Manager unlock with
/// every purchase (1 per student)."
///
/// Primary validation is still offline / no backend: codes validate
/// locally against an embedded shared "secret" string. On top of that,
/// two lightweight anti-abuse checks were added (Sept 2026) after a
/// concern was raised that a leaked code could be reused/profited from
/// indefinitely:
///   1. A best-effort EXPIRY check — if the free-form 6-digit payload
///      happens to look like a date (instructors commonly type today's
///      date when generating a batch), a code older than 30 days is
///      rejected. This does NOT change how codes are generated — the
///      payload stays genuinely free-form (a date, initials, a running
///      number) — it just opportunistically parses a date out of
///      whatever's there. A payload that doesn't look like a date skips
///      this check entirely (no expiry enforced).
///   2. A REUSE check against a tiny flat-file server endpoint
///      (redeem-check.php + used_codes.json, same static-file-on-the-
///      WordPress-root pattern as package-access.php) — once a code is
///      successfully redeemed, it's marked used and can't be redeemed
///      again. This is a fire-and-forget/fail-open layer, not a hard
///      dependency: SafePrep has no real backend, so if the network
///      call fails or times out, redemption proceeds anyway (matches
///      the same fail-open pattern CsvLoader already uses for its
///      GitHub sync checks) — a leaked code that can't reach the
///      internet isn't going to be blocked here, but that's an
///      acceptable trade-off: the goal isn't stopping every edge case,
///      it's killing the profit motive. A code that dies in 30 days and
///      can't be reused after one redemption isn't worth exploiting.
/// Gerry can always manually burn a specific leaked code via the
/// Redeem Codes tab in the FSME Admin CMS (writes the same
/// used_codes.json), independent of whether the app-side checks catch
/// it.
///
/// Code shape: 8 digits, "PPPPPP" + "CC" — a free 6-digit payload (the
/// instructor can type anything memorable: today's date, a student's
/// initials as a phone-keypad spelling, a running number) followed by
/// a 2-digit checksum. The checksum function is intentionally simple
/// (small-modulus running hash, no external crypto package) so it can
/// be reproduced EXACTLY in a companion generator tool the instructor
/// uses to actually produce codes — see the "SafePrep Redeem Code
/// Generator" page. If `_secret` below is ever changed, the generator
/// tool's copy of the same constant must change identically or every
/// code it produces stops validating.
enum RedeemResult { success, invalidCode, expired, alreadyRedeemed }

class RedeemCodeService {
  RedeemCodeService._();

  static const String _secret = 'FSME-ISF-Redeem-2026';

  // Same static-file pattern as package-access.php — flat JSON on the
  // WordPress root, no database, no auth (matches the low-volume/
  // low-risk tolerance already accepted for that file).
  static const String _checkUrl =
      'https://foodsafetymadeeasy.com/redeem-check.php';

  static const int _codeMaxAgeDays = 30;

  // Keeps every intermediate value well inside a safe integer range in
  // BOTH Dart and JavaScript (the generator tool is a plain HTML/JS
  // page), so the two implementations can never silently diverge on
  // large-number overflow/wraparound behavior. Do not "simplify" this
  // to bitwise ops or a 32-bit mask — that reintroduces exactly the
  // cross-language mismatch risk this design avoids.
  static const int _modulus = 1000003; // a prime under one million

  static String _checksumFor(String payload) {
    var hash = 0;
    for (final unit in ('$_secret$payload').codeUnits) {
      hash = (hash * 31 + unit) % _modulus;
    }
    return (hash % 100).toString().padLeft(2, '0');
  }

  static bool _isValid(String rawCode) {
    final digitsOnly = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 8) return false;
    final payload = digitsOnly.substring(0, 6);
    final providedChecksum = digitsOnly.substring(6, 8);
    return providedChecksum == _checksumFor(payload);
  }

  /// Best-effort: tries to read a date out of the free-form 6-digit
  /// payload WITHOUT requiring one to be there. Tries the full 6
  /// digits as YYMMDD first (most precise), then falls back to just
  /// the first 4 digits as YYMM (month precision, assumes the 1st).
  /// Returns null if neither parse produces a plausible date — that's
  /// the normal case for a payload that's initials or a running
  /// number, and simply means no expiry is enforced for that code.
  static DateTime? _parseDateFromPayload(String payload) {
    final yy = int.tryParse(payload.substring(0, 2));
    if (yy == null) return null;
    final year = 2000 + yy;

    // Try full YYMMDD first.
    final mmFull = int.tryParse(payload.substring(2, 4));
    final dd = int.tryParse(payload.substring(4, 6));
    if (mmFull != null &&
        dd != null &&
        mmFull >= 1 &&
        mmFull <= 12 &&
        dd >= 1 &&
        dd <= 31) {
      final candidate = DateTime(year, mmFull, dd);
      // DateTime silently rolls invalid days forward (e.g. Feb 30 ->
      // Mar 2) — reject anything that didn't round-trip, since that
      // means it wasn't really a valid calendar date.
      if (candidate.year == year &&
          candidate.month == mmFull &&
          candidate.day == dd) {
        return candidate;
      }
    }

    // Fall back to just YYMM (first 4 digits) -> assume the 1st.
    final mm = int.tryParse(payload.substring(2, 4));
    if (mm != null && mm >= 1 && mm <= 12) {
      return DateTime(year, mm, 1);
    }

    return null;
  }

  static bool _isExpired(String payload) {
    final issued = _parseDateFromPayload(payload);
    if (issued == null) return false; // no date detected -> no expiry
    return DateTime.now().difference(issued).inDays > _codeMaxAgeDays;
  }

  /// Fail-open by design (matches CsvLoader's sync-check pattern):
  /// if the request errors, times out, or the endpoint is unreachable,
  /// this returns false (treat as "not used") rather than blocking a
  /// legitimate redemption on SafePrep having no real backend.
  static Future<bool> _checkAlreadyUsed(String digitsOnly) async {
    try {
      final response = await http
          .get(Uri.parse('$_checkUrl?code=$digitsOnly'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data is Map && data['used'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Fire-and-forget — deliberately not awaited by [redeem]. A failure
  /// here just means the reuse check stays soft for this code; it
  /// never blocks or reverses the unlock the student already got.
  static void _markUsed(String digitsOnly) {
    http
        .post(
          Uri.parse(_checkUrl),
          body: {'code': digitsOnly},
        )
        .timeout(const Duration(seconds: 4))
        .catchError((_) {});
  }

  /// Attempts to redeem [rawCode] (dashes/spaces tolerated — only the
  /// digits are checked). On success, unlocks the app with the same
  /// 7-day access window a real purchase grants. On failure, state is
  /// left untouched and the specific [RedeemResult] tells the caller
  /// why, so the UI can show an accurate message instead of a generic
  /// failure.
  static Future<RedeemResult> redeem(String rawCode) async {
    final digitsOnly = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
    final valid = _isValid(digitsOnly);

    if (!valid) {
      MixpanelService.instance.track(
        'redeem_code_attempt',
        properties: {'app_name': 'SP', 'valid': false, 'reason': 'invalid'},
      );
      return RedeemResult.invalidCode;
    }

    final payload = digitsOnly.substring(0, 6);

    if (_isExpired(payload)) {
      MixpanelService.instance.track(
        'redeem_code_attempt',
        properties: {'app_name': 'SP', 'valid': true, 'reason': 'expired'},
      );
      return RedeemResult.expired;
    }

    if (await _checkAlreadyUsed(digitsOnly)) {
      MixpanelService.instance.track(
        'redeem_code_attempt',
        properties: {
          'app_name': 'SP',
          'valid': true,
          'reason': 'already_redeemed',
        },
      );
      return RedeemResult.alreadyRedeemed;
    }

    MixpanelService.instance.track(
      'redeem_code_attempt',
      properties: {'app_name': 'SP', 'valid': true, 'reason': 'ok'},
    );

    final state = AppState();
    // Same first-unlock cleanup _handleSuccess() does for a real
    // purchase, so a redeemed unlock behaves identically to a paid one
    // from here on.
    if (!state.hasUnlockedApp) {
      state.testHistory.clear();
      state.clearCurriculumProgress();
      state.hasSeenIntro = false;
    }
    state.hasUnlockedApp = true;
    state.purchaseType = PurchaseType.sevenDay;
    state.purchaseDate = DateTime.now();
    state.isRedeemedAccess = true;
    await AppStatePersistence.save();

    _markUsed(digitsOnly); // fire-and-forget, does not block success

    MixpanelService.instance.track(
      'redeem_code_success',
      properties: {'app_name': 'SP'},
    );
    return RedeemResult.success;
  }
}
