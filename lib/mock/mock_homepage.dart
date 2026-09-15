import 'package:flutter/material.dart';
import '../constants.dart';

/// SCREENSHOT MOCK — Home Page
/// A standalone, dependency-light copy of HomePage with hardcoded ideal data
/// for App Store screenshots. No AppState, no marquee scrolling, no top facts bar.
/// Navigate to this page only when capturing screenshots.
class MockHomePage extends StatelessWidget {
  const MockHomePage({super.key});

  // ── Gold palette (matches real HomePage) ──────────────────
  static const Color _goldDark = Color(0xFFC8A84B);
  static const Color _goldLight = Color(0xFFFFF3C4);
  static const Color _goldText = Color(0xFF8B6914);

  // ── IDEAL SCREENSHOT DATA ─────────────────────────────────
  static const int _readinessScore = 100; // green light — the payoff shot
  static const String _coachMessage =
      'Green light \u2014 you\u2019ve done the work. Go pass.';
  static const String _cheerMessage =
      'You\u2019re ready. We knew you could do it.';
  // 6 curriculum trophies earned, 5 mastered — populated but believable
  static const int _curriculumEarned = 6;
  static const int _masteredEarned = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0C575), width: 2),
          ),
          child: Padding(
            padding: AppSizes.pageMargin,
            child: Column(
              children: [
                // ── Logo header (kept) ──
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
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
                      Image.asset('Assets/splash.png', width: 36, height: 36),
                      const SizedBox(width: 6),
                      Text(
                        'Prep\u2122',
                        style: TextStyle(
                          fontSize: AppFonts.header,
                          fontWeight: FontWeight.w600,
                          color: AppColors.bodyText,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── TOP FACTS MARQUEE REMOVED for screenshots ──
                const SizedBox(height: 4),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      spacing: 10,
                      children: [
                        _buildWowBanners(),
                        _buildTrophySection(),
                        _buildFooterSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── WOW BANNERS (replace button stack for screenshots) ────
  Widget _buildWowBanners() {
    return Column(
      children: [
        _wowBanner(
          headline: 'Know the exact moment\nyou\u2019re ready to pass.',
          sub: 'Not just quiz scores \u2014 your true exam readiness, live.',
          big: true,
        ),
        const SizedBox(height: 7),
        _wowBanner(
          headline: 'Built by a ServSafe\u00AE instructor',
          sub: '20 years preparing people for the real exam.',
        ),
        const SizedBox(height: 7),
        _wowBanner(
          headline: 'Stop over-studying.',
          sub: 'We tell you when you\u2019re ready. Then you go pass.',
        ),
      ],
    );
  }

  Widget _wowBanner({
    required String headline,
    required String sub,
    bool big = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: big ? 11 : 9),
      decoration: BoxDecoration(
        color: const Color(0xFF2E4374),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0C575), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            headline,
            style: TextStyle(
              fontSize: big ? 19 : 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFFC7D3EC),
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Trophy section (hardcoded earned states) ──────────────
  Widget _buildTrophySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D5A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F3C6}', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'My Trophies',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              const Text(
                '2 of 2 earned',
                style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two milestone trophies — both earned
          Row(
            children: [
              Expanded(child: _earnedTrophyCard('SafePrep Unlocked')),
              const SizedBox(width: 10),
              Expanded(child: _earnedTrophyCard('Optimized Path Chosen')),
            ],
          ),

          const SizedBox(height: 10),

          // Curriculum + Mastered mini boxes — populated
          Row(
            children: [
              Expanded(child: _miniTrophyBox('CURRICULUM', _curriculumEarned)),
              const SizedBox(width: 10),
              Expanded(child: _miniTrophyBox('MASTERED', _masteredEarned)),
            ],
          ),

          const SizedBox(height: 10),

          // Readiness meter + static marquee
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildReadinessMeter()),
                const SizedBox(width: 10),
                Expanded(child: _buildStaticMarquee()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _earnedTrophyCard(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _goldDark, width: 1.5),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('\u{1F3C6}', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: _goldDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTrophyBox(String title, int earnedCount) {
    return Container(
      height: 95,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D5A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _goldText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  if (i >= earnedCount) return const SizedBox(width: 26);
                  return _miniTrophyTile();
                }),
              ),
              if (earnedCount > 4) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final idx = i + 4;
                    if (idx >= earnedCount) return const SizedBox(width: 26);
                    return _miniTrophyTile();
                  }),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTrophyTile() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _goldLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _goldDark, width: 1),
      ),
      child: const Center(
        child: Text('\u{1F3C6}', style: TextStyle(fontSize: 11)),
      ),
    ),
  );

  Widget _buildReadinessMeter() {
    const score = _readinessScore;
    const label = '\u{1F7E2} Green Light';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'ServSafe Readiness',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _goldText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildPartialStars(score),
          const SizedBox(height: 6),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.green.shade600,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPartialStars(int score) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starMin = i * 20.0;
        final starMax = (i + 1) * 20.0;
        double fillFraction = 0.0;
        if (score >= starMax) {
          fillFraction = 1.0;
        } else if (score > starMin) {
          fillFraction = (score - starMin) / 20.0;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _buildPartialStar(fillFraction),
        );
      }),
    );
  }

  Widget _buildPartialStar(double fillFraction) {
    return SizedBox(
      width: 24,
      height: 26,
      child: Stack(
        children: [
          const Text(
            '\u2605',
            style: TextStyle(
              fontSize: 22,
              color: Color(0xFFDDDDDD),
              height: 1.1,
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: fillFraction,
              child: const Text(
                '\u2605',
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFC8A84B),
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STATIC marquee (no scrolling) — full clean lines ──────
  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }

  Widget _buildStaticMarquee() {
    const coachColor = Color(0xFF1A5276);
    const cheerColor = Color(0xFFC8A84B);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D5A0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              _iconBadge(Icons.school, coachColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _coachMessage,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: coachColor,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8D5A0), height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              _iconBadge(Icons.emoji_events, cheerColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _cheerMessage,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: cheerColor,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        spacing: 2,
        children: [
          // Lifetime member label (best-looking footer state)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: const Text(
              '\u2B50 SafePrep\u2122 Lifetime Member',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFF0C575),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
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
          Text(
            AppStrings.footerLine3,
            style: TextStyle(
              fontSize: AppFonts.footer,
              color: AppColors.starMotifBlue,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
