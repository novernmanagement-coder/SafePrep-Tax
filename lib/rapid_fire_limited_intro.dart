import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../app_state.dart';
import '../app_state_persistence.dart';
import '../mixpanel_service.dart';
import 'rapid_fire_limited_page.dart';

/// Intro screen for the limited Rapid Fire — positioned between the
/// paywall decline and the actual tool. Its job is to make a free
/// offering feel like a gift rather than a consolation prize.
///
/// The copy frames the tool as special (category-specific, not random)
/// and useful (60 seconds, focused) — but honest about the limit: 2
/// free rounds, not unlimited access. The category selection reinforces
/// the "not just random questions" promise — they pick what to study,
/// which is the personalization hook in miniature.
///
/// FSME pops up once, below the Start button: a "psst" aside revealing
/// this is his favorite of the six trainers, a quote of the Boss's
/// read on the user (hesitant, needs one more preview), then he bolts
/// as she approaches. Standard pop-in timing (2s delay, 2300ms fade).
/// Per the standing typing rule, his own lines type out; the quoted
/// Boss line and his self-talk exit both reveal instantly.
class RapidFireLimitedIntro extends StatefulWidget {
  const RapidFireLimitedIntro({super.key});

  @override
  State<RapidFireLimitedIntro> createState() => _RapidFireLimitedIntroState();
}

/// Who an FSME popup line is directed at / how it renders.
/// - user: FSME's default voice (gold) — types out.
/// - boss: the Boss's own quoted words, relayed by FSME (blue) —
///   instant, since it's her direct assessment being reported verbatim.
/// - self: FSME noticing her and bolting (gray) — instant.
enum _FsmeAudience { user, boss, self }

/// Script-definition line (immutable).
class _FsmeLine {
  final String text;
  final _FsmeAudience audience;
  const _FsmeLine(this.text, {this.audience = _FsmeAudience.user});
}

/// Mutable render-time counterpart — [text] grows as a user-audience
/// line types out; other lines just get their full text set once.
class _TermLine {
  String text;
  final _FsmeAudience audience;
  _TermLine(this.text, this.audience);
}

