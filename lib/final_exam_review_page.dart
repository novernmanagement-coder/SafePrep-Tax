import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'home_page.dart';
import 'csv_loader.dart';
import 'final_exam_grade_page.dart';
import 'safe_prep_nav_bar.dart';

class FinalExamReviewPage extends StatefulWidget {
  final List<QuestionModel> missedQuestions;
  final TestResult result;

  const FinalExamReviewPage({
    super.key,
    required this.missedQuestions,
    required this.result,
  });

  @override
  State<FinalExamReviewPage> createState() => _FinalExamReviewPageState();
}

class _FinalExamReviewPageState extends State<FinalExamReviewPage> {
  int _currentIndex = 0;

  void _goNext() {
    setState(
      () => _currentIndex = (_currentIndex + 1) % widget.missedQuestions.length,
    );
  }

  void _goPrevious() {
    setState(
      () => _currentIndex =
          (_currentIndex - 1 + widget.missedQuestions.length) %
          widget.missedQuestions.length,
    );
  }

  void _goToGrade() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FinalExamGradePage(result: widget.result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuestions = widget.missedQuestions.isNotEmpty;
    final q = hasQuestions ? widget.missedQuestions[_currentIndex] : null;

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
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomePage(),
                              ),
                            ),
                            child: Row(
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
                        ],
                      ),
                    ),

                    Text(
                      hasQuestions
                          ? 'Take a moment to review'
                          : 'You got everything right!',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (hasQuestions)
                      Text(
                        'Question ${_currentIndex + 1} of ${widget.missedQuestions.length}',
                        style: TextStyle(
                          fontSize: AppFonts.subheader,
                          color: AppColors.subtleText,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    if (q != null) ...[
                      Container(
                        width: double.infinity,
                        padding: AppSizes.cardPadding,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(
                            AppSizes.cardCornerRadius,
                          ),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Text(
                          q.questionText,
                          style: const TextStyle(
                            fontSize: AppFonts.question,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: AppColors.strongText,
                          ),
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        padding: AppSizes.cardPadding,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(
                            AppSizes.cardCornerRadius,
                          ),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Text(
                          q.explanation,
                          style: TextStyle(
                            fontSize: AppFonts.body,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: AppSizes.primaryButtonHeight,
                              child: ElevatedButton(
                                onPressed: _goPrevious,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryButton,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.buttonCornerRadius,
                                    ),
                                  ),
                                ),
                                child: const Text('Back'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: AppSizes.primaryButtonHeight,
                              child: ElevatedButton(
                                onPressed: _goNext,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryButton,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.buttonCornerRadius,
                                    ),
                                  ),
                                ),
                                child: const Text('Next'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: _goToGrade,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text('Grade Exam'),
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
