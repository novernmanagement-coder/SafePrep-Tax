import 'package:flutter/material.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_paywall.dart';

/// Onboarding screen 5 of the new flow — "How do you learn best?"
///
/// Determines how their ongoing study content is presented once
/// they're in the app — the choice is real, not theatre, since the
/// content they land on afterward visibly follows it.
///
/// Per the redesigned funnel's trimmed-role direction, this is now a
/// quick selection screen only — no FSME terminal confirmation, no
/// eyes, no per-mode authored script. Same tap-until-confident
/// interaction as the previous two screens: selecting doesn't lock in
/// or auto-advance; Continue only appears after the first tap.
class OnboardStudyStyle extends StatefulWidget {
  const OnboardStudyStyle({super.key});

  @override
  State<OnboardStudyStyle> createState() => _OnboardStudyStyleState();
}

class _OnboardStudyStyleState extends State<OnboardStudyStyle> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  StudyStyle? _selected;

  void _choose(StudyStyle style) {
    setState(() => _selected = style);

    OnboardingAnswers.instance.studyStyle = style;

    MixpanelService.instance.track(
      'SpOn_Style_Selected',
      properties: {'app_name': 'SP', 'study_style': style.tag},
    );
  }

  void _advance() {
    if (_selected == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardPaywall()),
    );
  }

  /// Header row: back chevron, centred progress, balancing spacer.
  Widget _header(int filled, int total) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            alignment: Alignment.centerLeft,
            icon: Icon(
              Icons.chevron_left,
              size: 24,
              color: _softWhite.withValues(alpha: 0.4),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              return Container(
                width: 22,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: i < filled
                      ? _gold
                      : _softWhite.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 32),
      ],
    );
  }

  /// A single illustrative question, rendered differently per style so
  /// the user can see exactly what each mode looks like before they
  /// pick — not just read a one-line description of it.
  static const String _exampleQuestion = 'What is the temperature danger zone?';
  static const String _exampleWrong = '32\u00B0F \u2013 100\u00B0F';
  static const String _exampleRight = '41\u00B0F \u2013 135\u00B0F';
  static const String _exampleWhy =
      'Bacteria multiply fastest between 41\u00B0F and 135\u00B0F.';

  static const Color _green = Color(0xFF639922);
  static const Color _red = Color(0xFFE24B4A);

  /// One tappable style option. Free re-selection, matching the
  /// previous two screens' pattern.
  Widget _option({
    required StudyStyle style,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final bool isSelected = _selected == style;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _choose(style),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? _gold.withValues(alpha: 0.12) : _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? _gold : _gold.withValues(alpha: 0.3),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 21, color: _gold),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _softWhite,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: _softWhite.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.check : Icons.chevron_right,
                      size: 18,
                      color: isSelected ? _gold : _gold.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _examplePreview(style),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact mock of the actual question card for this style — same
  /// illustrative question every time, feedback rendered the way that
  /// mode really shows it.
  Widget _examplePreview(StudyStyle style) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _darkBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _exampleQuestion,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _softWhite.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          _exampleAnswerRow(style, text: _exampleWrong, isCorrect: false),
          const SizedBox(height: 5),
          _exampleAnswerRow(style, text: _exampleRight, isCorrect: true),
          if (style == StudyStyle.explanations) ...[
            const SizedBox(height: 8),
            Text(
              _exampleWhy,
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: _gold.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (style == StudyStyle.quizFormat) ...[
            const SizedBox(height: 6),
            Text(
              'Score revealed at the end \u2014 no feedback during.',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: _softWhite.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One answer row in the example. quizFormat never colors an answer
  /// (no feedback shown during); the other two modes always do —
  /// answersOnly just skips the explanation line above.
  Widget _exampleAnswerRow(
    StudyStyle style, {
    required String text,
    required bool isCorrect,
  }) {
    final bool showFeedback = style != StudyStyle.quizFormat;
    final Color color = !showFeedback
        ? _softWhite.withValues(alpha: 0.55)
        : (isCorrect ? _green : _red);

    return Row(
      children: [
        if (showFeedback)
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 13,
            color: color,
          )
        else
          Icon(
            Icons.radio_button_unchecked,
            size: 13,
            color: _softWhite.withValues(alpha: 0.3),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(5, 5),

              const SizedBox(height: 22),

              const Icon(Icons.lightbulb_outline, size: 28, color: _gold),

              const SizedBox(height: 12),

              const Text(
                'How do you learn best?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _softWhite,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "We'll set up your questions this way.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _softWhite.withValues(alpha: 0.5),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              _option(
                style: StudyStyle.explanations,
                icon: Icons.help_outline,
                label: 'Answers and explanations',
                subtitle: 'Show me why I missed it',
              ),
              _option(
                style: StudyStyle.answersOnly,
                icon: Icons.check_circle_outline,
                label: 'Answers only',
                subtitle: 'Just show me the right one',
              ),
              _option(
                style: StudyStyle.quizFormat,
                icon: Icons.format_list_numbered,
                label: 'Quiz format',
                subtitle: 'Score me at the end',
              ),

              if (_selected != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _advance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xFF0A0A0F),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Continue  \u2192',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}