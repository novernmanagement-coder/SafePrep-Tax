import 'package:flutter/material.dart';

import 'fsme_eye.dart'; // FsmeEyePair, EyeMood
import 'app_state.dart'; // AppState singleton
import 'iap_service.dart'; // IAPService, IAPResult

/// Android-only counterpart to RenewPage. Reached from the same
/// "day 5" nav-bar prompt (see safe_prep_nav_bar.dart's _goRenew,
/// which branches on Platform.isAndroid), but grants LIFETIME access
/// for a one-time $2.99 purchase instead of a repeatable 7-day
/// extension — so the copy here is deliberately different from
/// RenewPage's "until [date]" framing, which would be actively wrong
/// for a lifetime unlock. iOS is untouched; it still uses RenewPage
/// and the real, live SafePrepRenewalWeek product.
class LifetimeOfferPage extends StatefulWidget {
  const LifetimeOfferPage({super.key});

  @override
  State<LifetimeOfferPage> createState() => _LifetimeOfferPageState();
}

class _LifetimeOfferPageState extends State<LifetimeOfferPage> {
  bool _purchasing = false;
  String _displayedLine = '';
  late final String _fullLine;

  @override
  void initState() {
    super.initState();

    final state = AppState();
    final readiness = state.readinessScore;

    _fullLine =
        'Good choice. Your readiness is at $readiness% — this unlocks '
        'full access for good. No more countdown, no more renewing.';

    _typeOutLine();
  }

  Future<void> _typeOutLine() async {
    for (int i = 1; i <= _fullLine.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 18));
      setState(() => _displayedLine = _fullLine.substring(0, i));
    }
  }

  Future<void> _handleUnlock() async {
    setState(() => _purchasing = true);
    var result = await IAPService.instance.buyLifetimeOffer();
    if (!mounted) return;

    // See IAPService.waitForLateUnlock — a timeout doesn't necessarily
    // mean the purchase failed, just that confirmation arrived late.
    if (result == IAPResult.timeout) {
      final unlockedLate = await IAPService.instance.waitForLateUnlock();
      if (!mounted) return;
      if (unlockedLate) result = IAPResult.success;
    }

    if (result == IAPResult.success) {
      Navigator.of(context).pop(true); // caller can react to the unlock
      return;
    }
    if (result == IAPResult.canceled) {
      setState(() => _purchasing = false);
      return; // user intentionally backed out — no error to show
    }

    setState(() => _purchasing = false);
    final message = result.userMessage;
    if (message != null) _showError(message);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goBack() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1B2E), // matches RenewPage
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FsmeEyePair(mood: EyeMood.typing, size: 24),
                  const SizedBox(height: 6),
                  const Text(
                    'F S M E',
                    style: TextStyle(
                      color: Color(0xFFEF9F27),
                      fontSize: 12,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16233A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _displayedLine,
                      style: const TextStyle(
                        color: Color(0xFFFAEEDA),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _purchasing ? null : _handleUnlock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF9F27),
                        foregroundColor: const Color(0xFF412402),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _purchasing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock for \$2.99'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _purchasing ? null : _goBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB4B2A9),
                        side: const BorderSide(color: Color(0xFF444441)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Go back'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
