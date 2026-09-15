import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';
import 'home_page.dart';

class AboutProctorsPage extends StatelessWidget {
  const AboutProctorsPage({super.key});

  static const String _proctorUrl =
      'https://www.servsafe.com/Instructors-Proctors';

  Future<void> _launchUrl() async {
    final uri = Uri.parse(_proctorUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildCard(String title, List<String> items) {
    return Container(
      padding: AppSizes.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.strongText,
              )),
          ...items.map((item) => Text(item,
              style:
                  TextStyle(fontSize: 13, color: AppColors.bodyText))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
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
                          Text('Safe',
                              style: TextStyle(
                                fontSize: AppFonts.header,
                                fontWeight: FontWeight.w600,
                                color: AppColors.bodyText,
                              )),
                          const SizedBox(width: 6),
                          Image.asset('Assets/splash.png',
                              width: 36, height: 36),
                          const SizedBox(width: 6),
                          Text('Prep™',
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

              Text('About Proctors',
                  style: TextStyle(
                    fontSize: AppFonts.header,
                    fontWeight: FontWeight.bold,
                    color: AppColors.strongText,
                  ),
                  textAlign: TextAlign.center),

              _buildCard('What Is a Proctor?', [
                'A proctor is a ServSafe®-certified individual authorized to administer the ServSafe® Manager certification exam.',
              ]),

              _buildCard('Proctor Responsibilities', [
                '• Verify the identity of the exam candidate',
                '• Administer the exam under controlled conditions',
                '• Monitor the exam session to ensure integrity',
                '• Submit results to ServSafe® upon completion',
              ]),

              _buildCard('What a Proctor Is Not', [
                'A proctor is not an instructor. A proctor does not provide guidance, answer questions, offer advice, or assist with exam content in any way. The sole function of a proctor is to administer and monitor the exam and to verify that the person taking the exam is who they represent themselves to be.',
              ]),

              _buildCard('Independent Service Providers', [
                'Proctors are independent, self-employed professionals. They are not employees or agents of ServSafe®, the National Restaurant Association®, or SafePrep™. Proctoring fees are set independently by each proctor and may vary. SafePrep™ makes no representation regarding proctor availability, pricing, or scheduling.',
              ]),

              _buildCard('To Schedule Your Exam', [
                'Use the ServSafe® proctor locator to find a certified proctor in your area.',
              ]),

              SizedBox(
                width: double.infinity,
                height: AppSizes.primaryButtonHeight,
                child: ElevatedButton(
                  onPressed: _launchUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppSizes.buttonCornerRadius),
                    ),
                  ),
                  child: const Text('www.ServSafe.com',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
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
    );
  }
}