// lib/mock/mock_final_exam_grade_page.dart
// ─────────────────────────────────────────────────────────────────────────────
// MOCK SCREEN — App Store Screenshot use only. Remove before production build.
// Shot 3: Final Exam Results — "payoff"
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class MockFinalExamGradePage extends StatelessWidget {
  const MockFinalExamGradePage({super.key});

  // ── Hardcoded ideal data ──────────────────────────────────────────────────
  static const int _overallScore = 94;

  static const List<Map<String, dynamic>> _categories = [
    {'name': 'Time & Temperature', 'score': 96},
    {'name': 'Cross-Contamination', 'score': 100},
    {'name': 'Food Preparation', 'score': 92},
    {'name': 'Receiving & Storage', 'score': 91},
    {'name': 'Personal Hygiene', 'score': 90},
    {'name': 'Cleaning & Sanitizing', 'score': 95},
    {'name': 'Facility & Equipment', 'score': 93},
    {'name': 'Food Safety Management', 'score': 94},
  ];

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color _bgBlue = Color(0xFF0A1628);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _cardBorder = Color(0xFFDDDDDD);
  static const Color _strongText = Color(0xFF1A1A1A);
  static const Color _subtleText = Color(0xFF888888);
  static const Color _bodyText = Color(0xFFE0E0E0);
  static const Color _greenScore = Color(0xFF2E7D32);
  static const Color _goldFrame = Color(0xFFD4AF37);
  static const Color _primaryButton = Color(0xFF1A3A6B);
  static const Color _bannerBg = Color(0xFF2E4374);
  static const Color _bannerBorder = Color(0xFFF0C575);
  static const Color _bannerSub = Color(0xFFC7D3EC);

  Color _scoreColor(int score) {
    if (score <= 50) return const Color(0xFFE53935);
    if (score <= 65) return const Color(0xFFFF7043);
    if (score <= 84) return const Color(0xFFFFB300);
    return _greenScore;
  }

  Widget _buildCategoryRow(String category, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _strongText,
              ),
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _scoreColor(score),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenContent = Scaffold(
      backgroundColor: _bgBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Safe',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: _bodyText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Image.asset('Assets/splash.png', width: 36, height: 36),
                    const SizedBox(width: 6),
                    Text(
                      'Prep™',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: _bodyText,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Wow banner ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _bannerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _bannerBorder, width: 1.5),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'We said you were ready.\nWe were right.',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '94% on the exam. The Readiness Index called it.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _bannerSub,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Your Results label ───────────────────────────────────────
              Text(
                'Your Results',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _bodyText,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // ── Overall score card ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      'Overall Score',
                      style: TextStyle(fontSize: 12, color: _subtleText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_overallScore%',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor(_overallScore),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Category breakdown ───────────────────────────────────────
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _bodyText,
                    ),
                  ),
                ),
              ),

              ..._categories.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildCategoryRow(
                    cat['name'] as String,
                    cat['score'] as int,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Primary button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryButton,
                    disabledBackgroundColor: _primaryButton,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "You're ready →",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Footer ───────────────────────────────────────────────────
              const Text(
                'ServSafe® is a registered trademark of the',
                style: TextStyle(fontSize: 9, color: Color(0xFF6A6A6A)),
                textAlign: TextAlign.center,
              ),
              const Text(
                'National Restaurant Association Educational Foundation.',
                style: TextStyle(fontSize: 9, color: Color(0xFF6A6A6A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'SafePrep is an independent prep tool.',
                style: TextStyle(fontSize: 9, color: Color(0xFF4DA3FF)),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    // ── Gold frame (matching Shots 1 & 2) ────────────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: _goldFrame, width: 6),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _goldFrame.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: screenContent,
          ),
        ),
      ),
    );
  }
}
