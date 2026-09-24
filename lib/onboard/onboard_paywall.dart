import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import '../iap_service.dart';
import '../fsme_post_purchase_landing.dart';
import '../redeem_code_service.dart';
import 'onboard_answers.dart';
import 'onboard_trust.dart';

/// Onboarding paywall — redesigned for the self-report funnel, then
/// redesigned again to add a personalized recap, then redesigned a
/// third time (Sept 2026) into this long-form version.
///
/// One product now — a $19.99 lifetime unlock — per Gerry's Sept 2026
/// call: this is a career-gateway certification (a shot at a higher-
/// paying job), not a subscription-shaped thing, so a single durable
/// purchase fits the niche better than a time-limited access window.
/// Uses the existing kProductUnlockApp / IAPService.buyUnlockApp()
/// product (formerly offered as a $9.99 upsell after a 7-day trial;
/// now the front-door offer at $19.99). A cheaper "Level 2" tier may
/// be added later as its own separate product — this screen still
/// only ever asks once, for one thing.
///
/// LONG-FORM EXPERIMENT (Sept 2026): the short version of this screen
/// (recap card straight into the price) is the one confirmed real leak
/// in the whole funnel (~50-63% of viewers never convert to purchase-
/// intent). Working theory: by this point the funnel has built real
/// momentum, and a short paywall kills it rather than protecting it —
/// people arrive ready to buy and the short version doesn't fully make
/// the case for what they're paying for, so they hesitate. This
/// version stacks the full picture (what unlocks, why it works, what's
/// included) before asking, deliberately trading screen length for a
/// more complete pitch. Price is intentionally still withheld until
/// this screen (see [[safeprep-onboarding]] — a deliberate momentum
/// strategy, not an oversight); the App Store listing's own "less than
/// a cup of coffee" line is the current fix for anyone who'd otherwise
/// be surprised by a price existing at all (see [[safeprep-marketing]]).
/// Gerry's call: leave the CONTENT recap row in for this test (a
/// separate, still-unresolved theory about that row alone is parked,
/// not merged into this experiment) — ship this whole page as one
/// bundled test, watch Pay_Viewed→Purchase, and revert the page
/// entirely if it doesn't move the number rather than iterating on it
/// piecemeal.
///
/// The recap card confirms the user's own exam-date, study-style, and
/// content-preference answers back to them (read-only — no inline
/// editing; see [_recapCard] for why). FSME does NOT appear on this
/// screen (removed Sept 2026, along with his content-preference
/// reaction line, as part of the long-form redesign below — he was
/// the one non-gold visual accent on an otherwise disciplined page,
/// and stood out more once the page got longer). There is no longer
/// a knowledge-level/test-
/// history question anywhere in the funnel — it was cut entirely
/// (see [[safeprep-onboarding]]) since it was seen as a real drop-off
/// risk: people may not answer it truthfully, and there was no way to
/// tell. "Adjust setup" (formerly "Start over") is the one correction
/// path, re-running the actual questions rather than letting people
/// fix answers in place here — same underlying mechanism, just
/// relabeled to fit this screen's tone.
///
/// "Show me more first" routes to the Rapid Fire preview as a taste
/// of the tool before a second ask, rather than a hard decline exit.
///
/// On purchase success, routes to [FsmePostPurchaseLanding] — the
/// one-time FSME cluster tour — rather than the old terminal-style
/// build-sequence screen, since the self-report funnel has no
/// diagnostic data to build a "your plan is ready" sequence from.
class OnboardPaywall extends StatefulWidget {
  const OnboardPaywall({super.key});

  @override
  State<OnboardPaywall> createState() => _OnboardPaywallState();
}

