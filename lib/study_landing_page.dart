import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'category_study_page.dart';
import 'category_quiz_page.dart';
import 'onboard/onboard_answers.dart'; // OnboardingAnswers, StudyStyle
import 'fsme_eye.dart'; // FsmeEyePair, EyeMood

/// Call this instead of navigating directly to CategoryStudyPage /
/// CategoryQuizPage. Shows the one-time FSME landing modal on the
/// user's very first-ever visit to the study module (global flag,
/// not per-category); every entry after that routes straight through.
void navigateToStudy(BuildContext context, String category) {
  final state = AppState();

  // Re-entering Study/Quiz for a category that's ALREADY mastered is
  // a deliberate "I want to start over" signal, by design — full
  // reset of that category's question-level mastery data, nothing
  // persists. This is the single shared entry point every "Study →"
  // button routes through (Dashboard's active AND mastered category
  // cards both call this), so it's the right choke point for the
  // trigger regardless of where the tap originated.
  if (state.masteredCategories.contains(category)) {
    state.clearQuestionMasteryForCategory(category);
    AppStatePersistence.save();
  }

  if (!state.hasSeenStudyLanding) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudyLandingPage(category: category)),
    );
    return;
  }
  _goToDestination(context, category, replace: false);
}

/// Routes to Full Study or Quiz Only based on the user's onboarding
/// StudyStyle answer. quizFormat is the one style that skips
/// per-question feedback (Retro) — it's the only one routed straight
/// to the quiz; the other two both still want to see the material
/// first, so they get Full Study Mode.
void _goToDestination(
  BuildContext context,
  String category, {
  required bool replace,
}) {
  final style = OnboardingAnswers.instance.studyStyle;
  final destination = style == StudyStyle.quizFormat
      ? CategoryQuizPage(category: category)
      : CategoryStudyPage(category: category);

  if (replace) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }
}

class StudyLandingPage extends StatefulWidget {
  final String category;
  const StudyLandingPage({super.key, required this.category});

  @override
  State<StudyLandingPage> createState() => _StudyLandingPageState();
}

class _StudyLandingPageState extends State<StudyLandingPage> {
  static const Map<StudyStyle, String> _styleLabel = {
    StudyStyle.explanations: 'Answers and Explanations',
    StudyStyle.answersOnly: 'Answers Only',
    StudyStyle.quizFormat: 'Quiz Format',
  };

  String get _fsmeLine {
    final style = OnboardingAnswers.instance.studyStyle;
    final label = _styleLabel[style] ?? 'your chosen style';
    return "Your preferred study style is $label. We've set the system up "
        "to accommodate that. Should you want to change the style, it's "
        "just the flip of a switch.";
  }

  void _continue() {
    final state = AppState();
    state.hasSeenStudyLanding = true;
    AppStatePersistence.save();
    _goToDestination(context, widget.category, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'STUDY',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: AppColors.subtleText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.category,
                    style: TextStyle(
                      fontSize: AppFonts.header,
                      fontWeight: FontWeight.w600,
                      color: AppColors.bodyText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  const FsmeEyePair(mood: EyeMood.idle, size: 20),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(
                        AppSizes.cardCornerRadius,
                      ),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      _fsmeLine,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.strongText,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.primaryButtonHeight,
                    child: ElevatedButton(
                      onPressed: _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.buttonCornerRadius,
                          ),
                        ),
                      ),
                      child: const Text('Got it'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
