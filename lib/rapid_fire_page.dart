import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'csv_loader.dart';
import 'app_state_persistence.dart';
import 'readiness_engine.dart';
import 'fsme_eye.dart';
import 'peace_of_mind_page.dart';
import 'mixpanel_service.dart';

class RapidFirePage extends StatefulWidget {
  const RapidFirePage({super.key});

  @override
  State<RapidFirePage> createState() => _RapidFirePageState();
}

class _RapidFirePageState extends State<RapidFirePage>
    with TickerProviderStateMixin {
  static const int _questionDurationMs = 3000;
  static const int _answerDurationMs = 5000;
  static const int _slideInMs = 320;
  static const int _slideOutMs = 260;

  List<QuestionModel> _deck = [];
  int _currentIndex = 0;
  bool _isPaused = false;
  bool _isStopped = false;
  bool _answerTapped = false;
  int _correctSlot = 0;

  int _correct = 0;
  int _incorrect = 0;
  int _skipped = 0;

  String _questionText = '';
  String _answerAText = '';
  String _answerBText = '';
  Color _bubbleColor = AppColors.primaryButton;
  Color _accentColor = AppColors.primaryButton;

  AnimationController? _slideController;
  Animation<Offset> _slideOffset = const AlwaysStoppedAnimation(Offset.zero);

  bool _answersVisible = false;
  Color _colorA = const Color(0xFF4A6FA5);
  Color _colorB = const Color(0xFF4A6FA5);
  bool _buttonsEnabled = true;

  double _timerProgress = 0.0;
  Color _timerColor = AppColors.primaryButton;

  // ── FSME ──────────────────────────────────────────────────────
  // Small, silent presence in the header: types one intro line on
  // entry (self-clearing — collapses back to zero height once it's
  // done, doesn't leave a permanent gap), then settles into `serious`
  // and just watches. Reacts to answers eye-only — no new text, no
  // popups, nothing that adds a beat to the question/answer timer
  // loop. Per the standing rule on file: humor sits before the
  // questions, never during, so it never distracts a concentrating
  // user under time pressure.
  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();
  static const Duration _typeCharDelay = Duration(milliseconds: 18);
  static const Duration _introHold = Duration(milliseconds: 1800);
  static const String _introLine =
      "If I'm a big tool, then this is the tool-iest tool that have "
      "tooled.";

  EyeMood _eyeMood = EyeMood.fibbing;
  String _introDisplayedText = '';
  bool _showIntro = true;
  Timer? _befuddledRevertTimer;

  static const Map<String, Color> _categoryColors = {
    'Time & Temperature': Color(0xFFC0392B),
    'Cross-Contamination': Color(0xFFE67E22),
    'Food Preparation': Color(0xFF27AE60),
    'Receiving & Storage': Color(0xFF2980B9),
    'Personal Hygiene': Color(0xFF8E44AD),
    'Cleaning & Sanitizing': Color(0xFF16A085),
    'Facility & Equipment': Color(0xFF34495E),
    'Food Safety Management': Color(0xFFB7950B),
  };

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track('rapid_fire_started');
    _awardExtraCredit();
    _playIntro();
    _init();
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

  void _awardExtraCredit() {
    final state = AppState();
    state.extraCreditPoints =
        (state.extraCreditPoints +
                ReadinessEngine.extraCreditForAction(
                  ExtraCreditAction.rapidFire,
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

  Future<void> _init() async {
    await _loadDeck();
    _runSession();
  }

  @override
  void dispose() {
    _isStopped = true;
    _slideController?.dispose();
    _befuddledRevertTimer?.cancel();
    super.dispose();
  }

  Future<void> _runSession() async {
    while (!_isStopped) {
      if (_currentIndex >= _deck.length) _currentIndex = 0;

      if (_deck.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      final q = _deck[_currentIndex];
      if (!mounted) return;
      setState(() {
        _answerTapped = false;
        _answersVisible = false;
        _timerProgress = 0.0;
        _timerColor = AppColors.primaryButton;
        _buttonsEnabled = true;
        _colorA = const Color(0xFF4A6FA5);
        _colorB = const Color(0xFF4A6FA5);
        _applyQuestion(q);
      });

      await _slideIn();
      if (_isStopped) return;

      await _pausableDelay(_questionDurationMs, warningMs: 0);
      if (_isStopped) return;

      if (mounted) setState(() => _answersVisible = true);

      await _pausableDelay(_answerDurationMs, warningMs: 2000);
      if (_isStopped) return;

      if (!_answerTapped && mounted) {
        setState(() => _skipped++);
        if (!_showIntro) {
          _befuddledRevertTimer?.cancel();
          _eyeKey.currentState?.tired();
        }
      }

      await Future.delayed(const Duration(milliseconds: 200));
      if (_isStopped) return;

      await _slideOut();
      _currentIndex++;
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  void _applyQuestion(QuestionModel q) {
    String category = q.category;
    if (category.toLowerCase() == 'pest management') {
      category = 'Food Safety Management';
    }
    final color = _categoryColors[category] ?? AppColors.primaryButton;
    _bubbleColor = color;
    _accentColor = color;
    _questionText = q.questionText;

    final answers = [q.answer1, q.answer2, q.answer3, q.answer4];
    final correctText = answers[q.correctAnswer];
    final wrongs = <String>[];
    for (int i = 0; i < answers.length; i++) {
      if (i != q.correctAnswer) wrongs.add(answers[i]);
    }
    wrongs.shuffle();
    final wrongText = wrongs[0];

    _correctSlot = Random().nextInt(2);
    if (_correctSlot == 0) {
      _answerAText = correctText;
      _answerBText = wrongText;
    } else {
      _answerAText = wrongText;
      _answerBText = correctText;
    }
  }

  void _onAnswerA() {
    if (!_buttonsEnabled || _answerTapped) return;
    _answerTapped = true;
    _handleAnswer(isCorrect: _correctSlot == 0, tappedA: true);
  }

  void _onAnswerB() {
    if (!_buttonsEnabled || _answerTapped) return;
    _answerTapped = true;
    _handleAnswer(isCorrect: _correctSlot == 1, tappedA: false);
  }

  void _handleAnswer({required bool isCorrect, required bool tappedA}) {
    setState(() {
      _buttonsEnabled = false;
      if (isCorrect) {
        _correct++;
        if (tappedA) {
          _colorA = const Color(0xFF2E7D32);
          _colorB = const Color(0xFF888888);
        } else {
          _colorB = const Color(0xFF2E7D32);
          _colorA = const Color(0xFF888888);
        }
      } else {
        _incorrect++;
        if (tappedA) {
          _colorA = const Color(0xFFC62828);
          _colorB = const Color(0xFF2E7D32);
        } else {
          _colorB = const Color(0xFFC62828);
          _colorA = const Color(0xFF2E7D32);
        }
      }
    });
    _reactToAnswer(isCorrect);
  }

  /// Silent eye-only reaction — never blocks or delays the answer
  /// loop itself, just rides alongside it. Correct gets a quick
  /// surprise() bulge (one-shot, auto-reverts). Wrong briefly sets
  /// the mood to befuddled, then reverts to serious after a beat —
  /// befuddled isn't one of the triggered one-shots, so this is done
  /// by hand with a short timer rather than a method call.
  void _reactToAnswer(bool isCorrect) {
    if (!_showIntro) {
      if (isCorrect) {
        _eyeKey.currentState?.surprise();
      } else {
        _befuddledRevertTimer?.cancel();
        setState(() => _eyeMood = EyeMood.befuddled);
        _befuddledRevertTimer = Timer(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(() => _eyeMood = EyeMood.serious);
        });
      }
    }
  }

  Future<void> _pausableDelay(int totalMs, {required int warningMs}) async {
    int elapsed = 0;
    while (elapsed < totalMs) {
      if (_isStopped || _answerTapped) return;
      if (!_isPaused) {
        await Future.delayed(const Duration(milliseconds: 100));
        elapsed += 100;
        if (mounted) {
          setState(() {
            _timerProgress = elapsed / totalMs;
            if (warningMs > 0 && elapsed >= totalMs - warningMs) {
              _timerColor = const Color(0xFFC62828);
            }
          });
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _slideIn() async {
    _slideController?.dispose();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _slideInMs),
    );
    _slideOffset = Tween<Offset>(begin: const Offset(1.5, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController!,
            curve: Curves.easeOutCubic,
          ),
        );
    if (mounted) setState(() {});
    await _slideController!.forward();
  }

  Future<void> _slideOut() async {
    _slideController?.dispose();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _slideOutMs),
    );
    _slideOffset = Tween<Offset>(begin: Offset.zero, end: const Offset(-1.5, 0))
        .animate(
          CurvedAnimation(parent: _slideController!, curve: Curves.easeInCubic),
        );
    if (mounted) setState(() {});
    await _slideController!.forward();
  }

  Future<void> _loadDeck({bool append = false}) async {
    final all = await QuestionLoader.loadAll(shuffle: false);
    final state = AppState();
    final existing = _deck.map((q) => q.id).toSet();

    final mustInclude = all
        .where((q) => q.mustInclude == 1 && !existing.contains(q.id))
        .toList();

    final mustIds = {...mustInclude.map((q) => q.id), ...existing};

    final weakCategories =
        AppState.allCategories
            .where(
              (c) =>
                  state.hasScoreForCategory(c) &&
                  state.getCategoryScore(c) < AppState.masteryThreshold,
            )
            .toList()
          ..sort(
            (a, b) =>
                state.getCategoryScore(a).compareTo(state.getCategoryScore(b)),
          );

    final personalized = <QuestionModel>[];
    final needed = 50 - mustInclude.length;

    for (final category in weakCategories) {
      if (personalized.length >= needed) break;
      final candidates =
          all
              .where(
                (q) =>
                    !mustIds.contains(q.id) &&
                    !personalized.any((p) => p.id == q.id) &&
                    q.category.toLowerCase() == category.toLowerCase(),
              )
              .toList()
            ..sort((a, b) => b.difficulty.compareTo(a.difficulty));
      personalized.addAll(candidates.take(needed - personalized.length));
    }

    if (personalized.length < needed) {
      final random =
          all
              .where(
                (q) =>
                    !mustIds.contains(q.id) &&
                    !personalized.any((p) => p.id == q.id),
              )
              .toList()
            ..sort((a, b) => b.difficulty.compareTo(a.difficulty))
            ..shuffle();
      personalized.addAll(random.take(needed - personalized.length));
    }

    final newCards = [...mustInclude, ...personalized];
    if (mounted) {
      setState(() {
        if (append) {
          _deck.addAll(newCards);
        } else {
          _deck = newCards;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFsmeIntroBanner(),
            Expanded(child: _buildCardArea()),
            _buildScoreCounters(),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _stopAndExit,
            child: Image.asset(
              'Assets/splash.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),
          FsmeEyePair(key: _eyeKey, mood: _eyeMood, size: 22, spacing: 6),
          const Expanded(
            child: Column(
              children: [
                Text(
                  '⚡ Rapid Fire',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'The Tough Questions',
                  style: TextStyle(
                    fontSize: AppFonts.caption,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          _ctrlButton('Stop', _stopAndExit),
        ],
      ),
    );
  }

  /// Self-clearing — collapses to zero height via AnimatedSize once
  /// the intro line finishes its hold, so it never permanently steals
  /// vertical space from the question/answer area below it.
  Widget _buildFsmeIntroBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _showIntro
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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

  Widget _buildCardArea() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            color: _accentColor.withValues(alpha: 0.4),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: SlideTransition(
              position: _slideOffset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuestionBubble(),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    opacity: _answersVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _buildAnswerButtons(),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 24,
          right: 24,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _timerProgress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _timerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBubble() {
    return CustomPaint(
      painter: _BubblePainter(color: _bubbleColor),
      child: SizedBox(
        width: 320,
        height: 150,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: Text(
              _questionText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerButtons() {
    return SizedBox(
      width: 320,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _answerButton('A', _answerAText, _colorA, _onAnswerA),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _answerButton('B', _answerBText, _colorB, _onAnswerB),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerButton(
    String label,
    String text,
    Color bgColor,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      onPressed: _buttonsEnabled ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        disabledBackgroundColor: bgColor,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0x99FFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCounters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _scoreBox(
              '✓ Correct',
              '$_correct',
              const Color(0xFFE8F5E9),
              const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _scoreBox(
              '✗ Incorrect',
              '$_incorrect',
              const Color(0xFFFFEBEE),
              const Color(0xFFC62828),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _scoreBox(
              '— Skipped',
              '$_skipped',
              const Color(0xFFF5F5F5),
              const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppFonts.caption,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ctrlButton(_isPaused ? '▶ Resume' : '⏸ Pause', _onPause),
          const SizedBox(width: 12),
          _ctrlButton('Load More Questions ＋', _onMoreFacts),
        ],
      ),
    );
  }

  Widget _ctrlButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryButton,
        foregroundColor: AppColors.primaryButtonForeground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(
          fontSize: AppFonts.body,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }

  void _onPause() => setState(() => _isPaused = !_isPaused);
  void _onMoreFacts() => _loadDeck(append: true);

  void _stopAndExit() {
    MixpanelService.instance.track(
      'rapid_fire_completed',
      properties: {
        'correct': _correct,
        'incorrect': _incorrect,
        'skipped': _skipped,
      },
    );
    _isStopped = true;
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PeaceOfMindPage()),
      );
    }
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  const _BubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(20, 0)
      ..quadraticBezierTo(0, 0, 0, 20)
      ..lineTo(0, 100)
      ..quadraticBezierTo(0, 120, 20, 120)
      ..lineTo(30, 120)
      ..lineTo(20, 145)
      ..lineTo(60, 120)
      ..lineTo(300, 120)
      ..quadraticBezierTo(320, 120, 320, 100)
      ..lineTo(320, 20)
      ..quadraticBezierTo(320, 0, 300, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
}
