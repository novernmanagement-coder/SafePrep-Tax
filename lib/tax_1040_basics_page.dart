import 'package:flutter/material.dart';
import 'constants.dart';
import 'home_page.dart';
import 'safe_prep_nav_bar.dart';
import 'tax_1040_income_page.dart';

// "1040 Basics" — a section-by-section walkthrough of the actual Form 1040,
// learn-by-doing style: each section is a drag-and-drop exercise that maps
// real-world income/expense items onto the actual line of the form they
// belong on. This page is just the landing menu; each button below pushes
// the section's own exercise page, and that page's back action returns
// here (not all the way to Home).
//
// Only "Income" has a built exercise so far (Sept 2026). The rest are
// listed as Coming soon so the full 6-section shape of the module is
// visible up front, and each can be swapped for a real page later without
// touching this file's layout.
class Tax1040BasicsPage extends StatelessWidget {
  const Tax1040BasicsPage({super.key});

  static const List<_SectionInfo> _sections = [
    _SectionInfo(
      title: 'Filing Status',
      subtitle: 'Which box at the top of the form applies to you',
      emoji: '🗂️',
      available: false,
    ),
    _SectionInfo(
      title: 'Income',
      subtitle: 'Drag each item onto the line it belongs on',
      emoji: '💰',
      available: true,
    ),
    _SectionInfo(
      title: 'Adjustments & AGI',
      subtitle: 'Schedule 1 adjustments that get you to Line 11',
      emoji: '⚖️',
      available: false,
    ),
    _SectionInfo(
      title: 'Deductions',
      subtitle: 'Standard vs. itemized, and what lands where',
      emoji: '📉',
      available: false,
    ),
    _SectionInfo(
      title: 'Credits',
      subtitle: 'Where credits reduce the tax you actually owe',
      emoji: '🎯',
      available: false,
    ),
    _SectionInfo(
      title: 'Payments & Refund',
      subtitle: 'Withholding, payments, and settling up',
      emoji: '🧾',
      available: false,
    ),
  ];

  void _openSection(BuildContext context, _SectionInfo section) {
    if (!section.available) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${section.title} — coming soon'),
          content: const Text(
            'This section is still being built. Income is ready to go now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Tax1040IncomeDragPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSizes.pageMargin,
                child: Column(
                  spacing: 12,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomePage(),
                              ),
                            ),
                            child: Row(
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
                                Image.asset(
                                  'Assets/splash.png',
                                  width: 36,
                                  height: 36,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Starter:',
                                  style: TextStyle(
                                    fontSize: AppFonts.header,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.bodyText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '1040 Basics',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.bold,
                        color: AppColors.strongText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Learn the exam by learning the form. Work through the real Form '
                        '1040 section by section — drag real-world items onto the line '
                        'they actually belong on.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.bodyText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ..._sections.asMap().entries.map((entry) {
                      final index = entry.key;
                      final section = entry.value;
                      return _SectionButton(
                        number: index + 1,
                        total: _sections.length,
                        section: section,
                        onTap: () => _openSection(context, section),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        spacing: AppSizes.footerSpacing,
                        children: [
                          Text(
                            AppStrings.footerLine1,
                            style: TextStyle(
                              fontSize: AppFonts.footer,
                              color: AppColors.footerText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            AppStrings.footerLine2,
                            style: TextStyle(
                              fontSize: AppFonts.footer,
                              color: AppColors.footerText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SafePrepNavBar(),
          ],
        ),
      ),
    );
  }
}

class _SectionInfo {
  final String title;
  final String subtitle;
  final String emoji;
  final bool available;

  const _SectionInfo({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.available,
  });
}

class _SectionButton extends StatelessWidget {
  final int number;
  final int total;
  final _SectionInfo section;
  final VoidCallback onTap;

  const _SectionButton({
    required this.number,
    required this.total,
    required this.section,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = section.available
        ? AppColors.primaryButton
        : AppColors.neutralButton;
    final Color fg = section.available
        ? AppColors.primaryButtonForeground
        : AppColors.neutralButtonForeground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
      child: Container(
        width: double.infinity,
        padding: AppSizes.cardPadding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
          border: Border.all(
            color: section.available
                ? AppColors.primaryButton
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Text(section.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    'Section $number of $total · ${section.title}',
                    style: TextStyle(
                      fontSize: AppFonts.button,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  Text(
                    section.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: fg.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            if (!section.available)
              Text(
                'Soon',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.subtleText,
                ),
              )
            else
              Icon(Icons.chevron_right, color: fg),
          ],
        ),
      ),
    );
  }
}
