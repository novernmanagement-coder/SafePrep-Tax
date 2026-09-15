import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'dashboard_page.dart';
import 'assessment_info_page.dart';
import 'category_quiz_page.dart';
import 'mixpanel_service.dart';
import 'safe_prep_nav_bar.dart';
import 'onboard/onboard_answers.dart'; // OnboardingAnswers, StudyStyle

class CategoryStudyPage extends StatefulWidget {
  final String category;

  const CategoryStudyPage({super.key, required this.category});

  @override
  State<CategoryStudyPage> createState() => _CategoryStudyPageState();
}

class _CategoryStudyPageState extends State<CategoryStudyPage> {
  final AppState _state = AppState();
  List<CurriculumModel> _queue = [];
  int _currentIndex = 0;
  bool _loaded = false;
  String _mode = 'Standard';

  static const String _assessmentPromptKey = 'has_seen_assessment_prompt';

  // ── Toggle state ────────────────────────────────────────────────
  // Key Points visibility, initialized from the onboarding answer
  // (only answersOnly starts hidden — see the rule banked this
  // session: style 2/answersOnly never sees supplementary explanation
  // content by default), then freely switchable via the toggle row,
  // same "never locked to the initial choice" pattern as every other
  // toggle built tonight.
  late bool _showKeyPoints;

  @override
  void initState() {
    super.initState();
    _showKeyPoints =
        OnboardingAnswers.instance.studyStyle != StudyStyle.answersOnly;
    _loadCurriculum();
  }

  String _determineMode() {
    if (!_state.hasScoreForCategory(widget.category)) return 'Standard';
    final score = _state.getCategoryScore(widget.category);
    if (score < 50) return 'Recovery';
    if (score < 85) return 'Assessment';
    return 'Standard';
  }

  Future<void> _loadCurriculum() async {
    _mode = _determineMode();
    final all = await CurriculumLoader.loadByCategory(widget.category, _mode);
    setState(() {
      _queue = all;
      _loaded = true;
      // Toggle-session cache: resume wherever the user left off if
      // they just came back from Quiz Mode (or from this same page,
      // toggling back), instead of always restarting at card 1. See
      // AppState.studySessionIndex.
      final savedIndex = _state.studySessionIndex[widget.category] ?? 0;
      _currentIndex = savedIndex < _queue.length ? savedIndex : 0;
    });
    MixpanelService.instance.track(
      'study_started',
      properties: {
        'category': widget.category,
        'mode': _mode,
        'card_count': _queue.length,
      },
    );
  }

  List<String> _buildKeyPoints(CurriculumModel content) {
    if (content.keyPoints.isNotEmpty) {
      return content.keyPoints
          .split('|')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
    return content.content
        .split('.')
        .map((s) => s.trim())
        .where((s) => s.length > 8)
        .take(5)
        .map((s) => '$s.')
        .toList();
  }

  /// Shows the assessment recommendation dialog once, then navigates
  /// to [destination]. If they've already seen it, navigates directly.
  Future<void> _navigateWithPrompt(Widget destination) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_assessmentPromptKey) ?? false;

    if (!mounted) return;

    if (!hasSeen) {
      await prefs.setBool(_assessmentPromptKey, true);

      MixpanelService.instance.track(
        'assessment_prompt_shown',
        properties: {'app_name': 'SP', 'from_category': widget.category},
      );

      final takeAssessment = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assessment_outlined,
                  size: 32,
                  color: AppColors.primaryButton,
                ),
                const SizedBox(height: 12),
                Text(
                  'Want a more complete study plan?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.strongText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your plan is based on 10 diagnostic questions. '
                  'A full 30-question assessment will map every '
                  'category and adapt as you go.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.bodyText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryButton,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonCornerRadius,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Take the assessment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No thanks, keep studying',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.subtleText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted) return;

