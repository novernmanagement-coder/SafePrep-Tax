import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'fsme_eye.dart';
import 'peace_of_mind_page.dart';
import 'safe_prep_nav_bar.dart';
import 'mixpanel_service.dart';

// Interview Prep reuses the Scenario Drills template (schema, loader
// pattern, and page structure) per Gerry's direction, but the answer
// format is deliberately different: each question packs several
// readiness tips into two bundled choices, with the correct answer
// always being "All of the above" (a good-habits question) or "None
// of the above" (a bad-habits question) rather than picking the one
// best narrative answer. This lets each scenario teach more than one
// tip at a time. MVP ships with 2 scenarios (InterviewPrep.csv) to
// get into review quickly; content grows from there.
class InterviewPrepPage extends StatefulWidget {
  const InterviewPrepPage({
    super.key,
    this.showNavBar = true,
    this.showBrandHeader = true,
  });

  // Both default to true so Tax Starter's existing usage (home_page.dart
  // -> PeaceOfMindPage -> here) is completely unaffected. Set false when
  // this page is reused standalone (e.g. a separate interview-prep-only
  // app) where Tax Starter's bottom nav and "Tax [logo] Starter" header
  // branding/tap-target don't apply.
  final bool showNavBar;
  final bool showBrandHeader;

  @override
  State<InterviewPrepPage> createState() => _InterviewPrepPageState();
}

enum _Phase { question, choices, result }

class _InterviewPrepPageState extends State<InterviewPrepPage> {
  List<InterviewPrepModel> _prompts = [];
  int _currentIndex = 0;
  InterviewPrepModel? _current;

  _Phase _phase = _Phase.question;
  bool? _wasCorrect;
  int _selectedChoice = 0;

  double _questionOpacity = 0;
  double _choicesOpacity = 0;
  double _resultOpacity = 0;
  double _explanationOpacity = 0;
  double _nextButtonOpacity = 0;
  bool _isExplaining = false;

  final ScrollController _scrollController = ScrollController();

  // ── FSME ──────────────────────────────────────────────────────
  // Same self-clearing header pattern as Scenario Drills, reusing the
  // interviewer/candidate character art (Assets/instructor_*.png and
  // Assets/student_*.png) since those files were replaced with
  // interview-themed art under the same names.
  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();
  static const Duration _typeCharDelay = Duration(milliseconds: 18);
  static const Duration _introHold = Duration(milliseconds: 1800);
  static const String _introLine =
      "Ok, this one took some doing too — I had to hire an "
      "interviewer and find someone who didn't mind getting the same "
      "job offer over and over. (He's one of the extra-prepared "
      "candidates, who just wants you to nail this too.)";

  EyeMood _eyeMood = EyeMood.fibbing;
  String _introDisplayedText = '';
  bool _showIntro = true;

  String get _interviewerImage {
    if (_wasCorrect == null) {
      return _phase == _Phase.question
          ? 'Assets/instructor_asking.png'
          : 'Assets/instructor_waiting.png';
    }
    if (_isExplaining) return 'Assets/instructor_explaining.png';
    return _wasCorrect!
        ? 'Assets/instructor_correct.png'
        : 'Assets/instructor_incorrect.png';
  }

  String? get _candidateImage {
    if (_phase == _Phase.question) return null;
    if (_wasCorrect == null) {
      return _choicesOpacity > 0 ? 'Assets/student_thinking.png' : null;
    }
    if (_isExplaining) return 'Assets/student_listening.png';
    return _wasCorrect!
        ? 'Assets/student_correct.png'
        : 'Assets/student_incorrect.png';
  }

  @override
  void initState() {
    super.initState();
    _init();
    _playIntro();
  }

  Future<void> _playIntro() async {
    for (var i = 1; i <= _introLine.length; i++) {
      if (!mounted) return;
      await Future.delayed(_typeCharDelay);
      if (!mounted) return;
      setState(() => _introDisplayedText = _introLine.substring(0, i));
    }
    if (!mounted) return;
    await Future.delayed(_introHold);
    if (!mounted) return;
    setState(() {
      _showIntro = false;
      _eyeMood = EyeMood.serious;
    });
  }

