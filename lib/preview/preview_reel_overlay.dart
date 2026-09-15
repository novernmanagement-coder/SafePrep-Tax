import 'package:flutter/material.dart';
import '../constants.dart';
import '../app_state.dart';
import '../readiness_engine.dart';

class PreviewReelOverlay extends StatefulWidget {
  final VoidCallback onBuy;
  final bool isPurchasing;
  final String unlockPrice;
  final VoidCallback? onBuySevenDay;
  final VoidCallback? onBuyFourteenDay;

  const PreviewReelOverlay({
    super.key,
    required this.onBuy,
    required this.isPurchasing,
    required this.unlockPrice,
    this.onBuySevenDay,
    this.onBuyFourteenDay,
  });

  @override
  State<PreviewReelOverlay> createState() => _PreviewReelOverlayState();
}

class _PreviewReelOverlayState extends State<PreviewReelOverlay>
    with TickerProviderStateMixin {
  int _reelIndex = 0;
  bool _reelShowingBlurb = false;
  bool _running = true;

  late AnimationController _itemController;
  late Animation<double> _itemFade;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _mutedWhite = Color(0x99F0EDE8);

  static const List<Map<String, String>> _featureSlides = [
    {
      'asset': 'Assets/reel_dashboard.png',
      'label': 'Dashboard',
      'blurb':
          'Your personalized study plan — built from your results, not a meaningless unending list of questions.',
    },
    {
      'asset': 'Assets/reel_study.png',
      'label': 'Study',
      'blurb':
          'Each study category, adapted to your level. Every topic explained clearly — with key points that make it stick.',
    },
    {
      'asset': 'Assets/reel_flashcards.png',
      'label': 'Flash Cards',
      'blurb':
          '82 cards, color-coded by category. Tap to reveal — a classic study method built into your personalized deck.',
    },
    {
      'asset': 'Assets/reel_scenario.png',
      'label': 'Scenario Drills',
      'blurb': 'Real exam scenarios. Instructor led, student participation.',
    },
    {
      'asset': 'Assets/reel_rapidfire.png',
      'label': 'Rapid Fire',
      'blurb':
          'Fast-paced reaction training — because the real exam doesn\'t wait.',
    },
    {
      'asset': 'Assets/reel_mnemonics.png',
      'label': 'Mnemonics',
      'blurb':
          'For those hard-to-remember subjects, word association at its best.',
    },
  ];

  late final List<Map<String, String>> _reelItems;

  @override
  void initState() {
    super.initState();

    _reelItems = [
      {
        'asset': '',
        'label': 'Your Results',
        'blurb': _buildPersonalizedMessage(),
      },
      ..._featureSlides,
      {
        'asset': '',
        'label': 'Your Readiness',
        'blurb': _buildReadinessTimeline(),
      },
    ];

    _itemController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _itemFade = CurvedAnimation(
      parent: _itemController,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _itemController.forward();
    _runLoop();
  }

  @override
  void dispose() {
    _running = false;
    _itemController.dispose();
    super.dispose();
  }

  String _buildPersonalizedMessage() {
    final state = AppState();
    final overall = state.getOverallScore();

    if (overall >= 95) {
      return 'Your results are exceptional — your curriculum is ready to keep you sharp. Your personalized study plan awaits.';
    }

    final scored =
        AppState.allCategories
            .where((c) => state.hasScoreForCategory(c))
            .toList()
          ..sort(
            (a, b) =>
                state.getCategoryScore(a).compareTo(state.getCategoryScore(b)),
          );

    final count = overall >= AppState.masteryThreshold ? 2 : 3;
    final focus = scored.take(count).toList();

    if (focus.isEmpty) {
      return 'Your personalized curriculum is built and ready — let\'s get to work.';
    }

    final categoryList = focus.length == 1
        ? focus[0]
        : focus.length == 2
        ? '${focus[0]} and ${focus[1]}'
        : '${focus[0]}, ${focus[1]}, and ${focus[2]}';

    return 'Your results indicate further study of $categoryList — your personalized curriculum is ready and waiting.';
  }

  String _buildReadinessTimeline() {
    final state = AppState();
    final score = ReadinessEngine.calculate(state);

    if (score >= 85) {
      return 'Very high aptitude detected. Minor study needed — fine-tune with the Peace of Mind tools and 60-Second modules and you\'re ready.';
    }
    if (score >= 66) {
      return 'You\'ve shown real aptitude — a focused 2–3 day window should have you 100% ready to take the exam.';
    }
    if (score >= 41) {
      return 'With your study plan and Peace of Mind tools, most students in your range are 100% exam-ready in 3–4 days.';
    }
    return 'Focused daily study gets you there fast. On average, students at your level are exam-ready in 5 days or less.';
  }

  Future<void> _runLoop() async {
    while (_running && mounted) {
      // Personalized card (index 0) — hold, then move to first feature blurb
      if (_reelIndex == 0) {
        await Future.delayed(const Duration(seconds: 8));
        if (!_running || !mounted) return;
        await _itemController.reverse();
        if (!mounted) return;
        setState(() {
          _reelShowingBlurb = true; // show blurb first
          _reelIndex = 1;
        });
        await _itemController.forward();
        continue;
      }

      // Readiness card (last slide) — hold, then loop back to start
      if (_reelIndex == _reelItems.length - 1) {
        await Future.delayed(const Duration(seconds: 8));
        if (!_running || !mounted) return;
        await _itemController.reverse();
        if (!mounted) return;
        setState(() {
          _reelShowingBlurb = false;
          _reelIndex = 0;
        });
        await _itemController.forward();
        continue;
      }

      // Feature slides
      if (_reelShowingBlurb) {
        // Currently showing blurb — hold, then show screenshot
        await Future.delayed(const Duration(milliseconds: 3500));
        if (!_running || !mounted) return;
        await _itemController.reverse();
        if (!mounted) return;
        setState(() => _reelShowingBlurb = false);
        await _itemController.forward();
      } else {
        // Currently showing screenshot — hold, then move to next blurb
        await Future.delayed(const Duration(milliseconds: 3500));
        if (!_running || !mounted) return;
        await _itemController.reverse();
        if (!mounted) return;
        final nextIndex = _reelIndex + 1;
        if (nextIndex == _reelItems.length - 1) {
          // Next is readiness card
          setState(() {
            _reelShowingBlurb = false;
            _reelIndex = nextIndex;
          });
        } else {
          // Next is another feature slide — show its blurb first
          setState(() {
            _reelShowingBlurb = true;
            _reelIndex = nextIndex;
          });
        }
        await _itemController.forward();
      }
    }
  }

  Widget _buildPersonalizedCard(String message, double screenWidth) {
    return Container(
      width: screenWidth * 0.78,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'YOUR RESULTS',
            style: TextStyle(
              color: _gold.withValues(alpha: 0.5),
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _softWhite,
              fontSize: 16,
              fontWeight: FontWeight.w300,
              height: 1.7,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessCard(String message, double screenWidth) {
    return Container(
      width: screenWidth * 0.78,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'YOUR READINESS',
            style: TextStyle(
              color: _gold.withValues(alpha: 0.6),
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _softWhite,
              fontSize: 16,
              fontWeight: FontWeight.w300,
              height: 1.7,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotFrame(
    String asset,
    String label,
    double screenWidth,
    double screenHeight,
  ) {
    final frameWidth = screenWidth * 0.55;
    final frameHeight = screenHeight * 0.42;

    return Column(
      children: [
        Container(
          width: frameWidth,
          height: frameHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: asset.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(asset, fit: BoxFit.contain),
                )
              : Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.3),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: _gold.withValues(alpha: 0.5),
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBlurbCard(String blurb, double screenWidth) {
    return SizedBox(
      width: screenWidth * 0.75,
      child: Text(
        blurb,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _softWhite,
          fontSize: 18,
          fontWeight: FontWeight.w300,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildPurchaseButtons() {
    if (widget.isPurchasing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    return Column(
      children: [
        _buildTierButton(
          label: '\$4.99  —  7 Days Access',
          sublabel: 'Try it out',
          isHighlighted: false,
          onTap: widget.onBuySevenDay ?? widget.onBuy,
        ),
        const SizedBox(height: 8),
        _buildTierButton(
          label: '\$8.99  —  14 Days Access',
          sublabel: 'Study deeper',
          isHighlighted: false,
          onTap: widget.onBuyFourteenDay ?? widget.onBuy,
        ),
        const SizedBox(height: 8),
        _buildTierButton(
          label: '\$9.99  —  Lifetime Access',
          sublabel: 'Best value  •  Yours forever  ★',
          isHighlighted: true,
          onTap: widget.onBuy,
        ),
      ],
    );
  }

  Widget _buildTierButton({
    required String label,
    required String sublabel,
    required bool isHighlighted,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isHighlighted ? _gold : const Color(0xFF1A1A14),
          foregroundColor: isHighlighted ? const Color(0xFF0A0A0F) : _softWhite,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
            side: BorderSide(
              color: isHighlighted ? _gold : _gold.withValues(alpha: 0.4),
              width: isHighlighted ? 0 : 1,
            ),
          ),
          elevation: isHighlighted ? 6 : 2,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? const Color(0xFF0A0A0F) : _softWhite,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10,
                color: isHighlighted
                    ? const Color(0xFF0A0A0F).withValues(alpha: 0.7)
                    : _mutedWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final item = _reelItems[_reelIndex];
    final isPersonalizedSlide = _reelIndex == 0;
    final isReadinessSlide = _reelIndex == _reelItems.length - 1;

    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _itemFade,
              child: isPersonalizedSlide
                  ? _buildPersonalizedCard(item['blurb']!, screenWidth)
                  : isReadinessSlide
                  ? _buildReadinessCard(item['blurb']!, screenWidth)
                  : _reelShowingBlurb
                  ? _buildBlurbCard(item['blurb']!, screenWidth)
                  : _buildScreenshotFrame(
                      item['asset']!,
                      item['label']!,
                      screenWidth,
                      screenHeight,
                    ),
            ),

            const SizedBox(height: 24),

            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_reelItems.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _reelIndex ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _reelIndex
                        ? _gold
                        : _gold.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _buildPurchaseButtons(),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
