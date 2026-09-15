import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'csv_loader.dart';
import 'fsme_eye.dart';
import 'peace_of_mind_page.dart';
import 'readiness_engine.dart';
import 'mixpanel_service.dart';

enum _CardState { deck, question, reveal }

class FlashCardsPage extends StatefulWidget {
  const FlashCardsPage({super.key});

  @override
  State<FlashCardsPage> createState() => _FlashCardsPageState();
}

class _FlashCardsPageState extends State<FlashCardsPage>
    with SingleTickerProviderStateMixin {
  List<QuestionModel> _cards = [];
  int _currentIndex = 0;
  _CardState _state = _CardState.deck;
  bool _isAnimating = false;

  late AnimationController _flipController;
  late Animation<double> _scaleX;

  // ── FSME ──────────────────────────────────────────────────────
  // Small, self-clearing intro banner under the header — same
  // pattern as RapidFirePage: types on entry, holds briefly, then
  // collapses to zero height so it never permanently steals space
  // from the card area. No ongoing reactions on this page (flash
  // cards are self-graded, no correct/wrong signal to react to).
  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();
  static const Duration _typeCharDelay = Duration(milliseconds: 18);
  static const Duration _introHold = Duration(milliseconds: 1800);
  static const String _introLine =
      "Did I tell you I got kicked out of Vegas for counting cards? "
      "I counted 1.3 million cards in the city \u2014 that's what "
      "inspired Flash Cards. Time-tested, and a great way for "
      "humans to lock in the information.";

  EyeMood _eyeMood = EyeMood.fibbing;
  String _introDisplayedText = '';
  bool _showIntro = true;

  static const Map<String, _Suit> _categorySuits = {
    'Time & Temperature': _Suit('🌡', Color(0xFFC0392B), 'T&T'),
    'Cross-Contamination': _Suit('⚠', Color(0xFFE67E22), 'CC'),
    'Food Preparation': _Suit('✦', Color(0xFF27AE60), 'FP'),
    'Receiving & Storage': _Suit('◈', Color(0xFF2980B9), 'R&S'),
    'Personal Hygiene': _Suit('❋', Color(0xFF8E44AD), 'PH'),
    'Cleaning & Sanitizing': _Suit('✺', Color(0xFF16A085), 'C&S'),
    'Facility & Equipment': _Suit('⚙', Color(0xFF2C3E50), 'F&E'),
    'Food Safety Management': _Suit('◉', Color(0xFFB7950B), 'FSM'),
  };

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scaleX = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadCards();
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

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final all = await QuestionLoader.loadAll(shuffle: false);
    final state = AppState();
    const needed = 50;

    final mustInclude = all.where((q) => q.mustInclude == 1).toList();
    final mustIds = mustInclude.map((q) => q.id).toSet();

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
            ..shuffle();
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
            ..shuffle();
      personalized.addAll(random.take(needed - personalized.length));
    }

    if (mounted) {
      setState(() => _cards = [...mustInclude, ...personalized]);
      MixpanelService.instance.track(
        'flash_cards_started',
        properties: {'deck_size': _cards.length},
      );
    }
  }

  Future<void> _flipCard(VoidCallback swapContent) async {
    if (_isAnimating) return;
    _isAnimating = true;
    await _flipController.forward();
    swapContent();
    await _flipController.reverse();
    _isAnimating = false;
  }

  void _onCardTap() {
    if (_isAnimating || _cards.isEmpty) return;
    switch (_state) {
      case _CardState.deck:
        _flipCard(() => setState(() => _state = _CardState.question));
        break;
      case _CardState.question:
        _flipCard(() => setState(() => _state = _CardState.reveal));
        break;
      case _CardState.reveal:
        break;
    }
  }

  void _onDone() {
    final state = AppState();
    state.extraCreditPoints =
        (state.extraCreditPoints +
                ReadinessEngine.extraCreditForAction(
                  ExtraCreditAction.flashCards,
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
    MixpanelService.instance.track(
      'flash_cards_completed',
      properties: {'cards_reviewed': _currentIndex + 1},
    );
    Navigator.pop(context);
  }

  void _onNext() {
    if (_isAnimating) return;
    if (_currentIndex >= _cards.length - 1) {
      _onDone();
      return;
    }
    _currentIndex++;
    _flipCard(() => setState(() => _state = _CardState.question));
  }

  void _onPrev() {
    if (_isAnimating || _currentIndex <= 0) return;
    _currentIndex--;
    _flipCard(() => setState(() => _state = _CardState.question));
  }

  static String _normalizeCategory(String cat) =>
      cat.toLowerCase() == 'pest management' ? 'Food Safety Management' : cat;

  _Suit _suitFor(String category) =>
      _categorySuits[_normalizeCategory(category)] ??
      const _Suit('◆', Color(0xFF4A6FA5), '??');

  String get _progressText {
    if (_cards.isEmpty) return 'Loading...';
    final hint = switch (_state) {
      _CardState.deck => 'Tap card to begin',
      _CardState.question => 'Tap card for answer',
      _CardState.reveal => 'Tap Next for next card',
    };
    return 'Card ${_currentIndex + 1} of ${_cards.length}  —  $hint';
  }

  bool get _prevEnabled => _currentIndex > 0 && _state != _CardState.deck;
  bool get _nextEnabled => _state == _CardState.reveal;
  String get _nextLabel =>
      _currentIndex == _cards.length - 1 && _state == _CardState.reveal
      ? 'Done ✓'
      : 'Next →';

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
            _buildNavButtons(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Safe',
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
                'Prep™',
                style: TextStyle(
                  fontSize: AppFonts.header,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bodyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Flash Cards',
            style: TextStyle(
              fontSize: AppFonts.header,
              fontWeight: FontWeight.bold,
              color: AppColors.strongText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _progressText,
            style: const TextStyle(
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
  /// vertical space from the card area below it.
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

  Widget _buildCardArea() {
    return Center(
      child: SizedBox(
        width: 300,
        height: 380,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: 10,
              bottom: 10,
              child: _deckShadow(280, 360, const Color(0xFF3A5A8A)),
            ),
            Positioned(
              right: 5,
              bottom: 5,
              child: _deckShadow(284, 360, const Color(0xFF3D6090)),
            ),
            Align(
              alignment: Alignment.center,
              child: _deckShadow(288, 360, const Color(0xFF4268A0)),
            ),
            AnimatedBuilder(
              animation: _scaleX,
              builder: (_, _) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(_scaleX.value, 1.0, 1.0),
                child: GestureDetector(
                  onTap: _onCardTap,
                  child: Container(
                    width: 292,
                    height: 364,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: switch (_state) {
                        _CardState.deck => _buildCardBack(),
                        _CardState.question => _buildCardFront(),
                        _CardState.reveal => _buildCardReveal(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deckShadow(double w, double h, Color color) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44000000),
          blurRadius: 12,
          offset: Offset(4, 4),
        ),
      ],
    ),
  );

  Widget _buildCardBack() {
    return Container(
      color: const Color(0xFF2A4A80),
      child: Stack(
        children: [
          CustomPaint(size: const Size(292, 364), painter: _CardBackPainter()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'Assets/splash.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                  color: Colors.white.withValues(alpha: 0.9),
                  colorBlendMode: BlendMode.modulate,
                ),
                const SizedBox(height: 10),
                const Text(
                  'SafePrep™',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap to draw',
                  style: TextStyle(fontSize: 12, color: Color(0x80FFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront() {
    if (_cards.isEmpty) return const SizedBox();
    final q = _cards[_currentIndex];
    final suit = _suitFor(q.category);
    final normCat = _normalizeCategory(q.category);

    return Column(
      children: [
        Container(
          color: suit.color,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _suitCorner(suit, crossAxisAlignment: CrossAxisAlignment.start),
              Expanded(
                child: Text(
                  normCat,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              _suitCorner(suit, crossAxisAlignment: CrossAxisAlignment.end),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'QUESTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFAAAAAA),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  q.questionText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppFonts.question,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap to reveal answer',
                  style: TextStyle(fontSize: 11, color: Color(0xFFCCCCCC)),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: suit.color,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                suit.symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Text(
                  q.subcategory,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ),
              Text(
                suit.symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardReveal() {
    if (_cards.isEmpty) return const SizedBox();
    final q = _cards[_currentIndex];
    final suit = _suitFor(q.category);
    final answers = [q.answer1, q.answer2, q.answer3, q.answer4];
    final correct = answers[q.correctAnswer];

    return Column(
      children: [
        Container(
          color: suit.color,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(
                suit.symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Expanded(
                child: Text(
                  'ANSWER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                suit.symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFFFFDF5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  correct,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFEEEEEE)),
                const SizedBox(height: 8),
                Text(
                  q.explanation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: suit.color,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: const Center(
            child: Text(
              'Tap Next for the next card',
              style: TextStyle(fontSize: 10, color: Color(0xB3FFFFFF)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _suitCorner(
    _Suit suit, {
    required CrossAxisAlignment crossAxisAlignment,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          suit.symbol,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          suit.abbr,
          style: const TextStyle(fontSize: 9, color: Color(0xCCFFFFFF)),
        ),
      ],
    );
  }

  Widget _buildNavButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navButton('← Previous', _prevEnabled ? _onPrev : null),
          const SizedBox(width: 16),
          _navButton(_nextLabel, _nextEnabled ? _onNext : null),
        ],
      ),
    );
  }

  Widget _navButton(String label, VoidCallback? onPressed) => SizedBox(
    width: 120,
    height: 44,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryButton,
        foregroundColor: AppColors.primaryButtonForeground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
        ),
        textStyle: const TextStyle(
          fontSize: AppFonts.button,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    ),
  );
}

class _Suit {
  final String symbol;
  final Color color;
  final String abbr;
  const _Suit(this.symbol, this.color, this.abbr);
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    fill.color = Colors.white.withValues(alpha: 0.04);
    _diamond(canvas, fill, 146, 182, 126, 162);
    _diamond(canvas, fill, 146, 182, 94, 122);
    _diamond(canvas, fill, 146, 182, 64, 82);
    fill.color = Colors.white.withValues(alpha: 0.08);
    _diamond(canvas, fill, 30, 50, 20, 20);
    _diamond(canvas, fill, 262, 50, 20, 20);
    _diamond(canvas, fill, 30, 314, 20, 20);
    _diamond(canvas, fill, 262, 314, 20, 20);
  }

  void _diamond(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double hw,
    double hh,
  ) {
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - hh)
        ..lineTo(cx + hw, cy)
        ..lineTo(cx, cy + hh)
        ..lineTo(cx - hw, cy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
