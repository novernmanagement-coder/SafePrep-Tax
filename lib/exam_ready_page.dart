import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'dashboard_page.dart';
import 'safe_prep_nav_bar.dart';

class ExamReadyPage extends StatefulWidget {
  final int overallScore;

  const ExamReadyPage({super.key, required this.overallScore});

  @override
  State<ExamReadyPage> createState() => _ExamReadyPageState();
}

class _ExamReadyPageState extends State<ExamReadyPage> {
  final AppState _state = AppState();
  final List<double> _starOpacities = [0, 0, 0, 0, 0];
  double _scorePanelOpacity = 0;
  double _categoryStackOpacity = 0;
  double _actionsPanelOpacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), _runCelebration);
  }

  Future<void> _runCelebration() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      setState(() => _starOpacities[i] = 1.0);
    }
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _scorePanelOpacity = 1.0);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _categoryStackOpacity = 1.0);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _actionsPanelOpacity = 1.0);
  }

  Widget _buildCategoryCard(String category) {
    final score = _state.getCategoryScore(category);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2C4A6A), width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF4DA3FF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              color: AppColors.scoreBand4,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '✓ Mastered',
            style: TextStyle(color: AppColors.scoreBand4, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = AppState.allCategories;
    final rows = <Widget>[];
    for (int i = 0; i < categories.length; i += 2) {
      final cat1 = categories[i];
      final cat2 = i + 1 < categories.length ? categories[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(child: _buildCategoryCard(cat1)),
            const SizedBox(width: 10),
            Expanded(
              child: cat2 != null ? _buildCategoryCard(cat2) : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < categories.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Column(
                        spacing: 4,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Safe',
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
                                'Prep™',
                                style: TextStyle(
                                  fontSize: AppFonts.header,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.bodyText,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            "You're ready.",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Go let everyone know!',
                            style: TextStyle(
                              fontSize: AppFonts.body,
                              color: AppColors.subtleText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        spacing: 16,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (i) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: AnimatedOpacity(
                                  opacity: _starOpacities[i],
                                  duration: const Duration(milliseconds: 300),
                                  child: const Text(
                                    '★',
                                    style: TextStyle(
                                      fontSize: 30,
                                      color: Color(0xFFF0C575),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          AnimatedOpacity(
                            opacity: _scorePanelOpacity,
                            duration: const Duration(milliseconds: 400),
                            child: Column(
                              spacing: 4,
                              children: [
                                const Text(
                                  'FINAL EXAM SCORE',
                                  style: TextStyle(
                                    color: Color(0xFF4DA3FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${widget.overallScore}%',
                                  style: TextStyle(
                                    color: AppColors.scoreBand4,
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          const Divider(color: Color(0xFF2C2C2C)),

                          AnimatedOpacity(
                            opacity: _categoryStackOpacity,
                            duration: const Duration(milliseconds: 400),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 10,
                              children: [
                                const Text(
                                  'CATEGORY BREAKDOWN',
                                  style: TextStyle(
                                    color: Color(0xFF4DA3FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                _buildCategoryGrid(),
                              ],
                            ),
                          ),

                          const Divider(color: Color(0xFF2C2C2C)),

                          AnimatedOpacity(
                            opacity: _actionsPanelOpacity,
                            duration: const Duration(milliseconds: 400),
                            child: Column(
                              spacing: 10,
                              children: [
                                const Text(
                                  "You didn't just study. You prepared.",
                                  style: TextStyle(
                                    color: Color(0xFFE0E0E0),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DashboardPage(),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: const Color(0xFF8A8A8A),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'My Dashboard',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                Text(
                                  "If SafePrep helped you get here, we'd love to hear about it.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.subtleText,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
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
