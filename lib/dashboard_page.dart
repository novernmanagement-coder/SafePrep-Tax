import 'package:flutter/material.dart';
import 'constants.dart';
import 'cluster_info_page.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'fsme_help_box.dart';
import 'home_page.dart';
import 'study_landing_page.dart';
import 'sixty_second_refresh_page.dart';
import 'safe_prep_nav_bar.dart';
import 'mixpanel_service.dart';
import 'onboard/onboard_paywall.dart';
import 'readiness_engine.dart'; // TODO(gerry): confirm this is the real filename/path for the ReadinessEngine class — guessed from the class name to match this project's file-naming convention.
import 'review_prompt_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AppState _state = AppState();
  bool _studyCategoriesExpanded = true;
  bool _masteredExpanded = false;
  List<FactModel> _facts = [];
  int _lastFactIndex = -1;
  String _currentFact = '';

  // Dashboard IS the dashboardStudy cluster, so its FsmeHelpBox opens
  // that cluster's explanation directly.
  static const List<String> _fsmeHelpMessages = [
    "Every category, your scores, what's mastered — it's all here.",
    "Pulsing cards mean study this next. Not broken, just insistent.",
    "Tap me — I'll 'splain what this whole thing is for.",
  ];

  void _openDashboardExplanation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClusterInfoPage(
          cluster: AppCluster.dashboardStudy,
          launchContext: ClusterLaunchContext.landing,
        ),
      ),
    );
  }

  static const List<String> categoryOrder = [
    'Time & Temperature',
    'Cross-Contamination',
    'Food Preparation',
    'Receiving & Storage',
    'Personal Hygiene',
    'Cleaning & Sanitizing',
    'Facility & Equipment',
    'Food Safety Management',
  ];

  // ── National average seed values (DISPLAY-ONLY) ─────────────────────
  // Best-guess placeholders, not sourced data — swap in real numbers
  // when available. These are never written to AppState/ReadinessEngine;
  // they exist purely so the Dashboard doesn't look empty before a user
  // has generated any real data. The moment a category has a real score
  // (hasScoreForCategory == true), its seeded value is ignored entirely.
  static const Map<String, int> _nationalAverages = {
    'Time & Temperature': 68,
    'Cross-Contamination': 74,
    'Food Preparation': 78,
    'Receiving & Storage': 76,
    'Personal Hygiene': 82,
    'Cleaning & Sanitizing': 80,
    'Facility & Equipment': 85,
    'Food Safety Management': 71,
  };

  int get _nationalAverageOverall {
    final values = _nationalAverages.values.toList();
    return values.reduce((a, b) => a + b) ~/ values.length;
  }

  @override
  void initState() {
    super.initState();
    // Gated on real purchase state — either never purchased, or a
    // sevenDay/fourteenDay purchase whose calendar expiry has passed
    // (AppState.isExpired). This replaces the old TrialTimerService-
    // based check, which stopped meaning anything once the trial
    // system was removed and is the exact same dead-check pattern
    // already found and fixed in safe_prep_nav_bar.dart's
    // _goDashboard() — kept deliberately strict here too rather than
    // just deleted, so an expired purchaser can't slip past the gate.
    final bool locked = !_state.hasUnlockedApp || _state.isExpired;
    if (locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardPaywall()),
          (route) => false,
        );
      });
      return;
    }

    // Readiness score, computed once per dashboard visit — feeds both
    // the dashboard_viewed Mixpanel properties below (moved here from
    // home_viewed, since users spend their time on the Dashboard, not
    // the Home page) and the second review-prompt trigger (90%+
    // readiness), which shares the exact same one-time-fire flag as
    // FinalExamGradePage's 85%-final-exam-score trigger — whichever
    // condition a user hits first asks; the other is skipped, since
    // ReviewPromptDialog is assumed to set hasSeenReviewPrompt itself
    // (mirrors the call pattern in FinalExamGradePage.build(), the only
    // other real call site seen so far).
    final int readiness = ReadinessEngine.calculate(_state);

    MixpanelService.instance.track(
      'dashboard_viewed',
      properties: {
        'app_name': 'SP',
        'readiness_score': readiness,
        'days_remaining': _state.daysRemaining,
      },
    );

    if (readiness >= 90 && !_state.hasSeenReviewPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ReviewPromptDialog.show(
            context,
            source: 'dashboard_readiness',
            triggerValue: readiness,
          );
        }
      });
    }

    _loadFacts();
    _startFactTimer();
  }

  Future<void> _loadFacts() async {
    final facts = await FactLoader.loadAll();
    setState(() {
      _facts = facts;
      if (facts.isNotEmpty) _currentFact = facts[0].fact;
    });
  }

  void _startFactTimer() {
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _currentFact = _nextFact());
      _startFactTimer();
    });
  }

  String _nextFact() {
    if (_facts.isEmpty) return '';
    if (_facts.length == 1) return _facts[0].fact;
    int index;
    do {
      index = DateTime.now().millisecondsSinceEpoch % _facts.length;
    } while (index == _lastFactIndex);
    _lastFactIndex = index;
    return _facts[index].fact;
  }

  Color _scoreColor(int percent) {
    if (percent <= 50) return AppColors.scoreBand1;
    if (percent <= 65) return AppColors.scoreBand2;
    if (percent <= 84) return AppColors.scoreBand3;
    return AppColors.scoreBand4;
  }

  String _formatDelta(int delta) {
    if (delta > 0) return '+$delta vs baseline';
    if (delta < 0) return '$delta vs baseline';
    return 'No change vs baseline';
  }

  // Routes through the shared navigateToStudy() helper (see
  // study_landing_page.dart) instead of pushing CategoryStudyPage
  // directly, so a user's very first-ever "Study →" tap — whether it
  // happens here or anywhere else in the app — still shows the
  // one-time FSME study-landing modal before landing in the module.
  void _goToStudy(String category) {
    navigateToStudy(context, category);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
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
                Image.asset('Assets/splash.png', width: 36, height: 36),
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
    );
  }

  Widget _buildSummaryCards() {
    final hasTestResult = _state.latestResult != null;
    final hasQuizScores = _state.categoryQuizScores.isNotEmpty;

    int latest = 0;
    String overallText = '—';
    String deltaText = 'No test taken yet';
    String baselineText = '';
    Color overallColor = const Color(0xFF555555);

    if (hasTestResult) {
      latest = _state.latestResult!.overallScore;
      final baseline = _state.baselineResult!.overallScore;
      final delta = latest - baseline;
      overallText = '$latest%';
      deltaText = _formatDelta(delta);
      baselineText = 'Baseline: $baseline%';
      overallColor = _scoreColor(latest);
    } else if (hasQuizScores) {
      final scores = _state.categoryQuizScores.values.toList();
      latest = scores.reduce((a, b) => a + b) ~/ scores.length;
      overallText = '$latest%';
      deltaText =
          'Avg of ${scores.length} ${scores.length == 1 ? 'category' : 'categories'}';
      overallColor = _scoreColor(latest);
    } else if (!_state.hasUnlockedApp) {
      // Trial mode only, no real data yet — show the seeded national
      // average so a browsing trial user doesn't see a blank dashboard.
      // Display-only: never written to AppState. Purchased users always
      // fall through to the default blank/dash state below, even right
      // after purchase — the "Thank You" modal already tells them they're
      // starting fresh, so the dashboard should actually look fresh too.
      latest = _nationalAverageOverall;
      overallText = '$latest%';
      deltaText = 'National average — not your score yet';
      baselineText = 'Adapts as you study';
      overallColor = _scoreColor(latest);
    }

    final currPct = _state.getOverallCurriculumPercent();
    final masteredCount = _state.masteredCategories.length;
    final totalCount = AppState.allCategories.length;
    final studiedCount = _state.studiedCategories.length;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF4DA3FF), width: 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  const Text(
                    'OVERALL SCORE PROGRESS',
                    style: TextStyle(
                      color: Color(0xFF4DA3FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    overallText,
                    style: TextStyle(
                      color: overallColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    deltaText,
                    style: const TextStyle(
                      color: Color(0xFF4DA3FF),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    baselineText,
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF4DA3FF), width: 4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  const Text(
                    'CURRICULUM PROGRESS',
                    style: TextStyle(
                      color: Color(0xFF4DA3FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$currPct%',
                    style: TextStyle(
                      color: currPct == 100
                          ? AppColors.scoreBand4
                          : const Color(0xFF4DA3FF),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$masteredCount of $totalCount categories',
                    style: const TextStyle(
                      color: Color(0xFF4DA3FF),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    '$studiedCount studied',
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String category,
    int score,
    int baseline,
    bool hasTaken,
    bool pulseFast,
    bool pulseSlow,
  ) {
    return AnimatedOpacity(
      opacity: (pulseFast || pulseSlow) ? 0.7 : 1.0,
      duration: Duration(milliseconds: pulseFast ? 600 : 1100),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF4DA3FF), width: 4),
          boxShadow: (pulseFast || pulseSlow)
              ? [
                  BoxShadow(
                    color: const Color(0xFF4DA3FF).withValues(alpha: 0.5),
                    blurRadius: pulseFast ? 18 : 14,
                    spreadRadius: pulseFast ? 4 : 3,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              category.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF4DA3FF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              hasTaken
                  ? '$score%'
                  : (_state.hasUnlockedApp
                        ? '—'
                        : '${_nationalAverages[category] ?? 75}%'),
              style: TextStyle(
                color: hasTaken ? _scoreColor(score) : const Color(0xFF6B7A8A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              hasTaken
                  ? 'Baseline: $baseline%'
                  : (_state.hasUnlockedApp
                        ? 'Not yet tested'
                        : 'National avg — adapts as you study'),
              style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 10),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton(
                onPressed: () => _goToStudy(category),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4DA3FF),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Study →',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyGrid() {
    final mastered = _state.masteredCategories;
    final studyCategories = categoryOrder
        .where((c) => !mastered.contains(c))
        .toList();

    final failingCategories =
        studyCategories
            .where(
              (c) =>
                  _state.hasScoreForCategory(c) &&
                  _state.getCategoryScore(c) < AppState.masteryThreshold,
            )
            .toList()
          ..sort(
            (a, b) => _state
                .getCategoryScore(a)
                .compareTo(_state.getCategoryScore(b)),
          );

    final untestedCategories = studyCategories
        .where((c) => !_state.hasScoreForCategory(c))
        .toList();

    List<String> pulseCategories;
    if (failingCategories.length >= 2) {
      pulseCategories = failingCategories.take(2).toList();
    } else if (failingCategories.length == 1) {
      pulseCategories = [failingCategories[0]];
      if (untestedCategories.isNotEmpty) {
        pulseCategories.add(untestedCategories[0]);
      }
    } else {
      pulseCategories = untestedCategories.take(2).toList();
    }

    final needsFlipCard = studyCategories.length % 2 != 0;
    final rows = <Widget>[];

    for (int i = 0; i < studyCategories.length; i += 2) {
      final cat1 = studyCategories[i];
      final cat2 = i + 1 < studyCategories.length
          ? studyCategories[i + 1]
          : null;

      rows.add(
        Row(
          children: [
            Expanded(
              child: _buildCategoryCard(
                cat1,
                _state.getCategoryScore(cat1),
                _state.getBaselineScore(cat1),
                _state.hasScoreForCategory(cat1),
                pulseCategories.isNotEmpty && pulseCategories[0] == cat1,
                pulseCategories.length > 1 && pulseCategories[1] == cat1,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: cat2 != null
                  ? _buildCategoryCard(
                      cat2,
                      _state.getCategoryScore(cat2),
                      _state.getBaselineScore(cat2),
                      _state.hasScoreForCategory(cat2),
                      pulseCategories.isNotEmpty && pulseCategories[0] == cat2,
                      pulseCategories.length > 1 && pulseCategories[1] == cat2,
                    )
                  : needsFlipCard
                  ? _buildFactCard()
                  : const SizedBox(),
            ),
          ],
        ),
      );

      if (i + 2 < studyCategories.length) rows.add(const SizedBox(height: 12));
    }

    return Column(children: rows);
  }

  Widget _buildFactCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F33),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4DA3FF), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          const Text(
            'DID YOU KNOW?',
            style: TextStyle(
              color: Color(0xFF4DA3FF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _currentFact,
              key: ValueKey(_currentFact),
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteredSection() {
    final mastered = _state.masteredCategories;
    if (mastered.isEmpty) return const SizedBox();

    return Column(
      children: [
        const Divider(color: Color(0xFF2C2C2C)),
        GestureDetector(
          onTap: () => setState(() => _masteredExpanded = !_masteredExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mastered',
                    style: TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _masteredExpanded ? '▼' : '▶',
                  style: const TextStyle(
                    color: Color(0xFF4DA3FF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_masteredExpanded) ...[
          const SizedBox(height: 12),
          const Text(
            'Categories scoring 85% or above.',
            style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...List.generate((mastered.length / 2).ceil(), (rowIndex) {
            final i = rowIndex * 2;
            final cat1 = mastered[i];
            final cat2 = i + 1 < mastered.length ? mastered[i + 1] : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: _buildMasteredCard(cat1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: cat2 != null
                        ? _buildMasteredCard(cat2)
                        : const SizedBox(),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMasteredCard(String category) {
    final score = _state.getCategoryScore(category);
    final baseline = _state.getBaselineScore(category);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2C4A6A), width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF4DA3FF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              color: AppColors.scoreBand4,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Baseline: $baseline%',
            style: const TextStyle(color: Color(0xFF555555), fontSize: 10),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: () => _goToStudy(category),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C4A6A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Study →',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = _state.userName;
    final dashTitle = userName.isNotEmpty
        ? 'SafePrep™ $userName\'s Dashboard'
        : 'SafePrep™ Dashboard';

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    _buildHeader(),
                    FsmeHelpBox(
                      messages: _fsmeHelpMessages,
                      onTap: _openDashboardExplanation,
                      enabled: _state.fsmeEnabled,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        spacing: 16,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(
                                dashTitle,
                                style: const TextStyle(
                                  color: Color(0xFFE0E0E0),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Divider(color: Color(0xFF2C2C2C)),
                            ],
                          ),
                          _buildSummaryCards(),
                          const Divider(color: Color(0xFF2C2C2C)),
                          Column(
                            spacing: 0,
                            children: [
                              GestureDetector(
                                onTap: () => setState(
                                  () => _studyCategoriesExpanded =
                                      !_studyCategoriesExpanded,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Study Categories',
                                          style: TextStyle(
                                            color: Color(0xFFE0E0E0),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _studyCategoriesExpanded ? '▼' : '▶',
                                        style: const TextStyle(
                                          color: Color(0xFF4DA3FF),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_studyCategoriesExpanded) ...[
                                const SizedBox(height: 12),
                                _buildStudyGrid(),
                              ],
                            ],
                          ),
                          _buildMasteredSection(),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SixtySecondRefreshPage(
                              returnTo: SixtySecondReturnTo.dashboard,
                            ),
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
                        child: const Text('⏱ 60-Second Refresh'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SafePrepNavBar(isDashboardPage: true),
          ],
        ),
      ),
    );
  }
}
