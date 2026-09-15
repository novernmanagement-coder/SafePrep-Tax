import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'peace_of_mind_page.dart';
import 'safe_prep_nav_bar.dart';

class InstructorTipsPage extends StatefulWidget {
  const InstructorTipsPage({super.key});

  @override
  State<InstructorTipsPage> createState() => _InstructorTipsPageState();
}

class _InstructorTipsPageState extends State<InstructorTipsPage> {
  List<ProTipModel> _tips = [];

  static ({Color color, String label, String icon}) _typeStyle(String type) =>
      switch (type.toLowerCase()) {
        'tip' => (color: const Color(0xFF2980B9), label: 'TIP', icon: '💡'),
        'trap' => (color: const Color(0xFFC0392B), label: 'TRAP', icon: '⚠'),
        'memoryhook' => (
          color: const Color(0xFF8E44AD),
          label: 'MEMORY HOOK',
          icon: '🧠',
        ),
        'scenario' => (
          color: const Color(0xFF16A085),
          label: 'SCENARIO',
          icon: '📋',
        ),
        _ => (
          color: const Color(0xFF4A6FA5),
          label: type.toUpperCase(),
          icon: '•',
        ),
      };

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    var tips = await ProTipLoader.loadPersonalized();
    if (tips.isEmpty) tips = await ProTipLoader.loadAll(shuffle: true);
    if (mounted) setState(() => _tips = tips);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildTipsList()),
            const SafePrepNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Safe',
                style: TextStyle(
                  fontSize: AppFonts.header,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bodyText,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const PeaceOfMindPage()),
                ),
                child: Image.asset(
                  'Assets/splash.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Prep™',
                style: TextStyle(
                  fontSize: AppFonts.header,
                  fontWeight: FontWeight.w600,
                  color: AppColors.bodyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "📖 Instructor's Playbook",
            style: TextStyle(
              fontSize: AppFonts.header,
              fontWeight: FontWeight.bold,
              color: AppColors.strongText,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '25+ years of ServSafe\u00ae expertise',
            style: TextStyle(
              fontSize: AppFonts.caption,
              color: AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsList() {
    if (_tips.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryButton),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _tips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final tip = _tips[i];
        final style = _typeStyle(tip.type);
        return _buildTipCard(
          content: tip.content,
          typeLabel: style.label,
          icon: style.icon,
          accentColor: style.color,
        );
      },
    );
  }

  Widget _buildTipCard({
    required String content,
    required String typeLabel,
    required String icon,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border(bottom: BorderSide(color: accentColor, width: 3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$icon  $typeLabel',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: AppFonts.body,
              color: Color(0xFF1A1A1A),
              height: 1.57,
            ),
          ),
        ],
      ),
    );
  }
}
