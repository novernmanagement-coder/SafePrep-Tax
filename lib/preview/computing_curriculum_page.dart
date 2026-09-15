import 'package:flutter/material.dart';
import '../app_state.dart';
import '../readiness_engine.dart';
import 'preview_reveal_page.dart';

class ComputingCurriculumPage extends StatefulWidget {
  final int questionsAnswered;
  final List<String> coveredCategories;
  final Map<String, int> answeredPerCategory;

  const ComputingCurriculumPage({
    super.key,
    required this.questionsAnswered,
    required this.coveredCategories,
    required this.answeredPerCategory,
  });

  static Future<void> show(
    BuildContext context, {
    required int questionsAnswered,
    required List<String> coveredCategories,
    required Map<String, int> answeredPerCategory,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComputingCurriculumPage(
          questionsAnswered: questionsAnswered,
          coveredCategories: coveredCategories,
          answeredPerCategory: answeredPerCategory,
        ),
      ),
    );
  }

  @override
  State<ComputingCurriculumPage> createState() =>
      _ComputingCurriculumPageState();
}

class _ComputingCurriculumPageState extends State<ComputingCurriculumPage>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _mutedWhite = Color(0x99F0EDE8);

  late AnimationController _progressController;
  late Animation<double> _progressAnim;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final List<Map<String, dynamic>> _lines = [];
  bool _done = false;
  bool _showMeter = false;
  bool _showButton = false;

  static const Map<String, double> _categoryWeights = {
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

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _progressController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ).drive(Tween(begin: 0.5, end: 1.0));

    _runSequence();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _typeLine(
    String text, {
    bool isPayoff = false,
    bool isPunchline = false,
    bool isActionLine = false,
    int preDelayMs = 400,
  }) async {
    await Future.delayed(Duration(milliseconds: preDelayMs));
    if (!mounted) return;

    setState(
      () => _lines.add({
        'text': text,
        'displayedText': '',
        'checked': false,
        'isPayoff': isPayoff,
        'isPunchline': isPunchline,
        'isActionLine': isActionLine,
      }),
    );

    final charDelay = text.length > 50
        ? 15
        : text.length > 30
        ? 20
        : 28;
    for (int i = 1; i <= text.length; i++) {
      await Future.delayed(Duration(milliseconds: charDelay));
      if (!mounted) return;
      setState(() => _lines.last['displayedText'] = text.substring(0, i));
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _lines.last['checked'] = true);

    if (isActionLine) {
      _pulseController.repeat(reverse: true);
    }

    await Future.delayed(const Duration(milliseconds: 400));
  }

  bool _fullyCovered(String category) {
    final maxQ = AppState.categoryMaxQuestions[category] ?? 1;
    final answeredQ = widget.answeredPerCategory[category] ?? 0;
    return answeredQ >= maxQ;
  }

  String _punchline(int readinessScore) {
    if (readinessScore >= 85) {
      return 'Your readiness score indicates a high-aptitude curriculum — reduced, refined, and adapted to your level.';
    }
    if (readinessScore >= 66) {
      return 'Your readiness score indicates a condensed curriculum — targeting your gaps, building on your strengths.';
    }
    if (readinessScore >= 41) {
      return 'Your readiness score indicates a weighted curriculum — adjusted to your aptitude, focused where it counts most.';
    }
    return 'Your readiness score indicates a comprehensive curriculum — every category built from the ground up, calibrated to your results.';
  }

  String _actionLine(int readinessScore) {
    if (readinessScore >= 85) {
      return 'Very high aptitude detected. Minor study needed — fine-tune with the Peace of Mind tools and 60-Second modules and you\'re ready.';
    }
    if (readinessScore >= 66) {
      return 'You\'ve shown real aptitude. Your personalized study plan has been adapted to your knowledge level — a focused 2–3 day window should have you 100% ready to take the exam.';
    }
    if (readinessScore >= 41) {
      return 'Your personalized curriculum eliminates the guesswork — no unnecessary questions, just what you need. With your study plan and Peace of Mind tools, most students in your range are 100% exam-ready in 3–4 days.';
    }
    return 'Focused daily study gets you there fast. On average, students at your level are exam-ready in 5 days or less.';
  }

  Future<void> _runSequence() async {
    final state = AppState();
    final q = widget.questionsAnswered;
    final covered = widget.coveredCategories;
    final fullData = q >= 30;

    final scoredCategories = List<String>.from(covered)
      ..sort(
        (a, b) =>
            state.getCategoryScore(a).compareTo(state.getCategoryScore(b)),
      );

    final overallScore = state.getOverallScore();
    final highPerformer =
        !fullData && overallScore >= AppState.masteryThreshold;

    await _typeLine('$q responses received and locked in.');

    if (fullData) {
      await _typeLine('Full dataset confirmed...');
    } else if (highPerformer) {
      await _typeLine('Partial dataset received...');
      await _typeLine('Early indicators exceptional...');
    } else {
      await _typeLine('Analyzing partial data...');
      await _typeLine('Determining sufficiency...');
    }

    if (fullData || highPerformer) {
      final toShow = scoredCategories.take(3).toList();
      for (final cat in toShow) {
        final score = state.getCategoryScore(cat);
        final weight = ((_categoryWeights[cat] ?? 0.02) * 100).round();
        final fully = _fullyCovered(cat);
        if (!fully) {
          await _typeLine(
            'Partial data for $cat — gathering external benchmarks...',
          );
        } else if (score >= AppState.masteryThreshold) {
          await _typeLine(
            'Sufficient data — $cat confirmed ($weight% of exam).',
          );
        } else {
          await _typeLine(
            'Sufficient data — personalizing $cat ($weight% of exam).',
          );
        }
      }

      if (scoredCategories.isNotEmpty) {
        final focus = scoredCategories.first;
        if (state.getCategoryScore(focus) < AppState.masteryThreshold) {
          await _typeLine('$focus flagged for immediate focus.');
        }
      }

      final unseen = AppState.allCategories
          .where((c) => !covered.contains(c))
          .toList();
      if (unseen.isNotEmpty) {
        await _typeLine(
          'Insufficient data for ${unseen.first} — gathering external benchmarks...',
        );
        await _typeLine('SafePrep adjusting...');
      }
    } else {
      final fullyCoveredCats = scoredCategories
          .where((c) => _fullyCovered(c))
          .take(2)
          .toList();
      final partiallyCoveredCats = scoredCategories
          .where((c) => !_fullyCovered(c))
          .toList();

      for (final cat in fullyCoveredCats) {
        await _typeLine('Able to process $cat personalization.');
      }

      final unseen = AppState.allCategories
          .where((c) => !covered.contains(c))
          .toList();
      final partialCount = partiallyCoveredCats.length + unseen.length;
      if (partialCount > 0) {
        final categoryWord = partialCount == 1 ? 'category' : 'categories';
        await _typeLine(
          'Insufficient data for $partialCount $categoryWord — redirecting...',
        );
      }

      await _typeLine('Gathering external ServSafe® performance data...');
      await _typeLine('Cross-referencing national pass rates...');
      await _typeLine('SafePrep adjusting...');
      await _typeLine('Computing...');
      await _typeLine('Computing...');
    }

    if (highPerformer) {
      await _typeLine('SafePrep calibrating to advanced track...');
    } else {
      await _typeLine('Calibrating final curriculum weights...');
    }

    final readinessScore = ReadinessEngine.calculate(state);

    await _typeLine(
      _punchline(readinessScore),
      isPunchline: true,
      preDelayMs: 600,
    );

    await _typeLine(
      'Your curriculum is ready.',
      isPayoff: true,
      preDelayMs: 500,
    );

    await _typeLine(
      _actionLine(readinessScore),
      isActionLine: true,
      preDelayMs: 500,
    );

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _showMeter = true);

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _done = true;
      _showButton = true;
    });
  }

  void _onContinue() {
    _pulseController.stop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PreviewRevealPage()),
    );
  }

  Widget _buildPartialStars(int score) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starMin = i * 20.0;
        final starMax = (i + 1) * 20.0;
        double fill = 0.0;
        if (score >= starMax) {
          fill = 1.0;
        } else if (score > starMin) {
          fill = (score - starMin) / 20.0;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: SizedBox(
            width: 22,
            height: 24,
            child: Stack(
              children: [
                const Text(
                  '★',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF333300),
                    height: 1.1,
                  ),
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: fill,
                    child: const Text(
                      '★',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFFD4AF37),
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildReadinessMeter() {
    final state = AppState();
    final score = ReadinessEngine.calculate(state);
    final isGreen = score >= 100;

    String label;
    if (score >= 100) {
      label = '🟢 Green Light';
    } else if (score >= 85) {
      label = 'Nearly Ready';
    } else if (score >= 66) {
      label = 'Almost There';
    } else if (score >= 41) {
      label = 'Building Momentum';
    } else {
      label = 'Keep Going';
    }

    return AnimatedOpacity(
      opacity: _showMeter ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isGreen
              ? const Color(0xFF0A1F0A)
              : _gold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGreen
                ? Colors.green.shade700.withValues(alpha: 0.5)
                : _gold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              'ServSafe Readiness',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _gold.withValues(alpha: 0.7),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            _buildPartialStars(score),
            const SizedBox(height: 8),
            Text(
              '$score%',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isGreen ? Colors.green.shade400 : _gold,
              ),
            ),
            const SizedBox(height: 2),
            if (score > 5)
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isGreen
                      ? Colors.green.shade400
                      : _gold.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  color: _gold.withValues(alpha: 0.06),
                ),
                child: const Icon(Icons.auto_awesome, color: _gold, size: 22),
              ),

              const SizedBox(height: 16),

              Text(
                'SafePrep™ Engine',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _gold.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              // Lines — fills available space
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _lines.map((line) {
                      final isActionLine = line['isActionLine'] as bool;
                      final displayedText = line['displayedText'] as String;
                      final checked = line['checked'] as bool;
                      final isPayoff = line['isPayoff'] as bool;
                      final isPunchline = line['isPunchline'] as bool;

                      if (isActionLine && checked) {
                        return AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _pulseAnim.value,
                              child: child,
                            );
                          },
                          child: _buildLine(
                            displayedText,
                            checked: checked,
                            isPayoff: isPayoff,
                            isPunchline: isPunchline,
                            isActionLine: true,
                          ),
                        );
                      }

                      return _buildLine(
                        displayedText,
                        checked: checked,
                        isPayoff: isPayoff,
                        isPunchline: isPunchline,
                        isActionLine: isActionLine,
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Meter
              if (_showMeter) ...[
                _buildReadinessMeter(),
                const SizedBox(height: 16),
              ],

              // Progress bar
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (context, _) {
                  return Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _done ? 1.0 : _progressAnim.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _done
                                    ? _gold
                                    : _gold.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _done
                            ? 'Complete'
                            : '${(_progressAnim.value * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: _gold.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Button — pinned to bottom
              if (_showButton) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _onContinue,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        "Great news →",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(0xFF0A0A0F),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(
    String text, {
    required bool checked,
    required bool isPayoff,
    required bool isPunchline,
    required bool isActionLine,
  }) {
    final isSpecial = isPayoff || isPunchline || isActionLine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: checked
                  ? Icon(
                      Icons.check,
                      key: const ValueKey('checked'),
                      size: isSpecial ? 16 : 13,
                      color: _gold,
                    )
                  : SizedBox(
                      key: const ValueKey('unchecked'),
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _gold.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isPayoff
                    ? 15
                    : isPunchline
                    ? 13
                    : isActionLine
                    ? 12
                    : 12,
                fontWeight: isPayoff
                    ? FontWeight.w700
                    : isPunchline
                    ? FontWeight.w500
                    : isActionLine
                    ? FontWeight.w400
                    : FontWeight.w300,
                color: isPayoff
                    ? _gold
                    : isPunchline
                    ? _gold.withValues(alpha: 0.85)
                    : isActionLine
                    ? _gold.withValues(alpha: 0.7)
                    : _mutedWhite,
                height: 1.5,
                letterSpacing: isPayoff ? 0.3 : 0.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
