import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'peace_of_mind_page.dart';
import 'safe_prep_nav_bar.dart';
import 'mixpanel_service.dart';

// NOTE: file kept as instructor_tips_page.dart (no rename — this
// device can't rename/delete files). This used to be the ServSafe
// "Instructor's Playbook" / Proctor Tips page; repurposed (Sept 2026)
// into the Glossary of Terms Quiz that FSME calls out as a bonus on
// the Trainers page. Deliberately NOT wired into AppState/
// ReadinessEngine — this is a vocabulary self-test, not exam-weighted
// content, so it never touches category scores, mastery, or
// readiness.
class GlossaryQuizPage extends StatefulWidget {
  const GlossaryQuizPage({super.key});

  @override
  State<GlossaryQuizPage> createState() => _GlossaryQuizPageState();
}

class _GlossaryQuizPageState extends State<GlossaryQuizPage> {
  static const Color _gold = Color(0xFFD4AF37);

  List<GlossaryQuizQuestion> _questions = [];
  bool _loaded = false;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track('glossary_quiz_viewed');
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await GlossaryQuizLoader.loadAll(shuffle: true);
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _loaded = true;
    });
  }

  void _selectAnswer(int index) {
    if (_selectedAnswer != null) return; // already answered this one
    setState(() {
      _selectedAnswer = index;
      if (index == _questions[_currentIndex].correctAnswer) _score++;
    });
  }

  void _next() {
    if (_currentIndex >= _questions.length - 1) {
      MixpanelService.instance.track(
        'glossary_quiz_completed',
        properties: {'score': _score, 'total': _questions.length},
      );
      setState(() => _showResults = true);
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedAnswer = null;
    });
  }

  void _restart() {
    setState(() {
      _questions = List.of(_questions)..shuffle();
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _showResults = false;
    });
  }

  void _goToTrainers() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const PeaceOfMindPage()),
  );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Tax',
                style: TextStyle(
                  fontSize: AppFonts.header,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bodyText,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _goToTrainers,
                child: Image.asset(
                  'Assets/splash.png',
                  width: 36,
                  height: 36,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Starter',
                style: TextStyle(
                  fontSize: AppFonts.header,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bodyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '🧠 Glossary of Terms Quiz',
            style: TextStyle(
              fontSize: AppFonts.header,
              fontWeight: FontWeight.bold,
              color: AppColors.strongText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _answerColor(int index) {
    final q = _questions[_currentIndex];
    if (_selectedAnswer == null) return AppColors.primaryButton;
    if (index == q.correctAnswer) return const Color(0xFF3BA776); // green
    if (index == _selectedAnswer) return const Color(0xFFC0392B); // red
    return AppColors.primaryButton.withValues(alpha: 0.4);
  }

  Widget _buildQuiz() {
    final q = _questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(
          'Question ${_currentIndex + 1} of ${_questions.length}',
          style: TextStyle(fontSize: 12, color: AppColors.subtleText),
          textAlign: TextAlign.center,
        ),
        Container(
          padding: AppSizes.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            q.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.strongText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        for (int i = 0; i < q.answers.length; i++)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _selectAnswer(i),
              style: ElevatedButton.styleFrom(
                backgroundColor: _answerColor(i),
                foregroundColor: Colors.white,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: Text(
                q.answers[i],
                style: const TextStyle(fontSize: AppFonts.body),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        if (_selectedAnswer != null)
          SizedBox(
            width: double.infinity,
            height: AppSizes.primaryButtonHeight,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: Text(
                _currentIndex >= _questions.length - 1
                    ? 'See My Score'
                    : 'Next →',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  String _resultMessage() {
    if (_questions.isEmpty) return '';
    final pct = (_score * 100) / _questions.length;
    if (pct >= 90) return 'You know your forms and terms cold. FSME was right to brag.';
    if (pct >= 70) return 'Solid! A little more review and these are locked in.';
    return 'Worth another pass through the Glossary — these terms show up everywhere.';
  }

  Widget _buildResults() {
    return Column(
      spacing: 16,
      children: [
        const Icon(Icons.emoji_events, size: 48, color: _gold),
        Text(
          '$_score / ${_questions.length}',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.strongText,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _resultMessage(),
            style: TextStyle(fontSize: 14, color: AppColors.bodyText),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: AppSizes.primaryButtonHeight,
          child: ElevatedButton(
            onPressed: _restart,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppSizes.buttonCornerRadius,
                ),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: AppSizes.primaryButtonHeight,
          child: ElevatedButton(
            onPressed: _goToTrainers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppSizes.buttonCornerRadius,
                ),
              ),
            ),
            child: const Text('Back to Trainers'),
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
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSizes.pageMargin,
                child: !_loaded
                    ? const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator(color: _gold)),
                      )
                    : _questions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: Center(child: Text('No questions found.')),
                          )
                        : (_showResults ? _buildResults() : _buildQuiz()),
              ),
            ),
            const SafePrepNavBar(),
          ],
        ),
      ),
    );
  }
}
