import 'package:flutter/material.dart';
import 'constants.dart';
import 'cluster_info_page.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'expert_club_dialog.dart';
import 'final_exam_intro_page.dart';
import 'fsme_help_box.dart';
import 'readiness_engine.dart';
import 'mixpanel_service.dart';

class AssessmentPageV2 extends StatefulWidget {
  const AssessmentPageV2({super.key});

  @override
  State<AssessmentPageV2> createState() => _AssessmentPageV2State();
}

class _AssessmentPageV2State extends State<AssessmentPageV2> {
  List<QuestionModel> _questions = [];
  List<int> _selectedAnswers = [];
  int _currentIndex = 0;
  bool _loaded = false;

  // Assessment IS one of the five clusters, so its FsmeHelpBox opens
  // that single cluster's explanation directly — unlike Home/Settings,
  // which aren't any one cluster themselves and open a list instead.
  static const List<String> _fsmeHelpMessages = [
    "This builds your custom study plan — there's no pass or fail here.",
    "Order and answer positions shuffle every time, so don't bother memorizing a pattern.",
    "Tap me — I'll 'splain what this whole thing is for.",
  ];

  void _openAssessmentExplanation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClusterInfoPage(
          cluster: AppCluster.assessment,
          launchContext: ClusterLaunchContext.landing,
        ),
      ),
    );
  }

  static const Map<String, double> categoryWeights = {
    'Time & Temperature': 0.23,
    'Cross-Contamination': 0.15,
    'Receiving & Storage': 0.15,
    'Personal Hygiene': 0.14,
    'Cleaning & Sanitizing': 0.12,
    'Food Preparation': 0.12,
    'Food Safety Management': 0.05,
    'Facility & Equipment': 0.02,
    'Pest Management': 0.02,
  };

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    MixpanelService.instance.track(
      'assessment_started',
      properties: {'app_name': 'SP'},
    );
  }

  Future<void> _loadQuestions() async {
    final all = await QuestionLoader.loadAll(shuffle: false);
    final selected = <QuestionModel>[];
    final usedIds = <String>{};

    // Trial users get 20 questions, paid users get 40
    final target = AppState().hasUnlockedApp
        ? AppConstants.diagnosticQuestionsFull
        : AppConstants.diagnosticQuestions;

    final categoryCounts = <String, int>{};
    int allocated = 0;

    for (final cat in categoryWeights.keys) {
      final count = ((categoryWeights[cat]! * target).round()).clamp(1, target);
      categoryCounts[cat] = count;
      allocated += count;
    }

    while (allocated < target) {
      categoryCounts['Time & Temperature'] =
          categoryCounts['Time & Temperature']! + 1;
      allocated++;
    }
    while (allocated > target) {
      categoryCounts['Time & Temperature'] =
          categoryCounts['Time & Temperature']! - 1;
      allocated--;
    }

    for (final cat in categoryWeights.keys) {
      final needed = categoryCounts[cat]!;
      final pool = all
          .where((q) => q.category == cat && !usedIds.contains(q.id))
          .toList();
      pool.shuffle();

      final mustInclude = pool.where((q) => q.mustInclude == 1).toList()
        ..shuffle();
      final taken = mustInclude.take(needed).toList();
      selected.addAll(taken);
      for (final q in taken) {
        usedIds.add(q.id);
      }

      int remaining = needed - taken.length;
      if (remaining <= 0) continue;

      final rest = pool.where((q) => !usedIds.contains(q.id)).toList();
      final hard = rest.where((q) => q.difficulty == 3).toList()..shuffle();
      final medium = rest.where((q) => q.difficulty == 2).toList()..shuffle();
      final easy = rest.where((q) => q.difficulty == 1).toList()..shuffle();

      final hardCount = (remaining * AppConstants.diagnosticHardWeight).round();
      final mediumCount = (remaining * AppConstants.diagnosticMediumWeight)
          .round();
      final easyCount = remaining - hardCount - mediumCount;

      final fill = [
        ...hard.take(hardCount),
        ...medium.take(mediumCount),
        ...easy.take(easyCount),
      ];

      if (fill.length < remaining) {
        final fallback =
            rest.where((q) => !fill.any((f) => f.id == q.id)).toList()
              ..shuffle();
        fill.addAll(fallback.take(remaining - fill.length));
      }

      final fillTaken = fill.take(remaining).toList();
      selected.addAll(fillTaken);
      for (final q in fillTaken) {
        usedIds.add(q.id);
      }
    }

    selected.shuffle();
    final shuffled = selected.map((q) => q.shuffled()).toList();

    setState(() {
      _questions = shuffled;
      _selectedAnswers = List.filled(shuffled.length, -1);
      _loaded = true;
    });
  }

  void _selectAnswer(int index) {
    setState(() {
      _selectedAnswers[_currentIndex] = index;
    });
  }

  void _goNext() {
    if (_selectedAnswers[_currentIndex] == -1) return;
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submitAssessment();
    }
  }

  void _goPrevious() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _submitAssessment() async {
    final state = AppState();
    final result = ScoringEngine.processResults(
      _questions,
      _selectedAnswers,
      TestType.diagnostic,
    );

    MixpanelService.instance.track(
      'assessment_completed',
      properties: {
        'score': result.overallScore,
        'question_count': _questions.length,
        'is_unlocked': state.hasUnlockedApp,
        'app_name': 'SP',
      },
    );

    // Saving a category score here can push it straight to "mastered"
    // (>= masteryThreshold) without the user ever visiting that
    // category's CategoryStudyPage, which is the only other place
    // markCategoryStudied() gets called. Without this, a category can
    // show up in masteredCategories but never in studiedCategories —
    // visible as a MASTERED trophy with no matching CURRICULUM trophy,
    // and a permanent "go study this" nag from ReadinessEngine.coachMessage.
    for (final kvp in result.categoryScores.entries) {
      state.saveCategoryQuizScore(kvp.key, kvp.value);
      if (kvp.value >= AppState.masteryThreshold) {
        state.markCategoryStudied(kvp.key);
      }
    }

    state.testHistory.add(result);

    if (!state.earnedTrophyIds.contains('DiagnosticCompleted')) {
      state.addEarnedMilestone('DiagnosticCompleted', 'Optimized Path Chosen');
    }

    state.readinessScore = ReadinessEngine.calculate(state);
    state.readinessCoachMessage = ReadinessEngine.coachMessage(
      state,
      state.readinessScore,
    );
    state.readinessCheerMessage = ReadinessEngine.cheerleaderMessage(
      state,
      state.readinessScore,
    );

    AppStatePersistence.save();

    // Expert Club only for paid users on full 40-question assessment
    if (state.hasUnlockedApp && result.overallScore >= 95) {
      final dialogResult = await ExpertClubDialog.show(context, state.userName);
      if (!mounted) return;
      if (dialogResult == ExpertClubResult.takeExam) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FinalExamIntroPage()),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

  Widget _buildAnswerButton(int index, String text) {
    final isSelected = _selectedAnswers[_currentIndex] == index;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _selectAnswer(index),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? AppColors.selectedAnswer
              : AppColors.primaryButton,
          foregroundColor: isSelected
              ? AppColors.selectedAnswerForeground
              : Colors.white,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
            side: BorderSide(
              color: isSelected
                  ? AppColors.selectedAnswerBorder
                  : AppColors.primaryButton,
            ),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: AppFonts.body),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFE3F0F9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('No questions found.')));
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final starProgress = progress * 5;
    final hasSelected = _selectedAnswers[_currentIndex] != -1;
    final isLast = _currentIndex == _questions.length - 1;

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: AppSizes.pageMargin,
            child: Column(
              spacing: 12,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          MixpanelService.instance.track(
                            'assessment_abandoned',
                            properties: {
                              'questions_answered': _currentIndex,
                              'total_questions': _questions.length,
                              'app_name': 'SP',
                            },
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomePage()),
                          );
                        },
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

                FsmeHelpBox(
                  messages: _fsmeHelpMessages,
                  onTap: _openAssessmentExplanation,
                  enabled: AppState().fsmeEnabled,
                ),

                Text(
                  'Question ${_currentIndex + 1} of ${_questions.length}',
                  style: TextStyle(
                    fontSize: AppFonts.subheader,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bodyText,
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
                    q.questionText,
                    style: const TextStyle(
                      fontSize: AppFonts.question,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: AppColors.strongText,
                    ),
                  ),
                ),

                Column(
                  spacing: 8,
                  children: [
                    _buildAnswerButton(0, q.answer1),
                    _buildAnswerButton(1, q.answer2),
                    _buildAnswerButton(2, q.answer3),
                    _buildAnswerButton(3, q.answer4),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: _currentIndex > 0 ? _goPrevious : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.disabledButton,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 140,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: hasSelected ? _goNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.disabledButton,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: Text(isLast ? 'Submit' : 'Next'),
                      ),
                    ),
                  ],
                ),

                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '★',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black.withValues(
                                alpha: starProgress >= (i + 1) ? 1.0 : 0.2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFB0B0B0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    spacing: AppSizes.footerSpacing,
                    children: [
                      Text(
                        AppStrings.footerLine1,
                        style: TextStyle(
                          fontSize: AppFonts.footer,
                          color: AppColors.footerText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        AppStrings.footerLine2,
                        style: TextStyle(
                          fontSize: AppFonts.footer,
                          color: AppColors.footerText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        AppStrings.footerLine3,
                        style: TextStyle(
                          fontSize: AppFonts.footer,
                          color: AppColors.starMotifBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
