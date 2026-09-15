import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Sustained gaze/blink states FSME's eyes can be in. Set via
/// [FsmeEyePair.mood] and the widget reacts automatically — the
/// calling screen never touches gaze coordinates, blink timers, or
/// animation controllers directly. See /people/fsme-character.md for
/// the full design rationale behind each state.
///
/// - [idle]: ambient default — ONLY random horizontal darting, moderate
///   blink rate. Used whenever nothing else applies.
/// - [typing]: a line is actively animating character-by-character.
///   Faster, tighter horizontal dart than idle; blink nearly
///   suppressed. Takes priority over content-based moods while text
///   is actively revealing.
/// - [serious]: weight/stakes content (e.g. a Final Exam line). Gaze
///   locks dead-center, no dart. Blink rate drops way down — held eye
///   contact reads as sincerity.
/// - [thinking]: brief pause after a line finishes. Gaze locks
///   up-and-left (recalling a real memory — the NLP "eye-accessing
///   cues" reference).
/// - [befuddled]: confusion/exasperation ("why???"). Gaze locks
///   straight up with a small continuous horizontal jitter so it
///   doesn't read as frozen. Blink slightly faster than idle.
/// - [fibbing]: lying/dodging tell. Gaze locks up-and-right —
///   deliberately mirrors [thinking] on the opposite side
///   (up-left = recalling a real memory, up-right = constructing/
///   inventing one — the popularized "lying" tell).
enum EyeMood { idle, typing, serious, thinking, befuddled, fibbing }

/// FSME's eyes — always used as a PAIR. This is the primary widget:
/// it owns exactly ONE shared gaze/blink/bulge animation state and
/// renders two eye visuals off of it, so the two eyes can never fall
/// out of sync with each other (each picking its own random dart
/// target independently was the original bug — it read as
/// cross-eyed). Drive it with [mood] for sustained states; use a
/// [GlobalKey] of type [FsmeEyePairState] to call
/// [FsmeEyePairState.surprise] or [FsmeEyePairState.tired] for
/// momentary one-shot beats that aren't really "moods" — they play
/// once and hand control back to whatever mood was active before.
class FsmeEyePair extends StatefulWidget {
  final EyeMood mood;
  final double size;
  final double spacing;
  // When true, renders both eyes as flat closed lids regardless of
  // mood — no dart, no blink, no bulge. Used for a static "FSME is
  // off/sleeping" indicator (e.g. the Settings toggle), not a mood
  // in the ambient sense — sleep never auto-resolves back to a mood
  // the way the momentary one-shots do.
  final bool asleep;

  const FsmeEyePair({
    super.key,
    this.mood = EyeMood.idle,
    this.size = 34,
    this.spacing = 10,
    this.asleep = false,
  });

  @override
  State<FsmeEyePair> createState() => FsmeEyePairState();
}

