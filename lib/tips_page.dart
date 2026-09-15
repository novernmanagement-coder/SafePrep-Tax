import 'package:flutter/material.dart';
import 'constants.dart';
import 'fsme_eye.dart';
import 'home_page.dart';
import 'safe_prep_nav_bar.dart';
import 'mixpanel_service.dart';

class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  // ── FSME ──────────────────────────────────────────────────────
  // Same self-clearing header pattern as the other trainers. Uses
  // Idle rather than Fibbing/Befuddled — this line is a confession,
  // not an active lie or a fumble, so neither mood quite fits; Idle
  // keeps it simple rather than forcing a stretch.
  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();
  static const Duration _typeCharDelay = Duration(milliseconds: 18);
  static const Duration _introHold = Duration(milliseconds: 1800);
  static const String _introLine =
      "Ok, I admit it \u2014 I didn't come up with these tips. The old "
      "people in the nerd room who teach this stuff did. However, I "
      "did take the credit for it.";

  EyeMood _eyeMood = EyeMood.typing;
  String _introDisplayedText = '';
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track('proctor_tips_viewed');
    _playIntro();
  }

  Future<void> _playIntro() async {
    for (var i = 1; i <= _introLine.length; i++) {
      if (!mounted) return;
      await Future.delayed(_typeCharDelay);
      if (!mounted) return;
      setState(() => _introDisplayedText = _introLine.substring(0, i));
    }
    if (!mounted) return;
    await Future.delayed(_introHold);
    if (!mounted) return;
    setState(() {
      _showIntro = false;
      _eyeMood = EyeMood.idle;
    });
  }

  Widget _buildCard(String title, List<String> paragraphs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppFonts.subheader,
              color: AppColors.strongText,
            ),
          ),
          ...paragraphs.map(
            (p) => Text(
              p,
              style: TextStyle(
                fontSize: AppFonts.body,
                color: AppColors.bodyText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Self-clearing — collapses to zero height via AnimatedSize once
  /// the intro line finishes its hold, so it never permanently steals
  /// vertical space from the tips list below.
  Widget _buildFsmeIntroBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _showIntro
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                _introDisplayedText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF555555),
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
                    ),
                    child: Row(
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
                          'Prep™',
                          style: TextStyle(
                            fontSize: AppFonts.header,
                            fontWeight: FontWeight.w600,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FsmeEyePair(
                    key: _eyeKey,
                    mood: _eyeMood,
                    size: 22,
                    spacing: 6,
                  ),
                ],
              ),
            ),

            _buildFsmeIntroBanner(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _buildCard('What Is a Proctor', [
                      'A proctor is a certified person who supervises your ServSafe® exam to make sure everything is done fairly and securely. They verify your identity, monitor the testing environment, and ensure exam rules are followed.',
                    ]),
                    _buildCard('How to Find a Proctor', [
                      'You can find a certified proctor by visiting ServSafe.com, selecting Exams, choosing Find a Proctor, and entering your ZIP code. You can then contact a proctor or test center directly to schedule your exam.',
                      'A certified proctor must be physically present with you during the entire exam. This ensures identity verification, a proper testing environment, and secure submission of your exam.',
                      'Some areas also offer approved test centers, which provide a testing room, a certified proctor on site, and computer stations.',
                    ]),
                    _buildCard('Cost of Proctoring', [
                      'Proctoring fees vary by location and provider. Typical costs range from 35 to 75 dollars. Some proctors include room use, computer access, or administrative fees in their pricing.',
                    ]),
                    _buildCard('Cost of the Exam', [
                      'Exam pricing varies depending on whether you purchase the exam only or a course and exam bundle. Typical exam only pricing ranges from 36 to 50 dollars.',
                    ]),
                    _buildCard('How to Purchase the Exam', [
                      'Students can purchase their own exam directly on the ServSafe® website. Go to ServSafe.com, select Exams, choose ServSafe® Manager Exam, and complete checkout. Students will receive an exam voucher code to bring on test day.',
                      'Some proctors offer a combined package that includes the exam, proctoring services, and use of a testing room or computer. In these cases, the student does not need to purchase the exam separately.',
                    ]),
                    _buildCard('How Long the Exam Takes', [
                      'The ServSafe® Manager exam allows up to 2 hours. Most people finish in 60 to 90 minutes. Your proctor will let you know when the exam begins and how much time remains.',
                    ]),
                    _buildCard('When You Get Your Results', [
                      'Online exams typically score immediately after submission. Paper exams may take 3 to 10 business days depending on processing time.',
                    ]),
                    _buildCard('What to Bring', [
                      'Most proctors require a valid government issued photo ID and any exam voucher you were provided. Phones, notes, books, and smart devices are not allowed during the exam.',
                    ]),
                    _buildCard('Tips for Exam Day', [
                      'Arrive early, bring your ID, use the restroom before starting, and ask any questions before the exam begins. Stay calm and take your time. You can flag questions and return to them.',
                    ]),
                    const SizedBox(height: 12),
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