class _RapidFireLimitedIntroState extends State<RapidFireLimitedIntro>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);
  // Matches the boss-line / self-line colors used across the rest of
  // the funnel.
  static const Color _bossBlue = Color(0xFF4A9BE2);
  static const Color _selfGray = Color(0xFF9E9E9E);

  /// Top 3 categories by real exam weight (matches the Trust page's
  /// weighted breakdown). No diagnostic exists anymore to personalize
  /// this, and this screen is a one-time taste, not somewhere users
  /// return to repeatedly — a fixed, meaningfully-chosen set is fine.
  static const List<String> _weakCategories = [
    'Time & Temperature',
    'Receiving & Storage',
    'Cross-Contamination',
  ];

  // ── FSME popup ───────────────────────────────────────────────────
  static const List<_FsmeLine> _fsmeScript = [
    _FsmeLine(
      'Psst\u2026 I made 6 of these 60-second trainers \u2014 this one\u2019s '
      'my favorite.',
    ),
    _FsmeLine(
      'I didn\u2019t have time to give you all the bells and whistles '
      'in this limited version \u2014 you should see the full one\u2026',
    ),
  ];

  bool _fsmeVisible = false;
  final List<_TermLine> _fsmeLines = [];
  Timer? _fsmeInTimer;

  /// Rounds left BEFORE this one is used — computed once at build time
  /// off AppState (rounds are only ever incremented on Start, not just
  /// by viewing this screen), so the copy always reflects what's
  /// actually available right now.
  int get _roundsLeft =>
      AppState.maxLimitedRapidFireRounds - AppState().limitedRapidFireRoundsUsed;

  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim;
  late AnimationController _blinkController;
  Timer? _blinkTimer;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _gazeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_advanceGaze);
    _gazeAnim.repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    // Standard pop-in timing: 2s delay, then the fade transition itself
    // takes 2300ms (see _fsmePopup's AnimatedOpacity).
    _fsmeInTimer = Timer(const Duration(seconds: 2), _startFsme);
  }

  void _advanceGaze() {
    final target = _gazeTarget.toDouble();
    final next = _gazeCurrent + (target - _gazeCurrent) * 0.18;
    if ((next - _gazeCurrent).abs() > 0.001) {
      setState(() => _gazeCurrent = next);
    }
  }

  void _scheduleGaze() {
    final delay = Duration(milliseconds: 1800 + _rng.nextInt(2200));
    _gazeTimer = Timer(delay, () {
      if (!mounted || !_fsmeVisible) return;
      if (_rng.nextDouble() < 0.30) {
        setState(() => _gazeTarget = _rng.nextBool() ? -1 : 1);
        Timer(Duration(milliseconds: 700 + _rng.nextInt(400)), () {
          if (mounted) setState(() => _gazeTarget = 0);
        });
      } else {
        setState(() => _gazeTarget = 0);
      }
      _scheduleGaze();
    });
  }

  void _scheduleBlink() {
    final delay = Duration(milliseconds: 3000 + _rng.nextInt(5000));
    _blinkTimer = Timer(delay, () async {
      if (!mounted || !_fsmeVisible) return;
      await _blinkController.forward(from: 0.0);
      if (mounted) await _blinkController.reverse();
      _scheduleBlink();
    });
  }

  void _startFsme() {
    if (!mounted) return;
    setState(() => _fsmeVisible = true);
    _scheduleGaze();
    _scheduleBlink();
    _revealFsme();
  }

  /// Reveals the popup script one line at a time. User-audience lines
  /// type out character by character; boss/self lines appear
  /// instantly. Pause between every line either way. Once the script
  /// finishes, holds for 5 seconds then fades out.
  Future<void> _revealFsme() async {
    for (final line in _fsmeScript) {
      if (!mounted) return;

      if (line.audience == _FsmeAudience.user) {
        final entry = _TermLine('', line.audience);
        setState(() => _fsmeLines.add(entry));
        for (var i = 1; i <= line.text.length; i++) {
          if (!mounted) return;
          setState(() => entry.text = line.text.substring(0, i));
          await Future.delayed(const Duration(milliseconds: 18));
        }
      } else {
        setState(() => _fsmeLines.add(_TermLine(line.text, line.audience)));
      }

      await Future.delayed(const Duration(milliseconds: 900));
    }

    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    setState(() => _fsmeVisible = false);
  }

  @override
  void dispose() {
    _fsmeInTimer?.cancel();
    _gazeAnim.dispose();
    _blinkController.dispose();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  /// One glowing red eye that darts and blinks — matches the
  /// funnel-wide 26x26 spec.
  Widget _davEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([_gazeAnim, _blinkController]),
      builder: (context, _) {
        final blink = 1.0 - _blinkController.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFF2200),
                  Color(0xFFCC1100),
                  Color(0xFF660000),
                  Color(0xFF1A0000),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _eyeRed.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(_gazeCurrent * 5, 0.5),
                child: Container(
                  width: 8,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// FSME popup — eyes + typed/instant readout, color per line audience.
  Widget _fsmePopup() {
    return AnimatedOpacity(
      opacity: _fsmeVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 2300),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _davEye(),
                const SizedBox(width: 10),
                Text(
                  'F S M E',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 3,
                    color: _eyeRed.withValues(alpha: 0.3),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(width: 10),
                _davEye(),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in _fsmeLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '> ${line.text}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                    color: switch (line.audience) {
                      _FsmeAudience.boss => _bossBlue,
                      _FsmeAudience.self => _selfGray,
                      _FsmeAudience.user => _gold.withValues(alpha: 0.85),
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Shown instead of the normal offer if this screen is somehow
  /// reached with 0 rounds left (the entry point in onboard_paywall.dart
  /// hides the "Try this first" link once rounds run out, so this is a
  /// defensive fallback, not the normal path).
  Widget _exhaustedView(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 40,
                  color: _gold.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 14),
                Text(
                  'You\u2019ve used both free Rapid Fire rounds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _softWhite,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The full version has unlimited rounds across every '
                  'category.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _softWhite.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    if (_roundsLeft <= 0) return _exhaustedView(context);

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 36, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),

              // Icon
              Icon(Icons.bolt_rounded, size: 40, color: _gold),

              const SizedBox(height: 14),

              // Eyebrow
              Text(
                'RAPID FIRE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                  color: _gold,
                ),
              ),

              const SizedBox(height: 14),

              // Headline \u2014 reflects however many of the 2 total rounds
              // are actually left, not a hardcoded "2".
              Text(
                '$_roundsLeft free round${_roundsLeft == 1 ? '' : 's'} of '
                'our most\npowerful retention tool.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 16),

              // Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'This is a limited version of Rapid Fire \u2014 designed '
                  'to keep the material top of mind in 60 seconds or less. '
                  'You get 2 rounds total, ever \u2014 use them whenever '
                  'you\u2019re ready.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _softWhite.withValues(alpha: 0.55),
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Feature callout
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: _gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Not just random questions. You choose the category '
                        'you want to refresh \u2014 every session is targeted '
                        'to what you need.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _softWhite.withValues(alpha: 0.6),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Pre-selected categories
              Text(
                'We\u2019ve selected 3 of the heaviest weighted categories from the test:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: _softWhite.withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _weakCategories.map((cat) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _gold,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Start button — sits directly below the category chips now.
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Consume a round HERE, on Start, not on completion —
                    // so backing out mid-round still counts against the
                    // 2-round cap rather than letting someone quit and
                    // retry indefinitely for a fresh random draw.
                    AppState().limitedRapidFireRoundsUsed++;
                    AppStatePersistence.save();

                    MixpanelService.instance.track(
                      'rapid_fire_limited_intro_start',
                      properties: {
                        'app_name': 'SP',
                        'rounds_used': AppState().limitedRapidFireRoundsUsed,
                      },
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => RapidFireLimitedPage()),
                    );
                  },
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
                  child: const Text(
                    'Start Rapid Fire  \u2192',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // FSME's "psst" aside — now appears below the Start button.
              _fsmePopup(),
            ],
          ),
        ),
      ),
    );
  }
}
