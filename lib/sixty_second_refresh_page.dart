import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'readiness_engine.dart';
import 'safe_prep_nav_bar.dart';
import 'mixpanel_service.dart';

enum SixtySecondReturnTo { homePage, dashboard }

class SixtySecondRefreshPage extends StatefulWidget {
  final SixtySecondReturnTo returnTo;

  const SixtySecondRefreshPage({
    super.key,
    this.returnTo = SixtySecondReturnTo.homePage,
  });

  @override
  State<SixtySecondRefreshPage> createState() => _SixtySecondRefreshPageState();
}

class _SixtySecondRefreshPageState extends State<SixtySecondRefreshPage> {
  final AppState _state = AppState();

  static const int questionMs = 3000;
  static const int answerMs = 2000;
  static const int categoryBursts = 5;

  static const Map<String, Color> categoryColors = {
    'Time & Temperature': Color(0xFFC0392B),
    'Cross-Contamination': Color(0xFFE67E22),
    'Food Preparation': Color(0xFF27AE60),
    'Receiving & Storage': Color(0xFF2980B9),
    'Personal Hygiene': Color(0xFF8E44AD),
    'Cleaning & Sanitizing': Color(0xFF16A085),
    'Facility & Equipment': Color(0xFF34495E),
    'Food Safety Management': Color(0xFFB7950B),
  };

  bool _isStopped = false;
  bool _showingBurst = false;
  String _currentCategory = '';
  String _questionText = '';
  String _answerText = '';
  String _progressText = '';
  double _timerProgress = 0.0;
  bool _showAnswer = false;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track('sixty_second_viewed');
    _awardExtraCredit();
  }

  void _awardExtraCredit() {
    final state = AppState();
    state.extraCreditPoints =
        (state.extraCreditPoints +
                ReadinessEngine.extraCreditForAction(
                  ExtraCreditAction.sixtySecond,
                ))
            .clamp(0.0, 10.0);
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
  }

  void _navigateBack() {
    setState(() => _isStopped = true);
    if (widget.returnTo == SixtySecondReturnTo.dashboard) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  Future<void> _startCategoryBursts(String category) async {
    MixpanelService.instance.track(
      'sixty_second_category_selected',
      properties: {'category': category},
    );
    setState(() {
      _isStopped = false;
      _showingBurst = true;
      _currentCategory = category;
    });
    final all = await QuestionLoader.loadByCategory(category);
    final questions =
        (all..sort((a, b) => b.difficulty.compareTo(a.difficulty)))
            .take(categoryBursts)
            .toList();
    if (questions.isEmpty) {
      setState(() => _showingBurst = false);
      return;
    }
    await _runBursts(questions, categoryBursts);
    if (!_isStopped && mounted) setState(() => _showingBurst = false);
  }

  Future<void> _runBursts(List<QuestionModel> questions, int count) async {
    for (int i = 0; i < count && !_isStopped && mounted; i++) {
      final q = questions[i % questions.length];
      final answers = [q.answer1, q.answer2, q.answer3, q.answer4];
      final correctText = answers[q.correctAnswer];

      setState(() {
        _progressText = '${i + 1} of $count';
        _questionText = q.questionText;
        _answerText = correctText;
        _showAnswer = false;
        _timerProgress = 0.0;
        _animating = true;
      });

      await _animateTimer(questionMs);
      if (_isStopped || !mounted) return;
      setState(() => _showAnswer = true);
      await _animateTimer(answerMs);
      if (_isStopped || !mounted) return;
      setState(() => _animating = false);
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _animateTimer(int totalMs) async {
    final steps = totalMs ~/ 50;
    for (int s = 0; s <= steps; s++) {
      if (_isStopped || !mounted) return;
      setState(() => _timerProgress = s / steps);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Widget _buildCategoryGrid() {
    final categories = AppState.allCategories;
    final hasMissed = _state.missedFinalExamQuestionIds.isNotEmpty;
    final rows = <Widget>[];

    for (int i = 0; i < categories.length; i += 2) {
      final cat1 = categories[i];
      final cat2 = i + 1 < categories.length ? categories[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(child: _buildCatButton(cat1)),
            const SizedBox(width: 10),
            Expanded(
              child: cat2 != null ? _buildCatButton(cat2) : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < categories.length) rows.add(const SizedBox(height: 10));
    }

    return Column(
      children: [
        ...rows,
        if (hasMissed) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _startFinalReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '📋 Final Test Review',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _startFinalReview() async {
    final missedIds = _state.missedFinalExamQuestionIds;
    if (missedIds.isEmpty) return;
    MixpanelService.instance.track(
      'sixty_second_final_review_started',
      properties: {'missed_question_count': missedIds.length},
    );
    setState(() {
      _isStopped = false;
      _showingBurst = true;
      _currentCategory = 'Final Test Review';
    });
    final all = await QuestionLoader.loadAll();
    final missed = all.where((q) => missedIds.contains(q.id)).toList()
      ..shuffle();
    final questions = missed.take(20).toList();
    if (questions.isEmpty) {
      setState(() => _showingBurst = false);
      return;
    }
    await _runBursts(questions, questions.length);
    if (!_isStopped && mounted) setState(() => _showingBurst = false);
  }

  Widget _buildCatButton(String category) {
    final color = categoryColors[category] ?? AppColors.primaryButton;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: () => _startCategoryBursts(category),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          category,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBurstPlayer() {
    final catColor =
        categoryColors[_currentCategory] ?? AppColors.primaryButton;
    return Column(
      spacing: 12,
      children: [
        Text(
          _progressText,
          style: TextStyle(fontSize: 13, color: AppColors.subtleText),
          textAlign: TextAlign.center,
        ),
        AnimatedOpacity(
          opacity: _animating ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: catColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _questionText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _showAnswer ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3BA776),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _answerText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _timerProgress,
              child: Container(
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _isStopped = true;
            _showingBurst = false;
          }),
          child: Text(
            '← Back to categories',
            style: TextStyle(fontSize: 13, color: AppColors.primaryButton),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Column(
                spacing: 4,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _navigateBack,
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
                  Text(
                    '60-Second Refresh',
                    style: TextStyle(
                      fontSize: AppFonts.header,
                      fontWeight: FontWeight.bold,
                      color: AppColors.strongText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _showingBurst
                        ? _currentCategory
                        : 'Select a category to begin',
                    style: TextStyle(fontSize: 13, color: AppColors.subtleText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _showingBurst
                    ? _buildBurstPlayer()
                    : _buildCategoryGrid(),
              ),
            ),
            const SafePrepNavBar(),
          ],
        ),
      ),
    );
  }
}
