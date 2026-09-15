import 'package:flutter/material.dart';
import 'home_page.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';

class IntroductoryPage extends StatefulWidget {
  const IntroductoryPage({super.key});

  @override
  State<IntroductoryPage> createState() => _IntroductoryPageState();
}

class _IntroductoryPageState extends State<IntroductoryPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  bool _showTapHint = false;
  late AnimationController _bobbingController;
  late Animation<double> _bobbingAnimation;

  @override
  void initState() {
    super.initState();
    _bobbingController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _bobbingAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _bobbingController, curve: Curves.easeInOut),
    );

    // Show welcome modal on every launch for trial users
    if (!AppState().hasUnlockedApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeModal());
    }
  }

  @override
  void dispose() {
    _bobbingController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      AppState().userName = name;
      AppStatePersistence.save();
    }
  }

  void _showHint() {
    setState(() => _showTapHint = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showTapHint = false);
    });
  }

  void _goToHomePage() {
    _saveName();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    });
  }

  void _showWelcomeModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0F),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                const Text(
                  'SafePrep™',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD4AF37),
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 1.5,
                  color: const Color(0xFFD4AF37),
                ),
                const SizedBox(height: 20),

                // Body
                const Text(
                  'You have 30 minutes to explore everything — no restrictions, no limits.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFF0EDE8),
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Browse wherever you like — however, we recommend starting out by tapping "Create my personalized curriculum" on the home page.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0x99F0EDE8),
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'When your trial ends, we\'ll make it easy to unlock full access.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0x77F0EDE8),
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Icon callout
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          'Assets/splash.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'This icon is always your way back to the Home Page.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFD4AF37),
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Got it button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goToHomePage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: const Color(0xFF0A0A0F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      elevation: 6,
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final hasResults = AppState().hasTakenAssessment;

    final resultsMessage = hasResults
        ? 'We already have your assessment results on file — your personalized curriculum is built and ready to go.\n\nIf you\'d prefer to start fresh, you can retake the assessment anytime from the home page.'
        : 'Head to the home page to take your free diagnostic assessment — we\'ll build your personalized curriculum from there.';

    return Scaffold(
      backgroundColor: AppColors.primaryButton,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: AppSizes.pageMargin,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSizes.bodySpacing,
                children: [
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _goToHomePage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'Assets/splash.png',
                            width: AppSizes.iconLarge,
                            height: AppSizes.iconLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedBuilder(
                        animation: _bobbingAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _bobbingAnimation.value),
                            child: const Text(
                              '▲',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap the icon above — it\'s always your way back to the Home Page',
                        style: TextStyle(
                          fontSize: AppFonts.caption,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  // Congratulations headline
                  const Text(
                    'Congratulations.',
                    style: TextStyle(
                      fontSize: AppFonts.title,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Core message
                  const Text(
                    'You just made the smartest move toward passing your ServSafe® exam.\n\nSafePrep™ was built for one purpose — to get you ready. Not with generic questions and guesswork, but with a system that learns you, adapts to you, and builds a curriculum around your results.\n\nYou\'re not just studying. You\'re preparing.',
                    style: TextStyle(
                      fontSize: AppFonts.body,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Context-aware results message
                  Text(
                    resultsMessage,
                    style: const TextStyle(
                      fontSize: AppFonts.body,
                      color: Colors.white70,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  Column(
                    spacing: AppSizes.headerSpacing,
                    children: [
                      const Text(
                        'What name do you like to go by?',
                        style: TextStyle(
                          fontSize: AppFonts.body,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                        width: AppSizes.primaryButtonWidth,
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          maxLength: 20,
                          decoration: const InputDecoration(
                            hintText: 'Enter your name',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                          onSubmitted: (_) {
                            _saveName();
                            _showHint();
                          },
                          onEditingComplete: () {
                            if (_nameController.text.trim().isNotEmpty) {
                              _saveName();
                              _showHint();
                            }
                          },
                        ),
                      ),
                      const Text(
                        '(Optional)',
                        style: TextStyle(
                          fontSize: AppFonts.caption,
                          color: Colors.white54,
                        ),
                      ),
                      if (_showTapHint)
                        const Text(
                          'Tap the icon above to continue',
                          style: TextStyle(
                            fontSize: AppFonts.question,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),

                  Column(
                    spacing: AppSizes.footerSpacing,
                    children: [
                      Text(
                        AppStrings.footerLine1,
                        style: const TextStyle(
                          fontSize: AppFonts.footer,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        AppStrings.footerLine2,
                        style: const TextStyle(
                          fontSize: AppFonts.footer,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        AppStrings.footerLine3,
                        style: const TextStyle(
                          fontSize: AppFonts.footer,
                          color: AppColors.starMotifBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