      if (takeAssessment == true) {
        MixpanelService.instance.track(
          'assessment_prompt_accepted',
          properties: {'app_name': 'SP'},
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AssessmentInfoPage()),
        );
        return;
      }

      MixpanelService.instance.track(
        'assessment_prompt_declined',
        properties: {'app_name': 'SP'},
      );
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _goNext() {
    if (_currentIndex == _queue.length - 1) {
      MixpanelService.instance.track(
        'study_completed',
        properties: {'category': widget.category, 'mode': _mode},
      );
      // Deck genuinely finished — clear the saved position so the
      // next fresh entry into this category's study mode starts over
      // at card 1 rather than resuming a completed deck.
      _state.studySessionIndex.remove(widget.category);
      _navigateWithPrompt(CategoryQuizPage(category: widget.category));
      return;
    }
    setState(() => _currentIndex++);
    _state.studySessionIndex[widget.category] = _currentIndex;
  }

  void _goPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _state.studySessionIndex[widget.category] = _currentIndex;
    }
  }

  // Direct jump to the quiz — bypasses the assessment-upsell prompt
  // deliberately, since that dialog is scoped to natural completion/
  // exit points, not to a manual mode switch. Jarring to interrupt a
  // toggle tap with an unrelated upsell.
  void _goQuizMode() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryQuizPage(category: widget.category),
      ),
    );
  }

  void _toggleKeyPoints() {
    setState(() => _showKeyPoints = !_showKeyPoints);
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _goQuizMode,
              icon: const Icon(Icons.bolt_outlined, size: 15),
              label: const Text(
                'Quiz Mode',
                style: TextStyle(fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bodyText,
                side: BorderSide(color: AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _toggleKeyPoints,
              icon: Icon(
                _showKeyPoints
                    ? Icons.notes_outlined
                    : Icons.short_text_outlined,
                size: 15,
              ),
              label: Text(
                _showKeyPoints ? 'Q&A&E' : 'Q&A',
                style: const TextStyle(fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bodyText,
                side: BorderSide(color: AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Column(
        spacing: 4,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _navigateWithPrompt(const DashboardPage()),
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
          if (!_state.hasTakenAssessment)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Full Curriculum · ',
                  style: TextStyle(fontSize: 12, color: AppColors.subtleText),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssessmentInfoPage(),
                    ),
                  ),
                  child: Text(
                    'Take the assessment to personalize',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryButton,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
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
          if (_queue.isNotEmpty)
            Text(
              _currentIndex < _queue.length
                  ? '${_currentIndex + 1} of ${_queue.length}'
                  : 'Complete',
              style: TextStyle(
                fontSize: AppFonts.caption,
                color: AppColors.subtleText,
              ),
              textAlign: TextAlign.center,
            ),
          if (_mode != 'Standard')
            Text(
              _mode == 'Assessment'
                  ? 'Current study mode: Focused Review'
                  : _mode == 'Recovery'
                  ? 'Current study mode: Extra Support'
                  : 'Current study mode: Review',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.subtleText,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildConceptCard(CurriculumModel content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            content.subcategory.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleText,
            ),
          ),
          Text(
            content.conceptTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.strongText,
            ),
          ),
          Divider(color: AppColors.divider),
          Text(
            content.content,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.bodyText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            "You've reviewed everything in this category.",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.strongText,
            ),
          ),
          Text(
            'Head back to the Dashboard to track your progress or move on to another category.',
            style: TextStyle(fontSize: 13, color: AppColors.bodyText),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPointsCard(List<String> points) {
    if (points.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY POINTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleText,
            ),
          ),
          const SizedBox(height: 8),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryButton,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(fontSize: 12, color: AppColors.bodyText),
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

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.servSafeBlue,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Text(
                  'Preparing your personalized content...',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.subtleText,
                  ),
                  textAlign: TextAlign.center,
                ),
                LinearProgressIndicator(
                  backgroundColor: AppColors.subtleText.withValues(alpha: 0.2),
                  color: AppColors.primaryButton,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isComplete = _queue.isEmpty || _currentIndex >= _queue.length;
    final content = isComplete ? null : _queue[_currentIndex];
    final keyPoints = content != null ? _buildKeyPoints(content) : <String>[];
    final isLast = _queue.isNotEmpty && _currentIndex == _queue.length - 1;

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Padding(
          padding: AppSizes.pageMargin,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(),

                      _buildToggleRow(),

                      isComplete || content == null
                          ? _buildCompletionCard()
                          : _buildConceptCard(content),

                      if (!isComplete) ...[
                        Row(
                          spacing: 8,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: AppSizes.primaryButtonHeight,
                                child: ElevatedButton(
                                  onPressed: _currentIndex > 0
                                      ? _goPrevious
                                      : null,
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
                                  child: const Text('← Previous'),
                                ),
                              ),
                            ),
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
                                  child: Text(isLast ? 'Take Quiz' : 'Next →'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: AppSizes.primaryButtonHeight,
                        child: ElevatedButton(
                          onPressed: () {
                            final allCardsViewed =
                                _queue.isEmpty ||
                                _currentIndex >= _queue.length - 1;
                            if (allCardsViewed) {
                              MixpanelService.instance.track(
                                'study_completed',
                                properties: {
                                  'category': widget.category,
                                  'mode': _mode,
                                },
                              );
                            } else {
                              MixpanelService.instance.track(
                                'study_abandoned',
                                properties: {
                                  'category': widget.category,
                                  'mode': _mode,
                                  'cards_viewed': _currentIndex,
                                  'total_cards': _queue.length,
                                },
                              );
                            }
                            _state.markCategoryStudied(widget.category);
                            AppStatePersistence.save();
                            _navigateWithPrompt(const DashboardPage());
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
                          child: const Text('Back to Dashboard'),
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (!isComplete && _showKeyPoints && keyPoints.isNotEmpty)
                        _buildKeyPointsCard(keyPoints),
                    ],
                  ),
                ),
              ),
              const SafePrepNavBar(),
            ],
          ),
        ),
      ),
    );
  }
}
