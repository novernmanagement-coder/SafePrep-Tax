import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_study_style.dart';

/// Onboarding screen 4 of the new flow — "When's your exam?"
///
/// Three urgency bands, no calendar, no FSME. Per the redesigned
/// funnel's trimmed-role direction, this is now a quick selection
/// screen only — no reaction script, no sneak-peek modal sequence.
/// The band still feeds pacing language downstream (deadline framing,
/// per-day study estimates).
///
/// Same tap-until-confident interaction as the content-preference
/// screen: selecting doesn't lock in or auto-advance; Continue only
/// appears after the first tap.
class OnboardExamDate extends StatefulWidget {
  const OnboardExamDate({super.key});

  @override
  State<OnboardExamDate> createState() => _OnboardExamDateState();
}

class _OnboardExamDateState extends State<OnboardExamDate>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  ExamWindow? _selected;

  // Thumbs-up micro-interaction (Sept 2026): a small one-shot burst on
  // top of whichever row was just tapped -- floats up and fades, purely
  // a moment of positive reinforcement, no dialogue/FSME involvement.
  // Re-tapping the same or a different row simply replays it.
  late final AnimationController _thumbsUpController;
  late final Animation<double> _thumbsUpOffset;
  late final Animation<double> _thumbsUpOpacity;
  ExamWindow? _burstWindow;

  @override
  void initState() {
    super.initState();
    _thumbsUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _thumbsUpOffset = Tween<double>(begin: 0, end: -34).animate(
      CurvedAnimation(parent: _thumbsUpController, curve: Curves.easeOut),
    );
    _thumbsUpOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_thumbsUpController);
    _thumbsUpController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _burstWindow = null);
      }
    });
  }

  @override
  void dispose() {
    _thumbsUpController.dispose();
    super.dispose();
  }

  static String _bandTag(ExamWindow w) {
    switch (w) {
      case ExamWindow.oneToThree:
        return '1-2';
      case ExamWindow.fourToTen:
        return '3-4';
      case ExamWindow.tenPlus:
        return '5+';
      case ExamWindow.notScheduled:
        return 'not_scheduled';
    }
  }

  void _choose(ExamWindow window) {
    setState(() {
      _selected = window;
      _burstWindow = window;
    });
    _thumbsUpController.forward(from: 0);

    OnboardingAnswers.instance.examWindow = window;

    MixpanelService.instance.track(
      'SpOn_Date_Selected',
      properties: {
        'app_name': 'SP',
        'exam_window': window.tag,
        'band': _bandTag(window),
      },
    );
  }

  void _advance() {
    if (_selected == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OnboardStudyStyle()),
    );
  }

  /// Header row: back chevron, centred progress, balancing spacer.
  Widget _header(int filled, int total) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            alignment: Alignment.centerLeft,
            icon: Icon(
              Icons.chevron_left,
              size: 24,
              color: _softWhite.withValues(alpha: 0.4),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              return Container(
                width: 22,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: i < filled
                      ? _gold
                      : _softWhite.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 32),
      ],
    );
  }

  /// One tappable band row. Free re-selection, matching the
  /// knowledge-level screen's pattern.
  Widget _option(ExamWindow window, String label) {
    final bool isSelected = _selected == window;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _choose(window),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? _gold.withValues(alpha: 0.12) : _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _gold : _gold.withValues(alpha: 0.3),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _softWhite,
                        ),
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.check : Icons.chevron_right,
                      size: 18,
                      color: isSelected ? _gold : _gold.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_burstWindow == window)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _thumbsUpController,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset(0, _thumbsUpOffset.value),
                        child: Opacity(
                          opacity: _thumbsUpOpacity.value,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.thumb_up,
                    color: _gold,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(4, 5),

              const SizedBox(height: 26),

              const Icon(Icons.event_outlined, size: 28, color: _gold),

              const SizedBox(height: 12),

              const Text(
                "When's your exam?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _softWhite,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'So we can optimize your plan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _softWhite.withValues(alpha: 0.5),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 26),

              _option(ExamWindow.oneToThree, '1\u20132 days'),
              _option(ExamWindow.fourToTen, '3\u20134 days'),
              _option(ExamWindow.tenPlus, '5+ days'),

              if (_selected != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _advance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _darkBg,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonCornerRadius,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Continue  \u2192',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
}
