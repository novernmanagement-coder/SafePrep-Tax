import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'home_page.dart';
import 'safe_prep_nav_bar.dart';

// NOTE: file kept as about_proctors_page.dart (no rename — this device
// can't rename/delete files). Content has moved twice now: originally
// the ServSafe proctor-info page, briefly an "Interview Primer" page,
// now a Glossary of Terms — a running reference for the vocabulary used
// throughout the app and the Intuit exam itself. Grouped by category so
// it doubles as a quick refresher per topic, not just an alphabetical
// dump.
//
// Sept 2026: converted from a hardcoded Dart list to CSV-driven
// (GlossaryTerms.csv, via GlossaryTermLoader in csv_loader.dart) so
// this page and the separate Glossary of Terms QUIZ (ServSafeProTips.csv)
// don't require editing two different places for what's conceptually
// the same term data.
class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key});

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  List<GlossaryTermModel> _terms = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final terms = await GlossaryTermLoader.loadAll();
    if (!mounted) return;
    setState(() {
      _terms = terms;
      _loaded = true;
    });
  }

  /// Groups terms by category, preserving the order categories first
  /// appear in the CSV (not alphabetical, not shuffled) so the page
  /// reads the same way every time.
  List<MapEntry<String, List<GlossaryTermModel>>> get _groupedByCategory {
    final order = <String>[];
    final byCategory = <String, List<GlossaryTermModel>>{};
    for (final t in _terms) {
      if (!byCategory.containsKey(t.category)) {
        order.add(t.category);
        byCategory[t.category] = [];
      }
      byCategory[t.category]!.add(t);
    }
    return order.map((c) => MapEntry(c, byCategory[c]!)).toList();
  }

  Widget _buildCard(String title, List<GlossaryTermModel> terms) {
    return Container(
      padding: AppSizes.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.strongText,
              )),
          ...terms.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: AppColors.bodyText, height: 1.35),
                  children: [
                    TextSpan(
                      text: '${t.term} — ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: t.definition),
                  ],
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
                    // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HomePage()),
                      ),
                      child: Row(
                        children: [
                          Text('Tax',
                              style: TextStyle(
                                fontSize: AppFonts.header,
                                fontWeight: FontWeight.w600,
                                color: AppColors.bodyText,
                              )),
                          const SizedBox(width: 6),
                          Image.asset('Assets/splash.png',
                              width: 36, height: 36),
                          const SizedBox(width: 6),
                          Text('Starter:',
                              style: TextStyle(
                                fontSize: AppFonts.header,
                                fontWeight: FontWeight.w600,
                                color: AppColors.bodyText,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Text('Glossary of Terms',
                  style: TextStyle(
                    fontSize: AppFonts.header,
                    fontWeight: FontWeight.bold,
                    color: AppColors.strongText,
                  ),
                  textAlign: TextAlign.center),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Quick definitions for the terms you\'ll see throughout the app and on the exam, grouped by category.',
                  style: TextStyle(fontSize: 13, color: AppColors.bodyText),
                  textAlign: TextAlign.center,
                ),
              ),

              if (!_loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                )
              else
                ..._groupedByCategory.map(
                  (entry) => _buildCard(entry.key, entry.value),
                ),

              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  spacing: AppSizes.footerSpacing,
                  children: [
                    Text(AppStrings.footerLine1,
                        style: TextStyle(
                            fontSize: AppFonts.footer,
                            color: AppColors.footerText),
                        textAlign: TextAlign.center),
                    Text(AppStrings.footerLine2,
                        style: TextStyle(
                            fontSize: AppFonts.footer,
                            color: AppColors.footerText),
                        textAlign: TextAlign.center),
                    Text(AppStrings.footerLine3,
                        style: TextStyle(
                            fontSize: AppFonts.footer,
                            color: AppColors.starMotifBlue),
                        textAlign: TextAlign.center),
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
