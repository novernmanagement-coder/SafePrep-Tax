import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'fsme_eye.dart';
import 'home_page.dart';
import 'flash_cards_page.dart';
import 'instructor_tips_page.dart';
import 'mnemonics_page.dart';
import 'rapid_fire_page.dart';
import 'scenario_drills_page.dart';
import 'safe_prep_nav_bar.dart';
import 'mixpanel_service.dart';

/// Peace of Mind is FSME's hub — the one place he gets to be fully
/// himself rather than just narrating. Below the five tool buttons he
/// greets the user with a short, auto-advancing line sequence
/// (Befuddled → Typing → Fibbing) — each line types out, holds for a
/// beat in its resting mood, then moves on with no tap required. No
/// tap-triggered reactions on the tool buttons yet — that's a later
/// pass.
class PeaceOfMindPage extends StatefulWidget {
  const PeaceOfMindPage({super.key});

  @override
  State<PeaceOfMindPage> createState() => _PeaceOfMindPageState();
}

class _PeaceOfMindPageState extends State<PeaceOfMindPage> {
  static const Duration _typeCharDelay = Duration(milliseconds: 18);
  static const Duration _fadeGap = Duration(milliseconds: 320);

  static const Color _davGold = Color(0xFFD4AF37);
  // Placeholder "processing" color for the opening hedge line — Gerry
  // to confirm the actual color to use; swap this constant once known.
  static const Color _processingColor = Color(0xFF9AA5B1);

  static const List<_GreetingLine> _lines = [
    _GreetingLine(
      text: "Yeah, I know, I say this every time you land here, but \u2014",
      mood: EyeMood.fibbing,
      color: _processingColor,
    ),
    _GreetingLine(
      text: "It's about time you got here.",
      mood: EyeMood.befuddled,
    ),
    _GreetingLine(
      text: "Where do you want to start? I made all of these.",
      mood: EyeMood.typing,
    ),
    _GreetingLine(
      text:
          "Yup, let me see... First place at the Byte-Me convention. "
          "Category was 'Best Tools, Made by Real Tools.' That makes "
          "me a bona-fide Tool.",
      mood: EyeMood.fibbing,
    ),
  ];

  int _lineIndex = -1;
  String _displayedText = '';
  EyeMood _mood = EyeMood.idle;
  Color _textColor = _davGold;

  static const Duration _holdDuration = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _advanceGreeting();
  }

  Future<void> _typeLine(String text) async {
    setState(() => _displayedText = '');
    for (var i = 1; i <= text.length; i++) {
      if (!mounted) return;
      await Future.delayed(_typeCharDelay);
      if (!mounted) return;
      setState(() => _displayedText = text.substring(0, i));
    }
  }

  Future<void> _advanceGreeting() async {
    final nextIndex = _lineIndex + 1;
    if (nextIndex >= _lines.length) {
      // Sequence is done — lock the gaze dead-center (Serious mood)
      // as the "your turn now" resting state while the user picks a
      // tool, instead of leaving the eyes in whatever the last line's
      // mood happened to be.
      setState(() {
        _mood = EyeMood.serious;
      });
      return;
    }

    final line = _lines[nextIndex];

    // Typing mood plays while the text is animating in, regardless of
    // the line's own resting mood — matches the rule established on
    // the post-purchase landing sequence.
    setState(() {
      _lineIndex = nextIndex;
      _mood = EyeMood.typing;
      _textColor = line.color;
      _displayedText = '';
    });

    if (nextIndex > 0) {
      await Future.delayed(_fadeGap);
      if (!mounted) return;
    }

    await _typeLine(line.text);
    if (!mounted) return;

    setState(() => _mood = line.mood);

    await Future.delayed(_holdDuration);
    if (!mounted) return;
    await _advanceGreeting();
  }

  void _go(BuildContext context, Widget page) => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => page),
  );

  void _trackTrainerSelected(String trainerName) {
    MixpanelService.instance.track(
      'trainer_selected',
      properties: {'trainer_name': trainerName},
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
                        ),
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
                            Image.asset(
                              'Assets/splash.png',
                              width: 36,
                              height: 36,
                            ),
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
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '\ud83d\udd13 60 Second Trainers',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w700,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'SafePrep\u2122 exclusive study tools \u2014 get that extra boost in confidence',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.subtleText,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    _buildToolButton(context, '\ud83c\udccf Flash Cards', () {
                      _trackTrainerSelected('flash_cards');
                      _go(context, const FlashCardsPage());
                    }),
                    const SizedBox(height: 8),
                    _buildToolButton(
                      context,
                      '\ud83c\udfad Scenario Drills',
                      () {
                        _trackTrainerSelected('scenario_drills');
                        _go(context, const ScenarioDrillsPage());
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildToolButton(context, '\u26a1 Rapid Fire', () {
                      _trackTrainerSelected('rapid_fire');
                      _go(context, const RapidFirePage());
                    }),
                    const SizedBox(height: 8),
                    _buildToolButton(context, '\ud83e\udde0 Mnemonics', () {
                      _trackTrainerSelected('mnemonics');
                      _go(context, const MnemonicsPage());
                    }),
                    const SizedBox(height: 8),
                    _buildToolButton(context, '\ud83d\udccc Proctor Tips', () {
                      _trackTrainerSelected('proctor_tips');
                      _go(context, const InstructorTipsPage());
                    }),

                    const SizedBox(height: 24),
                    _buildFsmeGreeting(),
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

  Widget _buildFsmeGreeting() {
    return Column(
      children: [
        Center(child: FsmeEyePair(mood: _mood, size: 34)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 60, maxHeight: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF13130F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              _displayedText,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: _textColor,
                height: 1.55,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolButton(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.primaryButtonHeight,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButton,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: AppFonts.button,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GreetingLine {
  final String text;
  final EyeMood mood;
  final Color color;
  const _GreetingLine({
    required this.text,
    required this.mood,
    this.color = _PeaceOfMindPageState._davGold,
  });
}
