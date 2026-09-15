import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'constants.dart';
import 'mixpanel_service.dart';

/// FSME's post-Final-Exam-pass review ask.
///
/// Matches the established FSME visual identity (dark card, gold text,
/// darting red eyes with blink) used in OnboardIntro and elsewhere,
/// rather than a generic Material dialog — this is one of FSME's
/// moments, so it should look like every other one.
///
/// Shown once ever (governed by AppState.hasSeenReviewPrompt), fired
/// from FinalExamGradePage on a first Final Exam pass at 85%+.
class ReviewPromptDialog extends StatefulWidget {
  const ReviewPromptDialog({
    super.key,
    required this.source,
    this.triggerValue,
  });

  /// Which trigger site fired this — e.g. 'final_exam_grade' (85%+ Final
  /// Exam score) or 'dashboard_readiness' (90%+ readiness). Tracked on
  /// show so we can tell the two paths apart in Mixpanel.
  final String source;

  /// The score/readiness value that satisfied the trigger, if the caller
  /// has one handy — purely informational for analytics.
  final int? triggerValue;

  /// Convenience launcher — call this instead of showDialog directly.
  static void show(
    BuildContext context, {
    required String source,
    int? triggerValue,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) =>
          ReviewPromptDialog(source: source, triggerValue: triggerValue),
    );
  }

  @override
  State<ReviewPromptDialog> createState() => _ReviewPromptDialogState();
}

class _ReviewPromptDialogState extends State<ReviewPromptDialog>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _eyeRed = Color(0xFFE24B4A);

  late AnimationController _blinkController;
  Timer? _blinkTimer;
  final math.Random _rng = math.Random();

  bool _lineVisible = false;

  static const String _line =
      "Look at you, my friend \u2014 that was awesome watching you take "
      "this exam, I could tell by question 60 you were going to ace "
      "this. I can tell you this: you are definitely ready for the "
      "real thing!\n\n"
      "Mind doing me a favor and rating us? Takes two seconds.";

  @override
  void initState() {
    super.initState();

    // Fired the moment this dialog actually renders — i.e. the review ask
    // was shown to the user — regardless of which trigger site called
    // show(). Note this only tells us the ask was presented, not what the
    // user did with Apple's native star picker afterward (Apple doesn't
    // report that back to us at all — see _dismiss()).
    MixpanelService.instance.track(
      'review_prompt_shown',
      properties: {
        'app_name': 'SP',
        'source': widget.source,
        if (widget.triggerValue != null) 'trigger_value': widget.triggerValue,
      },
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scheduleBlink();

    // Small beat before the line appears, so the eyes register first.
    Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _lineVisible = true);
    });
  }

  void _scheduleBlink() {
    final delay = Duration(milliseconds: 2200 + _rng.nextInt(3000));
    _blinkTimer = Timer(delay, () async {
      if (!mounted) return;
      await _blinkController.forward(from: 0.0);
      if (mounted) await _blinkController.reverse();
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _dismiss(
    BuildContext context, {
    required bool requestReview,
  }) async {
    final state = AppState();
    state.hasSeenReviewPrompt = true;
    AppStatePersistence.save();

    if (requestReview) {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        inAppReview.requestReview();
      }
    }

    if (context.mounted) Navigator.pop(context);
  }

  Widget _eye() {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, _) {
        final blink = 1.0 - _blinkController.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 30,
            height: 30,
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
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 9,
                height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0000),
                  borderRadius: BorderRadius.circular(4),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_eye(), const SizedBox(width: 10), _eye()],
            ),
            const SizedBox(height: 18),
            AnimatedOpacity(
              opacity: _lineVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Text(
                _line,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: _gold.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _dismiss(context, requestReview: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _darkBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSizes.buttonCornerRadius,
                    ),
                  ),
                ),
                child: const Text(
                  '\u2B50\u2B50\u2B50\u2B50\u2B50  Rate SafePrep',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _dismiss(context, requestReview: false),
              child: Text(
                'Not now',
                style: TextStyle(color: _softWhite.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
