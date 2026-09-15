import 'package:flutter/material.dart';
import '../iap_service.dart';
import '../app_state.dart';
import '../trial_timer_service.dart';
import '../mixpanel_service.dart';
import 'preview_assessment_page.dart';
import '../home_page.dart';
import 'preview_reveal_page.dart';

class PreviewCinematicSplash extends StatefulWidget {
  const PreviewCinematicSplash({super.key});

  @override
  State<PreviewCinematicSplash> createState() => _PreviewCinematicSplashState();
}

class _PreviewCinematicSplashState extends State<PreviewCinematicSplash>
    with TickerProviderStateMixin {
  late AnimationController _growController;
  late AnimationController _textController;
  late AnimationController _ctaController;

  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  late Animation<double> _line1Anim;
  late Animation<double> _line2Anim;
  late Animation<double> _line3Anim;
  late Animation<double> _line4Anim;
  late Animation<double> _line5Anim;
  late Animation<double> _line6Anim;

  late Animation<double> _ctaAnim;

  bool _isPurchasing = false;
  String? _errorMessage;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _mutedWhite = Color(0x99F0EDE8);

  bool get _isReturningUser => AppState().hasTakenAssessment;

  @override
  void initState() {
    super.initState();

    _growController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnim = CurvedAnimation(
      parent: _growController,
      curve: Curves.easeOutExpo,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _fadeAnim = CurvedAnimation(
      parent: _growController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ).drive(Tween(begin: 0.0, end: 1.0));

    _line1Anim = _staggeredFade(0.0, 0.18);
    _line2Anim = _staggeredFade(0.15, 0.33);
    _line3Anim = _staggeredFade(0.30, 0.48);
    _line4Anim = _staggeredFade(0.45, 0.63);
    _line5Anim = _staggeredFade(0.60, 0.78);
    _line6Anim = _staggeredFade(0.75, 0.95);

    _ctaAnim = CurvedAnimation(
      parent: _ctaController,
      curve: Curves.easeOutBack,
    ).drive(Tween(begin: 0.0, end: 1.0));

    MixpanelService.instance.track(
      'paywall_viewed',
      properties: {
        'source': _isReturningUser ? 'trial_expired' : 'fresh_launch',
      },
    );

    _runSequence();
  }

  Animation<double> _staggeredFade(double start, double end) {
    return CurvedAnimation(
      parent: _textController,
      curve: Interval(start, end, curve: Curves.easeOut),
    ).drive(Tween(begin: 0.0, end: 1.0));
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    await _growController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    await _ctaController.forward();
  }

  @override
  void dispose() {
    _growController.dispose();
    _textController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  // Shared purchase-outcome handler for all three tiers on this page.
  // IAPService now awaits the ACTUAL result (success / canceled / error /
  // timeout) instead of just "request submitted," so there is no more
  // need to poll AppState().hasUnlockedApp in a loop — the old
  // _waitForConfirmation() method this replaced is gone. `result` here
  // is the final, known outcome.
  Future<void> _completePurchase(IAPResult result) async {
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    if (result == IAPResult.success) {
      await TrialTimerService.instance.resetTrial();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
      return;
    }

    if (result == IAPResult.canceled) {
      // User intentionally backed out of the App Store sheet — no error
      // to show, nothing more to do.
      return;
    }

    setState(() => _errorMessage = result.userMessage);
  }

  Future<void> _onBuy() async {
    MixpanelService.instance.track(
      'purchase_initiated',
      properties: {'tier': 'lifetime'},
    );
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });
    final result = await IAPService.instance.buyUnlockApp();
    await _completePurchase(result);
  }

  void _startOver() {
    final state = AppState();
    state.reset();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PreviewRevealPage()),
    );
  }

  Widget _buildEspanolReference() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'También disponible: ',
              style: TextStyle(
                fontSize: 11,
                color: _mutedWhite,
                fontStyle: FontStyle.italic,
              ),
            ),
            TextSpan(
              text: 'SafePrep™ Español',
              style: TextStyle(
                fontSize: 11,
                color: _gold.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _growController,
          _textController,
          _ctaController,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: 340,
                    height: 340,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _gold.withValues(alpha: 0.07),
                          _darkBg.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Center(
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildTextLine(
                            _line1Anim,
                            child: Column(
                              children: [
                                Text(
                                  'SafePrep',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    color: _gold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 48,
                                  height: 2,
                                  color: _gold.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),

                          _buildTextLine(
                            _line2Anim,
                            child: _tagLine('The system that learns you,'),
                          ),
                          const SizedBox(height: 10),
                          _buildTextLine(
                            _line3Anim,
                            child: _tagLine('understands you,'),
                          ),
                          const SizedBox(height: 10),
                          _buildTextLine(
                            _line4Anim,
                            child: _tagLine('adapts to you,'),
                          ),
                          const SizedBox(height: 10),
                          _buildTextLine(
                            _line5Anim,
                            child: _tagLine(
                              'prepares you unlike anything else.',
                            ),
                          ),

                          const SizedBox(height: 28),

                          _buildTextLine(
                            _line6Anim,
                            child: Text(
                              'No frivolous questions.\nJust the information you need to pass.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: _mutedWhite,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (!_isReturningUser)
                            _buildTextLine(
                              _line6Anim,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _gold.withValues(alpha: 0.25),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: _gold.withValues(alpha: 0.05),
                                ),
                                child: Text(
                                  'The SafePrep™ Assessment is a mini-quiz designed specifically to diagnose your current ServSafe aptitude. Answer as many or as few questions as you like, we will do the rest.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _softWhite,
                                    fontWeight: FontWeight.w300,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 32),

                          ScaleTransition(
                            scale: _ctaAnim,
                            child: FadeTransition(
                              opacity: _ctaAnim,
                              child: Column(
                                children: [
                                  _isReturningUser
                                      ? _buildReturningButtons()
                                      : _buildCTAButton(),
                                  _buildEspanolReference(),
                                ],
                              ),
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextLine(Animation<double> anim, {required Widget child}) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: anim.drive(
          Tween(begin: const Offset(0, 0.3), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  Widget _tagLine(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        color: _softWhite,
        fontWeight: FontWeight.w300,
        height: 1.4,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildCTAButton() {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PreviewAssessmentPage()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: _gold, width: 1.5),
            borderRadius: BorderRadius.circular(40),
            color: _gold.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Take Your Free Assessment',
                style: TextStyle(
                  fontSize: 14,
                  color: _gold,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_ios_rounded, color: _gold, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturningButtons() {
    return Column(
      children: [
        _buildTierButton(
          label: '\$4.99  —  7 Days Access',
          sublabel: 'Try it out',
          isHighlighted: false,
          tier: 'seven_day',
          onTap: _isPurchasing
              ? null
              : () async {
                  MixpanelService.instance.track(
                    'purchase_initiated',
                    properties: {'tier': 'seven_day'},
                  );
                  setState(() {
                    _isPurchasing = true;
                    _errorMessage = null;
                  });
                  final result = await IAPService.instance.buySevenDay();
                  await _completePurchase(result);
                },
        ),
        const SizedBox(height: 10),

        _buildTierButton(
          label: '\$8.99  —  14 Days Access',
          sublabel: 'Study deeper',
          isHighlighted: false,
          tier: 'fourteen_day',
          onTap: _isPurchasing
              ? null
              : () async {
                  MixpanelService.instance.track(
                    'purchase_initiated',
                    properties: {'tier': 'fourteen_day'},
                  );
                  setState(() {
                    _isPurchasing = true;
                    _errorMessage = null;
                  });
                  final result = await IAPService.instance.buyFourteenDay();
                  await _completePurchase(result);
                },
        ),
        const SizedBox(height: 10),

        _buildTierButton(
          label: '\$9.99  —  Lifetime Access',
          sublabel: 'Best value  •  Yours forever  ★',
          isHighlighted: true,
          tier: 'lifetime',
          onTap: _isPurchasing ? null : _onBuy,
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: () => IAPService.instance.restorePurchases(),
          child: Text(
            'Restore previous purchase',
            style: TextStyle(fontSize: 13, color: _gold.withValues(alpha: 0.6)),
          ),
        ),

        const SizedBox(height: 4),

        TextButton(
          onPressed: _startOver,
          child: Text(
            '←  Start over',
            style: TextStyle(
              fontSize: 13,
              color: _softWhite.withValues(alpha: 0.35),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTierButton({
    required String label,
    required String sublabel,
    required bool isHighlighted,
    required String tier,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isHighlighted ? _gold : const Color(0xFF1A1A14),
          foregroundColor: isHighlighted ? const Color(0xFF0A0A0F) : _softWhite,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
            side: BorderSide(
              color: isHighlighted ? _gold : _gold.withValues(alpha: 0.4),
              width: isHighlighted ? 0 : 1,
            ),
          ),
          elevation: isHighlighted ? 6 : 2,
        ),
        child: _isPurchasing && isHighlighted
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0A0A0F),
                ),
              )
            : Column(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isHighlighted
                          ? const Color(0xFF0A0A0F)
                          : _softWhite,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isHighlighted
                          ? const Color(0xFF0A0A0F).withValues(alpha: 0.7)
                          : _mutedWhite,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
