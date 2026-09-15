import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import '../iap_service.dart';
import '../fsme_eye.dart';
import '../fsme_post_purchase_landing.dart';

/// The "Still want to see more?" trust page — pushed only after a user
/// COMPLETES Rapid Fire (not merely starts it), reached via
/// OnboardPaywall's "Not ready to commit yet? Try this first →" link.
/// Gating on Rapid Fire completion is the caller's job; this widget
/// assumes it's already been earned.
///
/// Opens with a short, autoplaying FSME beat (his one personality
/// moment on this screen — six lines, four seconds held apiece per
/// Gerry's spec), then unlocks into a clinical, scrollable rundown:
/// headline / subject matter, repeated straight through to a real
/// purchase CTA. Deliberately NOT user-paced — contrast
/// [FsmePostPurchaseLanding], which uses a tap-to-continue "thin
/// Continue" control. Gerry wants this one to just play.
///
/// Purchase here is self-contained (buys directly via [IAPService],
/// mirroring [OnboardPaywall]'s exact success/error handling) rather
/// than bouncing back to OnboardPaywall for a second tap — this is
/// the end of the funnel, so it should be able to close the sale on
/// its own. Restore Purchases is included for the same reason
/// OnboardPaywall keeps it always visible: Apple/Play expect it
/// discoverable up front, not just after an error.
///
/// TODO(gerry): years-teaching figure — Instructor's Playbook's live
/// header says "25+ years"; App Store copy and elsewhere say "20+".
/// Currently set to 20 below (`_yearsTeaching`) — pick the real number
/// and fix both places to match.
class OnboardFinalTrustPage extends StatefulWidget {
  const OnboardFinalTrustPage({super.key});

  @override
  State<OnboardFinalTrustPage> createState() => _OnboardFinalTrustPageState();
}

class _FsmeBeat {
  final EyeMood mood;
  final String line;
  // Only the "with my guidance and all—" beat uses this — maps
  // Gerry's "eyes pop" cue directly onto the real surprise() one-shot
  // rather than inventing a new mood for it.
  final bool surpriseOnEntry;
  const _FsmeBeat({
    required this.mood,
    required this.line,
    this.surpriseOnEntry = false,
  });
}

class _EntryData {
  final String title;
  final String desc;
  const _EntryData(this.title, this.desc);
}

