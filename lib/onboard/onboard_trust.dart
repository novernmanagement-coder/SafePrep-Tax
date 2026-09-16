import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_content_preference.dart';

/// Onboarding screen 2 of the new flow — the trust page.
///
/// Sits between the credential-based Intro screen and Content
/// Preference. Where Intro earns trust through credentials, this
/// screen earns trust through capability — a plain, concrete
/// statement of what the app actually does: unlimited randomized
/// quizzes, a real question bank, a full mock exam, and a category
/// breakdown weighted to match the real Intuit Tax Level 1 exam
/// blueprint.
///
/// Deliberately static — no FSME here. Per the redesigned funnel his
/// role is being trimmed way down; this screen has no natural comedy
/// beat anyway, since it's a pure capability pitch.
class OnboardTrust extends StatelessWidget {
  const OnboardTrust({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  /// Category weight, ordered to follow the Form 1040 entry sequence
  /// — same order as AppState.allCategories (see its comment for the
  /// full reasoning), not sorted by weight. Short labels match the
  /// ones used in rapid_fire_limited_page.
  static const List<_CategoryWeight> _categoryWeights = [
    _CategoryWeight('Filing Basics', 18),
    _CategoryWeight('Income', 16),
    _CategoryWeight('Retirement', 22),
    _CategoryWeight('Adjustments', 9),
    _CategoryWeight('HSA', 5),
    _CategoryWeight('Deductions', 6),
    _CategoryWeight('Tax Credits', 17),
    _CategoryWeight('Multi-State', 7),
  ];

  /// Header row: back chevron, centred progress, balancing spacer.
  /// Matches the pattern used on the other onboarding screens.
  Widget _header(BuildContext context, int filled, int total) {
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

  /// One 2x2 capability tile — icon, label.
  Widget _capabilityTile(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _gold),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _softWhite,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Full-width callout for the Interview Primer feature — sits below
  /// the 2x2 capability grid since it's a standout differentiator,
  /// not just another stat tile.
  Widget _interviewPrepBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.record_voice_over_outlined, size: 20, color: _gold),
          const SizedBox(height: 8),
          Text(
            'Our exclusive Intuit interview Prep module',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _softWhite,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Secrets to acing the interview',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: _gold.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// One category-weight row — name, percentage, proportional bar.
  Widget _categoryRow(_CategoryWeight cat, int maxPercent) {
    final double fraction = cat.percent / maxPercent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _softWhite,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${cat.percent}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Stack(
                children: [
                  Container(color: _softWhite.withValues(alpha: 0.1)),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: Container(color: _gold),
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
    // No longer sorted highest-to-lowest (now in 1040 order), so the
    // max has to be computed rather than assumed to be the first item.
    final int maxPercent = _categoryWeights
        .map((c) => c.percent)
        .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, 2, 5),

              const SizedBox(height: 26),

              Text(
                'WHAT YOU GET',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                  color: _gold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Your study plan, built from these core elements',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _softWhite.withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Everything you need.\nNothing you don\u2019t.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 20),

              // 2x2 capability grid.
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.35,
                children: [
                  _capabilityTile(
                    Icons.all_inclusive,
                    'Unlimited randomized quizzes',
                  ),
                  _capabilityTile(
                    Icons.bar_chart_rounded,
                    'Readiness and progress tracking',
                  ),
                  _capabilityTile(
                    Icons.checklist_rtl_outlined,
                    '300+ Intuit Tax aligned questions',
                  ),
                  _capabilityTile(
                    Icons.workspace_premium_outlined,
                    'Full 217 question exam',
                  ),
                ],
              ),

              const SizedBox(height: 8),

              _interviewPrepBox(),

              const SizedBox(height: 12),

              Text(
                'Questions adapt to your progress',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: _gold.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Weighted to match the real exam',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: _softWhite.withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(height: 10),

              // 2-column weighted category grid.
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.6,
                children: [
                  for (final cat in _categoryWeights)
                    _categoryRow(cat, maxPercent),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    MixpanelService.instance.track(
                      'SpOn_Trust_Next',
                      properties: {'app_name': 'ST'},
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnboardContentPreference(),
                      ),
                    );
                  },
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
                    'NEXT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Curriculum based on Intuit Tax Academy Level 1 material',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _softWhite.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category's weight for the trust-page breakdown.
class _CategoryWeight {
  final String label;
  final int percent;
  const _CategoryWeight(this.label, this.percent);
}