class _OnboardPaywallState extends State<OnboardPaywall> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  // Localized price straight from the App Store (falls back to \$19.99
  // only until the product has loaded). Hardcoding the price showed
  // US dollars to every storefront, including App Review's.
  String get _price => IAPService.instance.unlockPrice;

  bool _purchasing = false;
  bool _restoring = false;
  bool _redeeming = false;

  /// One read-only recap row on the paywall - confirms an answer back
  /// to the user, no interactivity. Deliberately not editable: an
  /// earlier draft let people tap to change answers right here, but
  /// that turned the paywall into a second round of decisions right
  /// before the purchase ask, which is exactly what this redesign is
  /// trying to remove. The one correction path is "Start over" below,
  /// which re-runs the actual questions instead.
  Widget _recapRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.12),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 12, color: _gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.05,
                    color: _softWhite.withValues(alpha: 0.4),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The "we already did the work" reinforcement card. Pure
  /// confirmation of what the user already told the app on the exam-
  /// date, study-style, and content-preference screens.
  Widget _recapCard() {
    final examWindow = OnboardingAnswers.instance.examWindow;
    final studyStyle = OnboardingAnswers.instance.studyStyle;
    final contentPreference = OnboardingAnswers.instance.contentPreference;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softWhite.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your personalized Tax exam prep is ready',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: _softWhite.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          _recapRow(
            icon: Icons.schedule,
            label: 'EXAM',
            value: examWindow?.label ?? 'Not set',
          ),
          _recapRow(
            icon: Icons.star,
            label: 'LEARNING STYLE',
            value: studyStyle?.label ?? 'Not set',
          ),
          _recapRow(
            icon: Icons.explore,
            label: 'FOCUS',
            value: contentPreference?.label ?? 'Not set',
          ),
        ],
      ),
    );
  }

  /// Small centered section eyebrow used to break up the long-form
  /// layout below the recap card — "WHAT YOU'LL UNLOCK NEXT", "WHY
  /// THIS WORKS", "YOUR ACCESS", "THE COST".
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
          color: _gold,
        ),
      ),
    );
  }

  /// One row in the "What you'll unlock next" list — icon badge, a
  /// bold title, and a one-line description. Purely informational,
  /// same content everyone sees regardless of their content-preference
  /// answer (that answer drives routing after purchase, not what's
  /// shown here).
  Widget _unlockItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 15, color: _gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _softWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: _softWhite.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One checked line in the "Your access" list — plain confirmation,
  /// no icons/descriptions needed like the unlock list above since
  /// these are single facts, not features to explain.
  Widget _accessRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Icon(Icons.check, size: 14, color: _gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: _softWhite),
            ),
          ),
        ],
      ),
    );
  }

  /// Sole correction path for the recap card above - re-runs the
  /// exam-date/study-style/knowledge questions from the Trust screen
  /// rather than offering per-field inline editing on the paywall
  /// itself (rejected earlier as "too much for them to decide on"
  /// right before the purchase ask). Labeled "Adjust setup" on screen
  /// (Sept 2026 long-form redesign) rather than "Start over" — same
  /// mechanism, softer framing to match this screen's tone.
  void _startOver() {
    MixpanelService.instance.track(
      'SpOn_Pay_StartOver',
      properties: {'app_name': 'ST'},
    );
    OnboardingAnswers.instance.reset();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardTrust()),
      (_) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'SpOn_Pay_Viewed',
      properties: {
        'app_name': 'ST',
        'content_preference':
            OnboardingAnswers.instance.contentPreference?.tag ?? 'unknown',
      },
    );
    _recordOnboardingRun();
  }

  /// Reaching the paywall counts as one completed onboarding run — the
  /// splash uses the tally to cap free runs before requiring the access
  /// code. Formerly incremented in OnboardReadiness, which no longer
  /// exists in the self-report redesign. See kOnboardingRunsKey.
  Future<void> _recordOnboardingRun() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(kOnboardingRunsKey) ?? 0;
    await prefs.setInt(kOnboardingRunsKey, current + 1);
  }

  Future<void> _purchase() async {
    if (_purchasing) return;
    setState(() => _purchasing = true);

    MixpanelService.instance.track(
      'SpOn_Purchase',
      properties: {
        'app_name': 'ST',
        'source': 'paywall',
        'price': _price,
        'content_preference':
            OnboardingAnswers.instance.contentPreference?.tag ?? 'unknown',
      },
    );

    var result = await IAPService.instance.buyUnlockApp();

    if (!mounted) return;

    // A timeout doesn't necessarily mean the purchase failed — StoreKit's
    // confirmation can simply arrive late (this is what caused Apple's
    // Sept 2026 rejection of this exact screen). Keep watching a bit
    // longer before treating it as a real failure; the spinner stays up
    // the whole time since _purchasing doesn't flip off until we're sure
    // either way.
    if (result == IAPResult.timeout) {
      final unlockedLate = await IAPService.instance.waitForLateUnlock();
      if (!mounted) return;
      if (unlockedLate) result = IAPResult.success;
    }

    setState(() => _purchasing = false);

    if (result == IAPResult.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FsmePostPurchaseLanding()),
        (_) => false,
      );
    } else if (result != IAPResult.canceled) {
      final message = result.userMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 12),
          ),
        );
      }
    }
  }

  // Recovery path for the Play Billing "already owned" scenario: a
  // purchase that charged the user's card and is already recorded as
  // owned on the store's side, but whose success never got processed
  // locally (e.g. the app was killed between the purchase completing
  // and AppStatePersistence.save() writing to disk, or a transient
  // stream error). Buying again just returns "item already owned"
  // from the store with no way forward, so this is the only escape
  // hatch for someone in that state — always visible, not just shown
  // after an error, since Apple/Play guidelines expect a restore
  // option to be discoverable up front, and the person in this state
  // never sees a purchase error on THIS attempt to know to look for one.
  Future<void> _restorePurchases() async {
    if (_restoring || _purchasing) return;
    setState(() => _restoring = true);

    MixpanelService.instance.track(
      'SpOn_Pay_Restore',
      properties: {'app_name': 'ST'},
    );

    final unlocked = await IAPService.instance.restoreAndWait();

    if (!mounted) return;
    setState(() => _restoring = false);

    if (unlocked) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FsmePostPurchaseLanding()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "We couldn't find a previous purchase for this account. "
            'If you were charged, please contact support.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 8),
        ),
      );
    }
  }

  // Entry point for anyone who got a free unlock code from an
  // instructor/partner instead of buying the IAP directly. See
  // RedeemCodeService for the offline validation scheme.
  Future<void> _showRedeemDialog() async {
    final controller = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: _darkBg,
              title: const Text(
                'Redeem a Code',
                style: TextStyle(color: _softWhite),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Have an unlock code? Enter it below.',
                    style: TextStyle(
                      color: _softWhite.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: _softWhite, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: '12345678',
                      hintStyle: TextStyle(
                        color: _softWhite.withValues(alpha: 0.3),
                      ),
                      errorText: errorText,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _gold),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _gold, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _redeeming
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: _softWhite.withValues(alpha: 0.6)),
                  ),
                ),
                TextButton(
                  onPressed: _redeeming
                      ? null
                      : () async {
                          setDialogState(() => errorText = null);
                          setState(() => _redeeming = true);
                          final result = await RedeemCodeService.redeem(
                            controller.text,
                          );
                          if (!mounted) return;
                          setState(() => _redeeming = false);
                          if (result == RedeemResult.success) {
                            Navigator.of(dialogContext).pop();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FsmePostPurchaseLanding(),
                              ),
                              (_) => false,
                            );
                          } else {
                            setDialogState(
                              () => errorText = switch (result) {
                                RedeemResult.expired =>
                                  "That code's expired — ask your instructor for a new one.",
                                RedeemResult.alreadyRedeemed =>
                                  "That code's already been redeemed.",
                                _ => "That code didn't work.",
                              },
                            );
                          }
                        },
                  child: _redeeming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _gold,
                          ),
                        )
                      : const Text(
                          'Redeem',
                          style: TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return Container(
                    width: 22,
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 22),

              Text(
                'Your study plan is ready',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: _softWhite,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 20),

              _recapCard(),

              const SizedBox(height: 4),

              GestureDetector(
                onTap: _startOver,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Adjust setup  →',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _softWhite.withValues(alpha: 0.4),
                      decoration: TextDecoration.underline,
                      decorationColor: _softWhite.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _sectionTitle("WHAT YOU'LL UNLOCK NEXT"),

              _unlockItem(
                icon: Icons.dashboard_rounded,
                title: 'Personal Dashboard',
                description:
                    'Your study hub — readiness score, progress, '
                    'and what to focus on next.',
              ),
              _unlockItem(
                icon: Icons.bolt,
                title: '60-Second Trainer',
                description: 'A fast primer that hits the core Tax concepts.',
              ),
              _unlockItem(
                icon: Icons.quiz,
                title: 'Personalized Quiz Sets',
                description: 'Adaptive questions based on your weak areas.',
              ),
              _unlockItem(
                icon: Icons.fact_check,
                title: 'Full 294-Question Bank',
                description:
                    'Built around the Intuit Academy Tax Level 1 curriculum.',
              ),
              _unlockItem(
                icon: Icons.all_inclusive,
                title: 'Unlimited Randomized Quizzes',
                description: 'No limits. No repeats unless you want them.',
              ),

              const SizedBox(height: 14),

              _sectionTitle('WHY THIS WORKS'),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _darkBg,
                        border: Border.all(color: _gold),
                      ),
                      child: const Icon(Icons.verified, size: 15, color: _gold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: _softWhite.withValues(alpha: 0.75),
                          ),
                          children: const [
                            TextSpan(text: 'Every question mapped to '),
                            TextSpan(
                              text:
                                  'the Intuit Academy Tax '
                                  'Level 1 curriculum',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _softWhite,
                              ),
                            ),
                            TextSpan(text: ' - not scraped, not generic.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _sectionTitle('YOUR ACCESS'),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _softWhite.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    _accessRow('Lifetime access'),
                    _accessRow('294 aligned questions'),
                    _accessRow('Adaptive progress tracking'),
                    _accessRow('Exam-weighted study flow'),
                    _accessRow('Exclusive Intuit Interview Prep'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _sectionTitle('THE COST'),

              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _purchasing ? null : _purchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _darkBg,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.buttonCornerRadius,
                      ),
                    ),
                  ),
                  child: _purchasing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _darkBg,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Unlock Your Plan \u2014 $_price',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Lifetime access. No limits.',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                                color: _darkBg.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: _restorePurchases,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _restoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _gold,
                          ),
                        )
                      : Text(
                          'Already purchased? Restore Purchases',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _softWhite.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),

              GestureDetector(
                onTap: _showRedeemDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Have an unlock code? Redeem it',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _softWhite.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
