import 'package:flutter/material.dart';
import 'constants.dart';
import 'fsme_eye.dart';
import 'interview_prep_page.dart';

// Minimal home screen for the spun-off interview-prep-only app (working
// name "How To Ace The Interview"). Reuses Tax Starter's real in-app
// design system (AppColors/AppFonts/AppSizes — the light blue/white
// theme, not the dark/gold marketing theme used on the landing page and
// PDFs) so it looks native next to the reused InterviewPrepPage rather
// than like a bolted-on skin.
class InterviewAppHomePage extends StatelessWidget {
  const InterviewAppHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FsmeEyePair(size: 40, spacing: 12),
              const SizedBox(height: 20),
              const Text(
                'How To Ace The Interview',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.strongText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Intuit Academy Tax Level 1 Interview Prep',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFonts.subheader,
                  color: AppColors.subtleText,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Passing the exam and being ready for the interview are '
                'two different milestones. The exam checks whether you '
                'picked the right answer. The interview checks whether '
                'you can explain why — out loud, on camera, in real '
                'time.\n\nPractice the actual skill it tests: explaining '
                'your reasoning clearly, under a little pressure, before '
                'the real thing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFonts.body,
                  color: AppColors.bodyText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: AppSizes.primaryButtonWidth,
                height: AppSizes.primaryButtonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InterviewPrepPage(
                        showNavBar: false,
                        showBrandHeader: false,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: AppColors.primaryButtonForeground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.buttonCornerRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Start Practicing',
                    style: TextStyle(
                      fontSize: AppFonts.button,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
