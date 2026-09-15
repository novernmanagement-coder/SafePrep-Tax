import 'dart:async';
import 'package:flutter/material.dart';
import 'fsme_eye.dart';

/// Small, permanent (not self-clearing) FSME presence for non-trainer
/// pages — sits below the header, auto-cycles through 2-3 short
/// messages, and on tap plays a quick "ouch" reaction before handing
/// off to [onTap] (which each page wires to open its own
/// ClusterInfoPage explanation). Respects the global FSME on/off
/// toggle via [enabled] — when false, renders nothing at all.
///
/// Content lives on the calling page, not here — this widget is
/// purely mechanical (cycling, reacting, rendering), same split as
/// every other FSME deployment in this app.
class FsmeHelpBox extends StatefulWidget {
  final List<String> messages;
  final VoidCallback onTap;
  final bool enabled;

  const FsmeHelpBox({
    super.key,
    required this.messages,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<FsmeHelpBox> createState() => _FsmeHelpBoxState();
}

class _FsmeHelpBoxState extends State<FsmeHelpBox> {
  final GlobalKey<FsmeEyePairState> _eyeKey = GlobalKey<FsmeEyePairState>();
  int _index = 0;
  Timer? _cycleTimer;
  bool _reacting = false;

  static const Duration _cycleInterval = Duration(seconds: 4);
  static const String _ouchLine = "Ouch. That hurt.";

  @override
  void initState() {
    super.initState();
    _scheduleCycle();
  }

  void _scheduleCycle() {
    _cycleTimer?.cancel();
    if (widget.messages.length <= 1) return;
    _cycleTimer = Timer.periodic(_cycleInterval, (_) {
      if (!mounted || _reacting) return;
      setState(() => _index = (_index + 1) % widget.messages.length);
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  /// Stops cycling, flashes the "ouch" line with a quick eye-bulge
  /// reaction, then hands off to the page's own navigation — the tap
  /// itself is a small moment, not just a silent jump to the next
  /// screen.
  Future<void> _handleTap() async {
    if (_reacting) return;
    _cycleTimer?.cancel();
    setState(() => _reacting = true);
    _eyeKey.currentState?.surprise();

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    widget.onTap();

    // Reset so the box is back to normal cycling if/when the user
    // returns to this page later.
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _reacting = false;
      _index = 0;
    });
    _scheduleCycle();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final text = _reacting ? _ouchLine : widget.messages[_index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF13130F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                FsmeEyePair(
                  key: _eyeKey,
                  mood: EyeMood.idle,
                  size: 20,
                  spacing: 6,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      text,
                      key: ValueKey(text),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFFD4AF37),
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
