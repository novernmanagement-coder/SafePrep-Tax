import 'package:flutter/material.dart';
import 'constants.dart';
import 'fsme_eye.dart';
import 'peace_of_mind_page.dart';
import 'safe_prep_nav_bar.dart';
import 'mixpanel_service.dart';

class MnemonicsPage extends StatefulWidget {
  const MnemonicsPage({super.key});

  @override
  State<MnemonicsPage> createState() => _MnemonicsPageState();
}

class _MnemonicsPageState extends State<MnemonicsPage> {
  static const List<_MnemonicEntry> _mnemonics = [
    _MnemonicEntry('E.C.O.L.I.™', 'Bacteria', Color(0xFFC0392B), [
      ('E', 'Entrails — ground beef, intestines'),
      ('C', 'Children — highest risk group'),
      ('O', 'Onset fast — 1–3 days'),
      ('L', 'Low dose — tiny amount makes you sick'),
      ('I', 'Improper cooking — undercooked burgers'),
    ]),
    _MnemonicEntry('S.A.L.M.O.N.™', 'Bacteria', Color(0xFFE67E22), [
      ('S', 'Shell eggs'),
      ('A', 'Animals — poultry, reptiles'),
      ('L', 'Live contamination — cross-contam'),
      ('M', 'Meat & milk'),
      ('O', 'Onset moderate — 6–48 hours'),
      ('N', 'No temperature abuse'),
    ]),
    _MnemonicEntry('S.H.I.G.E.L.L.A.™', 'Bacteria', Color(0xFF8E44AD), [
      ('S', 'Salads — potato, tuna, macaroni'),
      ('H', 'Hands — fecal-oral'),
      ('I', 'Ill workers — exclude'),
      ('G', 'Gastro outbreaks — daycares, camps'),
      ('E', 'Easily spread'),
      ('L', 'Low dose'),
      ('L', 'Let no bare-hand contact'),
      ('A', 'Avoid flies'),
    ]),
    _MnemonicEntry('B.A.C.I.L.L.U.S.™', 'Bacteria', Color(0xFF27AE60), [
      ('B', 'Buffet rice'),
      ('A', 'Asian fried rice syndrome'),
      ('C', 'Cook → cool quickly'),
      ('I', 'Illness two types — vomit / diarrhea'),
      ('L', 'Leftovers danger'),
      ('L', 'Long-lasting spores'),
      ('U', 'Unsafe holding temps'),
      ('S', 'Starchy foods — rice, pasta, potatoes'),
    ]),
    _MnemonicEntry('V.I.B.R.I.O.™', 'Bacteria', Color(0xFF2980B9), [
      ('V', 'Vibrant water — warm coastal waters'),
      ('I', 'In oysters'),
      ('B', 'Bloody infections possible'),
      ('R', 'Raw shellfish risk'),
      ('I', 'Immunocompromised danger'),
      ('O', 'Only reputable suppliers'),
    ]),
    _MnemonicEntry('N.O.R.O.V.I.R.U.S.™', 'Virus', Color(0xFF16A085), [
      ('N', 'No gloves? No service.'),
      ('O', 'Onset fast'),
      ('R', 'Ready-to-eat foods'),
      ('O', 'Outbreaks on cruise ships'),
      ('V', 'Very contagious'),
      ('I', 'Ill workers excluded'),
      ('R', 'Requires handwashing'),
      ('U', 'Uncooked foods spread it'),
      ('S', 'Shellfish sometimes involved'),
    ]),
    _MnemonicEntry('H.E.P.A.T.I.T.I.S.™ (A)', 'Virus', Color(0xFFD35400), [
      ('H', 'Hands → fecal-oral'),
      ('E', 'Exclusion required'),
      ('P', 'Poor hygiene'),
      ('A', 'Asymptomatic early'),
      ('T', 'Transmitted by RTE foods'),
      ('I', 'Incubation long — weeks'),
      ('T', 'Travel risk'),
      ('I', 'Infected food handlers'),
      ('S', 'Shellfish from polluted water'),
    ]),
    _MnemonicEntry('S.T.A.P.H.™', 'Toxin', Color(0xFF7F8C8D), [
      ('S', 'Skin infections'),
      ('T', 'Temperature abuse'),
      ('A', 'Aerosol contamination'),
      ('P', 'Protein foods'),
      ('H', 'Heat-stable toxin'),
    ]),
    _MnemonicEntry('C.B.O.T.™ (Botulism)', 'Toxin', Color(0xFF34495E), [
      ('C', 'Cans — bulging'),
      ('B', 'Baked potatoes in foil'),
      ('O', 'Oxygen-free environments'),
      ('T', 'Toxin deadly'),
    ]),
    _MnemonicEntry('C.P.E.R.F.™ (C. perfringens)', 'Toxin', Color(0xFFB7950B), [
      ('C', 'Cafeteria germ'),
      ('P', 'Protein foods'),
      ('E', 'Equipment pans — deep pans'),
      ('R', 'Reheating issues'),
      ('F', 'Fast onset'),
    ]),
    _MnemonicEntry('A.N.I.S.A.K.I.S.™', 'Parasite', Color(0xFF1ABC9C), [
      ('A', 'Aquatic parasite'),
      ('N', 'Not killed by acid'),
      ('I', 'In raw fish'),
      ('S', 'Sushi'),
      ('A', 'Abdominal pain'),
      ('K', 'Known for tingling throat'),
      ('I', 'Immediate removal needed'),
      ('S', 'Suppliers must freeze properly'),
    ]),
  ];

