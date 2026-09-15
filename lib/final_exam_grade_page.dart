import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'dashboard_page.dart';
import 'exam_ready_page.dart';
import 'safe_prep_nav_bar.dart';
import 'review_prompt_dialog.dart';

class FinalExamGradePage extends StatelessWidget {
  final TestResult result;

  const FinalExamGradePage({super.key, required this.result});

  Color _scoreColor(int score) {
    if (score <= 50) return AppColors.scoreBand1;
    if (score <= 65) return AppColors.scoreBand2;
    if (score <= 84) return AppColors.scoreBand3;
    return AppColors.scoreBand4;
  }

  String _scoreBandMessage(int score) {
    if (score <= 50) {
      return "We've adjusted your study plan and made it intuitive. Let's get to work.";
    }
    if (score <= 65) {
      return "Your results are very encouraging. You have the basics — we've created a personalized study plan just for you.";
    }
    if (score <= 84) {
      return "You mastered the basics. Now let's fine tune your knowledge — your personalized compact study plan is ready.";
    }
    if (score <= 99) {
      return "You're good to go. Come back and review anytime you like, we've added that option on the 60-Second Refresh.";
    }
    return "You're ready for the ServSafe® exam. The 60-Second Refresh will be waiting whenever you're ready.";
  }

  String _primaryButtonLabel(int score) {
    if (score <= 50) return 'Build my foundation';
    if (score <= 65) return 'Start my study plan';
    if (score <= 84) return 'Fine tune my knowledge';
    if (score <= 99) return 'Tweak my knowledge';
    return "You're ready →";
  }

  Widget _buildCategoryRow(String category, int score) {
    return Container(
      padding: AppSizes.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category,
              style: TextStyle(
                fontSize: AppFonts.body,
                fontWeight: FontWeight.w600,
                color: AppColors.strongText,
              ),
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: AppFonts.body,
              fontWeight: FontWeight.bold,
              color: _scoreColor(score),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = result.overallScore;
    final scoreColor = _scoreColor(score);
    final state = AppState();

    if (score >= 85 && !state.hasSeenReviewPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ReviewPromptDialog.show(
            context,
            source: 'final_exam_grade',
            triggerValue: score,
          );
        }
      });
    }

    final categories = [
      'Time & Temperature',
      'Cross-Contamination',
      'Food Preparation',
      'Receiving & Storage',
      'Personal Hygiene',
      'Cleaning & Sanitizing',
      'Facility & Equipment',
      'Food Safety Management',
    ];

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSizes.pageMargin,
                child: Column(
                  spacing: 10,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Safe',
                            style: TextStyle(
                              fontSize: AppFonts.header,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bodyText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Image.asset(
                            'Assets/splash.png',
                            width: 36,
                            height: 36,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Prep™',
                            style: TextStyle(
                              fontSize: AppFonts.header,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bodyText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      'Your Results',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    Container(
                      padding: AppSizes.cardPadding,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(
                          AppSizes.cardCornerRadius,
                        ),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        spacing: 4,
                        children: [
                          Text(
                            'Overall Score',
                            style: TextStyle(
                              fontSize: AppFonts.caption,
                              color: AppColors.subtleText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '$score%',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    Text(
                      _scoreBandMessage(score),
                      style: TextStyle(
                        fontSize: AppFonts.body,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Category Breakdown',
                          style: TextStyle(
                            fontSize: AppFonts.subheader,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ),
                    ),

                    ...categories.map((cat) {
                      final catScore =
                          result.categoryScores[cat] ??
                          state.getCategoryScore(cat);
                      return _buildCategoryRow(cat, catScore);
                    }),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          if (state.masteredCategories.length ==
                              AppState.allCategories.length) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExamReadyPage(overallScore: score),
                              ),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DashboardPage(),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: Text(_primaryButtonLabel(score)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SafePrepNavBar(),
          ],
        ),
      ),
    );
  }
}