  Future<void> _init() async {
    await _loadPrompts();
    _showPhase1();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPrompts() async {
    // Deliberately NOT shuffled — this walks the user through interview
    // readiness in order (confidence/knowledge first, then presentation,
    // tech, room, materials, opening, closing, follow-up), matching the
    // linear flow Gerry asked for rather than a randomized drill pool.
    _prompts = await InterviewPrepLoader.loadAll();

    _currentIndex = 0;
    _current = _prompts.isNotEmpty ? _prompts[0] : null;
    if (mounted) {
      setState(() {});
      MixpanelService.instance.track(
        'interview_prep_started',
        properties: {'prompt_count': _prompts.length},
      );
    }
  }

  void _showPhase1() {
    if (_current == null) return;
    setState(() {
      _phase = _Phase.question;
      _wasCorrect = null;
      _selectedChoice = 0;
      _isExplaining = false;
      _questionOpacity = 0;
      _choicesOpacity = 0;
      _resultOpacity = 0;
      _explanationOpacity = 0;
      _nextButtonOpacity = 0;
    });

    if (_scrollController.hasClients) _scrollController.jumpTo(0);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _questionOpacity = 1);
    });
  }

  Future<void> _transitionToPhase2() async {
    if (_current == null) return;
    setState(() => _phase = _Phase.choices);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _choicesOpacity = 1);
  }

  void _onChoiceSelected(int choiceIndex) {
    if (_phase != _Phase.choices) return;
    final isCorrect = choiceIndex == _current!.correctChoice;
    setState(() {
      _selectedChoice = choiceIndex;
      _phase = _Phase.result;
    });
    MixpanelService.instance.track(
      'interview_prep_answered',
      properties: {
        'prompt_index': _currentIndex,
        'category': _current?.category,
        'correct': isCorrect,
      },
    );
    _transitionToPhase3(isCorrect);
  }

  Future<void> _transitionToPhase3(bool isCorrect) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _wasCorrect = isCorrect;
      _choicesOpacity = 0;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _resultOpacity = 1);

    await Future.delayed(Duration(milliseconds: isCorrect ? 1500 : 800));
    if (!mounted) return;
    setState(() => _isExplaining = true);

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() => _explanationOpacity = 1);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _nextButtonOpacity = 1);
  }

  void _onNextPrompt() {
    _currentIndex++;
    if (_currentIndex >= _prompts.length) {
      _currentIndex = 0;
    }
    _current = _prompts[_currentIndex];
    _showPhase1();
  }

  Color _choiceColor(int oneBased) {
    if (_wasCorrect == null) return AppColors.primaryButton;
    if (oneBased == _current!.correctChoice) return const Color(0xFF3BA776);
    if (oneBased == _selectedChoice && !_wasCorrect!) {
      return const Color(0xFFE05C5C);
    }
    return const Color(0xFF999999);
  }

  String get _counterText => _prompts.isEmpty
      ? 'No questions available'
      : 'Question ${_currentIndex + 1} of ${_prompts.length}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFsmeIntroBanner(),
            Expanded(child: _buildBody()),
            if (widget.showNavBar) const SafePrepNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        children: [
          if (widget.showBrandHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tax',
                  style: TextStyle(
                    fontSize: AppFonts.header,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bodyText,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PeaceOfMindPage()),
                  ),
                  child: Image.asset(
                    'Assets/splash.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 8),
                FsmeEyePair(key: _eyeKey, mood: _eyeMood, size: 22, spacing: 6),
                const SizedBox(width: 8),
                const Text(
                  'Starter',
                  style: TextStyle(
                    fontSize: AppFonts.header,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bodyText,
                  ),
                ),
              ],
            ),
          ] else
            FsmeEyePair(key: _eyeKey, mood: _eyeMood, size: 26, spacing: 7),
          const SizedBox(height: 4),
          const Text(
            '💼 Interview Prep',
            style: TextStyle(
              fontSize: AppFonts.header,
              fontWeight: FontWeight.bold,
              color: AppColors.strongText,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Get ready for the real conversation',
            style: TextStyle(
              fontSize: AppFonts.caption,
              color: AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }

  /// Self-clearing — collapses to zero height via AnimatedSize once
  /// the intro line finishes its hold, so it never permanently steals
  /// vertical space from the character panel / question area below.
  Widget _buildFsmeIntroBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _showIntro
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                _introDisplayedText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF555555),
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }

  Widget _buildCharacterPanel() {
    final candidateAsset = _candidateImage;
    return Column(
      children: [
        SizedBox(
          height: 148,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: candidateAsset != null
                    ? Image.asset(
                        candidateAsset,
                        key: ValueKey(candidateAsset),
                        height: 148,
                        fit: BoxFit.contain,
                      )
                    : const SizedBox(width: 90, key: ValueKey('none')),
              ),
              const SizedBox(width: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Image.asset(
                  _interviewerImage,
                  key: ValueKey(_interviewerImage),
                  height: 148,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
        if (candidateAsset != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'You',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.subtleText,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 90,
                  child: Text(
                    'Interviewer',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.subtleText,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                _buildCharacterPanel(),
                const SizedBox(height: 8),
                _buildQuestionBubble(),
                const SizedBox(height: 12),
                if (_phase == _Phase.choices) _buildChoices(),
                if (_wasCorrect != null) ...[
                  const SizedBox(height: 12),
                  _buildResultBanner(),
                ],
                if (_explanationOpacity > 0) ...[
                  const SizedBox(height: 12),
                  _buildExplanationBubble(),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        _buildBottomButtons(),
      ],
    );
  }

  Widget _buildQuestionBubble() {
    return AnimatedOpacity(
      opacity: _questionOpacity,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              _current?.question ?? 'Loading...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFonts.question,
                color: AppColors.strongText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _counterText,
              style: const TextStyle(fontSize: 11, color: AppColors.subtleText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoices() {
    final bool enabled = _phase == _Phase.choices;
    return AnimatedOpacity(
      opacity: _choicesOpacity,
      duration: const Duration(milliseconds: 180),
      child: Column(
        children: [
          _choiceButton(1, 'A.  ${_current?.choice1 ?? ''}', enabled),
          const SizedBox(height: 8),
          _choiceButton(2, 'B.  ${_current?.choice2 ?? ''}', enabled),
          const SizedBox(height: 8),
          _choiceButton(3, 'C.  ${_current?.choice3 ?? ''}', enabled),
          const SizedBox(height: 8),
          _choiceButton(4, 'D.  ${_current?.choice4 ?? ''}', enabled),
        ],
      ),
    );
  }

  Widget _choiceButton(int index, String text, bool enabled) {
    final color = _choiceColor(index);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? () => _onChoiceSelected(index) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color,
          foregroundColor: AppColors.primaryButtonForeground,
          disabledForegroundColor: AppColors.primaryButtonForeground,
          elevation: 0,
          minimumSize: const Size(0, 48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: AppFonts.body),
        ),
        child: Text(text, softWrap: true),
      ),
    );
  }

  Widget _buildResultBanner() {
    final isCorrect = _wasCorrect ?? false;
    return AnimatedOpacity(
      opacity: _resultOpacity,
      duration: const Duration(milliseconds: 250),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCorrect ? const Color(0xFF3BA776) : const Color(0xFFE05C5C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          isCorrect
              ? '✓  Correct!'
              : '✗  Not quite — see the explanation below',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppFonts.subheader,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationBubble() {
    return AnimatedOpacity(
      opacity: _explanationOpacity,
      duration: const Duration(milliseconds: 350),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📖  Explanation',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.subtleText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _current?.explanation ?? '',
              style: const TextStyle(
                fontSize: AppFonts.body,
                color: AppColors.strongText,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Stack(
        children: [
          if (_phase == _Phase.question)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _transitionToPhase2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  foregroundColor: AppColors.primaryButtonForeground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontSize: AppFonts.body),
                ),
                child: const Text('Show me my choices  →'),
              ),
            ),
          if (_nextButtonOpacity > 0)
            AnimatedOpacity(
              opacity: _nextButtonOpacity,
              duration: const Duration(milliseconds: 250),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _onNextPrompt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.primaryButtonForeground,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontSize: AppFonts.body),
                  ),
                  child: const Text('Next Question  →'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
