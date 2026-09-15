import 'package:flutter/material.dart';

// TODO: adjust these imports to match your actual project structure
import 'fsme_eye.dart'; // FsmeEyePair, EyeMood
import 'app_state.dart'; // AppState singleton
import 'iap_service.dart'; // IAPService, IAPResult

/// Dedicated renewal screen. Two exits only: purchase ($2.99) or back.
/// NOT a modified OnboardPaywall — separate page, separate purpose.
class RenewPage extends StatefulWidget {
  const RenewPage({super.key});

  @override
  State<RenewPage> createState() => _RenewPageState();
}

class _RenewPageState extends State<RenewPage> {
  bool _purchasing = false;
  String _displayedLine = '';
  late final String _fullLine;
  late final DateTime _newExpiry;

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

  @override
  void initState() {
    super.initState();

    // Expiry math: current expiry + 7 days, preserving remaining days.
    // Falls back to now + 7 only if access has already fully lapsed.
    final state = AppState();
    final currentExpiry = state.expiryDate;
    final base =
        (currentExpiry != null && currentExpiry.isAfter(DateTime.now()))
        ? currentExpiry
        : DateTime.now();
    _newExpiry = base.add(const Duration(days: 7));

    final readiness = state.readinessScore;
    final dateStr = _formatDate(_newExpiry);

    _fullLine =
        'Good choice. Your readiness is at $readiness% — this gets you '
        'until $dateStr to tighten everything up.';

    _typeOutLine();
  }

  Future<void> _typeOutLine() async {
    for (int i = 1; i <= _fullLine.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 18));
      setState(() => _displayedLine = _fullLine.substring(0, i));
    }
  }

  Future<void> _handleRenew() async {
    setState(() => _purchasing = true);
    final previousExpiry = AppState().expiryDate;
    var result = await IAPService.instance.buyRenewal();
    if (!mounted) return;

    // See IAPService.waitForLateRenewal — a timeout doesn't necessarily
    // mean the purchase failed, just that confirmation arrived late.
    if (result == IAPResult.timeout) {
      final renewedLate = await IAPService.instance.waitForLateRenewal(
        previousExpiry,
      );
      if (!mounted) return;
      if (renewedLate) result = IAPResult.success;
    }

    if (result == IAPResult.success) {
      Navigator.of(context).pop(true); // caller can react to renewal
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
      backgroundColor: const Color(0xFF0F1B2E), // TODO: match app theme const
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
                      onPressed: _purchasing ? null : _handleRenew,
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
                          : const Text('Renew for \$2.99'),
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
