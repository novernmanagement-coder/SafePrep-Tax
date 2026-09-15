import 'package:flutter/material.dart';
import '../constants.dart';
import '../iap_service.dart';
import '../app_state.dart';
import '../splash_page.dart';
import '../trial_timer_service.dart';
import '../home_page.dart';
import '../mixpanel_service.dart';
import 'preview_shared.dart';
import 'preview_reel_overlay.dart';

class PreviewRevealPage extends StatefulWidget {
  const PreviewRevealPage({super.key});

  @override
  State<PreviewRevealPage> createState() => _PreviewRevealPageState();
}

class _PreviewRevealPageState extends State<PreviewRevealPage>
    with SingleTickerProviderStateMixin {
  bool _isPurchasing = false;
  String? _errorMessage;
  bool _reelVisible = false;

  late AnimationController _growController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _mutedWhite = Color(0x99F0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  @override
  void initState() {
    super.initState();
    _growController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(
      parent: _growController,
      curve: Curves.easeOutBack,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _fadeAnim = CurvedAnimation(
      parent: _growController,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _runEntrance();
  }

  Future<void> _runEntrance() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _growController.forward();
  }

  @override
  void dispose() {
    _growController.dispose();
    super.dispose();
  }

  // IAPService now awaits the ACTUAL purchase outcome (success / canceled /
  // error / timeout) instead of just "request submitted," so `result` here
  // is final and known — no more need to poll AppState().hasUnlockedApp in
  // a loop. The old _waitForConfirmation() method this replaced is gone.
  Future<void> _onBuy(String tier, Future<IAPResult> Function() buyFn) async {
    MixpanelService.instance.track(
      'purchase_tier_tapped',
      properties: {'tier': tier, 'app_name': 'SP'},
    );
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });
    final result = await buyFn();
    if (!mounted) return;
    setState(() => _isPurchasing = false);

    if (result == IAPResult.success) {
      MixpanelService.instance.track(
        'purchase_confirmed',
        properties: {'tier': tier, 'app_name': 'SP'},
      );
      _showPurchaseThankYouModal();
      return;
    }

    if (result == IAPResult.canceled) {
      // User intentionally backed out of the App Store sheet — no error
      // to show, nothing more to do.
      return;
    }

    setState(() => _errorMessage = result.userMessage);
  }

  void _showPurchaseThankYouModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thank you for your purchase!',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _gold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Anything you studied and scored during your trial carries right over — you\'re picking up exactly where you left off.',
                style: TextStyle(fontSize: 13, color: _mutedWhite, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 160,
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close modal
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const SplashPage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _darkBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Let\'s Go',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startOver() {
    if (TrialTimerService.instance.isExpired) {
      _showTrialExpiredModal();
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  void _showTrialExpiredModal() {
    MixpanelService.instance.track(
      'trial_expired_modal_shown',
      properties: {'app_name': 'SP'},
    );
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your trial has ended.',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _gold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'To continue, please select one of the payment options below.',
                style: TextStyle(fontSize: 13, color: _mutedWhite, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 100,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _darkBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1),
              color: _gold.withValues(alpha: 0.06),
            ),
            child: const Icon(Icons.check, color: _gold, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: _mutedWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButtons() {
    if (_isPurchasing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
        ),
      );
    }

    return Column(
      children: [
        _buildTierButton(
          label: '\$4.99  —  7 Days Access',
          sublabel: 'Try it out',
          isHighlighted: false,
          onTap: () => _onBuy('7day', IAPService.instance.buySevenDay),
        ),
        const SizedBox(height: 10),
        _buildTierButton(
          label: '\$8.99  —  14 Days Access',
          sublabel: 'Study deeper',
          isHighlighted: false,
          onTap: () => _onBuy('14day', IAPService.instance.buyFourteenDay),
        ),
        const SizedBox(height: 10),
        _buildTierButton(
          label: '\$9.99  —  Lifetime Access',
          sublabel: 'Best value  •  Yours forever  ★',
          isHighlighted: true,
          onTap: () => _onBuy('lifetime', IAPService.instance.buyUnlockApp),
        ),
      ],
    );
  }

  Widget _buildTierButton({
    required String label,
    required String sublabel,
    required bool isHighlighted,
    required VoidCallback onTap,
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
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
            side: BorderSide(
              color: isHighlighted ? _gold : _gold.withValues(alpha: 0.4),
              width: isHighlighted ? 0 : 1,
            ),
          ),
          elevation: isHighlighted ? 6 : 2,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? const Color(0xFF0A0A0F) : _softWhite,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          SafeArea(
            child: AnimatedBuilder(
              animation: _growController,
              builder: (context, _) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                color: _gold.withValues(alpha: 0.06),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Image.asset('Assets/splash.png'),
                              ),
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              'SafePrep\u2122',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: _gold,
                                letterSpacing: 1.5,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Container(
                              width: 48,
                              height: 1.5,
                              color: _gold.withValues(alpha: 0.4),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              'SafePrep is always adapting and reconfiguring to you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                color: _softWhite,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                                letterSpacing: 0.2,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'Your readiness meter is a proven algorithm — it tells you exactly when you\'re ready to take the ServSafe\u00ae exam with confidence.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: _mutedWhite,
                                fontWeight: FontWeight.w300,
                                height: 1.6,
                              ),
                            ),

                            const SizedBox(height: 28),

                            Container(
                              width: double.infinity,
                              height: 0.5,
                              color: _gold.withValues(alpha: 0.2),
                            ),

                            const SizedBox(height: 28),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildBenefitRow(
                                    'Adaptive',
                                    'We just proved it — SafePrep learns from your answers and adjusts to your knowledge level.',
                                  ),
                                  _buildBenefitRow(
                                    'Personalized',
                                    'Your curriculum is already waiting. Built from your results, not a generic template.',
                                  ),
                                  _buildBenefitRow(
                                    'Purposeful',
                                    'Every question has a reason. No repetition, no filler — just the information you need to pass.',
                                  ),
                                  _buildBenefitRow(
                                    'Built for you',
                                    'No fluff. Choose the plan that works for you.',
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  MixpanelService.instance.track(
                                    'preview_reel_viewed',
                                    properties: {'app_name': 'SP'},
                                  );
                                  setState(() => _reelVisible = true);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _gold.withValues(alpha: 0.7),
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.buttonCornerRadius,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Show me more \u2192',
                                  style: TextStyle(
                                    color: _gold.withValues(alpha: 0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    '\ud83c\udfc6',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '60 Second Trainers included free',
                                    style: TextStyle(
                                      color: _gold,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'See the full feature list at FoodSafetyMadeEasy.com',
                                    style: TextStyle(
                                      color: _mutedWhite,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            _buildPurchaseButtons(),

                            const SizedBox(height: 16),

                            Text(
                              'All plans include 60 Second Trainers',
                              style: TextStyle(
                                color: _mutedWhite,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 16),

                            TextButton(
                              onPressed: () {
                                MixpanelService.instance.track(
                                  'restore_purchase_tapped',
                                  properties: {'app_name': 'SP'},
                                );
                                IAPService.instance.restorePurchases();
                              },
                              child: Text(
                                'Restore previous purchase',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _gold.withValues(alpha: 0.6),
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),

                            TextButton(
                              onPressed: _startOver,
                              child: Text(
                                '\u2190  Start over',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _softWhite.withValues(alpha: 0.25),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            if (!(!AppState().hasUnlockedApp &&
                                TrialTimerService.instance.isExpired))
                              buildPreviewFooter(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_reelVisible)
            Positioned.fill(
              child: PreviewReelOverlay(
                onBuy: () =>
                    _onBuy('lifetime', IAPService.instance.buyUnlockApp),
                isPurchasing: _isPurchasing,
                unlockPrice: IAPService.instance.unlockPrice,
                onBuySevenDay: () =>
                    _onBuy('7day', IAPService.instance.buySevenDay),
                onBuyFourteenDay: () =>
                    _onBuy('14day', IAPService.instance.buyFourteenDay),
              ),
            ),
        ],
      ),
    );
  }
}
