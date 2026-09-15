import 'package:flutter/material.dart';
import '../constants.dart';
import '../csv_loader.dart';
import '../app_state.dart';
import '../app_state_persistence.dart';
import 'computing_curriculum_page.dart';

class PreviewAssessmentPage extends StatefulWidget {
  const PreviewAssessmentPage({super.key});

  @override
  State<PreviewAssessmentPage> createState() => _PreviewAssessmentPageState();
}

class _PreviewAssessmentPageState extends State<PreviewAssessmentPage> {
  List<QuestionModel> _questions = [];
  List<int> _selectedAnswers = [];
  int _currentIndex = 0;
  bool _loaded = false;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _cardBorder = Color(0x33D4AF37);

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
  }

  Future<void> _loadQuestions() async {
    final all = await QuestionLoader.loadAll(shuffle: false);
    final selected = <QuestionModel>[];
    final usedIds = <String>{};
    const target = AppConstants.diagnosticQuestions;

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

    for (final kvp in result.categoryScores.entries) {
      state.saveCategoryQuizScore(kvp.key, kvp.value);
    }

    state.testHistory.add(result);
    AppStatePersistence.save();

    final answered = _selectedAnswers.where((a) => a != -1).length;

    final coveredCategories = <String>{};
    final answeredPerCategory = <String, int>{};
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] != -1) {
        final cat = _questions[i].category;
        coveredCategories.add(cat);
        answeredPerCategory[cat] = (answeredPerCategory[cat] ?? 0) + 1;
      }
    }

    if (!mounted) return;
    await ComputingCurriculumPage.show(
      context,
      questionsAnswered: answered,
      coveredCategories: coveredCategories.toList(),
      answeredPerCategory: answeredPerCategory,
    );
  }

  String get _escapeButtonLabel {
    final answered = _selectedAnswers.where((a) => a != -1).length;
    return answered >= AppState.minAnswersForRawScores
        ? 'See my results \u2192'
        : 'See my estimated results \u2192';
  }

  Widget _buildAnswerButton(int index, String text) {
    final isSelected = _selectedAnswers[_currentIndex] == index;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _selectAnswer(index),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? _gold.withValues(alpha: 0.35)
              : _gold.withValues(alpha: 0.25),
          side: BorderSide(
            color: isSelected ? _gold : _gold.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 0.5,
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppFonts.body,
            color: isSelected ? _gold : _softWhite,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w300,
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(
          child: Text(
            'No questions found.',
            style: TextStyle(color: Color(0xFFF0EDE8)),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final starProgress = progress * 5;
    final hasSelected = _selectedAnswers[_currentIndex] != -1;
    final isLast = _currentIndex == _questions.length - 1;

    return Scaffold(
      backgroundColor: _darkBg,
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
                      Text(
                        'Safe',
                        style: TextStyle(
                          fontSize: AppFonts.header,
                          fontWeight: FontWeight.w600,
                          color: _gold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Image.asset('Assets/splash.png', width: 36, height: 36),
                      const SizedBox(width: 6),
                      Text(
                        'Prep™',
                        style: TextStyle(
                          fontSize: AppFonts.header,
                          fontWeight: FontWeight.w600,
                          color: _gold,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  'Question ${_currentIndex + 1} of ${_questions.length}',
                  style: TextStyle(
                    fontSize: AppFonts.subheader,
                    fontWeight: FontWeight.w600,
                    color: _softWhite,
                  ),
                ),

                Container(
                  width: double.infinity,
                  padding: AppSizes.cardPadding,
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(
                      AppSizes.cardCornerRadius,
                    ),
                    border: Border.all(color: _cardBorder, width: 0.5),
                  ),
                  child: Text(
                    q.questionText,
                    style: const TextStyle(
                      fontSize: AppFonts.question,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: _softWhite,
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
                      child: OutlinedButton(
                        onPressed: _currentIndex > 0 ? _goPrevious : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _currentIndex > 0
                                ? _gold
                                : _gold.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          backgroundColor: _gold.withValues(alpha: 0.25),
                          foregroundColor: _gold,
                          disabledForegroundColor: _gold.withValues(alpha: 0.3),
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
                      child: OutlinedButton(
                        onPressed: hasSelected ? _goNext : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: hasSelected
                                ? _gold
                                : _gold.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          backgroundColor: hasSelected
                              ? _gold.withValues(alpha: 0.35)
                              : _gold.withValues(alpha: 0.25),
                          foregroundColor: _gold,
                          disabledForegroundColor: _gold.withValues(alpha: 0.3),
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

                SizedBox(
                  width: double.infinity,
                  height: AppSizes.primaryButtonHeight,
                  child: TextButton(
                    onPressed: _submitAssessment,
                    style: TextButton.styleFrom(
                      foregroundColor: _gold.withValues(alpha: 0.6),
                    ),
                    child: Text(
                      _escapeButtonLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final lit = starProgress >= (i + 1);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '★',
                            style: TextStyle(
                              fontSize: 20,
                              color: lit ? _gold : _gold.withValues(alpha: 0.2),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.7),
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
                          color: _softWhite.withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        AppStrings.footerLine2,
                        style: TextStyle(
                          fontSize: AppFonts.footer,
                          color: _softWhite.withValues(alpha: 0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        AppStrings.footerLine3,
                        style: TextStyle(
                          fontSize: AppFonts.footer,
                          color: _gold.withValues(alpha: 0.6),
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