class _OnboardFinalTrustPageState extends State<OnboardFinalTrustPage> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  static const Duration _typeCharDelay = Duration(milliseconds: 18);
  // Gerry: "each section gets a 4 second pause" — interpreted as the
  // hold AFTER a line finishes typing (typing time itself varies by
  // line length), not a fixed total per beat. Flag if that reads
  // wrong once you see it play.
  static const Duration _beatHold = Duration(seconds: 4);

  static const int _yearsTeaching = 20; // TODO(gerry): confirm vs. 25
  static const String _price = '\$4.99';

  // Real ally-bit sequence. Mood choices map onto the ACTUAL EyeMood
  // enum from fsme_eye.dart rather than inventing states that don't
  // exist there — notably there's no literal "wink," so the nerd line
  // uses `fibbing` (up-and-right, the built-in "constructing/inventing
  // a memory" tell), which actually fits a tall-tale anecdote better
  // than a wink would have anyway.
  static const List<_FsmeBeat> _beats = [
    _FsmeBeat(
      mood: EyeMood.idle, // ambient dart reads as "looking around"
      line: 'Psst — shhh.',
    ),
    _FsmeBeat(
      mood: EyeMood.serious, // locked center, held eye contact
      line:
          "Straight up — the people who made this app are legit. "
          'Been doing this for years, and they’re exceptionally great '
          'at it.',
    ),
    _FsmeBeat(
      mood: EyeMood.fibbing, // up-right — no "wink" mood exists
      line:
          'I asked one of the basement nerds — how long’s it been '
          'since somebody didn’t pass? He thought about it, adjusted '
          'his thick glasses, and goes… "how would I know? I haven’t '
          'seen the sun in three months." …But yeah. It’s been a '
          'minute.',
    ),
    _FsmeBeat(
      mood: EyeMood.thinking, // up-left, pause after a line lands
      line: 'That’s not a stat. That’s a guy who’s lost count.',
    ),
    _FsmeBeat(
      mood: EyeMood.serious,
      line: 'But then… with my guidance and all—',
      surpriseOnEntry: true, // "eyes pop" == the real surprise() bulge
    ),
    _FsmeBeat(
      mood: EyeMood.befuddled, // straight up + jitter, "why???"
      line: 'I’ll tell you what… — what?',
    ),
  ];

  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();

  int _beatIndex = 0;
  String _displayedText = '';
  EyeMood _mood = EyeMood.typing;
  bool _unlocked = false;
  bool _purchasing = false;
  bool _restoring = false;
  Timer? _timer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'SpOn_FinalTrust_Viewed',
      properties: {'app_name': 'SP'},
    );
    _playBeat(0);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _playBeat(int index) async {
    final beat = _beats[index];

    setState(() {
      _beatIndex = index;
      _mood = EyeMood.typing;
      _displayedText = '';
    });

    for (var i = 1; i <= beat.line.length; i++) {
      if (_disposed) return;
      await Future.delayed(_typeCharDelay);
      if (_disposed) return;
      setState(() => _displayedText = beat.line.substring(0, i));
    }
    if (_disposed) return;

    setState(() => _mood = beat.mood);
    if (beat.surpriseOnEntry) {
      unawaited(_eyeKey.currentState?.surprise());
    }

    _timer = Timer(_beatHold, () {
      if (_disposed) return;
      if (index < _beats.length - 1) {
        _playBeat(index + 1);
      } else {
        MixpanelService.instance.track(
          'SpOn_FinalTrust_FsmeDone',
          properties: {'app_name': 'SP'},
        );
        setState(() => _unlocked = true);
      }
    });
  }

  Future<void> _purchase() async {
    if (_purchasing || _restoring) return;
    setState(() => _purchasing = true);

    MixpanelService.instance.track(
      'SpOn_FinalTrust_Purchase',
      properties: {'app_name': 'SP', 'source': 'final_trust_page'},
    );

    final result = await IAPService.instance.buySevenDay();

    if (!mounted) return;
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

  // Same escape hatch OnboardPaywall keeps for the Play Billing
  // "already owned" scenario — see that file's comment for the full
  // rationale. Kept here too since this screen can also be someone's
  // first real purchase attempt if they took the Rapid Fire detour.
  Future<void> _restorePurchases() async {
    if (_restoring || _purchasing) return;
    setState(() => _restoring = true);

    MixpanelService.instance.track(
      'SpOn_FinalTrust_Restore',
      properties: {'app_name': 'SP'},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fsmeBlock(),
              AnimatedOpacity(
                opacity: _unlocked ? 1 : 0.12,
                duration: const Duration(milliseconds: 500),
                child: IgnorePointer(
                  ignoring: !_unlocked,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 22),
                      _flagDivider("Here's the rest, no fluff"),
                      _section(
                        title: 'Most Difficult Categories',
                        meta: 'Based on our 180-question curriculum',
                        entries: const [
                          _EntryData(
                            '01  Time & Temperature',
                            'The heaviest subject matter in the course.',
                          ),
                          _EntryData(
                            '02  Cross-Contamination',
                            'Heavily presented throughout.',
                          ),
                          _EntryData(
                            '03  Pathogens',
                            'Thoroughly explained, no shortcuts.',
                          ),
                        ],
                      ),
                      _section(
                        title: 'Tips & Information',
                        meta: "Instructor's Playbook",
                        entries: const [
                          _EntryData(
                            'Tips',
                            "Straight guidance from someone who's "
                                'actually taught this material.',
                          ),
                          _EntryData(
                            'Traps',
                            "You won't find this anywhere else: we "
                                "identify and show you ServSafe's actual "
                                '"trap" answer patterns.',
                          ),
                          _EntryData(
                            'Memory Hooks',
                            'Built to make the toughest facts stick.',
                          ),
                          _EntryData(
                            'Real World Scenarios',
                            'Situations pulled from actual test-day '
                                'and on-the-job moments.',
                          ),
                        ],
                      ),
                      _section(
                        title: 'Study On Your Terms',
                        meta: 'No account, no connection required',
                        entries: const [
                          _EntryData(
                            'No Wi-Fi Needed',
                            "Once it's downloaded, it's yours — a "
                                'walk-in cooler, a break room, wherever.',
                          ),
                          _EntryData(
                            '60-Second Trainers',
                            'Bite-sized drills built to keep ServSafe '
                                'top of mind while you wait for test day.',
                          ),
                          _EntryData(
                            'Find a Proctor',
                            'A live locator for test sites near you — '
                                'no separate search required.',
                          ),
                        ],
                      ),
                      _section(
                        title: "Who's Behind It",
                        meta: "The part that isn't automated",
                        entries: [
                          _EntryData(
                            '$_yearsTeaching+ Years Teaching',
                            "Built by someone who's actually taught "
                                'this exam, not just read about it.',
                          ),
                        ],
                      ),
                      _guarantee(),
                      const SizedBox(height: 22),
                      _purchaseButton(),
                      const SizedBox(height: 8),
                      _restoreLink(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fsmeBlock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: _gold, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FsmeEyePair(key: _eyeKey, mood: _mood, size: 26, spacing: 7),
              const SizedBox(width: 10),
              const Text(
                'FSME',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: _gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Text(
              _displayedText,
              style: const TextStyle(
                fontSize: 14.5,
                fontStyle: FontStyle.italic,
                color: _softWhite,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_beats.length, (i) {
              final on = i <= _beatIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? _gold : _gold.withValues(alpha: 0.2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _flagDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: _gold.withValues(alpha: 0.15))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 1.6,
                color: _softWhite.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(child: Divider(color: _gold.withValues(alpha: 0.15))),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String meta,
    required List<_EntryData> entries,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _gold.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: _softWhite,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            meta.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: _softWhite.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _softWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.desc,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: _softWhite.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _guarantee() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WHEN SAFEPREP SAYS YOU'RE READY...",
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: _gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "...you're ready to pass. Not a quiz app — we figure out "
            'where you actually stand and close the gaps, backed by a '
            'money-back guarantee.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: _softWhite.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseButton() {
    return SizedBox(
      height: AppSizes.primaryButtonHeight,
      child: ElevatedButton(
        onPressed: _purchasing ? null : _purchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _darkBg,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
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
            : Text(
                'Unlock SafePrep — $_price',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _restoreLink() {
    return GestureDetector(
      onTap: _restorePurchases,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _restoring
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
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
    );
  }
}
