import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import '../app_state.dart';
import '../app_state_persistence.dart';
import '../category_study_page.dart';
import '../assessment_info_page.dart';
import 'onboard_answers.dart';

/// Post-purchase screen — the terminal build sequence.
///
/// Plays a short typing animation that makes the plan feel computed
/// rather than canned, then presents the starting point. No diagnostic
/// exists anymore to personalize the category — it's a fixed top
/// weighted category for everyone (matches the Trust page's
/// breakdown). Pace estimate is keyed to the self-reported knowledge
/// level instead. Nothing invented, just no longer diagnostic-driven.
class OnboardPostPurchase extends StatefulWidget {
  const OnboardPostPurchase({super.key});

  @override
  State<OnboardPostPurchase> createState() => _OnboardPostPurchaseState();
}

class _OnboardPostPurchaseState extends State<OnboardPostPurchase> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);

  static const int _maxEstimateMinutes = 240;

  final List<_BuildLine> _printed = [];
  bool _revealed = false;
  Timer? _typer;

  /// Top category by real exam weight (matches the Trust page's
  /// weighted breakdown and the rapid-fire preview's fixed set) — fixed
  /// for everyone now that there's no diagnostic to personalize
  /// against.
  static const String _topCategory = 'Time & Temperature';

  /// Estimate keyed to the self-reported knowledge level rather than
  /// diagnostic data — a rougher signal, but a real one the user
  /// actually gave us, and it still ties the "X min" language to
  /// something they told us about themselves.
  int get _estimateMinutes {
    switch (OnboardingAnswers.instance.knowledgeLevel) {
      case KnowledgeLevel.confident:
        return 90;
      case KnowledgeLevel.prepared:
        return 120;
      case KnowledgeLevel.almostReady:
        return 150;
      case KnowledgeLevel.newToServSafe:
        return _maxEstimateMinutes;
      case null:
        return 150;
    }
  }

  String get _estimateLabel {
    final h = _estimateMinutes ~/ 60;
    final m = _estimateMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }

  String get _paceLabel {
    final window = OnboardingAnswers.instance.examWindow;
    switch (window) {
      case ExamWindow.oneToThree:
        return 'Cram pace \u2014 focused sessions, no filler';
      case ExamWindow.fourToTen:
        return 'Steady pace \u2014 a few sessions across your week';
      case ExamWindow.tenPlus:
        return 'Comfortable pace \u2014 short daily sessions';
      case ExamWindow.notScheduled:
        return 'Flexible pace \u2014 move at your speed';
      default:
        return 'Flexible pace \u2014 move at your speed';
    }
  }

  @override
  void initState() {
    super.initState();

    MixpanelService.instance.track(
      'onboarding_post_purchase_viewed',
      properties: {'app_name': 'SP', 'top_category': _topCategory},
    );

    _startTyping();
  }

  @override
  void dispose() {
    _typer?.cancel();
    super.dispose();
  }

  List<_BuildLine> get _script {
    return [
      _BuildLine('> Unlocking full access'),
      _BuildLine('  confirmed', dim: true),
      _BuildLine('> Loading your responses'),
      _BuildLine('  readiness level recorded', dim: true),
      _BuildLine('> Building your sequence'),
      _BuildLine('  starting with ${_topCategory.toLowerCase()}', dim: true),
      _BuildLine('> Setting your pace'),
      _BuildLine('  $_estimateLabel estimated', dim: true),
      _BuildLine('> Plan ready'),
    ];
  }

  void _startTyping() {
    final script = _script;
    int lineIndex = 0;
    int charIndex = 0;

    _typer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (lineIndex >= script.length) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() => _revealed = true);
        });
        return;
      }

      final source = script[lineIndex];

      setState(() {
        if (charIndex == 0) {
          _printed.add(_BuildLine('', dim: source.dim));
        }
        charIndex++;
        _printed[_printed.length - 1] = _BuildLine(
          source.text.substring(0, charIndex),
          dim: source.dim,
        );
      });

      if (charIndex >= source.text.length) {
        lineIndex++;
        charIndex = 0;
      }
    });
  }

  void _startStudying() {
    // Clear any stale curriculum progress so the study page loads
    // from the beginning, not from a previous session's endpoint.
    final state = AppState();
    state.clearCurriculumProgress();
    AppStatePersistence.save();

    MixpanelService.instance.track(
      'onboarding_post_purchase_start',
      properties: {'app_name': 'SP', 'category': _topCategory},
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryStudyPage(category: _topCategory),
      ),
      (_) => false,
    );
  }

  void _fineTune() {
    MixpanelService.instance.track(
      'onboarding_post_purchase_fine_tune',
      properties: {'app_name': 'SP'},
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AssessmentInfoPage()),
      (_) => false,
    );
  }

  Widget _buildBox() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 172),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in _printed)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                line.text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.6,
                  color: line.dim ? _softWhite.withValues(alpha: 0.4) : _gold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Eyebrow
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: _gold),
                  const SizedBox(width: 6),
                  Text(
                    'PURCHASE COMPLETE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.6,
                      color: _gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildBox(),

              AnimatedOpacity(
                opacity: _revealed ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 22),

                    Text(
                      'Your study plan is in place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _softWhite,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _paceLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _softWhite.withValues(alpha: 0.5),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Primary: start studying weakest category
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _startStudying,
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
                        child: Text(
                          'Start: $_topCategory  \u2192',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Secondary: fine-tune via full assessment
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _fineTune,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _softWhite,
                          side: BorderSide(
                            color: _gold.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: Text(
                          'Fine-tune my plan  \u2022  30-question assessment',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: _softWhite.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Manifesto
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: _gold.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'Gimmick free. No meaningless calendars. No extended '
                        'plans. No fake milestones. We take pride in the '
                        'easiest app to navigate \u2014 one that actually '
                        'adapts to how you learn.\n\n'
                        'We\u2019ll have you prepared in 4 hours or less. '
                        'Not weeks.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: _softWhite.withValues(alpha: 0.35),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildLine {
  final String text;
  final bool dim;
  const _BuildLine(this.text, {this.dim = false});
}
