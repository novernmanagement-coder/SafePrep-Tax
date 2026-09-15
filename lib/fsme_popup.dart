import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────
/// FSME popup — reusable across the SafePrep app suite.
///
/// Wraps the eye/gaze/blink animation, the audience-color system, the
/// typing-vs-instant reveal rule, and the standard pop-in timing into
/// one drop-in widget. Callers just supply a script (a list of
/// [FsmeLine]) and optional config; sizing and timing are handled here
/// so every screen that uses FSME stays visually and behaviorally
/// consistent without re-copying the machinery.
///
/// Usage:
/// ```dart
/// FsmePopup(
///   lines: const [
///     FsmeLine('Hey — nice work in here.'),
///     FsmeLine('Beep. Boop.', audience: FsmeAudience.processing),
///     FsmeLine('...gotta go, boss is coming.', audience: FsmeAudience.self),
///   ],
/// )
/// ```
///
/// ── Audience / color system ─────────────────────────────────────────
/// - user: FSME's default voice (gold) — types out character by
///   character, per the standing typing rule.
/// - boss: directed at (or quoting) the Boss — blue, instant reveal.
/// - self: muttering/thinking to himself — gray, instant reveal.
/// - processing: system-status readout bits (Beep Boop, "X confirmed")
///   — teal, instant reveal.
/// [flash] marks the rare "sudden real expertise" beat — bold gold,
/// independent of audience.
///
/// ── Timing (all overridable, defaults match the established norms) ──
/// - [startDelay]: wait before the box starts fading in. Default 2s.
/// - [fadeInDuration]: the fade transition itself. Default 2300ms (the
///   "needs to sit there and resonate" pacing call).
/// - [holdThenFadeOut]: if set, the box fades back out this long after
///   the last line finishes revealing. If null (default), it stays
///   visible once shown — most decline/limit-screen uses want this.
/// - Per-line pacing: user lines type at 18ms/char; every line (typed
///   or instant) is followed by a 900ms pause before the next starts.
enum FsmeAudience { user, boss, self, processing }

class FsmeLine {
  final String text;
  final FsmeAudience audience;
  final bool flash;
  const FsmeLine(
    this.text, {
    this.audience = FsmeAudience.user,
    this.flash = false,
  });
}

/// Mutable render-time counterpart — [text] grows as a user-audience
/// line types out; other lines just get their full text set once.
class _RenderLine {
  String text;
  final FsmeAudience audience;
  final bool flash;
  _RenderLine(this.text, this.audience, {this.flash = false});
}

class FsmePopup extends StatefulWidget {
  /// The script to reveal, in order.
  final List<FsmeLine> lines;

  /// Delay before the box starts fading in. Default matches the
  /// funnel-wide standard (2s).
  final Duration startDelay;

  /// Duration of the fade-in (and fade-out, if [holdThenFadeOut] is
  /// set) transition itself. Default 2300ms.
  final Duration fadeInDuration;

  /// If non-null, the box fades out this long after the last line
  /// finishes revealing. If null, it stays visible permanently once
  /// shown (the common case for decline/limit screens).
  final Duration? holdThenFadeOut;

  /// Eye diameter. Default 26 — the funnel-wide standard. Only
  /// override for a deliberately different presentation (e.g. the
  /// Boss's larger 40px treatment on the readiness screen).
  final double eyeSize;

  /// Whether to show the small "F S M E" wordmark between the eyes.
  /// Default true.
  final bool showLabel;

  /// Called once, after the last line has finished revealing (and
  /// after any [holdThenFadeOut] hold — right as the fade-out starts,
  /// or immediately if there's no fade-out). Useful for gating a
  /// Continue button on the popup finishing.
  final VoidCallback? onComplete;

  const FsmePopup({
    super.key,
    required this.lines,
    this.startDelay = const Duration(seconds: 2),
    this.fadeInDuration = const Duration(milliseconds: 2300),
    this.holdThenFadeOut,
    this.eyeSize = 26,
    this.showLabel = true,
    this.onComplete,
  });

  @override
  State<FsmePopup> createState() => _FsmePopupState();
}

class _FsmePopupState extends State<FsmePopup> with TickerProviderStateMixin {
  // ── Standard palette — consistent everywhere FSME appears. ──────────
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _eyeRed = Color(0xFFE24B4A);
  static const Color _bossBlue = Color(0xFF4A9BE2);
  static const Color _selfGray = Color(0xFF9E9E9E);
  static const Color _processingTeal = Color(0xFF6FA8A6);

  bool _visible = false;
  final List<_RenderLine> _revealed = [];

  Timer? _inTimer;

  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late final AnimationController _gazeAnim;
  late final AnimationController _blinkController;
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

    _inTimer = Timer(widget.startDelay, _start);
  }

  void _start() {
    if (!mounted) return;
    setState(() => _visible = true);
    _scheduleGaze();
    _scheduleBlink();
    _reveal();
  }

  /// Reveals the script one line at a time. User-audience lines type
  /// out character by character; boss/self/processing lines appear
  /// instantly. A 900ms pause follows every line either way.
  Future<void> _reveal() async {
    for (final line in widget.lines) {
      if (!mounted) return;

      if (line.audience == FsmeAudience.user) {
        final entry = _RenderLine('', line.audience, flash: line.flash);
        setState(() => _revealed.add(entry));
        for (var i = 1; i <= line.text.length; i++) {
          if (!mounted) return;
          setState(() => entry.text = line.text.substring(0, i));
          await Future.delayed(const Duration(milliseconds: 18));
        }
      } else {
        setState(
          () => _revealed.add(
            _RenderLine(line.text, line.audience, flash: line.flash),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 900));
    }

    if (!mounted) return;

    final hold = widget.holdThenFadeOut;
    if (hold != null) {
      await Future.delayed(hold);
      if (!mounted) return;
      setState(() => _visible = false);
    }

    widget.onComplete?.call();
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
      if (!mounted || !_visible) return;
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
      if (!mounted || !_visible) return;
      await _blinkController.forward(from: 0.0);
      if (mounted) await _blinkController.reverse();
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _inTimer?.cancel();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    _gazeAnim.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Widget _eye() {
    final pupilW = widget.eyeSize * (8 / 26);
    final pupilH = widget.eyeSize * (10 / 26);
    final drift = widget.eyeSize * (5 / 26);

    return AnimatedBuilder(
      animation: Listenable.merge([_gazeAnim, _blinkController]),
      builder: (context, _) {
        final blink = 1.0 - _blinkController.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: widget.eyeSize,
            height: widget.eyeSize,
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
                  blurRadius: widget.eyeSize * (10 / 26),
                  spreadRadius: widget.eyeSize * (2 / 26),
                ),
              ],
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(_gazeCurrent * drift, 0.5),
                child: Container(
                  width: pupilW,
                  height: pupilH,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0000),
                    borderRadius: BorderRadius.circular(pupilW / 2),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: widget.fadeInDuration,
      child: Container(
        width: double.infinity,
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
                _eye(),
                if (widget.showLabel) ...[
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
                ] else
                  const SizedBox(width: 10),
                _eye(),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in _revealed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '> ${line.text}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: line.flash
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: switch (line.audience) {
                      FsmeAudience.boss => _bossBlue,
                      FsmeAudience.self => _selfGray,
                      FsmeAudience.processing => _processingTeal,
                      FsmeAudience.user => _gold.withValues(alpha: 0.85),
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
