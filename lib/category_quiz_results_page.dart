import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'category_study_page.dart';
import 'category_quiz_page.dart';
import 'readiness_engine.dart';
import 'recomputing_modal.dart';
import 'floating_reaction.dart';
import 'safe_prep_nav_bar.dart';

class CategoryQuizResultsPage extends StatefulWidget {
  final String category;
  final int correctCount;
  final int totalCount;

  // Which feedback mode the just-finished quiz actually ran in —
  // needed to know which tier of the fail-streak safety net applies.
  final bool wasRetroMode;

  const CategoryQuizResultsPage({
    super.key,
    required this.category,
    required this.correctCount,
    required this.totalCount,
    required this.wasRetroMode,
  });

  @override
  State<CategoryQuizResultsPage> createState() =>
      _CategoryQuizResultsPageState();
}

class _CategoryQuizResultsPageState extends State<CategoryQuizResultsPage> {
  final AppState _state = AppState();
  String _tickerFacts = '';

  // Fail-streak safety net threshold — kept as named constants rather
  // than inline magic numbers, matching kPassMark's real-exam-derived
  // reasoning (see safeprep-manager.md): 75% mirrors the actual
  // ServSafe pass mark, and 3-in-a-row (not 2) gives genuine
  // improvement enough runway to clear it on its own before the
  // switch fires.
  static const int _failThreshold = 75;
  static const int _streakToTrigger = 3;

  // Computed once in _saveScoreAndCheckStreak(), fired only after
  // RecomputingModal has fully closed — its dark barrier would hide
  // the reaction entirely if shown underneath it. Null means neither
  // Mastered nor Improved fired (flat or declined score) — silence
  // is the correct, deliberate visual for that outcome.
  ReactionType? _reaction;

