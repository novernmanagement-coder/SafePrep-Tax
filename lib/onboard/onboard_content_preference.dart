import 'package:flutter/material.dart';
import '../constants.dart';
import '../fsme_eye.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_exam_date.dart';

/// Onboarding screen 3 of the new flow -- content preference.
///
/// Sits right after the two trust screens (Intro, then the "what you
/// get" Trust page) and before Exam Date / Study Style. Moved up here
/// (rather than staying the last question before the paywall) after
/// the standalone Knowledge Level / test-history question was removed
/// from the funnel entirely -- that question was seen as a real
/// drop-off risk since people may not answer it truthfully (see
/// [[safeprep-onboarding]]), so rather than keep asking it in any
/// form, it's just gone, with nothing replacing it directly.
///
/// This is a ROUTING choice, not a content-tiering one -- see
/// [ContentPreference] for the full reasoning. No new content exists
/// for any of the three options; each just points at something
/// already built (Dashboard & Study, the Assessment, or Trainers).
/// Nothing is gated by the answer -- it only sets a default starting
/// point and shows up on the paywall recap.
///
/// Same tap-until-confident interaction as the other onboarding
/// screens: selecting doesn't lock in or auto-advance; Continue only
/// appears after the first tap.
class OnboardContentPreference extends StatefulWidget {
  const OnboardContentPreference({super.key});

  @override
  State<OnboardContentPreference> createState() =>
      _OnboardContentPreferenceState();
}

class _OnboardContentPreferenceState extends State<OnboardContentPreference> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  ContentPreference? _selected;

  // Passive FSME touch (Sept 2026): no dialogue, no popup, doesn't
  // block or slow the screen down -- just idle EyeMood.idle (which
  // already ambient-darts/looks-around on its own, nothing extra
  // needed for that part) sitting at the bottom, plus a one-shot wink
  // when the user makes a selection. Deliberately NOT a reaction line
  // -- the paywall already carries FSME's dedicated reaction to this
  // exact choice (OnboardPaywall._contentLineFor), so this stays
  // decoration only, consistent with the locked "keep this stretch of
  // the funnel frictionless" decision (see [[safeprep-onboarding]]).
  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();

  static const List<_PreferenceOption> _options = [
    _PreferenceOption(
      preference: ContentPreference.fullCurriculum,
      label: 'Full Curriculum',
      subtitle: 'Show me everything, already loaded and ready to go',
    ),
    _PreferenceOption(
      preference: ContentPreference.hotTopics,
      label: 'Hot Topics',
      subtitle: 'Focus on my weak spots -- we’ll find those first',
    ),
    _PreferenceOption(
      preference: ContentPreference.refresher,
      label: 'Refresher',
      subtitle: 'Just a quick refresher -- we’ve got tools built for that',
    ),
  ];

  void _choose(ContentPreference preference) {
    setState(() => _selected = preference);
    _eyeKey.currentState?.wink();

    MixpanelService.instance.track(
      'SpOn_ContentPref_Selected',
      properties: {'app_name': 'SP', 'content_preference': preference.tag},
    );
  }

  void _advance() {
    if (_selected == null) return;

    OnboardingAnswers.instance.contentPreference = _selected;

    MixpanelService.instance.track(
      'SpOn_ContentPref_Continue',
      properties: {'app_name': 'SP', 'content_preference': _selected!.tag},
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

  /// One tappable preference row. Free re-selection, matching the
  /// pattern used on every other onboarding screen.
  Widget _optionRow(_PreferenceOption option) {
    final bool isSelected = _selected == option.preference;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _choose(option.preference),
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
              _header(3, 5),

              const SizedBox(height: 26),

              Text(
                'ONE LAST THING',
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
                'What do you want\nto focus on?',
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
                'Nothing is locked in — you can explore everything '
                'either way.',
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
                      'Continue  →',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              Center(
                child: FsmeEyePair(
                  key: _eyeKey,
                  mood: EyeMood.idle,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One content-preference option's static content.
class _PreferenceOption {
  final ContentPreference preference;
  final String label;
  final String subtitle;
  const _PreferenceOption({
    required this.preference,
    required this.label,
    required this.subtitle,
  });
}