  // ── FSME ──────────────────────────────────────────────────────
  // Same self-clearing header pattern as the other trainers. This
  // one uses Befuddled rather than Fibbing — he's genuinely tripping
  // over the word itself, not making an exaggerated boast.
  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();
  static const Duration _typeCharDelay = Duration(milliseconds: 18);
  static const Duration _introHold = Duration(milliseconds: 1800);
  static const String _introLine =
      "Me-ne-nomics... in-menomics... menomonica... I can never "
      "pronounce that word. It took forever to come up with "
      "these \u2014 you better appreciate it!";

  EyeMood _eyeMood = EyeMood.befuddled;
  String _introDisplayedText = '';
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track('mnemonics_viewed');
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
      _eyeMood = EyeMood.serious;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFsmeIntroBanner(),
            Expanded(child: _buildCardsList()),
            const SafePrepNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              const SizedBox(width: 8),
              FsmeEyePair(key: _eyeKey, mood: _eyeMood, size: 22, spacing: 6),
              const SizedBox(width: 8),
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
            '🧠 Mnemonics',
            style: TextStyle(
              fontSize: AppFonts.header,
              fontWeight: FontWeight.bold,
              color: AppColors.strongText,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pathogen acronyms from forty years of instruction',
            style: TextStyle(
              fontSize: AppFonts.caption,
              color: AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }

  /// Self-clearing — collapses to zero height via AnimatedSize once
  /// the intro line finishes its hold, so it never permanently steals
  /// vertical space from the card list below.
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

  Widget _buildCardsList() {
    final items = <Widget>[];
    String currentType = '';
    for (final m in _mnemonics) {
      if (m.type != currentType) {
        currentType = m.type;
        items.add(_buildSectionHeader(currentType));
      }
      items.add(_buildMnemonicCard(m));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => items[i],
    );
  }

  Widget _buildSectionHeader(String type) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          fontSize: AppFonts.caption,
          fontWeight: FontWeight.bold,
          color: Color(0xFF888888),
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildMnemonicCard(_MnemonicEntry m) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: m.color, width: 4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: m.color,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEEEEEE), height: 1),
          const SizedBox(height: 8),
          ...m.letters.map((e) => _buildLetterRow(e.$1, e.$2, m.color)),
        ],
      ),
    );
  }

  Widget _buildLetterRow(String letter, String phrase, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                phrase,
                style: const TextStyle(
                  fontSize: AppFonts.body,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MnemonicEntry {
  final String name;
  final String type;
  final Color color;
  final List<(String, String)> letters;
  const _MnemonicEntry(this.name, this.type, this.color, this.letters);
}
