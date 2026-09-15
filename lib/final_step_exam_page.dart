import 'package:flutter/material.dart';
import 'constants.dart';
import 'cluster_info_page.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'fsme_help_box.dart';
import 'home_page.dart';
import 'final_exam_grade_page.dart';
import 'final_exam_review_page.dart';
import 'safe_prep_nav_bar.dart';

class FinalStepExamPage extends StatefulWidget {
  const FinalStepExamPage({super.key});

  @override
  State<FinalStepExamPage> createState() => _FinalStepExamPageState();
}

class _FinalStepExamPageState extends State<FinalStepExamPage> {
  final AppState _state = AppState();
  List<QuestionModel> _questions = [];
  List<int> _selectedAnswers = [];
  int _currentIndex = 0;
  bool _loaded = false;

  // This page IS the finalExam cluster, so its FsmeHelpBox opens that
  // cluster's explanation directly.
  static const List<String> _fsmeHelpMessages = [
    "90 questions, scored exactly like the real ServSafe exam.",
    "Whatever you get, results feed back into your curriculum.",
    "Tap me — I'll 'splain what this whole thing is for.",
  ];

  void _openFinalExamExplanation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClusterInfoPage(
          cluster: AppCluster.finalExam,
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

  static const int totalQuestions = 90;
  static const double hardWeight = 0.40;
  static const double mediumWeight = 0.40;

  // The Final Exam is the true readiness checkpoint — matches the
  // real ServSafe exam pass mark, same 75% used by the category-quiz
  // fail-streak safety net elsewhere (see category_quiz_results_page
  // .dart's _failThreshold). Not an arbitrary number.
  static const int _passThreshold = 75;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final all = await QuestionLoader.loadAll(shuffle: false);
    final selected = <QuestionModel>[];
    final usedIds = <String>{};

    final categoryCounts = <String, int>{};
    int allocated = 0;

    for (final cat in categoryWeights.keys) {
      final count = ((categoryWeights[cat]! * totalQuestions).round()).clamp(
        1,
        totalQuestions,
      );
      categoryCounts[cat] = count;
      allocated += count;
    }

    while (allocated < totalQuestions) {
      categoryCounts['Time & Temperature'] =
          categoryCounts['Time & Temperature']! + 1;
      allocated++;
    }
    while (allocated > totalQuestions) {
      categoryCounts['Time & Temperature'] =
          categoryCounts['Time & Temperature']! - 1;
      allocated--;
    }

    for (final cat in categoryWeights.keys) {
      final needed = categoryCounts[cat]!;
      final pool = all
          .where(
            (q) =>
                (q.category.toLowerCase() == cat.toLowerCase() ||
                    (cat == 'Food Safety Management' &&
                        q.category.toLowerCase() == 'pest management')) &&
                !usedIds.contains(q.id),
          )
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
      final hardCount = (remaining * hardWeight).round();
      final mediumCount = (remaining * mediumWeight).round();
      final easyCount = remaining - hardCount - mediumCount;

      final hard = rest.where((q) => q.difficulty == 3).toList()..shuffle();
      final medium = rest.where((q) => q.difficulty == 2).toList()..shuffle();
      final easy = rest.where((q) => q.difficulty == 1).toList()..shuffle();

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

  void _selectAnswer(int index) =>
      setState(() => _selectedAnswers[_currentIndex] = index);

  void _goNext() {
    if (_selectedAnswers[_currentIndex] == -1) return;
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submitExam();
    }
  }

  void _goPrevious() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _submitExam() {
    final result = ScoringEngine.processResults(
      _questions,
      _selectedAnswers,
      TestType.finalExam,
    );

    final passed = result.overallScore >= _passThreshold;

    if (passed) {
      // Unchanged from before — real exam performance, saved and
      // credited exactly as it's earned.
      for (final entry in result.categoryScores.entries) {
        _state.saveCategoryQuizScore(entry.key, entry.value);
        if (entry.value >= AppState.masteryThreshold) {
          _state.markCategoryStudied(entry.key);
        }
      }
    } else {
      // FAIL — full reset. The Final Exam is the one true readiness
      // checkpoint: failing it means whatever state got the user here
      // (assessment shortcuts, stale mastery, guessed answers) can't
      // be trusted. Treated the same as the assessment's own scoring
      // loop, category by category — a category that STILL hits
      // mastery on the exam itself earns real credit (score + marked
      // studied); every other category drops to a genuine 0%, not
      // just "needs review," and loses its studied flag so it reads
      // as un-started, not partially done.
      //
      // categoryBaselineScores is deliberately left untouched — see
      // AppState — so the user keeps a record of where they started,
      // a standing reminder that shortcuts don't work.
      for (final entry in result.categoryScores.entries) {
        if (entry.value >= AppState.masteryThreshold) {
          _state.saveCategoryQuizScore(entry.key, entry.value);
          _state.markCategoryStudied(entry.key);
        } else {
          _state.saveCategoryQuizScore(entry.key, 0);
          _state.studiedCategories.remove(entry.key);
        }
      }

      // Whole-app wipe, not scoped to only the categories that scored
      // low on THIS exam — a failed Final Exam invalidates the
      // mode-override/fail-streak/question-mastery signal everywhere,
      // not only where the exam happened to catch it.
      _state.categoryModeOverride.clear();
      _state.categoryQuizFailStreak.clear();
      _state.categoryQuizAttempts.clear();
      _state.clearAllQuestionMastery();
    }

    final missedIds = <String>[];
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] != _questions[i].correctAnswer) {
        missedIds.add(_questions[i].id);
      }
    }

    _state.missedFinalExamQuestionIds = missedIds;
    _state.testHistory.add(result);

    // BUG FIX: finalExamScore was declared on AppState and read by
    // ReadinessEngine.calculate() (score >= 85 => readiness forced to
    // 100) and by FinalExamGradePage's review-prompt check, but nothing
    // in this file ever actually SET it — so that override never fired
    // for anyone, no matter how well they scored on the Final Exam.
    _state.finalExamScore = result.overallScore;

    // Acing the Final Exam (90%+) is treated as full mastery across
    // every category — all trophies awarded — even if the user jumped
    // straight to the Final Exam without ever touching individual
    // category quizzes. Deliberately NOT touching studiedCategories/
    // curriculumProgress here directly: per Gerry, acing the exam proves
    // mastery, it doesn't mean they walked through the curriculum. Note
    // this still lights up the matching CURRICULUM trophies too, the
    // same way the diagnostic Assessment path already does — via
    // AppState.reconcileMasteredStudied() running on next state load,
    // which marks every mastered category as studied so there's never a
    // mismatched Mastered-without-Curriculum trophy or a stale "go
    // study this" coach nag. Confirmed intentional/kept as-is per Gerry.
    if (result.overallScore >= 90) {
      for (final category in AppState.allCategories) {
        _state.saveCategoryQuizScore(category, 100);
      }
    }

    AppStatePersistence.save();

    if (missedIds.isNotEmpty) {
      final missedQuestions = _questions
          .where((q) => missedIds.contains(q.id))
          .toList();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FinalExamReviewPage(
            missedQuestions: missedQuestions,
            result: result,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FinalExamGradePage(result: result)),
      );
    }
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
    final hasSelected = _selectedAnswers[_currentIndex] != -1;
    final isLast = _currentIndex == _questions.length - 1;

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

                    FsmeHelpBox(
                      messages: _fsmeHelpMessages,
                      onTap: _openFinalExamExplanation,
                      enabled: _state.fsmeEnabled,
                    ),

                    Text(
                      'SafePrep™ Final Exam',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Question ${_currentIndex + 1} of ${_questions.length}',
                      style: TextStyle(
                        fontSize: AppFonts.subheader,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
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
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: AppSizes.primaryButtonHeight,
                            child: ElevatedButton(
                              onPressed: _currentIndex > 0 ? _goPrevious : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryButton,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.disabledButton,
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
                              onPressed: hasSelected ? _goNext : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryButton,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.disabledButton,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.buttonCornerRadius,
                                  ),
                                ),
                              ),
                              child: Text(isLast ? 'Finish' : 'Next'),
                            ),
                          ),
                        ),
                      ],
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
