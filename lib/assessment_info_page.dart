import 'package:flutter/material.dart';
import 'constants.dart';
import 'home_page.dart';
import 'csv_loader.dart';
import 'assessment_page_v2.dart';
import 'safe_prep_nav_bar.dart';

class AssessmentInfoPage extends StatefulWidget {
  const AssessmentInfoPage({super.key});

  @override
  State<AssessmentInfoPage> createState() => _AssessmentInfoPageState();
}

class _AssessmentInfoPageState extends State<AssessmentInfoPage> {
  String _tickerFacts = '';

  @override
  void initState() {
    super.initState();
    _loadFacts();
  }

  Future<void> _loadFacts() async {
    final facts = await FactLoader.loadAll();
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
              ),

              Container(
                height: 32,
                margin: const EdgeInsets.only(bottom: 8),
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
                  child: _tickerFacts.isEmpty
                      ? const SizedBox()
                      : Marquee(text: _tickerFacts),
                ),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 16,
                  children: [
                    Text(
                      'Assessment Overview',
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '30 questions. We analyze your answers. We build your curriculum.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.bodyText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: AppSizes.primaryButtonWidth,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssessmentPageV2(),
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
                        child: const Text('Start Assessment'),
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
