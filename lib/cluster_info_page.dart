import 'package:flutter/material.dart';
import 'constants.dart';
import 'mixpanel_service.dart';
import 'fsme_popup.dart';

/// The five navigable clusters of the app. Order here is also the
/// canonical display order everywhere this enum is iterated (landing
/// page buttons, Settings list).
enum AppCluster { assessment, dashboardStudy, trainers, finalExam, settings }

/// Where the user launched this page from. Content is identical either
/// way — only the return behavior and the Mixpanel `source` property
/// differ. Landing-page context returns to the one-time post-purchase
/// tour; settings context returns to the Settings page. Both are, at
/// the mechanical level, just Navigator.pop() — the flag exists so the
/// bottom button's label and the analytics are a correct read of which
/// flow the user was actually in.
enum ClusterLaunchContext { landing, settings }

/// A single unit of content within a cluster's explanation. Clusters
/// with little to say (Assessment, Trainers, Final Exam) use a couple
/// of paragraph blocks. Clusters with more ground to cover (Dashboard
/// & Study, Settings) can mix in a heading block and a bullets block
/// to break their content into named sub-sections — without needing a
/// different page layout or a separate file per cluster.
sealed class _ContentBlock {
  const _ContentBlock();
}

class _Paragraph extends _ContentBlock {
  final String text;
  const _Paragraph(this.text);
}

class _Heading extends _ContentBlock {
  final String text;
  const _Heading(this.text);
}

class _Bullets extends _ContentBlock {
  final List<String> items;
  const _Bullets(this.items);
}

class _ClusterContent {
  final String title;
  final String eyebrow;
  final IconData icon;
  final List<_ContentBlock> blocks;
  final String fsmeLine;

  const _ClusterContent({
    required this.title,
    required this.eyebrow,
    required this.icon,
    required this.blocks,
    required this.fsmeLine,
  });
}

class ClusterInfoPage extends StatelessWidget {
  final AppCluster cluster;
  final ClusterLaunchContext launchContext;

  const ClusterInfoPage({
    super.key,
    required this.cluster,
    required this.launchContext,
  });