class FsmeEyePairState extends State<FsmeEyePair>
    with TickerProviderStateMixin {
  static const Color _eyeRed = Color(0xFFE24B4A);

  final math.Random _rng = math.Random();

  // ── Gaze ──────────────────────────────────────────────────────
  // X: -1 = full left, +1 = full right. Y: -1 = full up, +1 = full
  // down (matches screen coordinates directly, so no sign-flipping
  // needed when applying to the pupil's Offset). ONE set of values
  // shared by both rendered eyes.
  double _gazeX = 0.0;
  double _gazeY = 0.0;
  double _gazeTargetX = 0.0;
  double _gazeTargetY = 0.0;
  late final AnimationController _gazeAnim;
  Timer? _gazeTimer;

  // ── Blink / squint (tired reuses this same lid mechanism, just
  // held longer with slower easing) ───────────────────────────────
  late final AnimationController _lidController;
  Timer? _blinkTimer;

  // ── Surprise bulge (separate from the lid — this scales the whole
  // eye up, not a vertical flatten) ────────────────────────────────
  late final AnimationController _bulgeController;

  // ── Wink (separate from the shared lid — this only ever drives the
  // SECOND rendered eye, so it can close one eye while the other
  // keeps its normal gaze/blink going) ─────────────────────────────
  late final AnimationController _winkController;

  // Guards ambient blink from firing mid-one-shot.
  bool _oneShotActive = false;

  EyeMood get _mood => widget.mood;

  @override
  void initState() {
    super.initState();

    _gazeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_advanceGaze);
    _gazeAnim.repeat();

    _lidController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _bulgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _winkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _applyMood(_mood);
  }

  @override
  void didUpdateWidget(covariant FsmeEyePair oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _applyMood(widget.mood);
    }
  }

  @override
  void dispose() {
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    _gazeAnim.dispose();
    _lidController.dispose();
    _bulgeController.dispose();
    _winkController.dispose();
    super.dispose();
  }

  // ── Mood application ─────────────────────────────────────────
  void _applyMood(EyeMood mood) {
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();

    switch (mood) {
      case EyeMood.idle:
        _gazeTargetY = 0.0;
        _scheduleIdleDart();
        _scheduleBlink(minMs: 3000, maxMs: 8000);
        break;

      case EyeMood.typing:
        _gazeTargetY = 0.0;
        _scheduleTypingDart();
        // Blink stays suppressed for the duration of typing — no
        // timer scheduled at all.
        break;

      case EyeMood.serious:
        setState(() {
          _gazeTargetX = 0.0;
          _gazeTargetY = 0.0;
        });
        _scheduleBlink(minMs: 8000, maxMs: 12000);
        break;

      case EyeMood.thinking:
        setState(() {
          _gazeTargetX = -1.0;
          _gazeTargetY = -0.6;
        });
        _scheduleBlink(minMs: 3000, maxMs: 8000);
        break;

      case EyeMood.befuddled:
        _gazeTargetY = -1.0;
        _scheduleBefuddledJitter();
        _scheduleBlink(minMs: 1500, maxMs: 3000);
        break;

      case EyeMood.fibbing:
        setState(() {
          _gazeTargetX = 1.0;
          _gazeTargetY = -0.6;
        });
        _scheduleBlink(minMs: 3000, maxMs: 8000);
        break;
    }
  }

  // ── Ambient gaze scheduling ─────────────────────────────────────
  void _scheduleIdleDart() {
    final delay = Duration(milliseconds: 1800 + _rng.nextInt(2200));
    _gazeTimer = Timer(delay, () {
      if (!mounted || _mood != EyeMood.idle) return;
      if (_rng.nextDouble() < 0.30) {
        setState(() => _gazeTargetX = _rng.nextBool() ? -1 : 1);
        Timer(Duration(milliseconds: 700 + _rng.nextInt(400)), () {
          if (mounted && _mood == EyeMood.idle) {
            setState(() => _gazeTargetX = 0.0);
          }
        });
      } else {
        setState(() => _gazeTargetX = 0.0);
      }
      _scheduleIdleDart();
    });
  }

  void _scheduleTypingDart() {
    final delay = Duration(milliseconds: 250 + _rng.nextInt(250));
    _gazeTimer = Timer(delay, () {
      if (!mounted || _mood != EyeMood.typing) return;
      setState(
        () => _gazeTargetX = (_rng.nextDouble() * 0.8 - 0.4).clamp(-0.4, 0.4),
      );
      Timer(Duration(milliseconds: 150 + _rng.nextInt(150)), () {
        if (mounted && _mood == EyeMood.typing) {
          setState(() => _gazeTargetX = 0.0);
        }
      });
      _scheduleTypingDart();
    });
  }

  void _scheduleBefuddledJitter() {
    final delay = Duration(milliseconds: 400 + _rng.nextInt(300));
    _gazeTimer = Timer(delay, () {
      if (!mounted || _mood != EyeMood.befuddled) return;
      setState(
        () =>
            _gazeTargetX = (_rng.nextDouble() * 0.3 - 0.15).clamp(-0.15, 0.15),
      );
      _scheduleBefuddledJitter();
    });
  }

  void _advanceGaze() {
    final nextX = _gazeX + (_gazeTargetX - _gazeX) * 0.18;
    final nextY = _gazeY + (_gazeTargetY - _gazeY) * 0.18;
    if ((nextX - _gazeX).abs() > 0.001 || (nextY - _gazeY).abs() > 0.001) {
      setState(() {
        _gazeX = nextX;
        _gazeY = nextY;
      });
    }
  }

  // ── Blink scheduling ─────────────────────────────────────────
  void _scheduleBlink({required int minMs, required int maxMs}) {
    final delay = Duration(milliseconds: minMs + _rng.nextInt(maxMs - minMs));
    _blinkTimer = Timer(delay, () async {
      if (!mounted || _oneShotActive) return;
      await _lidController.forward(from: 0.0);
      if (mounted) await _lidController.reverse();
      if (!mounted) return;
      // Re-check mood in case it changed mid-blink (e.g. typing
      // suppresses blink entirely — don't reschedule into a mood
      // that shouldn't be blinking).
      if (_mood == EyeMood.typing) return;
      final range = _blinkRangeFor(_mood);
      _scheduleBlink(minMs: range.$1, maxMs: range.$2);
    });
  }

  (int, int) _blinkRangeFor(EyeMood mood) {
    switch (mood) {
      case EyeMood.idle:
      case EyeMood.thinking:
      case EyeMood.fibbing:
        return (3000, 8000);
      case EyeMood.serious:
        return (8000, 12000);
      case EyeMood.befuddled:
        return (1500, 3000);
      case EyeMood.typing:
        return (3000, 8000); // unused — typing never reschedules
    }
  }

  // ── Triggered one-shots ─────────────────────────────────────────
  /// Startle beat: eyes bulge (scale up) and snap back. Gaze locks
  /// center and blink is suppressed for the duration, then control
  /// returns to whatever mood was active before the call.
  Future<void> surprise() async {
    if (_oneShotActive) return;
    _oneShotActive = true;
    _blinkTimer?.cancel();

    final priorTargetX = _gazeTargetX;
    final priorTargetY = _gazeTargetY;
    setState(() {
      _gazeTargetX = 0.0;
      _gazeTargetY = 0.0;
    });

    await _bulgeController.forward(from: 0.0);
    if (mounted) await _bulgeController.reverse();

    if (!mounted) return;
    setState(() {
      _gazeTargetX = priorTargetX;
      _gazeTargetY = priorTargetY;
    });
    _oneShotActive = false;
    final range = _blinkRangeFor(_mood);
    if (_mood != EyeMood.typing) {
      _scheduleBlink(minMs: range.$1, maxMs: range.$2);
    }
  }

  /// Fatigue beat: eyes squint down, hold, then ease back open —
  /// slower and held longer than a normal blink so it reads as
  /// effortful rather than a quick blink. Reuses the same lid
  /// mechanism as blink, just with different timing.
  Future<void> tired() async {
    if (_oneShotActive) return;
    _oneShotActive = true;
    _blinkTimer?.cancel();

    final priorTargetY = _gazeTargetY;
    setState(() => _gazeTargetY = 0.4); // slight downward drift while squinted

    await _lidController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeIn,
    );
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _lidController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );

    if (!mounted) return;
    setState(() => _gazeTargetY = priorTargetY);
    _oneShotActive = false;
    final range = _blinkRangeFor(_mood);
    if (_mood != EyeMood.typing) {
      _scheduleBlink(minMs: range.$1, maxMs: range.$2);
    }
  }

  /// Playful one-shot: closes just the SECOND rendered eye (the one
  /// on the right) and reopens it — a wink, not a blink. The other
  /// eye's own gaze keeps moving underneath, unaffected — suppresses
  /// the shared ambient blink briefly so the two don't fire at once
  /// and read as a normal blink instead. Hands control back to
  /// whatever mood was active before once it resolves.
  Future<void> wink() async {
    if (_oneShotActive) return;
    _oneShotActive = true;
    _blinkTimer?.cancel();

    await _winkController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeIn,
    );
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _winkController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );

    if (!mounted) return;
    _oneShotActive = false;
    final range = _blinkRangeFor(_mood);
    if (_mood != EyeMood.typing) {
      _scheduleBlink(minMs: range.$1, maxMs: range.$2);
    }
  }

  // Static closed-lid shape for the asleep/off state — no gradient
  // eyeball, no pupil, no animation at all. A flat rounded bar reads
  // clearly as "closed" at small sizes without needing a full
  // eyelid-over-eyeball composite.
  Widget _sleepingEyeVisual() {
    return Container(
      width: widget.size,
      height: widget.size * 0.22,
      decoration: BoxDecoration(
        color: const Color(0xFF5A2020),
        borderRadius: BorderRadius.circular(widget.size),
      ),
    );
  }

  // Both rendered eyes read from the exact same _gazeX/_gazeY/lid/
  // bulge values below — that's what keeps them in lockstep instead
  // of each picking their own target independently.
  Widget _eyeVisual(double lidScaleY, double bulgeScale) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(bulgeScale, bulgeScale * lidScaleY),
      child: Container(
        width: widget.size,
        height: widget.size,
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
            offset: Offset(_gazeX * 6, 0.5 + _gazeY * 6),
            child: Container(
              width: widget.size * 0.265,
              height: widget.size * 0.324,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0000),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asleep) {
      // No animation at all while asleep — static, no controllers
      // driving it, cheapest possible render for a settings toggle.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sleepingEyeVisual(),
          SizedBox(width: widget.spacing),
          _sleepingEyeVisual(),
        ],
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _gazeAnim,
        _lidController,
        _bulgeController,
        _winkController,
      ]),
      builder: (context, _) {
        final lidScaleY = 1.0 - _lidController.value * 0.92;
        final bulgeScale = 1.0 + _bulgeController.value * 0.25;
        final winkScaleY = 1.0 - _winkController.value * 0.92;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eyeVisual(lidScaleY, bulgeScale),
            SizedBox(width: widget.spacing),
            // Second eye only — this is the one `wink()` closes.
            _eyeVisual(lidScaleY * winkScaleY, bulgeScale),
          ],
        );
      },
    );
  }
}
