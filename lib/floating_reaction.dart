import 'package:flutter/material.dart';

/// The two positive states a category-quiz result can earn. There is
/// deliberately no third "flat/declined" state — silence is the
/// correct visual for that outcome, not a discouraging badge. See
/// design discussion: a floating reaction should always mean
/// something genuinely happened, never a participation trophy.
enum ReactionType { mastered, improved }

/// Fire-and-forget floating reaction — inserts itself into the
/// nearest Overlay, drifts up from near the bottom of the screen with
/// a slight side-to-side wobble, fades in then out, and removes
/// itself when done. No caller bookkeeping required beyond the one
/// call: `FloatingReaction.show(context, type: ReactionType.mastered)`.
///
/// IMPORTANT: call this only in open space, never while a blocking
/// dialog (e.g. RecomputingModal) is still showing — its dark barrier
/// would hide the reaction entirely. See CategoryQuizResultsPage for
/// the sequencing pattern (await the modal, then show the reaction).
class FloatingReaction {
  static void show(BuildContext context, {required ReactionType type}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) =>
          _FloatingReactionWidget(type: type, onComplete: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _FloatingReactionWidget extends StatefulWidget {
  final ReactionType type;
  final VoidCallback onComplete;

  const _FloatingReactionWidget({required this.type, required this.onComplete});

  @override
  State<_FloatingReactionWidget> createState() =>
      _FloatingReactionWidgetState();
}

class _FloatingReactionWidgetState extends State<_FloatingReactionWidget>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0E14);

  late final AnimationController _controller;
  late final Animation<double> _rise;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    // Mastered gets a touch longer to land — it's the bigger moment.
    final duration = widget.type == ReactionType.mastered
        ? const Duration(milliseconds: 1800)
        : const Duration(milliseconds: 1300);

    _controller = AnimationController(vsync: this, duration: duration);

    _rise = Tween<double>(
      begin: 0,
      end: -240,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Fade in quickly, hold, fade out — never appears or disappears
    // abruptly.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Gentle side-to-side drift as it rises — a slow half-sine, not a
  /// literal wobble, so it reads as floating rather than shaking.
  double _horizontalDrift(double t) => 10 * (t < 0.5 ? t * 2 : (1 - t) * 2) - 5;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 130,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_horizontalDrift(_controller.value), _rise.value),
              child: Opacity(opacity: _opacity.value, child: child),
            );
          },
          child: Center(
            child: widget.type == ReactionType.mastered
                ? _masteredPill()
                : _improvedIcon(),
          ),
        ),
      ),
    );
  }

  /// The bigger win — branded pill: app mark + "Mastered" text.
  Widget _masteredPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('Assets/splash.png', width: 22, height: 22),
          const SizedBox(width: 10),
          const Text(
            'Mastered',
            style: TextStyle(
              color: _gold,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// The smaller, more frequent win — bare icon, no text, no logo.
  /// Deliberately a different shape from the Mastered pill's
  /// checkmark so the two never get confused mid-animation.
  Widget _improvedIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _darkBg,
        border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1),
      ),
      child: const Icon(Icons.thumb_up_rounded, color: _gold, size: 24),
    );
  }
}
