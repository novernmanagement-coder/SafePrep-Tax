import 'package:flutter/material.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';

/// Describes a fail-streak-triggered mode switch, passed to
/// RecomputingModal.show() when CategoryQuizResultsPage detects one.
/// The switch has ALREADY been applied to AppState by the caller
/// before this is shown — this modal surfaces it and lets the user
/// revert, it never applies the switch itself (system adapts, FSME
/// advocates — see the architecture decision this was built from).
class TierSwitchInfo {
  final String category;
  final String fromModeLabel; // 'Quiz Retro' or 'Quiz Proper'
  final String toModeLabel; // 'Quiz Proper' or 'Full Study'
  final int tier; // 1 or 2, only used to pick the revert action

  const TierSwitchInfo({
    required this.category,
    required this.fromModeLabel,
    required this.toModeLabel,
    required this.tier,
  });
}

class RecomputingModal extends StatefulWidget {
  final String category;
  final int readinessScore;
  final TierSwitchInfo? tierSwitch;

  const RecomputingModal({
    super.key,
    required this.category,
    required this.readinessScore,
    this.tierSwitch,
  });

  static Future<void> show(
    BuildContext context, {
    required String category,
    required int readinessScore,
    TierSwitchInfo? tierSwitch,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => RecomputingModal(
        category: category,
        readinessScore: readinessScore,
        tierSwitch: tierSwitch,
      ),
    );
  }

  @override
  State<RecomputingModal> createState() => _RecomputingModalState();
}

class _RecomputingModalState extends State<RecomputingModal>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _switchGold = Color(0xFFEF9F27);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _mutedWhite = Color(0x99F0EDE8);
  static const Color _red = Color(0xFFE24B4A);
  static const Color _redDark = Color(0xFF501313);

  final List<Map<String, dynamic>> _lines = [];
  bool _showAdvocateCheckIn = false;

  bool get _hasSwitch => widget.tierSwitch != null;

  Future<void> _typeLine(
    String text, {
    int preDelayMs = 300,
    bool highlight = false,
  }) async {
    await Future.delayed(Duration(milliseconds: preDelayMs));
    if (!mounted) return;

    setState(
      () => _lines.add({
        'displayedText': '',
        'checked': false,
        'highlight': highlight,
      }),
    );

    final charDelay = text.length > 40 ? 18 : 24;
    for (int i = 1; i <= text.length; i++) {
      await Future.delayed(Duration(milliseconds: charDelay));
      if (!mounted) return;
      setState(() => _lines.last['displayedText'] = text.substring(0, i));
    }

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _lines.last['checked'] = true);
  }

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    await _typeLine('Quiz results locked in.');

    if (_hasSwitch) {
      final ts = widget.tierSwitch!;
      await _typeLine('Assessing results...');
      await _typeLine('Current mode: ${ts.fromModeLabel}');
      await _typeLine('Three rounds under 75% detected.');
      await _typeLine('Switching to ${ts.toModeLabel}.', highlight: true);
      await _typeLine('Curriculum refined.');
      await _typeLine('Readiness score updated — ${widget.readinessScore}%');

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _showAdvocateCheckIn = true);
      // Does NOT auto-pop — waits for Yes/No.
      return;
    }

    await _typeLine('Recalibrating ${widget.category}...');
    await _typeLine('Curriculum refined.');
    await _typeLine('Readiness score updated — ${widget.readinessScore}%');

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _acceptSwitch() async {
    // Already applied by the caller — nothing to persist here.
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _revertSwitch() async {
    final ts = widget.tierSwitch;
    if (ts != null) {
      final state = AppState();
      // Tier 1 revert: drop the 'proper' override, back to whatever
      // the onboarding default was (Retro, in practice, since only
      // quizFormat users hit tier 1 at all).
      // Tier 2 revert: drop the 'fullStudy' override, back to
      // 'proper' — NOT all the way back to Retro, since tier 2 only
      // fires from an already-Proper state; reverting further than
      // that would silently discard the tier-1 switch too.
      if (ts.tier == 1) {
        state.categoryModeOverride.remove(ts.category);
      } else {
        state.categoryModeOverride[ts.category] = 'proper';
      }
      state.categoryQuizFailStreak[ts.category] = 0;
      await AppStatePersistence.save();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String get _advocateLine {
    final category = widget.tierSwitch?.category ?? widget.category;
    return "Hey — I just saw the system switch your study style for "
        "$category. Just this category, though — everywhere else stays "
        "exactly how you set it. Last three rounds you scored under 75% "
        "here. I'd trust the system — it's always adapting. You cool "
        "with the change?";
  }

  Widget _buildLogLines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _lines.map((line) {
        final displayedText = line['displayedText'] as String;
        final checked = line['checked'] as bool;
        final highlight = line['highlight'] as bool;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: checked
                      ? Icon(
                          Icons.check,
                          key: const ValueKey('checked'),
                          size: 13,
                          color: highlight ? _switchGold : _gold,
                        )
                      : SizedBox(
                          key: const ValueKey('unchecked'),
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: _gold.withValues(alpha: 0.4),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayedText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w300,
                    color: highlight ? _switchGold : _mutedWhite,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdvocateCheckIn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Container(height: 0.5, color: _gold.withValues(alpha: 0.15)),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: Row(
                children: [
                  _eyeDot(offsetRight: true),
                  const SizedBox(width: 5),
                  _eyeDot(offsetRight: false),
                ],
              ),
            ),
            Expanded(
              child: Text(
                _advocateLine,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFFF0EDE8),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _acceptSwitch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _darkBg,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Yes, keep it',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _revertSwitch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _mutedWhite,
                  side: BorderSide(color: _gold.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'No, switch back',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _eyeDot({required bool offsetRight}) {
    return Container(
      width: 11,
      height: 11,
      decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
      child: Align(
        alignment: offsetRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: const BoxDecoration(
            color: _redDark,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _darkBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gold.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                color: _gold.withValues(alpha: 0.06),
              ),
              child: const Icon(Icons.auto_awesome, color: _gold, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              'SafePrep™ Engine',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _gold.withValues(alpha: 0.8),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildLogLines(),
            if (_showAdvocateCheckIn) _buildAdvocateCheckIn(),
          ],
        ),
      ),
    );
  }
}