  @override
  void initState() {
    super.initState();
    _loadFacts();
    final tierSwitch = _saveScoreAndCheckStreak();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await RecomputingModal.show(
        context,
        category: widget.category,
        readinessScore: _state.readinessScore,
        tierSwitch: tierSwitch,
      );
      if (!mounted) return;
      if (_reaction != null) {
        FloatingReaction.show(context, type: _reaction!);
      }
    });
  }

  Future<void> _loadFacts() async {
    var facts = await FactLoader.loadByCategory(widget.category);
    if (facts.isEmpty) facts = await FactLoader.loadAll();
    setState(() {
      _tickerFacts = facts.map((f) => f.fact).join('  •  ');
    });
  }

  /// Saves the score (unchanged behavior), then runs the fail-streak
  /// check and applies a tier switch to AppState immediately if
  /// warranted — per the resolved architecture, the SYSTEM applies
  /// the switch here; RecomputingModal's job is only to surface and
  /// let the user revert it, never to decide or apply it itself.
  /// Returns non-null only when a switch was just triggered, so the
  /// modal knows to show the advocate check-in instead of the normal
  /// auto-dismiss sequence.
  TierSwitchInfo? _saveScoreAndCheckStreak() {
    final category = widget.category;

    // Captured BEFORE saving this attempt's score — needed for BOTH
    // the mastery-crossing check below AND the Improved reaction
    // (any positive delta vs. this exact prior value, per design
    // discussion — no minimum improvement threshold).
    final hadScore = _state.hasScoreForCategory(category);
    final previousScore = hadScore ? _state.getCategoryScore(category) : null;
    final wasMastered = hadScore && previousScore! >= AppState.masteryThreshold;

    final percent = widget.totalCount == 0
        ? 0
        : (widget.correctCount * 100) ~/ widget.totalCount;
    _state.saveCategoryQuizScore(category, percent);
    _state.incrementCategoryQuizAttempts(category);

    // Reaction detection — Mastered beats Improved (a newly-mastered
    // category is by definition also an improvement, but only gets
    // the bigger badge, never both). A first-ever attempt (no
    // previousScore to compare against) or a flat/declined score
    // triggers neither — silence, by design, not a discouraging badge.
    final newlyMastered = !wasMastered && percent >= AppState.masteryThreshold;
    if (newlyMastered) {
      _reaction = ReactionType.mastered;
    } else if (previousScore != null && percent > previousScore) {
      _reaction = ReactionType.improved;
    } else {
      _reaction = null;
    }

    // Question-level mastery reset: the moment a category NEWLY
    // reaches Mastered, its per-question mastery/streak data is
    // wiped — the full pool goes live again for whenever the user
    // chooses to study/quiz it further. See
    // AppState.clearQuestionMasteryForCategory for the other trigger
    // (deliberate re-entry into an already-mastered category, in
    // study_landing_page.dart's navigateToStudy()).
    if (newlyMastered) {
      _state.clearQuestionMasteryForCategory(category);
    }

    _state.readinessScore = ReadinessEngine.calculate(_state);
    _state.readinessCoachMessage = ReadinessEngine.coachMessage(
      _state,
      _state.readinessScore,
    );
    _state.readinessCheerMessage = ReadinessEngine.cheerleaderMessage(
      _state,
      _state.readinessScore,
    );

    TierSwitchInfo? tierSwitch;

    if (percent < _failThreshold) {
      final streak = (_state.categoryQuizFailStreak[category] ?? 0) + 1;
      _state.categoryQuizFailStreak[category] = streak;

      if (streak >= _streakToTrigger) {
        final currentOverride = _state.categoryModeOverride[category];

        if (widget.wasRetroMode && currentOverride == null) {
          // Tier 1: Retro, no override yet -> Proper.
          _state.categoryModeOverride[category] = 'proper';
          _state.categoryQuizFailStreak[category] = 0;
          tierSwitch = TierSwitchInfo(
            category: category,
            fromModeLabel: 'Quiz Retro',
            toModeLabel: 'Quiz Proper',
            tier: 1,
          );
        } else if (!widget.wasRetroMode && currentOverride != 'fullStudy') {
          // Tier 2: Proper (whether default or already-overridden),
          // not yet escalated to Full Study -> Full Study.
          _state.categoryModeOverride[category] = 'fullStudy';
          _state.categoryQuizFailStreak[category] = 0;
          tierSwitch = TierSwitchInfo(
            category: category,
            fromModeLabel: 'Quiz Proper',
            toModeLabel: 'Full Study',
            tier: 2,
          );
        }
        // If already at 'fullStudy', there's no further tier — do
        // nothing, just let the streak keep counting (harmless; Full
        // Study has no quiz-mode escalation path beyond itself).
      }
    } else {
      _state.categoryQuizFailStreak[category] = 0;
    }

    AppStatePersistence.save();
    return tierSwitch;
  }

  Color _scoreColor(int percent) {
    if (percent <= 50) return AppColors.scoreBand1;
    if (percent <= 65) return AppColors.scoreBand2;
    if (percent <= 84) return AppColors.scoreBand3;
    return AppColors.scoreBand4;
  }

  String _scoreMessage(int percent) {
    if (percent == 100) return 'Perfect. You know this category cold.';
    if (percent >= 80) return 'Strong work. You\'re close to mastering this.';
    if (percent >= 60) {
      return 'Good foundation. A little more review will lock it in.';
    }
    return 'This one needs more work — and that\'s okay. Study it again.';
  }

  @override
  Widget build(BuildContext context) {
    final percent = widget.totalCount == 0
        ? 0
        : (widget.correctCount * 100) ~/ widget.totalCount;
    final scoreColor = _scoreColor(percent);

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
                      widget.category,
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (_tickerFacts.isNotEmpty)
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0E8),
                          border: Border.all(color: const Color(0xFFC8B89A)),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Marquee(text: _tickerFacts),
                        ),
                      ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        spacing: 8,
                        children: [
                          Text(
                            '${widget.correctCount}/${widget.totalCount}',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.subtleText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _scoreMessage(percent),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.bodyText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryStudyPage(category: widget.category),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text('Study this category again'),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryQuizPage(category: widget.category),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text('Retake Quiz'),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DashboardPage(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text('Back to Dashboard'),
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
