import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_exam_date.dart';

/// Onboarding screen 3 of the new flow — ServSafe test history.
///
/// Replaces the diagnostic quiz entirely. Originally this asked the
/// user to self-assess their confidence (Confident / Prepared / Almost
/// ready / New to ServSafe) — that framing was dropped because it's a
/// judgment call, not a fact, and some people will round up rather
/// than admit low knowledge, even with no one watching. Asking about
/// test HISTORY instead is a plain fact nobody needs to feel awkward
/// answering honestly. Three flat, equal-weight options — no tier
/// language, no scope language ("full curriculum" vs "tune-up") —
/// since there's only one product to buy, there's nothing to
/// price-game toward. Selection only affects paywall subline copy and
/// a brief FSME reaction; it does NOT change the underlying
/// curriculum, pacing, or which category starts first.
///
/// Tap-until-confident interaction: selecting an option doesn't lock
/// it in or auto-advance — the user can freely re-select. The Continue
/// button only appears after the first tap, so nothing progresses
/// until they've actually chosen.
class OnboardKnowledgeLevel extends StatefulWidget {
  const OnboardKnowledgeLevel({super.key});

  @override
  State<OnboardKnowledgeLevel> createState() => _OnboardKnowledgeLevelState();
}

// KnowledgeLevel enum now lives in onboard_answers.dart (matching the
// ExamWindow / StudyStyle pattern) — imported above, not redefined here.

class _OnboardKnowledgeLevelState extends State<OnboardKnowledgeLevel> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  KnowledgeLevel? _selected;

  static const List<_LevelOption> _options = [
    _LevelOption(
      level: KnowledgeLevel.firstTime,
      label: 'First time test taker',
      subtitle: 'This is my first attempt',
    ),
    _LevelOption(
      level: KnowledgeLevel.takenBefore,
      label: 'Taken the test before',
      subtitle: 'I\u2019ve taken it once before',
    ),
    _LevelOption(
      level: KnowledgeLevel.takenMultiple,
      label: 'Taken it more than once',
      subtitle: 'I\u2019ve taken it a few times',
    ),
  ];

  void _choose(KnowledgeLevel level) {
    setState(() => _selected = level);

    MixpanelService.instance.track(
      'SpOn_Knowledge_Selected',
      properties: {'app_name': 'SP', 'level': level.tag},
    );
  }

  void _advance() {
    if (_selected == null) return;

    OnboardingAnswers.instance.knowledgeLevel = _selected;

    MixpanelService.instance.track(
      'SpOn_Knowledge_Continue',
      properties: {'app_name': 'SP', 'level': _selected!.tag},
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardExamDate()),
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

  /// One tappable level row. Free re-selection — tapping a different
  /// option just swaps which one is highlighted; nothing locks in
  /// until Continue is tapped.
  Widget _optionRow(_LevelOption option) {
    final bool isSelected = _selected == option.level;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _choose(option.level),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? _gold.withValues(alpha: 0.1) : _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? _gold : _gold.withValues(alpha: 0.3),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _softWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _softWhite.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
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
              _header(3, 6),

              const SizedBox(height: 26),

              Text(
                'SERVSAFE TEST HISTORY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w500,
                  color: _gold,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Have you taken\nthis exam before?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'All information kept strictly private.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _softWhite.withValues(alpha: 0.45),
                ),
              ),

              const SizedBox(height: 24),

              for (final option in _options) _optionRow(option),

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

/// One self-report option's static content.
class _LevelOption {
  final KnowledgeLevel level;
  final String label;
  final String subtitle;
  const _LevelOption({
    required this.level,
    required this.label,
    required this.subtitle,
  });
}
