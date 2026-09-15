import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_trust.dart';

/// Screen 1 of the onboarding funnel — authority and trust.
///
/// One job: establish that whoever built this app knows the exam cold.
/// Two stat tiles up top, a 500+ tile, and — appearing after a 2-second
/// beat — FSME introducing himself in the slot beside it. Then the
/// full-width SafePrep System box.
///
/// FSME's first appearance in the funnel: he fades in, darting eyes,
/// with a cocky-but-self-aware intro line. Sets up the character whose
/// payoff lands later on the decline / Rapid Fire screens.
///
/// Next screen: "When's your exam?" (OnboardExamDate).
class OnboardIntro extends StatefulWidget {
  const OnboardIntro({super.key});

  @override
  State<OnboardIntro> createState() => _OnboardIntroState();
}

/// Who a beat-two line is directed at — governs color.
enum _FsmeAudience { user, boss, self }

/// One line of FSME's beat-two script.
class _FsmeLine {
  final String text;
  final _FsmeAudience audience;
  const _FsmeLine(this.text, {this.audience = _FsmeAudience.user});
}

/// Mutable render-time counterpart to [_FsmeLine] — [text] grows as a
/// user-audience line types out character by character; boss/self
/// lines just get their full text set once.
class _RenderLine {
  String text;
  final _FsmeAudience audience;
  _RenderLine(this.text, this.audience);
}

class _OnboardIntroState extends State<OnboardIntro>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);
  // Matches the Boss's eye color (OnboardReadiness _eyeBlue) — reused
  // here so boss-directed lines carry the same association wherever
  // FSME talks to her across the funnel.
  static const Color _bossBlue = Color(0xFF4A9BE2);
  // FSME talking/thinking to himself — grayed, distinct from both the
  // user-facing gold and the boss-facing blue.
  static const Color _selfGray = Color(0xFF9E9E9E);

  // FSME shows up after a beat, then works through the full script.
  bool _fsmeVisible = false;
  Timer? _introTimer;
  final List<_RenderLine> _beatTwoLines = [];

  // Full script: arrival → confident recite → stumble → boss check-in →
  // recovers → delivers the line clean → seeks approval. The arrival
  // line is now a proper user-audience line in this same list (typed
  // out, gold), not a separate special-cased static line.
  static const List<_FsmeLine> _beatTwoScript = [
    _FsmeLine(
      '\u2014 oops. Didn\u2019t see you come in.',
    ),
    _FsmeLine(
      '\u2026Ahem \u2014 \u201CWelcome to SafePrep. We will prepare you '
      'for the ServSafe exam.\u201D',
    ),
  ];

  // Gaze + blink machinery (ported from OnboardExamDate).
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

    // FSME appears after 2 seconds, then the full script reveals —
    // each line paced 3 seconds apart.
    _introTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _fsmeVisible = true);
      _scheduleGaze();
      _scheduleBlink();
      _revealBeatTwo();
    });
  }

  /// Reveals the full script. Per the typing rule: lines addressed to
  /// the user type out character by character; boss/self lines appear
  /// all at once. Every line, once fully shown, holds for 3 seconds
  /// before the next one starts.
  Future<void> _revealBeatTwo() async {
    for (final line in _beatTwoScript) {
      if (!mounted) return;

      if (line.audience == _FsmeAudience.user) {
        final entry = _RenderLine('', line.audience);
        setState(() => _beatTwoLines.add(entry));
        for (var i = 1; i <= line.text.length; i++) {
          if (!mounted) return;
          setState(() => entry.text = line.text.substring(0, i));
          await Future.delayed(const Duration(milliseconds: 18));
        }
      } else {
        setState(
          () => _beatTwoLines.add(_RenderLine(line.text, line.audience)),
        );
      }

      // 3 seconds between every bit, uniformly, per Gerry's pacing call.
      await Future.delayed(const Duration(seconds: 3));
    }
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

  @override
  void dispose() {
    _introTimer?.cancel();
    _gazeAnim.dispose();
    _blinkController.dispose();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 40, 22, 26),
          child: Column(
            children: [
              const SizedBox(height: 28),

              Icon(Icons.verified_user_outlined, size: 44, color: _gold),

              const SizedBox(height: 12),

              Text(
                'SafePrep\u2122',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _softWhite,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 16),

              Container(width: 40, height: 2, color: _gold),

              const SizedBox(height: 20),

              Text(
                'We\u2019ll have you exam-ready\nin under 4 hours',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 26),

              // Top row: two stat tiles, equal height.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _statTile('20+', 'years experience')),
                    const SizedBox(width: 10),
                    Expanded(child: _statTile('1,000+', 'students taught')),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Bottom row: 500+ tile beside the FSME intro tile,
              // equal height.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _statTile('500+', 'targeted questions')),
                    const SizedBox(width: 10),
                    Expanded(child: _fsmeTile()),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Full-width SafePrep System box.
              _systemBox(),

              const SizedBox(height: 22),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      'Built by Certified ServSafe\u00AE Instructors '
                      'and Registered Proctors.\n'
                      'If it\u2019s not on the test, it\u2019s not in here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _softWhite.withValues(alpha: 0.55),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Student pass rate exceeds 95%.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _gold.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 34),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    MixpanelService.instance.track(
                      'SpOn_Intro_Next',
                      properties: {'app_name': 'SP'},
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnboardTrust(),
                      ),
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
                    'NEXT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
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

  Widget _statTile(String value, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: _softWhite.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  /// FSME intro tile — empty for 2 seconds, then he fades in with
  /// darting eyes and the arrival line, then the beat-two stumble
  /// script types in line by line.
  Widget _fsmeTile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.2), width: 1),
      ),
      child: AnimatedOpacity(
        opacity: _fsmeVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_davEye(), const SizedBox(width: 8), _davEye()],
            ),
            const SizedBox(height: 8),
            for (final line in _beatTwoLines)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    color: switch (line.audience) {
                      _FsmeAudience.boss => _bossBlue.withValues(alpha: 0.9),
                      _FsmeAudience.self => _selfGray.withValues(alpha: 0.8),
                      _FsmeAudience.user => _gold.withValues(alpha: 0.8),
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Single glowing darting eye (ported from OnboardExamDate, scaled
  /// down for the tile).
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

  /// Full-width box (spans both columns) spelling out the SafePrep
  /// System — the four apps plus the FSME hub.
  Widget _systemBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Text(
            'THE SAFEPREP SYSTEM',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w600,
              color: _gold.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'SafePrep  \u00B7  SafePrep Alcohol  \u00B7  '
            'SafePrep Refresher  \u00B7  SafePrep Espa\u00F1ol',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: _softWhite.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'FoodSafetyMadeEasy.com',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _gold.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}