  static const Map<AppCluster, _ClusterContent> _content = {
    AppCluster.assessment: _ClusterContent(
      eyebrow: 'THE ASSESSMENT',
      title: 'A full picture, not a guess',
      icon: Icons.fact_check_outlined,
      blocks: [
        _Paragraph(
          'The Assessment is a 30-question test drawn from every '
          'category on the real exam, weighted to match how often '
          'each topic actually appears.',
        ),
        _Paragraph(
          'It scores you category by category, not just overall — so '
          'you can see exactly where your gaps are instead of one '
          'flat number.',
        ),
        _Paragraph(
          'Results feed directly into your Dashboard: any category '
          'you score 85% or higher on is marked mastered, and the '
          'rest become your study priorities.',
        ),
        _Paragraph(
          'You can take it anytime, and retake it as often as you '
          'want as your knowledge improves.',
        ),
      ],
      fsmeLine:
          "This is the boss's baby — her engine, her algorithm. I "
          "just stand here and look supportive.",
    ),
    AppCluster.dashboardStudy: _ClusterContent(
      eyebrow: 'DASHBOARD & STUDY',
      title: 'Your progress, category by category',
      icon: Icons.dashboard_customize_outlined,
      blocks: [
        _Paragraph(
          'The Dashboard is your curriculum progress, category by '
          'category — every category broken out on its own card.',
        ),
        _Heading('What each card shows'),
        _Bullets([
          'Your current score in that category, once you have one',
          'How it compares to your baseline (your first score there)',
          'A Study button that opens that category\'s material',
        ]),
        _Heading('How Study adapts'),
        _Paragraph(
          'Study content adjusts to how you\'re doing in that '
          'category: struggling gets you extra support, close-but-not-'
          'there gets a focused review, and a fresh category gets the '
          'standard walkthrough.',
        ),
        _Heading('Mastered categories'),
        _Paragraph(
          'Once a category is studied and scores 85% or higher, it '
          'moves to the Mastered section below your active study '
          'list — so you can always see what\'s locked in versus what '
          'still needs work.',
        ),
      ],
      fsmeLine:
          "I like flying \u2014 all the gauges and clusters really "
          "floats my circuits.",
    ),
    AppCluster.trainers: _ClusterContent(
      eyebrow: '60-SECOND TRAINERS',
      title: 'Quick tools for quick moments',
      icon: Icons.bolt_outlined,
      blocks: [
        _Paragraph(
          'Five short-burst tools for whenever you have a spare '
          'minute: Flash Cards, Rapid Fire, Scenario Drills, Proctor '
          'Tips, and Mnemonics.',
        ),
        _Paragraph(
          'These aren\'t a replacement for the core curriculum '
          '(Boss told me to say that). But once you\'ve got a good '
          'knowledge base, these will get you over that hump — '
          'quick reinforcement, right before the exam or anytime '
          'you want a fast confidence check.',
        ),
        _Paragraph('Each one is short by design. No long sessions required.'),
      ],
      fsmeLine:
          "Okay, THESE — these I built. All five. Byte-Me conference, "
          "first place. I don't bring it up much.",
    ),
    AppCluster.finalExam: _ClusterContent(
      eyebrow: 'THE FINAL EXAM',
      title: 'A full run at the real thing',
      icon: Icons.workspace_premium_outlined,
      blocks: [
        _Paragraph(
          'The Final Exam is a full-length simulation built to '
          'mirror the real ServSafe exam — same question count, same '
          'category distribution.',
        ),
        _Paragraph(
          'It\'s always available — take it whenever you feel ready. '
          'There\'s no gate to unlock; that\'s your call.',
        ),
        _Paragraph(
          'Treat it like the real thing: one sitting, no looking '
          'things up. Your score here is the clearest signal of '
          'where you stand.',
        ),
      ],
      fsmeLine:
          "This part's serious. Even I don't joke around here. "
          "...okay, one joke. But that's it.",
    ),
    AppCluster.settings: _ClusterContent(
      eyebrow: 'SETTINGS',
      title: 'Account, access, and this tour',
      icon: Icons.settings_outlined,
      blocks: [
        _Heading('Purchase & access'),
        _Paragraph(
          'Your purchase details and access status live here — what '
          'you bought, and how long it\'s active.',
        ),
        _Heading('Revisit these explanations'),
        _Paragraph(
          'All five of these pages — Assessment, Dashboard & Study, '
          'Trainers, Final Exam, and this one — are available here '
          'anytime. You only get the guided tour once, but nothing '
          'about it is gone for good.',
        ),
        _Heading('Everything else'),
        _Bullets(['General app information', 'Support and contact details']),
      ],
      fsmeLine: "Honestly? This is just the junk drawer. Every app has one.",
    ),
  };

  String get _mixpanelSource => launchContext == ClusterLaunchContext.landing
      ? 'post_purchase_landing'
      : 'settings';

  String get _buttonLabel =>
      launchContext == ClusterLaunchContext.landing ? 'Got it' : 'Done';

  Widget _buildBlock(_ContentBlock block) {
    switch (block) {
      case _Paragraph(:final text):
        return Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.bodyText,
            height: 1.55,
          ),
        );
      case _Heading(:final text):
        return Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryButton,
          ),
        );
      case _Bullets(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            for (final item in items)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryButton,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.bodyText,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content[cluster]!;

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.bodyText),
                    onPressed: () {
                      MixpanelService.instance.track(
                        'cluster_info_closed',
                        properties: {
                          'cluster': cluster.name,
                          'source': _mixpanelSource,
                          'method': 'back_arrow',
                          'app_name': 'SP',
                        },
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSizes.pageMargin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Icon(
                          content.icon,
                          size: 26,
                          color: AppColors.primaryButton,
                        ),
                      ),
                    ),
                    Text(
                      content.eyebrow,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                        color: AppColors.subtleText,
                      ),
                    ),
                    Text(
                      content.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.strongText,
                        height: 1.3,
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(
                          AppSizes.cardCornerRadius,
                        ),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          for (final block in content.blocks)
                            _buildBlock(block),
                        ],
                      ),
                    ),
                    // Light FSME touch — one line, not a scene. The
                    // clinical content above does the actual
                    // explaining; this is just enough personality to
                    // keep it from reading like a manual page.
                    FsmePopup(lines: [FsmeLine(content.fsmeLine)]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: AppSizes.primaryButtonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    MixpanelService.instance.track(
                      'cluster_info_closed',
                      properties: {
                        'cluster': cluster.name,
                        'source': _mixpanelSource,
                        'method': 'button',
                        'app_name': 'SP',
                      },
                    );
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.buttonCornerRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    _buttonLabel,
                    style: const TextStyle(
                      fontSize: AppFonts.button,
                      fontWeight: FontWeight.w700,
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
}
