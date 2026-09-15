import 'package:flutter/material.dart';
import 'constants.dart';
import 'cluster_info_page.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'fsme_help_box.dart';
import 'home_page.dart';
import 'final_step_exam_page.dart';
import 'safe_prep_nav_bar.dart';

class FinalExamIntroPage extends StatefulWidget {
  const FinalExamIntroPage({super.key});

  @override
  State<FinalExamIntroPage> createState() => _FinalExamIntroPageState();
}

class _FinalExamIntroPageState extends State<FinalExamIntroPage> {
  String _tickerFacts = '';

  // Same finalExam cluster as FinalStepExamPage — this intro page and
  // the actual exam share one explanation.
  static const List<String> _fsmeHelpMessages = [
    "90 questions, scored exactly like the real ServSafe exam.",
    "Whatever you get, results feed back into your curriculum.",
    "Tap me — I'll 'splain what this whole thing is for.",
  ];

  void _openFinalExamExplanation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClusterInfoPage(
          cluster: AppCluster.finalExam,
          launchContext: ClusterLaunchContext.landing,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFacts();
  }

  Future<void> _loadFacts() async {
    var facts = await FactLoader.loadAll();
    setState(() {
      _tickerFacts = facts.map((f) => f.fact).join('  •  ');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Padding(
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
                        ),
                      ],
                    ),
                    Text(
                      'The SafePrep™ Exam',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              FsmeHelpBox(
                messages: _fsmeHelpMessages,
                onTap: _openFinalExamExplanation,
                enabled: AppState().fsmeEnabled,
              ),

              if (_tickerFacts.isNotEmpty)
                Container(
                  height: 32,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    border: Border.all(color: const Color(0xFFC8B89A)),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Marquee(text: _tickerFacts),
                  ),
                ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      "You're ready for this.",
                      style: TextStyle(
                        fontSize: AppFonts.subheader,
                        fontWeight: FontWeight.w600,
                        color: AppColors.strongText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '90 questions covering everything in the ServSafe® curriculum.',
                      style: TextStyle(
                        fontSize: AppFonts.body,
                        color: AppColors.subtleText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'There is no timer. One question at a time. Take a breath.',
                      style: TextStyle(
                        fontSize: AppFonts.body,
                        color: AppColors.subtleText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FinalStepExamPage(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text("I'm Ready — Start the Exam"),
                      ),
                    ),
                  ],
                ),
              ),

              const SafePrepNavBar(),
            ],
          ),
        ),
      ),
    );
  }
}
